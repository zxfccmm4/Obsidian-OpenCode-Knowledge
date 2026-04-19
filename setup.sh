#!/bin/bash
# ============================================================
# AI 知识库一键部署脚本
# 适用于 macOS | 面向非技术用户
# ============================================================
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/vault-template"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    AI 知识库 · 一键部署                   ║${NC}"
echo -e "${BLUE}║    Obsidian + OpenCode + 知识库规则        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ----------------------------------------------------------
# 第 1 步：确认目标路径
# ----------------------------------------------------------
echo -e "${YELLOW}【第 1 步 / 共 6 步】选择知识库存放位置${NC}"
echo ""
echo "你的知识库（Vault）要放在哪里？"
echo "直接回车 = 桌面上的「我的知识库」文件夹"
read -p "> 请输入路径（或直接回车）: " VAULT_PATH

if [ -z "$VAULT_PATH" ]; then
    VAULT_PATH="$HOME/Desktop/我的知识库"
fi

# 展开波浪号
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

if [ -d "$VAULT_PATH" ]; then
    echo -e "${RED}⚠ 目录已存在：$VAULT_PATH${NC}"
    read -p "  要覆盖吗？(y/N): " OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "已取消。"
        exit 0
    fi
    rm -rf "$VAULT_PATH"
fi

echo -e "${GREEN}✓ 知识库将创建在：$VAULT_PATH${NC}"
echo ""

# ----------------------------------------------------------
# 第 2 步：检查 Node.js
# ----------------------------------------------------------
echo -e "${YELLOW}【第 2 步 / 共 6 步】检查 Node.js${NC}"

if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ 已安装 Node.js $NODE_VERSION${NC}"
else
    echo -e "${RED}✗ 未检测到 Node.js${NC}"
    echo ""
    echo "Node.js 是 OpenCode 运行的基础，需要先安装。"
    echo ""
    echo "请选择安装方式："
    echo "  1) 自动安装（使用 Homebrew，推荐已装 brew 的用户）"
    echo "  2) 手动下载（打开 Node.js 官网下载页）"
    echo "  3) 跳过（我稍后自己装）"
    read -p "> 请选择 (1/2/3): " NODE_CHOICE

    case $NODE_CHOICE in
        1)
            if command -v brew &>/dev/null; then
                echo "正在通过 Homebrew 安装 Node.js..."
                brew install node
                echo -e "${GREEN}✓ Node.js 安装完成${NC}"
            else
                echo -e "${RED}未检测到 Homebrew。${NC}"
                echo "请先安装 Homebrew："
                echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                echo "或选择选项 2 手动下载。"
                exit 1
            fi
            ;;
        2)
            echo "正在打开 Node.js 下载页..."
            open "https://nodejs.org/zh-cn"
            echo ""
            echo -e "${YELLOW}请下载并安装 Node.js 后，重新运行此脚本。${NC}"
            exit 0
            ;;
        3)
            echo -e "${YELLOW}跳过。请稍后自行安装 Node.js，否则 OpenCode 无法运行。${NC}"
            ;;
        *)
            echo "无效选择，退出。"
            exit 1
            ;;
    esac
fi
echo ""

# ----------------------------------------------------------
# 第 3 步：安装 OpenCode
# ----------------------------------------------------------
echo -e "${YELLOW}【第 3 步 / 共 6 步】安装 OpenCode${NC}"

echo "正在安装或更新 OpenCode..."
npm install -g opencode-ai 2>/dev/null || {
    echo -e "${YELLOW}全局安装需要管理员权限，尝试 sudo...${NC}"
    sudo npm install -g opencode-ai
}

OPENCODE_PATH=$(command -v opencode 2>/dev/null || echo "")
if [ -z "$OPENCODE_PATH" ]; then
    echo -e "${RED}✗ OpenCode 安装完成后仍未找到 opencode 命令${NC}"
    echo "请确认 npm 全局 bin 已加入 PATH，然后重新运行脚本。"
    exit 1
