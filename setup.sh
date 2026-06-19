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
CONFIG_FILE="$HOME/.config/opencode/opencode.json"
readonly CONFIG_FILE

DRY_RUN=0
NON_INTERACTIVE=0
OVERWRITE_EXISTING=0
OVERWRITE_CONFIG=0
VAULT_PATH=""
NODE_INSTALL_CHOICE=""
PROVIDER_CHOICE=""
API_KEY="${OPENCODE_API_KEY:-}"

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
  --provider NAME         AI provider：zhipu | anthropic | openai | google | openrouter | deepseek | skip
  --api-key KEY           提供 AI provider 的 API Key
  --overwrite-config      允许覆盖已有的 ~/.config/opencode/opencode.json
  -h, --help              显示帮助

Environment:
  OPENCODE_API_KEY        当未传 --api-key 时，读取这个环境变量作为 API Key
EOF
}

print_banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║    AI 知识库 · 一键部署                   ║${NC}"
  echo -e "${BLUE}║    Obsidian + OpenCode + 知识库规则        ║${NC}"
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

install_global_npm_package() {
  local package_name="$1"

  if run_cmd npm install -g "$package_name"; then
    return 0
  fi

  echo -e "${YELLOW}全局安装需要管理员权限，尝试 sudo...${NC}"
  run_cmd sudo npm install -g "$package_name"
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

build_provider_config() {
  case "$PROVIDER_CHOICE" in
    1)
      MODEL_ID="zhipuglm/glm-5.2"
      PROVIDER_BLOCK="\"zhipuglm\": {
      \"name\": \"智谱 GLM\",
      \"npm\": \"@ai-sdk/openai-compatible\",
      \"models\": {
        \"glm-5.2\": { \"name\": \"GLM-5.2\" },
        \"glm-5.1\": { \"name\": \"GLM-5.1\" },
        \"glm-5\": { \"name\": \"GLM-5\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\",
        \"baseURL\": \"https://open.bigmodel.cn/api/coding/paas/v4\"
      }
    }"
      ;;
    2)
      MODEL_ID="anthropic/claude-opus-4-8"
      PROVIDER_BLOCK="\"anthropic\": {
      \"models\": {
        \"claude-opus-4-8\": { \"name\": \"Claude Opus 4.8\" },
        \"claude-sonnet-4-6\": { \"name\": \"Claude Sonnet 4.6\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
      ;;
    3)
      MODEL_ID="openai/gpt-5.5"
      PROVIDER_BLOCK="\"openai\": {
      \"models\": {
        \"gpt-5.5\": { \"name\": \"GPT-5.5\" },
        \"gpt-5.4-mini\": { \"name\": \"GPT-5.4 Mini\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
      ;;
    4)
      MODEL_ID="google/gemini-3.1-pro-preview"
      PROVIDER_BLOCK="\"google\": {
      \"models\": {
        \"gemini-3.1-pro-preview\": { \"name\": \"Gemini 3.1 Pro\" },
        \"gemini-3-flash\": { \"name\": \"Gemini 3 Flash\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
      ;;
    5)
      MODEL_ID="openrouter/anthropic/claude-opus-4.8"
      PROVIDER_BLOCK="\"openrouter\": {
      \"models\": {
        \"anthropic/claude-opus-4.8\": { \"name\": \"Claude Opus 4.8\" },
        \"openai/gpt-5.5\": { \"name\": \"GPT-5.5\" },
        \"google/gemini-3.1-pro-preview\": { \"name\": \"Gemini 3.1 Pro\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
      ;;
    6)
      MODEL_ID="deepseek/deepseek-v4-pro"
      PROVIDER_BLOCK="\"deepseek\": {
      \"name\": \"DeepSeek\",
      \"npm\": \"@ai-sdk/openai-compatible\",
      \"models\": {
        \"deepseek-v4-pro\": { \"name\": \"DeepSeek V4 Pro\" },
        \"deepseek-v4-flash\": { \"name\": \"DeepSeek V4 Flash\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\",
        \"baseURL\": \"https://api.deepseek.com/v1\"
      }
    }"
      ;;
    *)
      MODEL_ID=""
      PROVIDER_BLOCK=""
      ;;
  esac
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

step "【第 3 步 / 共 6 步】安装 OpenCode"
echo "正在安装或更新 OpenCode..."
install_global_npm_package "opencode-ai"

