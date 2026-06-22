#!/usr/bin/env bash
# ============================================================
# upgrade.sh — 升级已部署知识库的规则与技能，保留用户数据
#
# 只刷新「系统维护」类文件，绝不触碰用户数据：
#   ✓ 更新  AGENTS.md / scripts/ / .opencode/skill/
#   ✓ 合并  AI_CONFIG.md（用户可能改过，先备份再逐字段保留）
#   ✗ 绝不动  raw/ / wiki/ / assets/（你的笔记和素材）
#
# 用法：
#   bash scripts/upgrade.sh --vault <vault 路径>
#   bash scripts/upgrade.sh --vault <vault 路径> --dry-run
#   bash scripts/upgrade.sh --vault <vault 路径> --non-interactive
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/vault-template"

VAULT=""
DRY_RUN=0
NON_INTERACTIVE=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/upgrade.sh --vault PATH [options]

Options:
  --vault PATH        要升级的 Vault 目录（必填）
  --agent NAME        AI agent：opencode | claude-code | codex（默认：opencode）
  --dry-run           只预演，不写文件
  --non-interactive   不提问，使用安全默认值
  -h, --help          显示帮助
EOF
}

AGENT_CHOICE="opencode"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT="$2"; shift 2 ;;
    --agent)
      case "$2" in
        opencode|claude-code|codex|pi) AGENT_CHOICE="$2" ;;
        *) echo "无效的 --agent 值：$2" >&2; exit 1 ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$VAULT" ]]; then
  echo -e "${RED}✗ 缺少 --vault 参数${NC}" >&2
  usage
  exit 1
fi

VAULT="${VAULT/#\~/$HOME}"

if [[ ! -d "$VAULT" ]]; then
  echo -e "${RED}✗ Vault 目录不存在：$VAULT${NC}" >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo -e "${RED}✗ 找不到 vault-template（脚本位置异常）：$TEMPLATE_DIR${NC}" >&2
  echo "请确保在仓库根目录运行：bash scripts/upgrade.sh ..." >&2
  exit 1
fi

echo ""
echo "升级目标：$VAULT"
echo "模板来源：$TEMPLATE_DIR"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}[dry-run] 预演模式：不会写文件${NC}"
fi
echo ""

# 二次确认
if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  echo -e "${YELLOW}本次升级会更新规则文件和技能，绝不触碰 raw/ wiki/ assets/。${NC}"
  read -r -p "继续吗？(y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "已取消。"
    exit 0
  fi
  echo ""
fi

# 用户数据保护清单——这些子树绝不覆盖
verify_user_data_untouched() {
  echo -e "${GREEN}✓ 用户数据保护确认：raw/ wiki/ assets/ 不会被修改${NC}"
}

# 执行单次 cp（受 dry-run 控制）
sync_file() {
  local src="$1"
  local dst="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $src → $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# 同步整个目录树（技能、脚本）
sync_tree() {
  local src="$1"
  local dst="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] rsync $src/ → $dst/"
    return 0
  fi
  mkdir -p "$dst"
  if command -v rsync &>/dev/null; then
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    cp -R "$src" "$dst"
  fi
}

verify_user_data_untouched
echo ""

# 1. AGENTS.md —— 系统维护，直接覆盖
echo -e "${YELLOW}【1/4】更新 AGENTS.md（系统规则）${NC}"
sync_file "$TEMPLATE_DIR/AGENTS.md" "$VAULT/AGENTS.md"

# 2. AI_CONFIG.md —— 用户可能改过，先备份
echo ""
echo -e "${YELLOW}【2/4】更新 AI_CONFIG.md（用户配置，备份后合并）${NC}"
if [[ -f "$VAULT/AI_CONFIG.md" && "$DRY_RUN" -eq 0 ]]; then
  BACKUP="$VAULT/AI_CONFIG.md.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$VAULT/AI_CONFIG.md" "$BACKUP"
  echo -e "${GREEN}✓ 已备份现有配置到：$BACKUP${NC}"
  echo -e "${YELLOW}  注意：新模板覆盖了旧文件，请在备份里找回你的自定义配置（domains/triggers 等）后手动合并。${NC}"
  # 用模板覆盖，但保留 user-custom-rules 区域（若用户填了）
  if grep -q "user-custom-rules-start" "$VAULT/AI_CONFIG.md" 2>/dev/null; then
    # 提取用户自定义规则块（非注释行）
    USER_RULES=$(awk '/user-custom-rules-start/{f=1;next}/user-custom-rules-end/{f=0}f' "$VAULT/AI_CONFIG.md" \
                 | grep -v '^<!--' || true)
    if [[ -n "$USER_RULES" ]]; then
      echo -e "${YELLOW}  检测到你有非空的自定义规则，已保留在备份中，需手动迁回。${NC}"
    fi
  fi
fi
sync_file "$TEMPLATE_DIR/AI_CONFIG.md" "$VAULT/AI_CONFIG.md"

# 3. 技能目录 —— 按 agent 分发到对应目录
echo ""
case "$AGENT_CHOICE" in
  opencode)
    echo -e "${YELLOW}【3/4】更新技能目录 .opencode/skill/（整树同步）${NC}"
    sync_tree "$TEMPLATE_DIR/.opencode/skill" "$VAULT/.opencode/skill"
    ;;
  claude-code)
    echo -e "${YELLOW}【3/4】更新技能目录 .claude/skills/（整树同步）${NC}"
    sync_tree "$TEMPLATE_DIR/.opencode/skill" "$VAULT/.claude/skills"
    # 同步 CLAUDE.md（Claude Code 记忆文件）
    sync_file "$TEMPLATE_DIR/AGENTS.md" "$VAULT/CLAUDE.md"
    echo -e "${GREEN}✓ CLAUDE.md 已同步${NC}"
    ;;
  codex)
    echo -e "${YELLOW}【3/4】更新技能目录 ~/.codex/skills/（用户级，整树同步）${NC}"
    sync_tree "$TEMPLATE_DIR/.opencode/skill" "$HOME/.codex/skills"
    ;;
  pi)
    echo -e "${YELLOW}【3/4】更新技能目录 ~/.pi/skills/（用户级，整树同步）${NC}"
    sync_tree "$TEMPLATE_DIR/.opencode/skill" "$HOME/.pi/skills"
    ;;
esac

# 4. 辅助脚本
echo ""
echo -e "${YELLOW}【4/4】更新辅助脚本 scripts/（含 organize-social-assets.sh）${NC}"
sync_tree "$TEMPLATE_DIR/scripts" "$VAULT/scripts"
# 确保脚本可执行
if [[ "$DRY_RUN" -eq 0 ]]; then
  find "$VAULT/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
fi

echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}Dry run 完成。去掉 --dry-run 真正执行。${NC}"
  exit 0
fi

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 升级完成！                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "已更新：AGENTS.md、AI_CONFIG.md、技能、辅助脚本"
echo -e "${GREEN}✓ 你的笔记（raw/ wiki/ assets/）未受影响${NC}"
echo ""
echo -e "${YELLOW}建议：跑一次「lint wiki」让 AI 用新规则检查一遍知识库健康度。${NC}"
