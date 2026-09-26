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
KEEP_EXISTING=0
OVERWRITE_CONFIG=0
VAULT_PATH=""
VAULT_MODE="create"      # create | keep（保留已有笔记）| replace（旧目录改名备份后新建）
VAULT_BACKUP_PATH=""
NODE_INSTALL_CHOICE=""
PROVIDER_CHOICE=""
API_KEY="${OPENCODE_API_KEY:-}"
AGENT_CHOICE=""
PLUGIN_CHOICE=""

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
AGENT_OBSIDIAN_PLUGIN="" # Obsidian 插件仓库（owner/repo）；无则为空
AGENT_SERVE_CMD=""       # 后台服务命令（仅 opencode）；空表示该 agent 无 serve 模式

usage() {
  cat <<'EOF'
Usage:
  bash setup.sh [options]

Options:
  --dry-run               只预演，不写文件、不安装依赖
  --non-interactive       不进行交互提问；使用参数或安全默认值
  --vault PATH            指定知识库目录（默认：~/Desktop/我的知识库）
  --keep-existing         目录已存在时：保留里面的笔记，只更新规则和技能（适合重装、切换 agent）
  --overwrite-existing    目录已存在时：先把旧目录改名备份，再新建知识库（不会删除任何文件）
  --node-install MODE     缺少 Node.js 时的处理方式：brew | manual | skip
  --agent NAME            AI agent：opencode | claude-code | codex | pi（默认：opencode）
  --plugin NAME           Obsidian 插件：claudian（默认）| opencode-obsidian（仅 opencode）
  --provider NAME         AI provider：zhipu | anthropic | openai | google | openrouter | deepseek | skip
  --api-key KEY           提供 AI provider 的 API Key
  --overwrite-config      允许更新已有的 agent 配置文件（会先备份）
  -h, --help              显示帮助

Environment:
  OPENCODE_API_KEY        当未传 --api-key 时，读取这个环境变量作为 API Key

Agent 说明：
  opencode     默认。原生支持全部 6 个 provider。
  claude-code  Claude Code。只能连 Anthropic 协议的服务：anthropic | zhipu | deepseek | openrouter。
  codex        OpenAI Codex。
  pi           Pi，开源轻量 CLI。
  四个 agent 都用 claudian 插件在 Obsidian 内对话。
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

# 用 node 更新 JSON 配置：保留文件里已有的其他设置，只改我们负责的字段；
# 转义交给 JSON.stringify，路径或 API Key 里有引号、反斜杠也不会把文件写坏。
# 用法：update_json_file <文件> <JS 代码> [参数...]
#   JS 代码里可用：cfg（现有内容；文件不存在或解析失败时为 {}）、args（参数数组）、
#   secret（API Key，经环境变量传给 node，不会出现在进程列表里）
update_json_file() {
  local path="$1"
  local js="$2"
  shift 2

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would update $path"
    return 0
  fi

  mkdir -p "$(dirname "$path")"
  KB_SECRET="$API_KEY" node -e '
    const fs = require("fs");
    const [file, code, ...args] = process.argv.slice(1);
    let cfg = {};
    if (fs.existsSync(file)) {
      try {
        cfg = JSON.parse(fs.readFileSync(file, "utf8"));
      } catch (err) {
        console.error("⚠ " + file + " 不是标准 JSON（可能含注释），将重新生成");
      }
    }
    if (!cfg || typeof cfg !== "object" || Array.isArray(cfg)) cfg = {};
    new Function("cfg", "args", "secret", code)(cfg, args, process.env.KB_SECRET || "");
    // 配置里可能有 API Key，只允许自己读写
    fs.writeFileSync(file, JSON.stringify(cfg, null, 2) + "\n", { mode: 0o600 });
    fs.chmodSync(file, 0o600);
  ' "$path" "$js" "$@"
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
  local path="$1"
  local home_dir script_dir

  # 已存在的目录先解析成真实路径，防止 ~/Desktop/.. 这类写法绕过检查
  if [[ -d "$path" ]]; then
    path="$(cd "$path" && pwd -P)"
  fi
  home_dir="$(cd "$HOME" && pwd -P)"
  script_dir="$(cd "$SCRIPT_DIR" && pwd -P)"

  case "$path" in
    ""|"/"|"/Users"|"/Applications"|"/Library"|"/System"|"/Volumes")
      return 0
      ;;
    "$home_dir"|"$home_dir/Desktop"|"$home_dir/Documents"|"$home_dir/Downloads"|"$home_dir/Library"|"$script_dir")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# 清理交互输入的路径：去掉首尾空白和成对引号，还原把文件夹拖进终端时产生的反斜杠转义