OPENCODE_PATH="$(command -v opencode 2>/dev/null || true)"
if [[ -z "$OPENCODE_PATH" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    OPENCODE_PATH="opencode"
  else
    echo -e "${RED}✗ OpenCode 安装完成后仍未找到 opencode 命令${NC}"
    echo "请确认 npm 全局 bin 已加入 PATH，然后重新运行脚本。"
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${GREEN}✓ OpenCode 预演安装完成：$OPENCODE_PATH${NC}"
else
  echo -e "${GREEN}✓ OpenCode 已就绪：$OPENCODE_PATH $(opencode --version 2>/dev/null || echo "")${NC}"
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
echo -e "${GREEN}✓ 知识库已创建${NC}"
echo ""

step "【第 6 步 / 共 6 步】配置 AI 服务"
prompt_for_provider_choice

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
SHOULD_WRITE_CONFIG=1
MODEL_ID=""
PROVIDER_BLOCK=""

run_cmd mkdir -p "$OPENCODE_CONFIG_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
  echo -e "${YELLOW}⚠ 检测到已有 OpenCode 配置：$CONFIG_FILE${NC}"
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
build_provider_config

if [[ "$SHOULD_WRITE_CONFIG" -eq 1 && "$PROVIDER_CHOICE" != "7" && -n "$PROVIDER_BLOCK" ]]; then
  if [[ -f "$CONFIG_FILE" ]]; then
    CONFIG_BACKUP_FILE="$CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    run_cmd cp "$CONFIG_FILE" "$CONFIG_BACKUP_FILE"
    echo -e "${YELLOW}已备份现有配置到：$CONFIG_BACKUP_FILE${NC}"
  fi

  CONFIG_CONTENT=$(cat <<CONFIG_EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": { "options": { "store": false } },
    "plan": { "options": { "store": false } }
  },
  "model": "${MODEL_ID}",
  "provider": {
    ${PROVIDER_BLOCK}
  }
}
CONFIG_EOF
)
  write_file "$CONFIG_FILE" "$CONFIG_CONTENT"
  echo -e "${GREEN}✓ AI 服务配置完成${NC}"
elif [[ "$PROVIDER_CHOICE" == "7" ]]; then
  echo -e "${YELLOW}跳过 AI 服务配置。稍后请手动编辑 ~/.config/opencode/opencode.json${NC}"
fi
echo ""

if [[ -n "$OPENCODE_PATH" ]]; then
  PLUGIN_DIR="$VAULT_PATH/.obsidian/plugins/opencode-obsidian"
  NODE_BIN_PATH="$(command -v node 2>/dev/null || true)"
  if [[ -z "$NODE_BIN_PATH" ]]; then
    NODE_BIN_PATH="node"
  fi

  PLUGIN_CONTENT=$(cat <<DATADAT
{
  "port": 14096,
  "hostname": "127.0.0.1",
  "autoStart": true,
  "opencodePath": "$OPENCODE_PATH",
  "startupTimeout": 45000,
  "defaultViewLocation": "sidebar",
  "injectWorkspaceContext": false,
  "maxNotesInContext": 20,
  "maxSelectionLength": 2000,
  "customCommand": "$NODE_BIN_PATH $OPENCODE_PATH serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md",
  "useCustomCommand": true
}
DATADAT
)

  write_file "$PLUGIN_DIR/data.json" "$PLUGIN_CONTENT"
  echo -e "${GREEN}✓ 插件配置已生成${NC}"
fi

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
echo "  2. 安装 opencode-obsidian 插件："
echo "     推荐方式：在 Obsidian 设置 → 第三方插件 → 搜索安装「BRAT」"
echo "              → 打开 BRAT 设置 → Add Plugin → 输入：mtymek/opencode-obsidian"
echo ""
echo "  3. 启用插件后，侧边栏会出现 OpenCode 面板"
echo "     点击开始对话，试试说：「帮我创建一篇笔记」"
echo ""
echo -e "${BLUE}💡 自定义提示：${NC}编辑 $VAULT_PATH/AI_CONFIG.md 可以修改 AI 行为"
echo "   例如：添加知识域、修改触发词、调整输出语言等"
echo ""
echo -e "详细说明请参考同目录下的 ${BLUE}deployment-guide.md${NC}"
echo -e "插件配置与排障请参考 ${BLUE}opencode-obsidian-setup-troubleshooting.md${NC}"
echo -e "一键诊断脚本：${BLUE}bash \"$SCRIPT_DIR/scripts/opencode-obsidian-doctor.sh\" --vault \"$VAULT_PATH\"${NC}"
echo ""
