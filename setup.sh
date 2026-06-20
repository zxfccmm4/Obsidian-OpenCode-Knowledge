#!/usr/bin/env bash
# ============================================================
# AI 知识库一键部署脚本
# 适用于 macOS | 面向非技术用户
# ============================================================
# 单一事实源：支持的模型清单（更新模型时只改这里，再同步 GUIDE_FOR_AI.md）
# 核对来源（2026-06）：
#   zhipu     → glm-5.2 / glm-5.1 / glm-5     (docs.bigmodel.cn; GLM-5.2 当前旗舰，100万上下文)
#   anthropic → claude-opus-4-8 / claude-sonnet-4-6   (platform.claude.com; Opus 4.8 当前旗舰)
#   openai    → gpt-5.5 / gpt-5.4-mini       (developers.openai.com; GPT-5.5 当前旗舰)
#   google    → gemini-3.1-pro-preview / gemini-3-flash   (ai.google.dev; 原 gemini-3-pro 已 shut down)
#   openrouter→ anthropic/claude-opus-4.8 / openai/gpt-5.5
#   deepseek  → deepseek-v4-pro / deepseek-v4-flash
#               ⚠ deepseek-chat / deepseek-reasoner 将于 2026-07-24 下线，已弃用
# Node.js 要求：>= 21（OpenCode 运行时要求）
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
TEMPLATE_DIR="$SCRIPT_DIR/vault-template"
readonly TEMPLATE_DIR
DEFAULT_VAULT_PATH="$HOME/Desktop/我的知识库"
readonly DEFAULT_VAULT_PATH
# CONFIG_FILE 由 resolve_agent() 根据 --agent 填充（不再硬编码）

DRY_RUN=0
NON_INTERACTIVE=0
OVERWRITE_EXISTING=0
OVERWRITE_CONFIG=0
VAULT_PATH=""
NODE_INSTALL_CHOICE=""
PROVIDER_CHOICE=""
API_KEY="${OPENCODE_API_KEY:-}"
AGENT_CHOICE=""

# Agent 相关变量由 resolve_agent() 根据上面 AGENT_CHOICE 填充：
AGENT_ID=""              # opencode | claude-code | codex
AGENT_DISPLAY_NAME=""    # OpenCode | Claude Code | Codex
AGENT_NPM_PKG=""         # npm 包名
AGENT_BIN=""             # 二进制命令名
AGENT_CONFIG_DIR=""      # 用户配置目录
AGENT_CONFIG_FILE=""     # 配置文件全路径
AGENT_CONFIG_FORMAT=""   # json | toml
AGENT_VAULT_SKILL_DIR="" # 项目内技能目录（相对 vault 根）；codex 为空（用用户级）
AGENT_USER_SKILL_DIR=""  # 用户级技能目录；仅 codex 非空
AGENT_MEMORY_FILE=""     # 记忆文件名（AGENTS.md）
AGENT_NEEDS_CLAUDE_MD=0  # 是否额外生成 CLAUDE.md（仅 claude-code）
AGENT_OBSIDIAN_PLUGIN="" # Obsidian 插件仓庘认（owner/repo）；无则为空
AGENT_SERVE_CMD=""       # 后台服务命令（仅 opencode）；空表示该 agent 无 serve 模式

usage() {
  cat <<'EOF'
Usage:
  bash setup.sh [options]

Options:
  --dry-run               只预演，不写文件、不安装依赖
  --non-interactive       不进行交互提问；使用参数或安全默认值
  --vault PATH            指定知识库目录（默认：~/Desktop/我的知识库）
  --overwrite-existing    非交互模式下允许覆盖已存在的知识库目录
  --node-install MODE     缺少 Node.js 时的处理方式：brew | manual | skip
  --agent NAME            AI agent：opencode | claude-code | codex（默认：opencode）
  --provider NAME         AI provider：zhipu | anthropic | openai | google | openrouter | deepseek | skip
  --api-key KEY           提供 AI provider 的 API Key
  --overwrite-config      允许覆盖已有的 agent 配置文件
  -h, --help              显示帮助

Environment:
  OPENCODE_API_KEY        当未传 --api-key 时，读取这个环境变量作为 API Key

Agent 说明：
  opencode     默认。带 Obsidian 插件（opencode-obsidian），可在 Obsidian 内对话。
  claude-code  Claude Code。带 Obsidian 插件（claudian），可在 Obsidian 内对话。
  codex        OpenAI Codex。Obsidian 插件生态尚不成熟，主要在终端使用。
EOF
}

print_banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║    AI 知识库 · 一键部署                   ║${NC}"
  echo -e "${BLUE}║    Obsidian + 知识库规则 + AI Agent       ║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
  echo ""
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "${YELLOW}[dry-run] 预演模式：不会写文件，也不会安装依赖${NC}"
    echo ""
  fi
}

step() {
  echo -e "${YELLOW}$1${NC}"
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

write_file() {
  local path="$1"
  local content="$2"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would write $path"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
}

require_value() {
  local option_name="$1"
  local option_value="$2"

  if [[ -z "$option_value" ]]; then
    echo "缺少 ${option_name} 的值" >&2
    usage
    exit 1
  fi
}

open_url() {
  local url="$1"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would open $url"
    return 0
  fi

  open "$url"
}

normalize_node_install_choice() {
  case "$1" in
    1|brew)
      echo "1"
      ;;
    2|manual)
      echo "2"
      ;;
    3|skip)
      echo "3"
      ;;
    "")
      echo ""
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