clean_path_input() {
  local input="$1"

  input="${input#"${input%%[![:space:]]*}"}"
  input="${input%"${input##*[![:space:]]}"}"
  if [[ "$input" == \"*\" || "$input" == \'*\' ]]; then
    input="${input:1:${#input}-2}"
  fi
  printf '%s' "$input" | sed 's/\\\(.\)/\1/g'
}

# 目标目录已存在时决定怎么处理。脚本不会删除已有目录：
#   keep    = 保留里面的笔记，只更新规则、技能和辅助脚本
#   replace = 旧目录改名备份，再新建知识库
choose_existing_vault_mode() {
  echo -e "${YELLOW}⚠ 目录已存在：$VAULT_PATH${NC}"
  if [[ ! -f "$VAULT_PATH/AGENTS.md" ]]; then
    echo "  （这个目录看起来不是本项目创建的知识库）"
  fi

  if [[ "$KEEP_EXISTING" -eq 1 ]]; then
    VAULT_MODE="keep"
    return 0
  fi
  if [[ "$OVERWRITE_EXISTING" -eq 1 ]]; then
    VAULT_MODE="replace"
    return 0
  fi
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    echo -e "${RED}✗ 非交互模式下不会自动处理已有目录${NC}"
    echo "请加 --keep-existing（保留笔记）或 --overwrite-existing（旧目录改名备份后新建），或换一个 --vault 路径。"
    exit 1
  fi

  echo ""
  echo "  1) 保留里面的笔记，只更新规则和技能（重装、切换 agent 时选这个）"
  echo "  2) 把旧目录改名备份，然后新建一个空白知识库"
  echo "  3) 取消"
  read -r -p "> 请选择 (1/2/3，默认 3): " EXISTING_VAULT_ANSWER
  case "$EXISTING_VAULT_ANSWER" in
    1) VAULT_MODE="keep" ;;
    2) VAULT_MODE="replace" ;;
    *)
      echo "已取消。"
      exit 0
      ;;
  esac
}

# Claude Code 只会说 Anthropic 协议，OpenAI / Google 没有对应的兼容端点
provider_supported_by_agent() {
  if [[ "$AGENT_ID" == "claude-code" ]]; then
    case "$1" in
      3|4) return 1 ;;
    esac
  fi
  return 0
}

ensure_provider_supported() {
  if provider_supported_by_agent "$PROVIDER_CHOICE"; then
    return 0
  fi
  echo -e "${RED}✗ Claude Code 只能连接 Anthropic 协议的服务，不支持 OpenAI / Google${NC}" >&2
  echo "可选：anthropic | zhipu | deepseek | openrouter；想用 GPT / Gemini，请改用 --agent opencode 或 codex。" >&2
  exit 1
}

# 把模板里的每个技能复制到目标目录：同名技能整体替换，目标目录里的其他技能（例如用户自己装的）保持不动
install_skills() {
  local target_dir="$1"
  local skill_dir

  [[ -n "$target_dir" ]] || return 1
  run_cmd mkdir -p "$target_dir"
  for skill_dir in "$TEMPLATE_DIR/.opencode/skill"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_dir="${skill_dir%/}"
    run_cmd rm -rf "$target_dir/${skill_dir##*/}"
    run_cmd cp -R "$skill_dir" "$target_dir/"
  done
}

# 根据 AGENT_CHOICE 填充所有 agent 相关变量。
# 这是多 agent 支持的核心抽象层：所有 agent 差异都收敛到这里。
# 注：AGENT_MEMORY_FILE / AGENT_VAULT_SKILL_DIR / AGENT_CONFIG_DIR 为诊断与
# 文档性元数据（标明各 agent 的记忆文件名、技能目录、配置目录约定），保留供未来扩展。
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
      AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
      AGENT_SERVE_CMD=""
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
    pi)
      AGENT_ID="pi"
      AGENT_DISPLAY_NAME="Pi"
      AGENT_NPM_PKG="@mariozechner/pi-coding-agent"
      AGENT_BIN="pi"
      AGENT_CONFIG_DIR="$HOME/.pi"
      AGENT_CONFIG_FILE="$HOME/.pi/config.json"
      AGENT_CONFIG_FORMAT="json"
      AGENT_VAULT_SKILL_DIR=""
      AGENT_USER_SKILL_DIR="$HOME/.pi/skills"
      AGENT_MEMORY_FILE="AGENTS.md"
      AGENT_NEEDS_CLAUDE_MD=0
      AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
      AGENT_SERVE_CMD=""
      ;;
    *)
      echo -e "${RED}✗ 无效的 --agent 值：$agent${NC}" >&2
      echo "可选值：opencode | claude-code | codex | pi" >&2
      exit 1
      ;;
  esac
}