fi

echo -e "${GREEN}✓ OpenCode 已就绪：$OPENCODE_PATH $(opencode --version 2>/dev/null || echo "")${NC}"
echo ""

# ----------------------------------------------------------
# 第 4 步：安装 OpenCLI
# ----------------------------------------------------------
echo -e "${YELLOW}【第 4 步 / 共 6 步】安装 OpenCLI${NC}"

echo "正在安装 OpenCLI..."
npm install -g @jackwener/opencli 2>/dev/null || {
    echo -e "${YELLOW}全局安装需要管理员权限，尝试 sudo...${NC}"
    sudo npm install -g @jackwener/opencli
}

OPENCLI_PATH=$(command -v opencli 2>/dev/null || echo "")
if [ -n "$OPENCLI_PATH" ]; then
    echo -e "${GREEN}✓ OpenCLI 已就绪：$OPENCLI_PATH$(opencli --version 2>/dev/null || echo "")${NC}"
else
    echo -e "${YELLOW}⚠ OpenCLI 安装未成功，社交媒体采集功能需要手动安装${NC}"
    echo "  手动安装命令：npm install -g @jackwener/opencli"
fi
echo ""

# ----------------------------------------------------------
# 第 5 步：创建 Vault（从模板复制）
# ----------------------------------------------------------
echo -e "${YELLOW}【第 5 步 / 共 6 步】创建知识库${NC}"

# 复制模板
cp -R "$TEMPLATE_DIR" "$VAULT_PATH"

# 清理 .gitkeep
find "$VAULT_PATH" -name ".gitkeep" -delete

echo -e "${GREEN}✓ 知识库已创建${NC}"
echo ""

# ----------------------------------------------------------
# 第 6 步：配置 AI 服务
# ----------------------------------------------------------
echo -e "${YELLOW}【第 6 步 / 共 6 步】配置 AI 服务${NC}"
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
read -p "> 请选择 (1-7): " PROVIDER_CHOICE

# 创建 OpenCode 全局配置目录
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"
MODEL_ID=""
PROVIDER_BLOCK=""
ENV_HINT=""