normalize_provider_choice() {
  case "$1" in
    1|zhipu|zhipuglm|glm)
      echo "1"
      ;;
    2|anthropic)
      echo "2"
      ;;
    3|openai)
      echo "3"
      ;;
    4|google|gemini)
      echo "4"
      ;;
    5|openrouter)
      echo "5"
      ;;
    6|deepseek)
      echo "6"
      ;;
    7|skip|"")
      echo "7"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

is_dangerous_path() {
  case "$1" in
    ""|"."|".."|"/"|"$HOME"|"$HOME/"|"$SCRIPT_DIR"|"$SCRIPT_DIR/")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# 根据 AGENT_CHOICE 填充所有 agent 相关变量。
# 这是多 agent 支持的核心抽象层：所有 agent 差异都收敛到这里。
# 注：AGENT_MEMORY_FILE / AGENT_CONFIG_FORMAT / AGENT_VAULT_SKILL_DIR 为诊断与
# 文档性元数据（标明各 agent 的记忆文件名、配置格式、技能目录约定），保留供未来扩展。
# shellcheck disable=SC2034
resolve_agent() {
  local agent="${AGENT_CHOICE:-opencode}"

  case "$agent" in
    opencode)
      AGENT_ID="opencode"
      AGENT_DISPLAY_NAME="OpenCode"
      AGENT_NPM_PKG="opencode-ai"
      AGENT_BIN="opencode"
      AGENT_CONFIG_DIR="$HOME/.config/opencode"
      AGENT_CONFIG_FILE="$HOME/.config/opencode/opencode.json"
      AGENT_CONFIG_FORMAT="json"
      AGENT_VAULT_SKILL_DIR=".opencode/skill"
      AGENT_USER_SKILL_DIR=""
      AGENT_MEMORY_FILE="AGENTS.md"
      AGENT_NEEDS_CLAUDE_MD=0
      AGENT_OBSIDIAN_PLUGIN="mtymek/opencode-obsidian"
      AGENT_SERVE_CMD="serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md"
      ;;
    claude-code|claudecode|claude)
      AGENT_ID="claude-code"
      AGENT_DISPLAY_NAME="Claude Code"
      AGENT_NPM_PKG="@anthropic-ai/claude-code"
      AGENT_BIN="claude"
      AGENT_CONFIG_DIR="$HOME/.claude"
      AGENT_CONFIG_FILE="$HOME/.claude/settings.json"
      AGENT_CONFIG_FORMAT="json"
      AGENT_VAULT_SKILL_DIR=".claude/skills"
      AGENT_USER_SKILL_DIR=""
      AGENT_MEMORY_FILE="CLAUDE.md"
      AGENT_NEEDS_CLAUDE_MD=1
      AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
      AGENT_SERVE_CMD=""
      ;;
    codex)
      AGENT_ID="codex"
      AGENT_DISPLAY_NAME="Codex"
      AGENT_NPM_PKG="@openai/codex"
      AGENT_BIN="codex"
      AGENT_CONFIG_DIR="$HOME/.codex"
      AGENT_CONFIG_FILE="$HOME/.codex/config.toml"
      AGENT_CONFIG_FORMAT="toml"
      AGENT_VAULT_SKILL_DIR=""
      AGENT_USER_SKILL_DIR="$HOME/.codex/skills"
      AGENT_MEMORY_FILE="AGENTS.md"
      AGENT_NEEDS_CLAUDE_MD=0
      AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
      AGENT_SERVE_CMD=""
      ;;
    *)
      echo -e "${RED}✗ 无效的 --agent 值：$agent${NC}" >&2
      echo "可选值：opencode | claude-code | codex" >&2
      exit 1
      ;;
  esac
}

install_global_npm_package() {
  local package_name="$1"

  if run_cmd npm install -g "$package_name"; then
    return 0
  fi

  echo -e "${YELLOW}全局安装需要管理员权限，尝试 sudo...${NC}"
  run_cmd sudo npm install -g "$package_name"
}

prompt_for_agent_choice() {
  if [[ -n "$AGENT_CHOICE" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    AGENT_CHOICE="opencode"
    return 0
  fi

  echo ""
  echo "请选择驱动知识库的 AI Agent："
  echo ""
  echo "  1) OpenCode     — 默认。带 Obsidian 插件，可在 Obsidian 内对话（推荐）"
  echo "  2) Claude Code  — Anthropic 官方 CLI。带 claudian 插件，可在 Obsidian 内对话"
  echo "  3) Codex        — OpenAI 官方 CLI。主要在终端使用（Obsidian 插件尚不成熟）"
  echo ""
  read -r -p "> 请选择 (1-3，默认 1): " AGENT_ANSWER
  case "$AGENT_ANSWER" in
    2) AGENT_CHOICE="claude-code" ;;
    3) AGENT_CHOICE="codex" ;;
    *) AGENT_CHOICE="opencode" ;;
  esac
}