# 根据 PLUGIN_CHOICE 调整 Obsidian 插件选择。
# 默认 claudian（所有 agent 通用）；--plugin opencode-obsidian 仅 opencode 可用，切回 serve 模式。
apply_plugin_choice() {
  local plugin="${PLUGIN_CHOICE:-claudian}"

  case "$plugin" in
    opencode-obsidian)
      if [[ "$AGENT_ID" != "opencode" ]]; then
        echo -e "${YELLOW}⚠ --plugin opencode-obsidian 仅适用于 opencode agent，已忽略并使用 claudian${NC}"
        AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
        AGENT_SERVE_CMD=""
        return 0
      fi
      AGENT_OBSIDIAN_PLUGIN="mtymek/opencode-obsidian"
      AGENT_SERVE_CMD="serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md"
      ;;
    claudian|*)
      AGENT_OBSIDIAN_PLUGIN="YishenTu/claudian"
      AGENT_SERVE_CMD=""
      ;;
  esac
}

install_global_npm_package() {
  local package_name="$1"
  local global_root

  # Homebrew / nvm 装的 Node 全局目录归当前用户，不需要 sudo；官网安装包装的通常需要。
  # 先判断再决定，避免网络失败时也去要开机密码。
  global_root="$(npm root -g 2>/dev/null || true)"
  if [[ -n "$global_root" && ! -d "$global_root" ]]; then
    global_root="$(dirname "$global_root")"
  fi

  if [[ -n "$global_root" && ! -w "$global_root" ]]; then
    echo -e "${YELLOW}npm 全局目录需要管理员权限（${global_root}），将使用 sudo 安装，可能需要输入开机密码${NC}"
    run_cmd sudo npm install -g "$package_name" && return 0
  else
    run_cmd npm install -g "$package_name" && return 0
  fi

  echo -e "${RED}✗ 安装 $package_name 失败${NC}"
  echo "  如果是网络问题（国内常见），可以切换到国内镜像后重新运行脚本："
  echo "    npm config set registry https://registry.npmmirror.com"
  return 1
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
  echo "  1) OpenCode     — 默认。原生 6 大模型，claudian 插件可在 Obsidian 内对话（推荐）"
  echo "  2) Claude Code  — Anthropic 官方 CLI，推理能力强，claudian 插件支持"
  echo "  3) Codex        — OpenAI 官方 CLI，开放生态，claudian 插件支持"
  echo "  4) Pi           — 开源轻量 CLI，支持 15+ provider，claudian 插件支持"
  echo ""
  read -r -p "> 请选择 (1-4，默认 1): " AGENT_ANSWER
  case "$AGENT_ANSWER" in
    2) AGENT_CHOICE="claude-code" ;;
    3) AGENT_CHOICE="codex" ;;
    4) AGENT_CHOICE="pi" ;;
    *) AGENT_CHOICE="opencode" ;;
  esac
}

prompt_for_plugin_choice() {
  if [[ -n "$PLUGIN_CHOICE" ]]; then
    return 0
  fi

  # opencode-obsidian 仅 opencode 可选；其他 agent 只能用 claudian（已是默认）
  if [[ "$AGENT_ID" != "opencode" ]]; then
    PLUGIN_CHOICE="claudian"
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    PLUGIN_CHOICE="claudian"
    return 0
  fi

  echo ""
  echo "选择 Obsidian 插件（仅 OpenCode agent 可选）："
  echo ""
  echo "  1) claudian（默认）      — 通用插件，支持 OpenCode/Claude Code/Codex/Pi"
  echo "  2) opencode-obsidian     — OpenCode 原生插件，serve 后台服务模式"
  echo ""
  read -r -p "> 请选择 (1-2，默认 1): " PLUGIN_ANSWER
  case "$PLUGIN_ANSWER" in
    2) PLUGIN_CHOICE="opencode-obsidian" ;;
    *) PLUGIN_CHOICE="claudian" ;;
  esac
}

