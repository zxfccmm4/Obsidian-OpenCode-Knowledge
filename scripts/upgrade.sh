#!/usr/bin/env bash
# ============================================================
# upgrade.sh — 升级已部署知识库的规则与技能，保留用户数据
#
# 只刷新「系统维护」类文件，绝不改动用户数据：
#   ✓ 更新  AGENTS.md（claude-code 同时更新 CLAUDE.md）/ 技能 / scripts/
#   ✓ 保留  AI_CONFIG.md：你改过就原样保留，新模板另存为 AI_CONFIG.md.new
#   ✓ 补齐  缺失的 raw/ wiki/ assets/ 目录，以及 wiki/index.md、wiki/log.md
#   ✗ 绝不改  raw/ / wiki/ / assets/ 里已有的文件（你的笔记和素材）
#   ✗ 绝不删  你自己装的其他技能、自己放进 scripts/ 的文件
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
DEFAULT_VAULT="$HOME/Desktop/我的知识库"

VAULT=""
AGENT_CHOICE=""
DRY_RUN=0
NON_INTERACTIVE=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/upgrade.sh [--vault PATH] [options]

Options:
  --vault PATH        要升级的 Vault 目录（默认：~/Desktop/我的知识库）
  --agent NAME        AI agent：opencode | claude-code | codex | pi
                      不传时按 vault 自动识别；codex / pi 的技能装在用户目录，需要显式指定
  --dry-run           只预演，不写文件
  --non-interactive   不提问，使用安全默认值
  -h, --help          显示帮助
EOF
}

require_value() {
  if [[ -z "${2:-}" ]]; then
    echo "缺少 $1 的值" >&2
    usage
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      require_value "$1" "${2:-}"
      VAULT="$2"
      shift 2 ;;
    --agent)
      require_value "$1" "${2:-}"
      case "$2" in
        opencode|codex|pi) AGENT_CHOICE="$2" ;;
        claude-code|claudecode|claude) AGENT_CHOICE="claude-code" ;;
        *) echo "无效的 --agent 值：$2" >&2; exit 1 ;;
      esac
      shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

VAULT="${VAULT:-$DEFAULT_VAULT}"
VAULT="${VAULT/#\~/$HOME}"

if [[ ! -d "$VAULT" ]]; then
  echo -e "${RED}✗ Vault 目录不存在：$VAULT${NC}" >&2
  echo "请用 --vault 指定你的知识库路径。" >&2
  exit 1
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo -e "${RED}✗ 找不到 vault-template（脚本位置异常）：$TEMPLATE_DIR${NC}" >&2
  echo "请确保在仓库根目录运行：bash scripts/upgrade.sh ..." >&2
  exit 1
fi

# 没指定 --agent 时按 vault 里的技能目录判断（codex / pi 的技能在用户目录，vault 里看不出来）
if [[ -z "$AGENT_CHOICE" ]]; then
  if [[ -d "$VAULT/.claude/skills" || -f "$VAULT/CLAUDE.md" ]]; then
    AGENT_CHOICE="claude-code"
  elif [[ -d "$VAULT/.opencode/skill" ]]; then
    AGENT_CHOICE="opencode"
  else
    echo -e "${RED}✗ 无法从 vault 判断你用的是哪个 agent，请用 --agent 指定（codex / pi 用户必须指定）${NC}" >&2
    exit 1
  fi
  echo "按 vault 内容识别 agent 为：${AGENT_CHOICE}（不对的话请用 --agent 指定）"
fi

echo ""
echo "升级目标：$VAULT"
echo "模板来源：$TEMPLATE_DIR"
echo "Agent：$AGENT_CHOICE"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}[dry-run] 预演模式：不会写文件${NC}"
fi
echo ""

# 二次确认
if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  echo -e "${YELLOW}本次升级会更新规则文件和技能；raw/ wiki/ assets/ 里已有的文件一个都不会改。${NC}"
  read -r -p "继续吗？(y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "已取消。"
    exit 0
  fi
  echo ""
fi

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

# 逐个同步技能：同名技能整体替换，目标目录里的其他技能（比如你自己装的）保持不动
sync_skills() {
  local dst="$1"
  local skill_dir
  for skill_dir in "$TEMPLATE_DIR/.opencode/skill"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] $skill_dir → $dst/${skill_dir##*/}"
      continue
    fi
    mkdir -p "$dst"
    rm -rf "${dst:?}/${skill_dir##*/}"
    cp -R "$skill_dir" "$dst/"
  done
}

# 文件是否和模板的某个历史版本一模一样（即用户从没改过）。
# 只在仓库是 git clone 时能判断；下载 ZIP 的情况一律按「改过」处理，宁可多保留。
is_unmodified_template_copy() {
  local file="$1"
  local rel_path="$2"
  local rev

  [[ -d "$REPO_ROOT/.git" ]] || return 1
  command -v git &>/dev/null || return 1
  while IFS= read -r rev; do
    if git -C "$REPO_ROOT" show "$rev:$rel_path" 2>/dev/null | cmp -s - "$file"; then
      return 0
    fi
  done < <(git -C "$REPO_ROOT" log --format=%H -- "$rel_path" 2>/dev/null)
  return 1
}