prompt_for_provider_choice() {
  if [[ -n "$PROVIDER_CHOICE" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    PROVIDER_CHOICE="7"
    return 0
  fi

  echo ""
  echo "知识库需要一个 AI 大模型来驱动。请选择你的 AI 服务提供商："
  echo ""
  echo "  1) 智谱 GLM    — 国内服务，中文友好，注册简单（推荐国内用户）"
  echo "  2) Anthropic   — Claude 系列模型"
  echo "  3) OpenAI      — GPT 系列模型"
  echo "  4) Google      — Gemini 系列模型"
  echo "  5) OpenRouter  — 多模型网关，一个 Key 用多个模型"
  echo "  6) DeepSeek    — DeepSeek 模型（国内服务）"
  echo "  7) 跳过        — 稍后手动配置"
  echo ""
  read -r -p "> 请选择 (1-7): " PROVIDER_CHOICE
}

prompt_for_api_key_if_needed() {
  if [[ "$PROVIDER_CHOICE" == "7" ]]; then
    return 0
  fi

  if [[ -n "$API_KEY" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      API_KEY="<REQUIRED_API_KEY>"
      echo -e "${YELLOW}[dry-run] 未提供 API Key，使用占位符预演配置写入${NC}"
      return 0
    fi

    echo -e "${RED}✗ 非交互模式下，provider 不是 skip 时必须提供 API Key${NC}"
    echo "请使用 --api-key 或环境变量 OPENCODE_API_KEY。"
    exit 1
  fi

  case "$PROVIDER_CHOICE" in
    1)
      echo ""
      echo "请先获取 API Key："
      echo "  1. 访问 https://open.bigmodel.cn"
      echo "  2. 注册账号 →「API Keys」→ 创建 Key"
      echo ""
      ;;
    2)
      echo ""
      echo "请先获取 API Key：https://console.anthropic.com/settings/keys"
      echo ""
      ;;
    3)
      echo ""
      echo "请先获取 API Key：https://platform.openai.com/api-keys"
      echo ""
      ;;
    4)
      echo ""
      echo "请先获取 API Key：https://aistudio.google.com/apikey"
      echo ""
      ;;
    5)
      echo ""
      echo "请先获取 API Key：https://openrouter.ai/settings/keys"
      echo ""
      ;;
    6)
      echo ""
      echo "请先获取 API Key：https://platform.deepseek.com/api_keys"
      echo ""
      ;;
  esac

  read -r -s -p "> 请粘贴你的 API Key: " API_KEY
  echo ""

  if [[ -z "$API_KEY" ]]; then
    echo -e "${YELLOW}跳过。${NC}"
    PROVIDER_CHOICE="7"
  fi
}

# 各 provider 的共享元数据（所有 agent 共用，单一事实源）。
# 填充 P_NAME / P_MODELS / P_BASE_URL / P_ENV_KEY（P_ENV_KEY 用于 claude-code/codex 的 env 变量名）。
load_provider_meta() {
  case "$PROVIDER_CHOICE" in
    1)
      P_NAME="智谱 GLM"
      P_MODELS="glm-5.2 glm-5.1 glm-5"
      P_DEFAULT_MODEL="glm-5.2"
      P_BASE_URL="https://open.bigmodel.cn/api/coding/paas/v4"
      P_ENV_KEY="ZHIPU_API_KEY"
      P_OPENCODE_PROVIDER="zhipuglm"
      P_OPENCODE_NPM="@ai-sdk/openai-compatible"
      ;;
    2)
      P_NAME="Anthropic"
      P_MODELS="claude-opus-4-8 claude-sonnet-4-6"
      P_DEFAULT_MODEL="claude-opus-4-8"
      P_BASE_URL=""
      P_ENV_KEY="ANTHROPIC_API_KEY"
      P_OPENCODE_PROVIDER="anthropic"
      P_OPENCODE_NPM=""
      ;;
    3)
      P_NAME="OpenAI"
      P_MODELS="gpt-5.5 gpt-5.4-mini"
      P_DEFAULT_MODEL="gpt-5.5"
      P_BASE_URL=""
      P_ENV_KEY="OPENAI_API_KEY"
      P_OPENCODE_PROVIDER="openai"
      P_OPENCODE_NPM=""
      ;;
    4)
      P_NAME="Google"
      P_MODELS="gemini-3.1-pro-preview gemini-3-flash"
      P_DEFAULT_MODEL="gemini-3.1-pro-preview"
      P_BASE_URL=""
      P_ENV_KEY="GOOGLE_API_KEY"
      P_OPENCODE_PROVIDER="google"
      P_OPENCODE_NPM=""
      ;;
    5)
      P_NAME="OpenRouter"
      P_MODELS="anthropic/claude-opus-4.8 openai/gpt-5.5 google/gemini-3.1-pro-preview"
      P_DEFAULT_MODEL="anthropic/claude-opus-4.8"
      P_BASE_URL="https://openrouter.ai/api/v1"
      P_ENV_KEY="OPENROUTER_API_KEY"
      P_OPENCODE_PROVIDER="openrouter"
      P_OPENCODE_NPM=""
      ;;
    6)
      P_NAME="DeepSeek"
      P_MODELS="deepseek-v4-pro deepseek-v4-flash"
      P_DEFAULT_MODEL="deepseek-v4-pro"
      P_BASE_URL="https://api.deepseek.com/v1"
      P_ENV_KEY="DEEPSEEK_API_KEY"
      P_OPENCODE_PROVIDER="deepseek"
      P_OPENCODE_NPM="@ai-sdk/openai-compatible"
      ;;
    *)
      P_NAME=""
      P_MODELS=""
      P_DEFAULT_MODEL=""
      P_BASE_URL=""
      P_ENV_KEY=""
      P_OPENCODE_PROVIDER=""
      P_OPENCODE_NPM=""
      ;;
  esac
}