prompt_for_provider_choice() {
  local answer
  local unsupported=""

  if [[ -n "$PROVIDER_CHOICE" ]]; then
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    PROVIDER_CHOICE="7"
    return 0
  fi

  if [[ "$AGENT_ID" == "claude-code" ]]; then
    unsupported="（Claude Code 不支持）"
  fi

  echo ""
  echo "知识库需要一个 AI 大模型来驱动。请选择你的 AI 服务提供商："
  echo ""
  echo "  1) 智谱 GLM    — 国内服务，中文友好，注册简单（推荐国内用户）"
  echo "  2) Anthropic   — Claude 系列模型"
  echo "  3) OpenAI      — GPT 系列模型${unsupported}"
  echo "  4) Google      — Gemini 系列模型${unsupported}"
  echo "  5) OpenRouter  — 多模型网关，一个 Key 用多个模型"
  echo "  6) DeepSeek    — DeepSeek 模型（国内服务）"
  echo "  7) 跳过        — 稍后手动配置"
  echo ""
  while true; do
    read -r -p "> 请选择 (1-7): " answer
    if ! PROVIDER_CHOICE="$(normalize_provider_choice "$answer")"; then
      echo "无效选择，请输入 1-7 之间的数字。"
    elif ! provider_supported_by_agent "$PROVIDER_CHOICE"; then
      echo "Claude Code 只能连接 Anthropic 协议的服务，请换一个（或选 7 跳过）。"
    else
      break
    fi
  done
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

# 各 provider 的共享元数据（所有 agent 共用，单一事实源）：
#   P_BASE_URL            OpenCode 用的 baseURL（空 = 用 OpenCode 内置地址）
#   P_OPENAI_BASE_URL     OpenAI 兼容接口（Codex / Pi 用）
#   P_ANTHROPIC_BASE_URL  Anthropic 兼容接口（Claude Code 用；空 = Anthropic 官方）
#   P_ENV_KEY             Codex 读取 API Key 的环境变量名
load_provider_meta() {
  case "$PROVIDER_CHOICE" in
    1)
      P_NAME="智谱 GLM"
      P_MODELS="glm-5.2 glm-5.1 glm-5"
      P_DEFAULT_MODEL="glm-5.2"
      P_BASE_URL="https://open.bigmodel.cn/api/coding/paas/v4"
      P_OPENAI_BASE_URL="https://open.bigmodel.cn/api/paas/v4"
      P_ANTHROPIC_BASE_URL="https://open.bigmodel.cn/api/anthropic"
      P_ENV_KEY="ZHIPU_API_KEY"
      P_OPENCODE_PROVIDER="zhipuglm"
      P_OPENCODE_NPM="@ai-sdk/openai-compatible"
      ;;
    2)
      P_NAME="Anthropic"
      P_MODELS="claude-opus-4-8 claude-sonnet-4-6"
      P_DEFAULT_MODEL="claude-opus-4-8"
      P_BASE_URL=""
      P_OPENAI_BASE_URL="https://api.anthropic.com/v1"
      P_ANTHROPIC_BASE_URL=""
      P_ENV_KEY="ANTHROPIC_API_KEY"
      P_OPENCODE_PROVIDER="anthropic"
      P_OPENCODE_NPM=""
      ;;
    3)
      P_NAME="OpenAI"
      P_MODELS="gpt-5.5 gpt-5.4-mini"
      P_DEFAULT_MODEL="gpt-5.5"
      P_BASE_URL=""
      P_OPENAI_BASE_URL="https://api.openai.com/v1"
      P_ANTHROPIC_BASE_URL=""
      P_ENV_KEY="OPENAI_API_KEY"
      P_OPENCODE_PROVIDER="openai"
      P_OPENCODE_NPM=""
      ;;
    4)
      P_NAME="Google"
      P_MODELS="gemini-3.1-pro-preview gemini-3-flash"
      P_DEFAULT_MODEL="gemini-3.1-pro-preview"
      P_BASE_URL=""
      P_OPENAI_BASE_URL="https://generativelanguage.googleapis.com/v1beta/openai"
      P_ANTHROPIC_BASE_URL=""
      P_ENV_KEY="GOOGLE_API_KEY"
      P_OPENCODE_PROVIDER="google"
      P_OPENCODE_NPM=""
      ;;
    5)
      P_NAME="OpenRouter"
      P_MODELS="anthropic/claude-opus-4.8 openai/gpt-5.5 google/gemini-3.1-pro-preview"
      P_DEFAULT_MODEL="anthropic/claude-opus-4.8"
      P_BASE_URL="https://openrouter.ai/api/v1"
      P_OPENAI_BASE_URL="https://openrouter.ai/api/v1"
      P_ANTHROPIC_BASE_URL="https://openrouter.ai/api"
      P_ENV_KEY="OPENROUTER_API_KEY"
      P_OPENCODE_PROVIDER="openrouter"
      P_OPENCODE_NPM=""
      ;;
    6)
      P_NAME="DeepSeek"
      P_MODELS="deepseek-v4-pro deepseek-v4-flash"
      P_DEFAULT_MODEL="deepseek-v4-pro"
      P_BASE_URL="https://api.deepseek.com/v1"
      P_OPENAI_BASE_URL="https://api.deepseek.com/v1"
      P_ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
      P_ENV_KEY="DEEPSEEK_API_KEY"
      P_OPENCODE_PROVIDER="deepseek"
      P_OPENCODE_NPM="@ai-sdk/openai-compatible"
      ;;
    *)
      P_NAME=""
      P_MODELS=""
      P_DEFAULT_MODEL=""
      P_BASE_URL=""
      P_OPENAI_BASE_URL=""
      P_ANTHROPIC_BASE_URL=""
      P_ENV_KEY=""
      P_OPENCODE_PROVIDER=""
      P_OPENCODE_NPM=""
      ;;
  esac
}

