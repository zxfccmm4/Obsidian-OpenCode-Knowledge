#!/usr/bin/env bash
# ============================================================
# uninstall.sh — 卸载 AI 知识库（可选删除 vault 和 npm 全局包）
#
# 默认只删除 OpenCode 配置和 Obsidian 插件配置；
# vault 目录、npm 全局包需要显式确认才删。
#
# 用法：
#   bash scripts/uninstall.sh
#   bash scripts/uninstall.sh --vault <vault 路径>
#   bash scripts/uninstall.sh --vault <vault 路径> --remove-vault --remove-packages --non-interactive
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DEFAULT_VAULT="$HOME/Desktop/我的知识库"
VAULT=""
REMOVE_VAULT=0
REMOVE_PACKAGES=0
NON_INTERACTIVE=0
AGENT_CHOICE="opencode"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/uninstall.sh [options]

Options:
  --vault PATH          指定 vault 路径（默认：~/Desktop/我的知识库）
  --agent NAME          AI agent：opencode | claude-code | codex（默认：opencode）
  --remove-vault        同时删除 vault 目录（含你的所有笔记，谨慎！）
  --remove-packages     同时卸载全局 npm 包（agent CLI + opencli）
  --non-interactive     不提问，按给定参数执行（必须显式指定要删什么）
  -h, --help            显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT="$2"; shift 2 ;;
    --agent)
      case "$2" in
        opencode|claude-code|codex|pi) AGENT_CHOICE="$2" ;;
        *) echo "无效的 --agent 值：$2" >&2; exit 1 ;;
      esac
      shift 2 ;;
    --remove-vault) REMOVE_VAULT=1; shift ;;
    --remove-packages) REMOVE_PACKAGES=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

# 按 agent 解析配置路径 / 插件目录 / npm 包名
case "$AGENT_CHOICE" in
  opencode)
    CONFIG_DIR="$HOME/.config/opencode"
    CONFIG_FILE="$CONFIG_DIR/opencode.json"
    PLUGIN_SLUG="claudian"
    AGENT_NPM_PKG="opencode-ai"
    AGENT_DISPLAY="OpenCode"
    ;;
  claude-code)
    CONFIG_DIR="$HOME/.claude"
    CONFIG_FILE="$CONFIG_DIR/settings.json"
    PLUGIN_SLUG="claudian"
    AGENT_NPM_PKG="@anthropic-ai/claude-code"
    AGENT_DISPLAY="Claude Code"
    ;;
  codex)
    CONFIG_DIR="$HOME/.codex"
    CONFIG_FILE="$CONFIG_DIR/config.toml"
    PLUGIN_SLUG="claudian"
    AGENT_NPM_PKG="@openai/codex"
    AGENT_DISPLAY="Codex"
    ;;
  pi)
    CONFIG_DIR="$HOME/.pi"
    CONFIG_FILE="$CONFIG_DIR/config.json"
    PLUGIN_SLUG="claudian"
    AGENT_NPM_PKG="@mariozechner/pi-coding-agent"
    AGENT_DISPLAY="Pi"
    ;;
esac

VAULT="${VAULT:-$DEFAULT_VAULT}"
VAULT="${VAULT/#\~/$HOME}"

confirm() {
  local prompt="$1"
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt (y/N): " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

echo ""
printf '%b即将清理以下内容（agent: %s）：%b\n' "$YELLOW" "$AGENT_DISPLAY" "$NC"
printf '  1. %s 配置：%s（会先备份）\n' "$AGENT_DISPLAY" "$CONFIG_FILE"
[[ -n "$VAULT" && -d "$VAULT" && -n "$PLUGIN_SLUG" ]] && printf '  2. vault 插件配置：%s/.obsidian/plugins/%s/\n' "$VAULT" "$PLUGIN_SLUG"
[[ "$REMOVE_VAULT" -eq 1 ]] && printf '%b3. 整个 vault 目录：%s（含所有笔记！）%b\n' "$RED" "$VAULT" "$NC"
[[ "$REMOVE_PACKAGES" -eq 1 ]] && printf '  4. npm 全局包：%s、@jackwener/opencli\n' "$AGENT_NPM_PKG"
echo ""

# 对高风险操作额外确认
if [[ "$REMOVE_VAULT" -eq 1 ]]; then
  if ! confirm "$(printf '%b这会永久删除你的 vault（%s）及其全部笔记，确定吗？%b' "$RED" "$VAULT" "$NC")"; then
    echo "已保留 vault。"
    REMOVE_VAULT=0
  fi
fi

if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  if ! confirm "开始清理吗？"; then
    echo "已取消，未做任何改动。"
    exit 0
  fi
fi
echo ""

# 1. 删除 agent 配置（先备份）
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP="$CONFIG_FILE.uninstall-$(date +%Y%m%d-%H%M%S)"
  cp "$CONFIG_FILE" "$BACKUP"
  rm -f "$CONFIG_FILE"
  printf '%b✓ 已删除 %s 配置，备份在：%s%b\n' "$GREEN" "$AGENT_DISPLAY" "$BACKUP" "$NC"
else
  printf '%b· %s 配置不存在，跳过%b\n' "$YELLOW" "$AGENT_DISPLAY" "$NC"
fi

# 2. 删除插件配置（不删 vault 本身）
if [[ -n "$PLUGIN_SLUG" && -n "$VAULT" && -d "$VAULT/.obsidian/plugins/$PLUGIN_SLUG" ]]; then
  rm -rf "$VAULT/.obsidian/plugins/$PLUGIN_SLUG"
  printf '%b✓ 已删除 Obsidian 插件配置（%s）%b\n' "$GREEN" "$PLUGIN_SLUG" "$NC"
else
  printf '%b· 插件配置不存在，跳过%b\n' "$YELLOW" "$NC"
fi
# opencode 用户可能用了 opencode-obsidian，一并尝试清理
if [[ "$AGENT_CHOICE" == "opencode" && -n "$VAULT" && -d "$VAULT/.obsidian/plugins/opencode-obsidian" ]]; then
  rm -rf "$VAULT/.obsidian/plugins/opencode-obsidian"
  printf '%b✓ 已删除 Obsidian 插件配置（opencode-obsidian）%b\n' "$GREEN" "$NC"
fi

# 3. 可选：删除整个 vault
if [[ "$REMOVE_VAULT" -eq 1 && -d "$VAULT" ]]; then
  rm -rf "$VAULT"
  printf '%b✓ 已删除 vault 目录：%s%b\n' "$RED" "$VAULT" "$NC"
fi

# 4. 可选：卸载 npm 全局包（agent CLI + opencli）
if [[ "$REMOVE_PACKAGES" -eq 1 ]]; then
  for pkg in "$AGENT_NPM_PKG" "@jackwener/opencli"; do
    if npm ls -g "$pkg" &>/dev/null; then
      npm uninstall -g "$pkg"
      echo -e "${GREEN}✓ 已卸载 $pkg${NC}"
    else
      echo -e "${YELLOW}· $pkg 未安装，跳过${NC}"
    fi
  done
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🧹 卸载完成                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Obsidian 应用本身和 Node.js 未被卸载（它们是系统级依赖，可能被其他程序使用）。"
echo "如需删除，请手动操作。"