# 构建并写入指定 agent 的配置文件。返回 0 表示已写入，1 表示跳过。
write_agent_config() {
  if [[ "$SHOULD_WRITE_CONFIG" -eq 0 || "$PROVIDER_CHOICE" == "7" ]]; then
    echo -e "${YELLOW}跳过 AI 服务配置。稍后请手动编辑 ${AGENT_CONFIG_FILE}${NC}"
    return 1
  fi

  load_provider_meta
  if [[ -z "$P_NAME" ]]; then
    echo -e "${YELLOW}跳过 AI 服务配置。${NC}"
    return 1
  fi

  # 备份现有配置
  if [[ -f "$AGENT_CONFIG_FILE" ]]; then
    CONFIG_BACKUP_FILE="$AGENT_CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    run_cmd cp "$AGENT_CONFIG_FILE" "$CONFIG_BACKUP_FILE"
    echo -e "${YELLOW}已备份现有配置到：$CONFIG_BACKUP_FILE${NC}"
  fi

  case "$AGENT_ID" in
    opencode)    write_opencode_config ;;
    claude-code) write_claude_code_config ;;
    codex)       write_codex_config ;;
  esac

  echo -e "${GREEN}✓ ${AGENT_DISPLAY_NAME} 服务配置完成${NC}"
  return 0
}

# OpenCode: ~/.config/opencode/opencode.json（JSON）
write_opencode_config() {
  run_cmd mkdir -p "$AGENT_CONFIG_DIR"
  local models_json=""
  local first=1
  for m in $P_MODELS; do
    local display="$m"
    # OpenRouter 的 model 带斜杠，显示名取最后一段更友好
    [[ "$PROVIDER_CHOICE" == "5" ]] && display="${m##*/}"
    if [[ "$first" -eq 1 ]]; then
      models_json="        \"$m\": { \"name\": \"$display\" }"
      first=0
    else
      models_json="$models_json,
        \"$m\": { \"name\": \"$display\" }"
    fi
  done

  local name_line=""
  [[ -n "$P_OPENCODE_NPM" || "$PROVIDER_CHOICE" == "1" || "$PROVIDER_CHOICE" == "6" ]] && name_line="      \"name\": \"$P_NAME\",
"
  local npm_line=""
  [[ -n "$P_OPENCODE_NPM" ]] && npm_line="      \"npm\": \"$P_OPENCODE_NPM\",
"
  local baseurl_line=""
  [[ -n "$P_BASE_URL" ]] && baseurl_line="        \"baseURL\": \"$P_BASE_URL\",
"

  local config_content
  config_content=$(cat <<OPENCODE_EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": { "options": { "store": false } },
    "plan": { "options": { "store": false } }
  },
  "model": "${P_OPENCODE_PROVIDER}/${P_DEFAULT_MODEL}",
  "provider": {
    "${P_OPENCODE_PROVIDER}": {
${name_line}${npm_line}      "models": {
${models_json}
      },
      "options": {
${baseurl_line}        "apiKey": "${API_KEY}"
      }
    }
  }
}
OPENCODE_EOF
)
  write_file "$AGENT_CONFIG_FILE" "$config_content"
}

# Claude Code: ~/.claude/settings.json（JSON）+ 指引设置 env 变量
write_claude_code_config() {
  run_cmd mkdir -p "$AGENT_CONFIG_DIR"
  # Claude Code 通过 settings.json 的 env 段注入 API key/base url，model 在 settings 里设。
  # 第三方 provider（智谱/DeepSeek/OpenRouter）走 ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN。
  local env_block=""
  local model_setting=""

  case "$PROVIDER_CHOICE" in
    2) # 原生 Anthropic
      env_block="\"ANTHROPIC_API_KEY\": \"${API_KEY}\""
      model_setting="$P_DEFAULT_MODEL"
      ;;
    1|6|5) # OpenAI 兼容的第三方：走 base url
      local base="$P_BASE_URL"
      # 智谱的 coding 端点对 Claude Code 需要用通用端点
      [[ "$PROVIDER_CHOICE" == "1" ]] && base="https://open.bigmodel.cn/api/paas/v4"
      env_block="\"ANTHROPIC_BASE_URL\": \"$base\", \"ANTHROPIC_AUTH_TOKEN\": \"${API_KEY}\""
      model_setting="$P_DEFAULT_MODEL"
      ;;
    3|4) # OpenAI / Google：Claude Code 原生不支持，提示用户用原生或 OpenRouter
      echo -e "${YELLOW}⚠ Claude Code 原生只支持 Anthropic 系；已用 env 指向 $P_NAME，但兼容性可能受限。${NC}"
      env_block="\"ANTHROPIC_BASE_URL\": \"$P_BASE_URL\", \"ANTHROPIC_AUTH_TOKEN\": \"${API_KEY}\""
      model_setting="$P_DEFAULT_MODEL"
      ;;
  esac

  local config_content="{
  \"env\": {
    $env_block
  },
  \"model\": \"$model_setting\"
}"
  write_file "$AGENT_CONFIG_FILE" "$config_content"
  echo -e "${YELLOW}  配置已写入 ${AGENT_CONFIG_FILE}${NC}"
  echo -e "${YELLOW}  提示：也可改用环境变量（export ANTHROPIC_API_KEY=...）。${NC}"
}