# 构建并写入指定 agent 的配置文件。跳过时也返回 0：它在 set -e 下直接调用，
# 返回非零会让脚本在生成 Obsidian 插件配置之前就退出。
write_agent_config() {
  if [[ "$SHOULD_WRITE_CONFIG" -eq 0 || "$PROVIDER_CHOICE" == "7" ]]; then
    echo -e "${YELLOW}跳过 AI 服务配置。稍后请手动编辑 ${AGENT_CONFIG_FILE}${NC}"
    return 0
  fi

  load_provider_meta
  if [[ -z "$P_NAME" ]]; then
    echo -e "${YELLOW}跳过 AI 服务配置。${NC}"
    return 0
  fi

  # 备份现有配置（备份里有旧的 API Key，同样只允许自己读）
  if [[ -f "$AGENT_CONFIG_FILE" ]]; then
    CONFIG_BACKUP_FILE="$AGENT_CONFIG_FILE.backup-$(date +%Y%m%d-%H%M%S)"
    run_cmd cp "$AGENT_CONFIG_FILE" "$CONFIG_BACKUP_FILE"
    run_cmd chmod 600 "$CONFIG_BACKUP_FILE"
    echo -e "${YELLOW}已备份现有配置到：$CONFIG_BACKUP_FILE${NC}"
  fi

  case "$AGENT_ID" in
    opencode)    write_opencode_config ;;
    claude-code) write_claude_code_config ;;
    codex)       write_codex_config ;;
    pi)          write_pi_config ;;
  esac

  echo -e "${GREEN}✓ ${AGENT_DISPLAY_NAME} 服务配置完成${NC}"
  return 0
}

# OpenCode: ~/.config/opencode/opencode.json（JSON，合并写入，其他 provider / MCP 等设置保留）
write_opencode_config() {
  local display_name=""
  local models=()

  read -r -a models <<< "$P_MODELS"
  # 只有自定义的 OpenAI 兼容 provider（智谱 / DeepSeek）需要显示名和 npm 包
  if [[ -n "$P_OPENCODE_NPM" ]]; then
    display_name="$P_NAME"
  fi

  # 单引号里是 JS：$schema 是 JSON 字段名，不是 shell 变量
  # shellcheck disable=SC2016
  update_json_file "$AGENT_CONFIG_FILE" '
    const [providerId, defaultModel, name, npm, baseURL, ...models] = args;
    cfg.$schema = cfg.$schema || "https://opencode.ai/config.json";
    cfg.agent = cfg.agent || {};
    for (const agent of ["build", "plan"]) {
      cfg.agent[agent] = cfg.agent[agent] || {};
      cfg.agent[agent].options = Object.assign({}, cfg.agent[agent].options, { store: false });
    }
    cfg.model = providerId + "/" + defaultModel;
    cfg.provider = cfg.provider || {};
    const provider = cfg.provider[providerId] = cfg.provider[providerId] || {};
    if (name) provider.name = name;
    if (npm) provider.npm = npm;
    provider.models = provider.models || {};
    for (const m of models) {
      // OpenRouter 的模型名带斜杠，显示名取最后一段更友好
      provider.models[m] = provider.models[m] || { name: m.split("/").pop() };
    }
    provider.options = Object.assign({}, provider.options, { apiKey: secret });
    if (baseURL) provider.options.baseURL = baseURL;
  ' "$P_OPENCODE_PROVIDER" "$P_DEFAULT_MODEL" "$display_name" "$P_OPENCODE_NPM" "$P_BASE_URL" "${models[@]}"
}