case "$PROVIDER_CHOICE" in
    1)
        # 智谱 GLM
        echo ""
        echo "请先获取 API Key："
        echo "  1. 访问 https://open.bigmodel.cn"
        echo "  2. 注册账号 →「API Keys」→ 创建 Key"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="zhipuglm/glm-4.5"
            PROVIDER_BLOCK="\"zhipuglm\": {
      \"name\": \"智谱 GLM\",
      \"npm\": \"@ai-sdk/openai-compatible\",
      \"models\": {
        \"glm-4.5\": { \"name\": \"GLM-4.5\" },
        \"glm-4.5-air\": { \"name\": \"GLM-4.5-Air\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\",
        \"baseURL\": \"https://open.bigmodel.cn/api/coding/paas/v4\"
      }
    }"
        fi
        ;;
    2)
        # Anthropic
        echo ""
        echo "请先获取 API Key：https://console.anthropic.com/settings/keys"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="anthropic/claude-sonnet-4-20250514"
            PROVIDER_BLOCK="\"anthropic\": {
      \"models\": {
        \"claude-sonnet-4-20250514\": { \"name\": \"Claude Sonnet 4\" },
        \"claude-haiku-35-20241022\": { \"name\": \"Claude 3.5 Haiku\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
        fi
        ;;
    3)
        # OpenAI
        echo ""
        echo "请先获取 API Key：https://platform.openai.com/api-keys"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="openai/gpt-4.1"
            PROVIDER_BLOCK="\"openai\": {
      \"models\": {
        \"gpt-4.1\": { \"name\": \"GPT-4.1\" },
        \"gpt-4.1-mini\": { \"name\": \"GPT-4.1 Mini\" },
        \"gpt-4.1-nano\": { \"name\": \"GPT-4.1 Nano\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
        fi
        ;;
    4)
        # Google Gemini
        echo ""
        echo "请先获取 API Key：https://aistudio.google.com/apikey"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="google/gemini-2.5-pro"
            PROVIDER_BLOCK="\"google\": {
      \"models\": {
        \"gemini-2.5-pro\": { \"name\": \"Gemini 2.5 Pro\" },
        \"gemini-2.5-flash\": { \"name\": \"Gemini 2.5 Flash\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
        fi
        ;;
    5)
        # OpenRouter
        echo ""
        echo "请先获取 API Key：https://openrouter.ai/settings/keys"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="openrouter/anthropic/claude-sonnet-4-20250514"
            PROVIDER_BLOCK="\"openrouter\": {
      \"models\": {
        \"anthropic/claude-sonnet-4-20250514\": { \"name\": \"Claude Sonnet 4\" },
        \"openai/gpt-4.1\": { \"name\": \"GPT-4.1\" },
        \"google/gemini-2.5-pro\": { \"name\": \"Gemini 2.5 Pro\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\"
      }
    }"
        fi
        ;;
    6)
        # DeepSeek
        echo ""
        echo "请先获取 API Key：https://platform.deepseek.com/api_keys"
        echo ""
        read -p "> 请粘贴你的 API Key: " API_KEY
        if [ -z "$API_KEY" ]; then
            echo -e "${YELLOW}跳过。${NC}"
            PROVIDER_CHOICE="7"
        else
            MODEL_ID="deepseek/deepseek-chat"
            PROVIDER_BLOCK="\"deepseek\": {
      \"name\": \"DeepSeek\",
      \"npm\": \"@ai-sdk/openai-compatible\",
      \"models\": {
        \"deepseek-chat\": { \"name\": \"DeepSeek V3\" },
        \"deepseek-reasoner\": { \"name\": \"DeepSeek R1\" }
      },
      \"options\": {
        \"apiKey\": \"${API_KEY}\",
        \"baseURL\": \"https://api.deepseek.com/v1\"
      }
    }"
        fi
        ;;
    7|*)
        echo -e "${YELLOW}跳过 AI 服务配置。稍后请手动编辑 ~/.config/opencode/opencode.json${NC}"
        PROVIDER_CHOICE="7"
        ;;
esac

# 写入配置文件
if [ "$PROVIDER_CHOICE" != "7" ] && [ -n "$PROVIDER_BLOCK" ]; then
    cat > "$CONFIG_FILE" << CONFIG_EOF
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
    echo -e "${GREEN}✓ AI 服务配置完成${NC}"
fi
echo ""

# ----------------------------------------------------------
# 配置 opencode-obsidian 插件
# ----------------------------------------------------------
if [ -n "$OPENCODE_PATH" ]; then
    # 确保 Obsidian 插件目录存在
    PLUGIN_DIR="$VAULT_PATH/.obsidian/plugins/opencode-obsidian"
    mkdir -p "$PLUGIN_DIR"

    # 写入插件配置（使用检测到的 opencode 路径）
    NODE_PATH=$(command -v node 2>/dev/null || echo "/usr/local/bin/node")

    cat > "$PLUGIN_DIR/data.json" << DATADAT
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
  "customCommand": "$NODE_PATH $OPENCODE_PATH serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md",
  "useCustomCommand": true
}
DATADAT

    echo -e "${GREEN}✓ 插件配置已生成${NC}"
fi

# ----------------------------------------------------------
# 完成
# ----------------------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 部署完成！                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
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
echo -e "详细说明请参考同目录下的 ${BLUE}部署指南.md${NC}"
echo -e "插件配置与排障请参考 ${BLUE}OpenCode-Obsidian-标准安装与排障.md${NC}"
echo -e "一键诊断脚本：${BLUE}bash \"$SCRIPT_DIR/scripts/opencode-obsidian-doctor.sh\" --vault \"$VAULT_PATH\"${NC}"
echo ""
