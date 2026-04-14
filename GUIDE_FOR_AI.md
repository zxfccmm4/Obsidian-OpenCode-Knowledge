# AI Agent 部署指南

> 本文档面向 AI 智能体。用户将此链接交给你后，你应能独立完成 Obsidian + OpenCode AI 知识库的全部部署工作。

---

## 你要做什么

帮用户在本地 macOS 机器上搭建一个 **Obsidian + OpenCode AI 知识库**。部署完成后，用户可以在 Obsidian 里直接和 AI 对话，让 AI 帮忙录入、查询、整理笔记。

## 整体流程

```
检查环境 → 安装依赖 → 克隆仓库 → 运行部署脚本 → 引导用户完成剩余步骤
```

---

## 第 1 步：环境检查

在用户机器上依次检查以下条件：

### 1.1 操作系统

```bash
uname -s
```

必须是 `Darwin`（macOS）。如果是 Linux，流程类似但 `open` 命令需替换；如果是 Windows，暂不支持一键脚本，建议用户使用 WSL。

### 1.2 Node.js（≥ 18）

```bash
node -v
```

- **已安装** → 记录版本号，继续
- **未安装** → 执行安装：

```bash
# 优先用 Homebrew
if command -v brew &>/dev/null; then
    brew install node
else
    # 没有 Homebrew，先装 Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install node
fi
```

如果用户不愿意装 Homebrew，打开 https://nodejs.org/zh-cn 让用户手动下载。

### 1.3 确认 Obsidian 已安装

```bash
ls /Applications/Obsidian.app 2>/dev/null && echo "installed" || echo "not installed"
```

- **未安装** → 打开 https://obsidian.md 让用户下载，拖入「应用程序」

---

## 第 2 步：克隆仓库

```bash
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git ~/Desktop/Obsidian-OpenCode-Knowledge
```

如果用户希望放在其他位置，替换路径即可。

---

## 第 3 步：运行部署脚本

```bash
cd ~/Desktop/Obsidian-OpenCode-Knowledge && bash setup.sh
```

### 脚本是交互式的，你需要代替用户回答以下问题：

| 提示 | 建议回答 | 备注 |
|------|----------|------|
| 知识库存放位置 | 直接回车（默认 `~/Desktop/我的知识库`） | 可按用户意愿修改 |
| 目录已存在是否覆盖 | 看用户意愿 | 新用户通常不会遇到 |
| Node.js 安装方式 | 1（Homebrew 自动安装） | 前面已装好则不会出现 |
| 选择 AI 服务提供商 | 见下方决策表 | **必须问用户** |
| 粘贴 API Key | 用户提供的 Key | **必须问用户** |

### AI 服务选择决策表

问用户：「你想用哪个 AI 服务？」

| 选项 | 适合谁 | 注册地址 |
|------|--------|----------|
| 1 - 智谱 GLM ⭐ | 国内用户，中文场景，注册简单 | https://open.bigmodel.cn |
| 2 - Anthropic | 有 Claude API Key 的用户 | https://console.anthropic.com/settings/keys |
| 3 - OpenAI | 有 OpenAI API Key 的用户 | https://platform.openai.com/api-keys |
| 4 - Google Gemini | 有 Google AI API Key 的用户 | https://aistudio.google.com/apikey |
| 5 - OpenRouter | 想用一个 Key 访问多个模型的用户 | https://openrouter.ai/settings/keys |
| 6 - DeepSeek | 国内用户，性价比高 | https://platform.deepseek.com/api_keys |
| 7 - 跳过 | 用户暂时没有 Key | 稍后手动配置 |

如果用户没有 API Key：
1. 打开对应注册地址
2. 指导用户注册并创建 Key
3. 拿到 Key 后继续

---

## 第 4 步：手动部署方案（脚本失败时）

如果 `setup.sh` 运行失败，按以下步骤手动完成：

### 4.1 安装 OpenCode

```bash
npm install -g opencode
```

权限不足时加 `sudo`。

### 4.2 复制 Vault 模板

```bash
VAULT_PATH="$HOME/Desktop/我的知识库"
cp -R ~/Desktop/Obsidian-OpenCode-Knowledge/vault-template "$VAULT_PATH"
find "$VAULT_PATH" -name ".gitkeep" -delete
```

### 4.3 配置 AI 服务

根据用户选择的 provider，写入 `~/.config/opencode/opencode.json`：

```bash
mkdir -p ~/.config/opencode
```

然后根据用户选择的 provider 生成配置。以下是各 provider 的配置模板：

**智谱 GLM：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "zhipuglm/glm-4.5",
  "provider": {
    "zhipuglm": {
      "name": "智谱 GLM",
      "npm": "@ai-sdk/openai-compatible",
      "models": { "glm-4.5": { "name": "GLM-4.5" }, "glm-4.5-air": { "name": "GLM-4.5-Air" } },
      "options": { "apiKey": "<用户的API Key>", "baseURL": "https://open.bigmodel.cn/api/coding/paas/v4" }
    }
  }
}
```

**Anthropic：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "anthropic/claude-sonnet-4-20250514",
  "provider": {
    "anthropic": {
      "models": { "claude-sonnet-4-20250514": { "name": "Claude Sonnet 4" }, "claude-haiku-35-20241022": { "name": "Claude 3.5 Haiku" } },
      "options": { "apiKey": "<用户的API Key>" }
    }
  }
}
```