# 1. 补齐缺失的目录和索引文件（已存在的一律不动）
echo -e "${YELLOW}【1/5】检查知识库目录结构${NC}"
for dir in raw wiki assets; do
  if [[ ! -d "$VAULT/$dir" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] mkdir $VAULT/$dir"
    else
      mkdir -p "$VAULT/$dir"
    fi
    echo "  + 已创建 $dir/"
  fi
done
for file in wiki/index.md wiki/log.md; do
  if [[ ! -f "$VAULT/$file" ]]; then
    sync_file "$TEMPLATE_DIR/$file" "$VAULT/$file"
    echo "  + 已创建 $file"
  fi
done

# 2. AGENTS.md —— 系统维护，直接覆盖
echo ""
echo -e "${YELLOW}【2/5】更新 AGENTS.md（系统规则）${NC}"
sync_file "$TEMPLATE_DIR/AGENTS.md" "$VAULT/AGENTS.md"
if [[ "$AGENT_CHOICE" == "claude-code" ]]; then
  # CLAUDE.md 是 Claude Code 的记忆文件，内容与 AGENTS.md 相同
  sync_file "$TEMPLATE_DIR/AGENTS.md" "$VAULT/CLAUDE.md"
  echo -e "${GREEN}✓ CLAUDE.md 已同步${NC}"
fi

# 3. AI_CONFIG.md —— 用户配置：改过就原样保留
echo ""
echo -e "${YELLOW}【3/5】检查 AI_CONFIG.md（你的个人配置）${NC}"
if [[ ! -f "$VAULT/AI_CONFIG.md" ]]; then
  sync_file "$TEMPLATE_DIR/AI_CONFIG.md" "$VAULT/AI_CONFIG.md"
  echo -e "${GREEN}✓ 已创建 AI_CONFIG.md${NC}"
elif cmp -s "$TEMPLATE_DIR/AI_CONFIG.md" "$VAULT/AI_CONFIG.md"; then
  echo -e "${GREEN}✓ AI_CONFIG.md 已是最新${NC}"
elif is_unmodified_template_copy "$VAULT/AI_CONFIG.md" "vault-template/AI_CONFIG.md"; then
  sync_file "$TEMPLATE_DIR/AI_CONFIG.md" "$VAULT/AI_CONFIG.md"
  echo -e "${GREEN}✓ 你没改过 AI_CONFIG.md，已直接更新到新模板${NC}"
else
  sync_file "$TEMPLATE_DIR/AI_CONFIG.md" "$VAULT/AI_CONFIG.md.new"
  echo -e "${GREEN}✓ 你修改过 AI_CONFIG.md，已原样保留${NC}"
  echo -e "${YELLOW}  新模板另存为 AI_CONFIG.md.new。需要新配置项时对比后手动合并，也可以直接让 AI 帮你合并。${NC}"
fi

# 4. 技能目录 —— 按 agent 分发到对应目录
echo ""
case "$AGENT_CHOICE" in
  opencode)
    echo -e "${YELLOW}【4/5】更新技能目录 .opencode/skill/${NC}"
    sync_skills "$VAULT/.opencode/skill"
    ;;
  claude-code)
    echo -e "${YELLOW}【4/5】更新技能目录 .claude/skills/${NC}"
    sync_skills "$VAULT/.claude/skills"
    ;;
  codex)
    echo -e "${YELLOW}【4/5】更新技能目录 ~/.codex/skills/（用户级）${NC}"
    sync_skills "$HOME/.codex/skills"
    ;;
  pi)
    echo -e "${YELLOW}【4/5】更新技能目录 ~/.pi/skills/（用户级）${NC}"
    sync_skills "$HOME/.pi/skills"
    ;;
esac

# 5. 辅助脚本 —— 逐个文件更新，不删除你自己放进 scripts/ 的文件
echo ""
echo -e "${YELLOW}【5/5】更新辅助脚本 scripts/（含 organize-social-assets.sh）${NC}"
for script in "$TEMPLATE_DIR/scripts"/*; do
  [[ -f "$script" ]] || continue
  sync_file "$script" "$VAULT/scripts/${script##*/}"
done
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
echo -e "已更新：AGENTS.md、技能、辅助脚本"
echo -e "${GREEN}✓ 你的笔记（raw/ wiki/ assets/）和 AI_CONFIG.md 里的自定义内容未受影响${NC}"
echo ""
echo -e "${YELLOW}建议：跑一次「lint wiki」让 AI 用新规则检查一遍知识库健康度。${NC}"