# Codex: ~/.codex/config.toml（TOML）
write_codex_config() {
  run_cmd mkdir -p "$AGENT_CONFIG_DIR"
  # Codex 用 [model_providers.<id>] 定义 provider，model = "provider/model"。
  # wire_api: chat（OpenAI 兼容）或 responses（OpenAI 原生）。
  local provider_id="$P_OPENCODE_PROVIDER"
  local wire_api="chat"
  [[ "$PROVIDER_CHOICE" == "3" ]] && wire_api="responses"

  local base_url="$P_BASE_URL"
  # 智谱用通用端点
  [[ "$PROVIDER_CHOICE" == "1" ]] && base_url="https://open.bigmodel.cn/api/paas/v4"

  local config_content="# ${AGENT_DISPLAY_NAME} 配置 — 由 setup.sh 生成
[model_providers.${provider_id}]
name = \"${P_NAME}\"
base_url = \"${base_url}\"
wire_api = \"${wire_api}\"
env_key = \"${P_ENV_KEY}\"

[model_providers.${provider_id}.model_provider_info]
[[model_providers.${provider_id}.models]]"
  # Codex 主要用 model 字段（顶层）
  config_content="# ${AGENT_DISPLAY_NAME} 配置 — 由 setup.sh 生成
model = \"${provider_id}/${P_DEFAULT_MODEL}\"
model_provider = \"${provider_id}\"

[model_providers.${provider_id}]
name = \"${P_NAME}\"
base_url = \"${base_url}\"
wire_api = \"${wire_api}\"
env_key = \"${P_ENV_KEY}\"
"
  write_file "$AGENT_CONFIG_FILE" "$config_content"
  echo -e "${YELLOW}  请设置环境变量：export ${P_ENV_KEY}=\"${API_KEY}\"${NC}"
  echo -e "${YELLOW}  或写入 ~/.codex/auth.json（Codex 也会读取）。${NC}"
}

validate_option_combinations() {
  if [[ "$NON_INTERACTIVE" -eq 1 && "$PROVIDER_CHOICE" == "7" && -n "$API_KEY" ]]; then
    echo -e "${YELLOW}⚠ 已提供 API Key，但 provider=skip；将忽略 API Key${NC}"
    API_KEY=""
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 && -z "$NODE_INSTALL_CHOICE" ]] && ! command -v node &>/dev/null; then
    echo -e "${RED}✗ 非交互模式下，缺少 Node.js 时必须提供 --node-install${NC}"
    echo "可选值：brew | manual | skip"
    exit 1
  fi

  if [[ -n "$PROVIDER_CHOICE" && "$PROVIDER_CHOICE" != "7" && -z "$API_KEY" && "$DRY_RUN" -eq 0 && "$NON_INTERACTIVE" -eq 1 ]]; then
    echo -e "${RED}✗ 非交互模式下，provider 不是 skip 时必须提供 API Key${NC}"
    echo "请使用 --api-key 或环境变量 OPENCODE_API_KEY。"
    exit 1
  fi

  if [[ "$OVERWRITE_CONFIG" -eq 1 && "$PROVIDER_CHOICE" == "7" ]]; then
    echo -e "${YELLOW}⚠ --overwrite-config 在 provider=skip 时没有效果${NC}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --vault)
      require_value "--vault" "${2:-}"
      VAULT_PATH="$2"
      shift 2
      ;;
    --overwrite-existing)
      OVERWRITE_EXISTING=1
      shift
      ;;
    --node-install)
      require_value "--node-install" "${2:-}"
      NODE_INSTALL_CHOICE="$(normalize_node_install_choice "$2")" || {
        echo "无效的 --node-install 值：$2" >&2
        usage
        exit 1
      }
      shift 2
      ;;
    --agent)
      require_value "--agent" "${2:-}"
      case "$2" in
        opencode|claude-code|claudecode|claude|codex)
          AGENT_CHOICE="$2"
          ;;
        *)
          echo "无效的 --agent 值：$2" >&2
          echo "可选值：opencode | claude-code | codex" >&2
          usage
          exit 1
          ;;
      esac
      shift 2
      ;;
    --provider)
      require_value "--provider" "${2:-}"
      PROVIDER_CHOICE="$(normalize_provider_choice "$2")" || {
        echo "无效的 --provider 值：$2" >&2
        usage
        exit 1
      }
      shift 2
      ;;
    --api-key)
      require_value "--api-key" "${2:-}"
      API_KEY="$2"
      shift 2
      ;;
    --overwrite-config)
      OVERWRITE_CONFIG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage
      exit 1
      ;;
  esac
done

validate_option_combinations
print_banner

step "【选择 AI Agent】"
prompt_for_agent_choice
resolve_agent
echo -e "${BLUE}已选择 Agent: ${AGENT_DISPLAY_NAME}${NC}"
echo ""

step "【第 1 步 / 共 6 步】选择知识库存放位置"
echo ""
echo "你的知识库（Vault）要放在哪里？"
echo "直接回车 = 桌面上的「我的知识库」文件夹"

