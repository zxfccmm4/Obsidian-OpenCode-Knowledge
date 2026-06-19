#!/usr/bin/env bash
# ============================================================
# organize-social-assets.sh
# 整理 opencli download 下载的社交媒体图片资产。
#
# 解决两个 AGENTS.md 里 AI 容易出错的确定性操作：
#   1. opencli download 会创建以「笔记 ID」命名的子目录，需要提升到「笔记标题」目录
#   2. 配图 markdown 引用要按当前 md 文件位置算对相对路径（raw/social/<domain>/ 上溯三层）
#
# 用法：
#   bash organize-social-assets.sh \
#     --vault <vault 根路径> \
#     --platform <Xiaohongshu|Douyin|...> \
#     --note-id <opencli 下载的 ID 子目录名> \
#     --title <笔记标题，作为新目录名> \
#     [--ref-from <md 文件路径，默认 raw/social/<domain>/<title>.md>]
#
# AI 在 Social Ingest 流程中应调用此脚本，而不是自己拼 mv / rmdir / 相对路径。
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAULT=""
PLATFORM=""
NOTE_ID=""
TITLE=""
REF_FROM=""

usage() {
  cat <<'EOF'
Usage:
  bash organize-social-assets.sh --vault PATH --platform NAME --note-id ID --title "标题" [--ref-from PATH]

Options:
  --vault PATH      Vault 根目录（绝对路径）
  --platform NAME   平台名（Xiaohongshu / Douyin / Twitter ...，用作 assets 子目录名）
  --note-id ID      opencli download 生成的 ID 子目录名
  --title "标题"    笔记标题，将作为新的资产目录名
  --ref-from PATH   生成图片引用时所基于的 md 文件路径（相对 vault 根）；
                    默认推断为 raw/social/<domain>/<title>.md，故通常可不传
  -h, --help        显示帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault) VAULT="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --note-id) NOTE_ID="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --ref-from) REF_FROM="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage; exit 1 ;;
  esac
done

# 参数校验
missing=0
[[ -z "$VAULT" ]] && { echo -e "${RED}✗ 缺少 --vault${NC}" >&2; missing=1; }
[[ -z "$PLATFORM" ]] && { echo -e "${RED}✗ 缺少 --platform${NC}" >&2; missing=1; }
[[ -z "$NOTE_ID" ]] && { echo -e "${RED}✗ 缺少 --note-id${NC}" >&2; missing=1; }
[[ -z "$TITLE" ]] && { echo -e "${RED}✗ 缺少 --title${NC}" >&2; missing=1; }
[[ "$missing" -eq 1 ]] && { usage; exit 1; }

# 扩展 ~/ 并校验 vault 存在
VAULT="${VAULT/#\~/$HOME}"
if [[ ! -d "$VAULT" ]]; then
  echo -e "${RED}✗ Vault 目录不存在：$VAULT${NC}" >&2
  exit 1
fi

SRC_DIR="$VAULT/assets/$PLATFORM/$NOTE_ID"
DST_DIR="$VAULT/assets/$PLATFORM/$TITLE"

# --- 第一步：把 ID 子目录的文件提升到标题目录 ---
if [[ ! -d "$SRC_DIR" ]]; then
  echo -e "${YELLOW}⚠ 未找到源目录：$SRC_DIR${NC}"
  echo "  如果 opencli download 用了别的目录结构，请用 --note-id 指明实际目录名。"
  # 不视为致命错误：可能已经整理过，或目录结构不同。继续生成引用。
else
  mkdir -p "$DST_DIR"

  moved=0
  shopt -s nullglob dotglob
  for f in "$SRC_DIR"/*; do
    mv "$f" "$DST_DIR/"
    moved=$((moved + 1))
  done
  shopt -u nullglob dotglob

  # 删除现在为空的 ID 子目录
  if [[ -z "$(ls -A "$SRC_DIR" 2>/dev/null)" ]]; then
    rmdir "$SRC_DIR"
  fi

  echo -e "${GREEN}✓ 已移动 $moved 个文件到：$DST_DIR${NC}"
  [[ "$moved" -gt 0 ]] || echo -e "${YELLOW}  源目录为空，未移动文件${NC}"
fi

# --- 第二步：生成可粘贴的 markdown 图片引用 ---
# 图片文件名保持 opencli 下载的原始命名（{note_id}_{index}.jpg）
echo ""
echo "## 配图（复制到 raw 笔记对应位置）"
echo ""

shopt -s nullglob
images=()
if [[ -d "$DST_DIR" ]]; then
  for img in "$DST_DIR"/*.{jpg,jpeg,png,webp,gif}; do
    images+=("$img")
  done
fi
shopt -u nullglob

if [[ ${#images[@]} -eq 0 ]]; then
  echo -e "${YELLOW}⚠ 标题目录下未找到图片：$DST_DIR${NC}"
  exit 0
fi

# 计算相对路径：从 raw/social/<domain>/ 下任意 md 到 assets 都需上溯三层
# REF_FROM 缺省按 raw/social/<domain>/<title>.md 推断 → 上溯 3 层
UP_LEVELS=3
prefix=""
idx=0
while [[ "$idx" -lt "$UP_LEVELS" ]]; do
  prefix="../$prefix"
  idx=$((idx + 1))
done
# 取图片文件名，按编号列出
for img in "${images[@]}"; do
  basename_img="$(basename "$img")"
  echo "![](${prefix}assets/$PLATFORM/$TITLE/$basename_img)"
done
# shellcheck disable=SC2034
: "${REF_FROM:=raw/social/<domain>/${TITLE}.md}"

echo ""
img_count=${#images[@]}
printf '%b✓ 共生成 %s 条图片引用（相对路径前缀：%s）%b\n' "$GREEN" "$img_count" "$prefix" "$NC"