**OpenAI：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "openai/gpt-4.1",
  "provider": {
    "openai": {
      "models": { "gpt-4.1": { "name": "GPT-4.1" }, "gpt-4.1-mini": { "name": "GPT-4.1 Mini" } },
      "options": { "apiKey": "<用户的API Key>" }
    }
  }
}
```

**Google Gemini：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "google/gemini-2.5-pro",
  "provider": {
    "google": {
      "models": { "gemini-2.5-pro": { "name": "Gemini 2.5 Pro" }, "gemini-2.5-flash": { "name": "Gemini 2.5 Flash" } },
      "options": { "apiKey": "<用户的API Key>" }
    }
  }
}
```

**OpenRouter：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "openrouter/anthropic/claude-sonnet-4-20250514",
  "provider": {
    "openrouter": {
      "models": { "anthropic/claude-sonnet-4-20250514": { "name": "Claude Sonnet 4" }, "openai/gpt-4.1": { "name": "GPT-4.1" } },
      "options": { "apiKey": "<用户的API Key>" }
    }
  }
}
```

**DeepSeek：**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { "build": { "options": { "store": false } }, "plan": { "options": { "store": false } } },
  "model": "deepseek/deepseek-chat",
  "provider": {
    "deepseek": {
      "name": "DeepSeek",
      "npm": "@ai-sdk/openai-compatible",
      "models": { "deepseek-chat": { "name": "DeepSeek V3" }, "deepseek-reasoner": { "name": "DeepSeek R1" } },
      "options": { "apiKey": "<用户的API Key>", "baseURL": "https://api.deepseek.com/v1" }
    }
  }
}
```

### 4.4 配置 Obsidian 插件

```bash
VAULT_PATH="$HOME/Desktop/我的知识库"
OPENCODE_PATH=$(command -v opencode)
NODE_PATH=$(command -v node)
PLUGIN_DIR="$VAULT_PATH/.obsidian/plugins/opencode-obsidian"
mkdir -p "$PLUGIN_DIR"

cat > "$PLUGIN_DIR/data.json" << EOF
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
EOF
```

---

## 第 5 步：部署后引导

脚本或手动部署完成后，告诉用户还需要做以下 3 件事（脚本无法自动完成）：

### 5.1 在 Obsidian 中打开知识库

1. 打开 Obsidian
2. 点击「打开文件夹作为仓库」
3. 选择 `~/Desktop/我的知识库`（或用户指定的路径）

### 5.2 安装 opencode-obsidian 插件

二选一：

**方式 A（推荐）：** Obsidian 设置 → 第三方插件 → 浏览 → 搜索「OpenCode」→ 安装并启用

**方式 B（通过 BRAT）：**
1. Obsidian 设置 → 第三方插件 → 浏览 → 搜索「BRAT」→ 安装并启用
2. `⌘ P` 打开命令面板 →「BRAT: Add a plugin」
3. 输入 `mtymek/opencode-obsidian` → 安装并启用

### 5.3 开始使用

在 Obsidian 侧边栏找到 OpenCode 图标，打开面板，等连接成功后，试着说：

```
帮我创建一篇笔记，标题是《我的第一篇 AI 笔记》
```

---

## 验证清单

部署完成后，逐项确认：

| 检查项 | 命令/方法 | 预期结果 |
|--------|-----------|----------|
| Node.js | `node -v` | v18+ |
| OpenCode | `opencode --version` | 有版本号输出 |
| 知识库目录 | `ls ~/Desktop/我的知识库` | 看到 CLAUDE.md, raw/, wiki/, assets/ |
| AI 配置 | `cat ~/.config/opencode/opencode.json` | 包含用户选择的 provider 和 API Key |
| Obsidian 插件 | `ls ~/Desktop/我的知识库/.obsidian/plugins/opencode-obsidian/` | 看到 data.json |

全部通过 → 部署成功。

---

## 常见问题处理

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `npm install -g opencode` 权限不足 | 全局 npm 目录权限问题 | 加 `sudo`：`sudo npm install -g opencode` |
| `brew: command not found` | 未安装 Homebrew | 先装 Homebrew，或让用户手动下载 Node.js |
| OpenCode 面板连接失败 | API Key 无效或网络问题 | 检查 `~/.config/opencode/opencode.json` 中的 apiKey |
| OpenCode 面板显示空白 | 插件未启用 | Obsidian 设置 → 第三方插件 → 启用 opencode-obsidian |
| `git clone` 失败 | 网络问题 | 检查网络连接，或让用户手动下载 ZIP |

---

## 仓库结构参考

```
Obsidian-OpenCode-Knowledge/
├── setup.sh                  ← 一键部署脚本（交互式）
├── 部署指南.md                ← 面向人类的部署文档
├── GUIDE_FOR_AI.md           ← 你正在读的这个文件
├── README.md                 ← 项目说明（中文）
├── README.en.md              ← 项目说明（英文）
├── LICENSE                   ← MIT
├── CONTRIBUTING.md           ← 贡献指南
├── .github/                  ← Issue/PR 模板
└── vault-template/           ← 知识库模板
    ├── CLAUDE.md             ← AI 规则（Ingest/Query/Lint 三种行为）
    ├── raw/                  ← 原始素材目录（AI 只读）
    ├── wiki/                 ← AI 维护的笔记
    │   ├── index.md          ← 全局索引
    │   ├── log.md            ← 操作日志
    │   └── 使用指南.md
    ├── assets/               ← 配图
    └── .opencode/skill/      ← 预装 AI 技能
        ├── obsidian-cli/     ← Obsidian 操作能力
        ├── obsidian-markdown/ ← Markdown 生成
        └── defuddle/         ← 网页内容提取
```

---

## 项目链接

- **GitHub 仓库：** https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge
- **原始部署脚本：** https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/blob/main/setup.sh
- **本文档直链：** https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/blob/main/GUIDE_FOR_AI.md