if [[ -z "$VAULT_PATH" ]]; then
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    VAULT_PATH="$DEFAULT_VAULT_PATH"
  else
    read -r -p "> 请输入路径（或直接回车）: " VAULT_PATH
  fi
fi

if [[ -z "$VAULT_PATH" ]]; then
  VAULT_PATH="$DEFAULT_VAULT_PATH"
fi

VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

if is_dangerous_path "$VAULT_PATH"; then
  echo -e "${RED}✗ 这个路径过于危险，不能作为知识库目录：$VAULT_PATH${NC}"
  echo "请重新运行脚本，并选择一个单独的新目录。"
  exit 1
fi

if [[ -d "$VAULT_PATH" ]]; then
  echo -e "${YELLOW}⚠ 目录已存在：$VAULT_PATH${NC}"

  if [[ "$OVERWRITE_EXISTING" -eq 0 ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      echo -e "${RED}✗ 非交互模式下不会自动覆盖已有目录${NC}"
      echo "请改用 --overwrite-existing，或换一个 --vault 路径。"
      exit 1
    fi

    read -r -p "  要覆盖吗？(y/N): " OVERWRITE
    if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
      echo "已取消。"
      exit 0
    fi
  fi

  run_cmd rm -rf "$VAULT_PATH"
fi

echo -e "${GREEN}✓ 知识库将创建在：$VAULT_PATH${NC}"
echo ""

step "【第 2 步 / 共 6 步】检查 Node.js"

NODE_PATH="$(command -v node 2>/dev/null || true)"
NPM_PATH="$(command -v npm 2>/dev/null || true)"

if [[ -n "$NODE_PATH" ]]; then
  NODE_VERSION="$("$NODE_PATH" -v | sed 's/^v//')"
  NODE_MAJOR="${NODE_VERSION%%.*}"
  echo -e "${GREEN}✓ 已安装 Node.js v${NODE_VERSION}${NC}"

  # OpenCode 运行时要求 Node >= 21
  if [[ "$NODE_MAJOR" -lt 21 ]]; then
    echo -e "${YELLOW}⚠ Node.js 版本过低（当前 v${NODE_VERSION}，OpenCode 需要 v21+）${NC}"
    echo "建议升级：brew upgrade node   或   访问 https://nodejs.org/zh-cn 下载 LTS 版"
    echo ""
    if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
      read -r -p "  仍然继续部署吗？(y/N): " NODE_LOW_VERSION_CONTINUE
      if [[ "$NODE_LOW_VERSION_CONTINUE" != "y" && "$NODE_LOW_VERSION_CONTINUE" != "Y" ]]; then
        echo "已取消。请先升级 Node.js 到 v21+。"
        exit 0
      fi
    elif [[ "$DRY_RUN" -eq 0 ]]; then
      echo -e "${RED}✗ 非交互模式下 Node 版本过低（需要 v21+），退出${NC}"
      echo "请先升级 Node.js 后重试。"
      exit 1
    fi
  fi
else
  echo -e "${RED}✗ 未检测到 Node.js${NC}"
  echo ""
  echo "Node.js 是 OpenCode 运行的基础，需要先安装。"
  echo ""

  if [[ -z "$NODE_INSTALL_CHOICE" ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      echo -e "${RED}✗ 非交互模式下，缺少 Node.js 时必须指定 --node-install${NC}"
      echo "可选值：brew | manual | skip"
      exit 1
    fi

    echo "请选择安装方式："
    echo "  1) 自动安装（使用 Homebrew，推荐已装 brew 的用户）"
    echo "  2) 手动下载（打开 Node.js 官网下载页）"
    echo "  3) 跳过（我稍后自己装）"
    read -r -p "> 请选择 (1/2/3): " NODE_INSTALL_CHOICE
    NODE_INSTALL_CHOICE="$(normalize_node_install_choice "$NODE_INSTALL_CHOICE")" || {
      echo "无效选择，退出。"
      exit 1
    }
  fi

  case "$NODE_INSTALL_CHOICE" in
    1)
      if ! command -v brew &>/dev/null; then
        echo -e "${RED}未检测到 Homebrew。${NC}"
        echo "请先安装 Homebrew："
        # shellcheck disable=SC2016
        printf '%s\n' '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo "或改用 --node-install manual。"
        exit 1
      fi

      echo "正在通过 Homebrew 安装 Node.js..."
      run_cmd brew install node
      if [[ "$DRY_RUN" -eq 1 ]]; then
        NODE_PATH="node"
        NPM_PATH="npm"
      else
        NODE_PATH="$(command -v node 2>/dev/null || true)"
        NPM_PATH="$(command -v npm 2>/dev/null || true)"
      fi
      ;;
    2)
      echo "正在打开 Node.js 下载页..."
      open_url "https://nodejs.org/zh-cn"
      echo ""
      echo -e "${YELLOW}请下载并安装 Node.js 后，重新运行此脚本。${NC}"
      exit 0
      ;;
    3)
      echo -e "${YELLOW}跳过。请先安装 Node.js 后，再重新运行此脚本。${NC}"
      exit 0
      ;;
    *)
      echo "无效选择，退出。"
      exit 1
      ;;
  esac
fi

if [[ -z "$NPM_PATH" ]]; then
  echo -e "${RED}✗ 未检测到 npm${NC}"
  echo "请重新安装 Node.js（需包含 npm），然后重新运行此脚本。"
  exit 1
fi
echo ""