# Claude Code: ~/.claude/settings.json（JSON，只合并 env 里的认证项和 model，其他设置保留）
# Claude Code 只说 Anthropic 协议，第三方 provider 必须走它们的 Anthropic 兼容端点。
write_claude_code_config() {
  local model="$P_DEFAULT_MODEL"

  # 官方 Anthropic 用别名：始终指向最新的 Opus，不会因为模型版本更替而失效
  if [[ "$PROVIDER_CHOICE" == "2" ]]; then
    model="opus"
  fi

  update_json_file "$AGENT_CONFIG_FILE" '
    const [baseURL, model] = args;
    cfg.env = cfg.env || {};
    // 先清掉旧的认证项，避免切换 provider 后新旧 Key 同时生效
    for (const k of ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL"]) delete cfg.env[k];
    if (baseURL) {
      cfg.env.ANTHROPIC_BASE_URL = baseURL;
      cfg.env.ANTHROPIC_AUTH_TOKEN = secret;
      // 显式置空，防止把 shell 环境里的 Anthropic Key 发给第三方
      cfg.env.ANTHROPIC_API_KEY = "";
    } else {
      cfg.env.ANTHROPIC_API_KEY = secret;
    }
    cfg.model = model;
  ' "$P_ANTHROPIC_BASE_URL" "$model"
  echo -e "${YELLOW}  配置已写入 ${AGENT_CONFIG_FILE}（文件里的其他设置保持不变）${NC}"
}

# Codex: ~/.codex/config.toml（TOML）
# model 只写模型名，provider 由 model_provider 指定；API Key 不落盘，由 env_key 指定的环境变量提供。
write_codex_config() {
  local provider_id="$P_OPENCODE_PROVIDER"
  local wire_api="chat"

  if [[ "$PROVIDER_CHOICE" == "3" ]]; then
    # openai 是 Codex 内置 provider 的名字，自定义时换一个，确保走下面的 env_key
    provider_id="openai-api"
    wire_api="responses"
  fi

  local config_content="# ${AGENT_DISPLAY_NAME} 配置 — 由 setup.sh 生成
model = \"${P_DEFAULT_MODEL}\"
model_provider = \"${provider_id}\"

[model_providers.${provider_id}]
name = \"${P_NAME}\"
base_url = \"${P_OPENAI_BASE_URL}\"
wire_api = \"${wire_api}\"
env_key = \"${P_ENV_KEY}\"
"
  write_file "$AGENT_CONFIG_FILE" "$config_content"
  # 不回显 API Key：终端输出常被截图发到 Issue 里
  echo -e "${YELLOW}  Codex 从环境变量 ${P_ENV_KEY} 读取 API Key。把下面这行加到 ~/.zshrc（引号里换成你的 Key），然后重开终端：${NC}"
  echo "    export ${P_ENV_KEY}=\"你的 API Key\""
}

# Pi: ~/.pi/config.json（JSON，OpenAI 兼容，合并写入）
# Pi 主要靠 `pi` → `/login` 交互配置；这里生成最小配置 + 提示用 /login。
write_pi_config() {
  update_json_file "$AGENT_CONFIG_FILE" '
    const [model, baseUrl] = args;
    cfg.model = model;
    cfg.baseUrl = baseUrl;
    cfg.apiKey = secret;
  ' "$P_DEFAULT_MODEL" "$P_OPENAI_BASE_URL"
  echo -e "${YELLOW}  最小配置已写入 ${AGENT_CONFIG_FILE}${NC}"
  echo -e "${YELLOW}  推荐运行 ${AGENT_BIN} 后用 /login 完成交互式配置（支持 15+ provider）。${NC}"
}

validate_option_combinations() {
  if [[ "$KEEP_EXISTING" -eq 1 && "$OVERWRITE_EXISTING" -eq 1 ]]; then
    echo -e "${RED}✗ --keep-existing 和 --overwrite-existing 只能选一个${NC}"
    exit 1
  fi

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
    --keep-existing)
      KEEP_EXISTING=1
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
        opencode|claude-code|claudecode|claude|codex|pi)
          AGENT_CHOICE="$2"
          ;;
        *)
          echo "无效的 --agent 值：$2" >&2
          echo "可选值：opencode | claude-code | codex | pi" >&2
          usage
          exit 1
          ;;
      esac
      shift 2
      ;;
    --plugin)
      require_value "--plugin" "${2:-}"
      case "$2" in
        claudian|opencode-obsidian)
          PLUGIN_CHOICE="$2"
          ;;
        *)
          echo "无效的 --plugin 值：$2" >&2
          echo "可选值：claudian（默认）| opencode-obsidian（仅 opencode）" >&2
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
# 命令行指定的 provider 与 agent 不兼容时，在动任何文件之前就退出
if [[ -n "$PROVIDER_CHOICE" ]]; then
  ensure_provider_supported