step "【第 3 步 / 共 6 步】安装 ${AGENT_DISPLAY_NAME}"
echo "正在安装或更新 ${AGENT_DISPLAY_NAME}..."
install_global_npm_package "$AGENT_NPM_PKG"

AGENT_BIN_PATH="$(command -v "$AGENT_BIN" 2>/dev/null || true)"
if [[ -z "$AGENT_BIN_PATH" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    AGENT_BIN_PATH="$AGENT_BIN"
  else
    echo -e "${RED}✗ ${AGENT_DISPLAY_NAME} 安装完成后仍未找到 ${AGENT_BIN} 命令${NC}"
    echo "请确认 npm 全局 bin 已加入 PATH，然后重新运行脚本。"
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${GREEN}✓ ${AGENT_DISPLAY_NAME} 预演安装完成：$AGENT_BIN_PATH${NC}"
else
  echo -e "${GREEN}✓ ${AGENT_DISPLAY_NAME} 已就绪：$AGENT_BIN_PATH $("$AGENT_BIN" --version 2>/dev/null || echo "")${NC}"
fi
echo ""

step "【第 4 步 / 共 6 步】安装 OpenCLI"
echo "正在安装 OpenCLI..."
install_global_npm_package "@jackwener/opencli"

OPENCLI_PATH="$(command -v opencli 2>/dev/null || true)"
if [[ -n "$OPENCLI_PATH" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "${GREEN}✓ OpenCLI 预演安装完成：$OPENCLI_PATH${NC}"
  else
    echo -e "${GREEN}✓ OpenCLI 已就绪：$OPENCLI_PATH $(opencli --version 2>/dev/null || echo "")${NC}"
  fi
else
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo -e "${GREEN}✓ OpenCLI 预演安装完成：opencli${NC}"
  else
    echo -e "${YELLOW}⚠ OpenCLI 安装未成功，社交媒体采集功能需要手动安装${NC}"
    echo "  手动安装命令：npm install -g @jackwener/opencli"
  fi
fi
echo ""

step "【第 5 步 / 共 6 步】创建知识库"
run_cmd cp -R "$TEMPLATE_DIR" "$VAULT_PATH"
run_cmd find "$VAULT_PATH" -name ".gitkeep" -delete

# 按选择的 agent 分发技能目录 + 记忆文件
distribute_skills_and_memory() {
  local vault_skill_source="$VAULT_PATH/.opencode/skill"

  case "$AGENT_ID" in
    opencode)
      # 模板已含 .opencode/skill/，无需移动；AGENTS.md 已在 vault 根
      :
      ;;
    claude-code)
      # 复制技能到 .claude/skills/，移除 .opencode/
      if [[ -d "$vault_skill_source" ]]; then
        run_cmd mkdir -p "$VAULT_PATH/.claude"
        run_cmd cp -R "$vault_skill_source" "$VAULT_PATH/.claude/skills"
        run_cmd rm -rf "$VAULT_PATH/.opencode"
      fi
      ;;
    codex)
      # Codex 技能是用户级：复制到 ~/.codex/skills/
      if [[ -n "$AGENT_USER_SKILL_DIR" && -d "$vault_skill_source" ]]; then
        run_cmd mkdir -p "$(dirname "$AGENT_USER_SKILL_DIR")"
        run_cmd cp -R "$vault_skill_source" "$AGENT_USER_SKILL_DIR"
        echo -e "${GREEN}✓ 技能已安装到用户目录：$AGENT_USER_SKILL_DIR${NC}"
      fi
      # vault 内移除 .opencode/（codex 不用它）；AGENTS.md 保留（codex 加载它）
      run_cmd rm -rf "$VAULT_PATH/.opencode"
      ;;
  esac

  # Claude Code 额外需要 CLAUDE.md（内容与 AGENTS.md 相同，Claude Code 自动加载）
  if [[ "$AGENT_NEEDS_CLAUDE_MD" -eq 1 && -f "$VAULT_PATH/AGENTS.md" ]]; then
    run_cmd cp "$VAULT_PATH/AGENTS.md" "$VAULT_PATH/CLAUDE.md"
    echo -e "${GREEN}✓ 已生成 CLAUDE.md（Claude Code 记忆文件）${NC}"
  fi
}
distribute_skills_and_memory

echo -e "${GREEN}✓ 知识库已创建${NC}"
echo ""

step "【第 6 步 / 共 6 步】配置 AI 服务"
prompt_for_provider_choice

SHOULD_WRITE_CONFIG=1

if [[ -f "$AGENT_CONFIG_FILE" ]]; then
  echo -e "${YELLOW}⚠ 检测到已有 ${AGENT_DISPLAY_NAME} 配置：$AGENT_CONFIG_FILE${NC}"
  echo "覆盖前会自动备份旧配置。"

  if [[ "$OVERWRITE_CONFIG" -eq 0 ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      SHOULD_WRITE_CONFIG=0
      echo -e "${YELLOW}将保留现有配置。本次只创建知识库和插件配置。${NC}"
    else
      read -r -p "> 是否继续覆盖这个配置？(y/N): " OVERWRITE_CONFIG_ANSWER
      if [[ "$OVERWRITE_CONFIG_ANSWER" != "y" && "$OVERWRITE_CONFIG_ANSWER" != "Y" ]]; then
        SHOULD_WRITE_CONFIG=0
        echo -e "${YELLOW}将保留现有配置。本次只创建知识库和插件配置。${NC}"
      fi
    fi
  fi
fi

if [[ "$SHOULD_WRITE_CONFIG" -eq 0 ]]; then
  PROVIDER_CHOICE="7"
fi

prompt_for_api_key_if_needed
write_agent_config
echo ""

# 根据 agent 生成 Obsidian 插件配置（仅 opencode / claude-code；codex 无成熟插件）
write_obsidian_plugin_config() {
  if [[ -z "$AGENT_OBSIDIAN_PLUGIN" ]]; then
    echo -e "${YELLOW}⚠ ${AGENT_DISPLAY_NAME} 暂无成熟的 Obsidian 插件，请在终端使用 ${AGENT_BIN}。${NC}"
    return 0
  fi
  if [[ -z "$AGENT_BIN_PATH" ]]; then
    echo -e "${YELLOW}⚠ 未检测到 ${AGENT_BIN}，跳过 Obsidian 插件配置。${NC}"
    return 0
  fi

  local plugin_slug="${AGENT_OBSIDIAN_PLUGIN##*/}"
  local plugin_dir="$VAULT_PATH/.obsidian/plugins/$plugin_slug"
  local node_bin_path
  node_bin_path="$(command -v node 2>/dev/null || true)"
  [[ -z "$node_bin_path" ]] && node_bin_path="node"

  case "$AGENT_ID" in
    opencode)
      local plugin_content
      plugin_content=$(cat <<OPCODE_DAT
{
  "port": 14096,
  "hostname": "127.0.0.1",
  "autoStart": true,
  "opencodePath": "$AGENT_BIN_PATH",
  "startupTimeout": 45000,
  "defaultViewLocation": "sidebar",
  "injectWorkspaceContext": false,
  "maxNotesInContext": 20,
  "maxSelectionLength": 2000,
  "customCommand": "$node_bin_path $AGENT_BIN_PATH ${AGENT_SERVE_CMD}",
  "useCustomCommand": true
}
OPCODE_DAT
)
      write_file "$plugin_dir/data.json" "$plugin_content"
      echo -e "${GREEN}✓ Obsidian 插件配置已生成（opencode-obsidian）${NC}"
      ;;
    claude-code|codex)
      # claudian 支持多个 agent（Claude Code / Codex / OpenCode）。
      # 配置用 cliPathsByHost 按 OS 映射对应 agent 的 CLI 路径。
      local host_os="darwin"
      local plugin_content
      plugin_content=$(cat <<CLAUDE_DAT
{
  "autoStart": true,
  "defaultViewLocation": "sidebar",
  "maxNotesInContext": 20,
  "maxSelectionLength": 2000,
  "cliPathsByHost": {
    "${host_os}": {
      "${AGENT_BIN}": "$AGENT_BIN_PATH"
    }
  }
}
CLAUDE_DAT
)
      write_file "$plugin_dir/data.json" "$plugin_content"
      echo -e "${GREEN}✓ Obsidian 插件配置已生成（claudian · ${AGENT_DISPLAY_NAME}）${NC}"
      ;;
  esac
}

write_obsidian_plugin_config

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 部署完成！                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}Dry run complete.${NC} 没有实际写入文件，也没有安装依赖。"
  echo ""
  echo "如果想真的执行，可去掉 --dry-run 后重新运行同一条命令。"
  exit 0
fi

echo -e "知识库位置：${BLUE}$VAULT_PATH${NC}"
echo ""
echo -e "${YELLOW}接下来你需要做 3 件事：${NC}"
echo ""
echo "  1. 打开 Obsidian → 「打开文件夹作为仓库」→ 选择："
echo "     $VAULT_PATH"
echo ""
echo "  2. 安装 ${AGENT_DISPLAY_NAME} 的 Obsidian 插件："
echo "     推荐方式：在 Obsidian 设置 → 第三方插件 → 搜索安装「BRAT」"
echo "              → 打开 BRAT 设置 → Add Plugin → 输入：${AGENT_OBSIDIAN_PLUGIN}"
echo ""
echo "  3. 启用插件后，侧边栏会出现 ${AGENT_DISPLAY_NAME} 面板，"
echo "     点击开始对话，试试说：「帮我创建一篇笔记」"
echo ""
echo -e "${BLUE}💡 自定义提示：${NC}编辑 $VAULT_PATH/AI_CONFIG.md 可以修改 AI 行为"
echo "   例如：添加知识域、修改触发词、调整输出语言等"
echo ""
echo -e "详细说明请参考同目录下的 ${BLUE}deployment-guide.md${NC}"
# 按 agent 指向对应排障文档
TROUBLESHOOTING_DOC="opencode-obsidian-setup-troubleshooting.md"
[[ "$AGENT_ID" == "claude-code" ]] && TROUBLESHOOTING_DOC="claude-code-setup-troubleshooting.md"
[[ "$AGENT_ID" == "codex" ]] && TROUBLESHOOTING_DOC="codex-setup-troubleshooting.md"
echo -e "插件配置与排障请参考 ${BLUE}${TROUBLESHOOTING_DOC}${NC}"
echo -e "一键诊断脚本：${BLUE}bash \"$SCRIPT_DIR/scripts/opencode-obsidian-doctor.sh\" --vault \"$VAULT_PATH\"${NC}"
echo ""