fi
prompt_for_plugin_choice
apply_plugin_choice
echo -e "${BLUE}已选择 Agent: ${AGENT_DISPLAY_NAME}${NC}"
echo -e "${BLUE}Obsidian 插件: $([[ "$AGENT_OBSIDIAN_PLUGIN" == *"claudian"* ]] && echo "claudian" || echo "opencode-obsidian")${NC}"
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
    VAULT_PATH="$(clean_path_input "$VAULT_PATH")"
  fi
fi

if [[ -z "$VAULT_PATH" ]]; then
  VAULT_PATH="$DEFAULT_VAULT_PATH"
fi

VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
# 相对路径转成绝对路径；去掉末尾的 /（否则改名备份时会把目录挪进自己里面）
if [[ "$VAULT_PATH" != /* ]]; then
  VAULT_PATH="$PWD/$VAULT_PATH"
fi
while [[ "$VAULT_PATH" == */ && "$VAULT_PATH" != "/" ]]; do
  VAULT_PATH="${VAULT_PATH%/}"
done

if [[ -e "$VAULT_PATH" && ! -d "$VAULT_PATH" ]]; then
  echo -e "${RED}✗ 这个路径已存在，但不是文件夹：$VAULT_PATH${NC}"
  exit 1
fi

if is_dangerous_path "$VAULT_PATH"; then
  echo -e "${RED}✗ 这个路径过于危险，不能作为知识库目录：$VAULT_PATH${NC}"
  echo "请重新运行脚本，并选择一个单独的新目录。"
  exit 1
fi

# 这里只决定怎么处理，真正动文件放到第 5 步：前面安装失败退出时，已有目录原封不动
if [[ -d "$VAULT_PATH" && -n "$(ls -A "$VAULT_PATH")" ]]; then
  choose_existing_vault_mode
fi

case "$VAULT_MODE" in
  keep)    echo -e "${GREEN}✓ 将保留已有笔记，更新这个知识库：$VAULT_PATH${NC}" ;;
  replace) echo -e "${GREEN}✓ 旧目录会先改名备份，再在这里新建知识库：$VAULT_PATH${NC}" ;;
  *)       echo -e "${GREEN}✓ 知识库将创建在：$VAULT_PATH${NC}" ;;
esac
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
# OpenCLI 只用于社交媒体采集，装不上也不影响知识库本身，所以失败时继续往下走
install_global_npm_package "@jackwener/opencli" || true

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

# 按选择的 agent 分发技能目录 + 记忆文件（仅新建知识库时调用；保留模式由 upgrade.sh 处理）
distribute_skills_and_memory() {
  case "$AGENT_ID" in
    opencode)
      # 模板已含 .opencode/skill/，无需移动；AGENTS.md 已在 vault 根
      :
      ;;
    claude-code)
      install_skills "$VAULT_PATH/.claude/skills"
      run_cmd rm -rf "$VAULT_PATH/.opencode"
      ;;
    codex|pi)
      # Codex / Pi 的技能是用户级的；AGENTS.md 保留在 vault 根（它们都会加载）
      install_skills "$AGENT_USER_SKILL_DIR"
      echo -e "${GREEN}✓ 技能已安装到用户目录：$AGENT_USER_SKILL_DIR${NC}"
      run_cmd rm -rf "$VAULT_PATH/.opencode"
      ;;
  esac

  # Claude Code 额外需要 CLAUDE.md（内容与 AGENTS.md 相同，Claude Code 自动加载）
  if [[ "$AGENT_NEEDS_CLAUDE_MD" -eq 1 ]]; then
    run_cmd cp "$TEMPLATE_DIR/AGENTS.md" "$VAULT_PATH/CLAUDE.md"
    echo -e "${GREEN}✓ 已生成 CLAUDE.md（Claude Code 记忆文件）${NC}"
  fi
}

if [[ "$VAULT_MODE" == "keep" ]]; then
  # 复用升级脚本：刷新规则、技能和辅助脚本，补齐缺失的目录；已有笔记一律不动
  UPGRADE_ARGS=(--vault "$VAULT_PATH" --agent "$AGENT_ID" --non-interactive)
  if [[ "$DRY_RUN" -eq 1 ]]; then
    UPGRADE_ARGS+=(--dry-run)
  fi
  "$BASH" "$SCRIPT_DIR/scripts/upgrade.sh" "${UPGRADE_ARGS[@]}"
  echo -e "${GREEN}✓ 知识库已更新，原有笔记保持不变${NC}"
else
  if [[ "$VAULT_MODE" == "replace" ]]; then
    VAULT_BACKUP_PATH="$VAULT_PATH.backup-$(date +%Y%m%d-%H%M%S)"
    run_cmd mv "$VAULT_PATH" "$VAULT_BACKUP_PATH"
    echo -e "${YELLOW}旧目录已改名备份为：$VAULT_BACKUP_PATH${NC}"
  fi
  run_cmd mkdir -p "$VAULT_PATH"
  run_cmd cp -R "$TEMPLATE_DIR/." "$VAULT_PATH/"
  run_cmd find "$VAULT_PATH" -name ".gitkeep" -delete
  distribute_skills_and_memory
  echo -e "${GREEN}✓ 知识库已创建${NC}"
fi
echo ""

step "【第 6 步 / 共 6 步】配置 AI 服务"
prompt_for_provider_choice

SHOULD_WRITE_CONFIG=1

if [[ -f "$AGENT_CONFIG_FILE" ]]; then
  echo -e "${YELLOW}⚠ 检测到已有 ${AGENT_DISPLAY_NAME} 配置：$AGENT_CONFIG_FILE${NC}"
  if [[ "$AGENT_CONFIG_FORMAT" == "json" ]]; then
    echo "只会更新其中的模型和 API Key，其他设置保留；更新前会自动备份。"
  else
    echo "会整体覆盖这个文件；覆盖前会自动备份。"
  fi

  if [[ "$OVERWRITE_CONFIG" -eq 0 ]]; then
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
      SHOULD_WRITE_CONFIG=0
      echo -e "${YELLOW}将保留现有配置。本次只创建知识库和插件配置。${NC}"
    else
      read -r -p "> 是否继续更新这个配置？(y/N): " OVERWRITE_CONFIG_ANSWER
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

# 生成 Obsidian 插件配置（四个 agent 默认都用 claudian；opencode 可选 opencode-obsidian）
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

  case "$AGENT_OBSIDIAN_PLUGIN" in
    *opencode-obsidian)
      # 路径和启动命令每次都更新；界面偏好类设置只在缺失时补默认值（保留用户在插件里改过的）
      update_json_file "$plugin_dir/data.json" '
        const [binPath, command] = args;
        const defaults = {
          autoStart: true,
          startupTimeout: 45000,
          defaultViewLocation: "sidebar",
          injectWorkspaceContext: false,
          maxNotesInContext: 20,
          maxSelectionLength: 2000
        };
        for (const [key, value] of Object.entries(defaults)) {
          if (!(key in cfg)) cfg[key] = value;
        }
        Object.assign(cfg, {
          port: 14096,
          hostname: "127.0.0.1",
          opencodePath: binPath,
          customCommand: command,
          useCustomCommand: true
        });
      ' "$AGENT_BIN_PATH" "$node_bin_path $AGENT_BIN_PATH ${AGENT_SERVE_CMD}"
      echo -e "${GREEN}✓ Obsidian 插件配置已生成（opencode-obsidian）${NC}"
      ;;
    *claudian)
      # claudian 支持多个 agent（OpenCode / Claude Code / Codex / Pi）。
      # 配置用 cliPathsByHost 按 OS 映射对应 agent 的 CLI 路径；切换 agent 时旧的路径保留。
      update_json_file "$plugin_dir/data.json" '
        const [host, bin, binPath] = args;
        const defaults = { autoStart: true, defaultViewLocation: "sidebar", maxNotesInContext: 20, maxSelectionLength: 2000 };
        for (const [key, value] of Object.entries(defaults)) {
          if (!(key in cfg)) cfg[key] = value;
        }
        cfg.cliPathsByHost = cfg.cliPathsByHost || {};
        cfg.cliPathsByHost[host] = Object.assign({}, cfg.cliPathsByHost[host], { [bin]: binPath });
      ' "darwin" "$AGENT_BIN" "$AGENT_BIN_PATH"
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
if [[ -n "$VAULT_BACKUP_PATH" ]]; then
  echo -e "旧知识库备份：${BLUE}$VAULT_BACKUP_PATH${NC}"
fi
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
[[ "$AGENT_ID" == "pi" ]] && TROUBLESHOOTING_DOC="pi-setup-troubleshooting.md"
echo -e "插件配置与排障请参考 ${BLUE}${TROUBLESHOOTING_DOC}${NC}"
# 诊断脚本只针对 opencode-obsidian（serve 模式）；其他情况用通用的环境自检
if [[ "$AGENT_OBSIDIAN_PLUGIN" == *opencode-obsidian ]]; then
  echo -e "一键诊断脚本：${BLUE}bash \"$SCRIPT_DIR/scripts/opencode-obsidian-doctor.sh\" --vault \"$VAULT_PATH\"${NC}"
else
  echo -e "环境自检脚本：${BLUE}bash \"$SCRIPT_DIR/scripts/verify.sh\" --vault \"$VAULT_PATH\"${NC}"
fi
echo ""
