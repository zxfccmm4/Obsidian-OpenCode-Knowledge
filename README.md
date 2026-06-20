[English](README.en.md) | [中文](README.md)

# 🧠 Obsidian + AI Agent 知识库

> 面向非技术用户的本地 AI 知识管理方案。支持 OpenCode / Claude Code / Codex，无需编程，一键部署，开箱即用。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/zxfccmm4/Obsidian-OpenCode-Knowledge?style=social)](https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/stargazers)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-000000?logo=apple&logoColor=white)](#-快速开始)
[![Agents](https://img.shields.io/badge/Agents-OpenCode%20%7C%20Claude%20Code%20%7C%20Codex-blue)](docs/agents.md)

---

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 📥 **自动录入** | 文章、PDF、截图直接丢给 AI，自动整理成结构化笔记 |
| 📱 **社交媒体采集** | 小红书、抖音、Twitter、微博等平台内容一键归类、分析、消化（通过 [OpenCLI](https://github.com/jackwener/OpenCLI) 驱动） |
| 🔍 **智能查询** | 像聊天一样问 AI：「我之前写过关于 XX 的内容吗？」 |
| 🏥 **定期体检** | AI 自动检查知识库健康度，发现死链、重复、孤岛页面 |
| 🔒 **本地存储** | 笔记文件保存在你的电脑上；使用 AI 时，内容会发送给你配置的模型服务商 |
| 🛠️ **一键部署** | 运行脚本，5 分钟搞定安装 |

---

## 🚀 快速开始

> 📌 **平台支持：** 一键脚本当前仅支持 **macOS**（脚本依赖 `open`、Homebrew 等系统命令）。
> Linux 用户可手动执行 `setup.sh`，部分调用需把 `open` 替换为 `xdg-open`；Windows 用户建议在 WSL2 中使用。

### 方式一：让 AI 帮你部署（零门槛）

把下面这句话发给任何 AI 助手（ChatGPT、Claude、GLM 等），它会自动帮你完成全部部署：

```
请帮我部署 AI 知识库：https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/blob/main/GUIDE_FOR_AI.md
```

> 📖 AI 助手会读取 [`GUIDE_FOR_AI.md`](GUIDE_FOR_AI.md) 中的完整部署流程，自动完成环境检查、安装、配置。

### 方式二：手动安装（3 步）

```bash
# 第 1 步：克隆仓库
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git
cd Obsidian-OpenCode-Knowledge

# 第 2 步：运行安装脚本（macOS）
bash setup.sh

# 第 3 步：在 Obsidian 中打开生成的「我的知识库」文件夹
```

> 📖 详细步骤请参考 [`deployment-guide.md`](deployment-guide.md)

### 选择 AI Agent

知识库支持三个 AI agent 驱动，部署时用 `--agent` 选择（默认 `opencode`）：

| Agent | Obsidian 插件 | 适合 |
|-------|-------------|------|
| **OpenCode** ⭐（默认） | ✅ opencode-obsidian | 想在 Obsidian 内直接对话 |
| **Claude Code** | ✅ claudian | Anthropic 生态用户 |
| **Codex** | ✅ claudian | OpenAI 生态用户 |

```bash
bash setup.sh --agent opencode        # 默认，推荐大多数用户
bash setup.sh --agent claude-code     # Claude Code
bash setup.sh --agent codex           # OpenAI Codex
```

> 📖 详细的对比与选型建议见 [`docs/agents.md`](docs/agents.md)

### 先做只读检查

如果你还不想安装，或者想先确认仓库状态和本机环境，建议先跑一次：

```bash
bash scripts/verify.sh
```

### `setup.sh` 会做什么

安装脚本会自动完成这些事情：

1. **选择 AI Agent**：opencode / claude-code / codex 三选一（默认 opencode）
2. **检查 Node.js**：确认是否已安装，缺失时可引导用 Homebrew 安装
3. **安装所选 Agent**：通过 npm 全局安装对应的 CLI（opencode-ai / @anthropic-ai/claude-code / @openai/codex）
4. **安装 OpenCLI**：安装社交媒体采集和网页自动化所需 CLI
5. **创建你的 Vault**：把 `vault-template/` 复制到你选择的位置
6. **分发技能与规则**：按所选 agent 把技能放到对应目录，生成 `AGENTS.md`（claude-code 额外生成 `CLAUDE.md`）
7. **配置 AI 服务**：从 6 个 provider 中选择一个，生成对应 agent 的配置文件
8. **处理已有配置**：如果检测到已有 agent 配置，会先询问是否覆盖，并在覆盖前自动备份
9. **生成 Obsidian 插件配置**：按所选 agent 写入插件 `data.json`（opencode → opencode-obsidian；claude-code/codex → claudian）

### 自动化模式

如果你是让 AI、脚本或 CI 帮你部署，可以用这两个参数：

- `--non-interactive`：不再提问，必须配合显式参数或安全默认值
- `--dry-run`：只预演流程，不安装依赖、不写文件

示例：

```bash
bash setup.sh --dry-run --non-interactive --vault "$HOME/Desktop/我的知识库" --provider skip
```

如果要真正的非交互安装，常见参数组合是：

```bash
bash setup.sh --non-interactive --vault "$HOME/Desktop/我的知识库" --provider openai --api-key "<KEY>" --overwrite-existing --overwrite-config
```

### 🔄 升级与卸载

部署后，如果想获取最新的规则、技能或脚本：

```bash
# 先更新仓库，再升级你的知识库（只更新规则/技能，绝不碰你的笔记）
git pull
bash scripts/upgrade.sh --agent <你的agent> --vault "$HOME/Desktop/我的知识库"
# 例如：bash scripts/upgrade.sh --agent claude-code --vault "$HOME/Desktop/我的知识库"
```

> `upgrade.sh` 只刷新 `AGENTS.md`/`CLAUDE.md`、技能、辅助脚本；`raw/` `wiki/` `assets/` 原封不动；`AI_CONFIG.md` 会先备份。不传 `--agent` 时默认 opencode。

想清理（卸载对应 agent 的配置 / 插件配置 / 可选删除 vault 与 npm 包）：

```bash
bash scripts/uninstall.sh --agent <你的agent> --vault "$HOME/Desktop/我的知识库"
# 严格清理：bash scripts/uninstall.sh --agent codex --vault <路径> --remove-vault --remove-packages --non-interactive
```

> ⚠️ `--remove-vault` 会永久删除你的全部笔记，需二次确认。

更新历史详见 [`CHANGELOG.md`](CHANGELOG.md)。

---

## 🏗️ 架构概览

这套方案由三个组件协同工作，中间的 AI Agent 可三选一：

```
┌──────────────────────────────────────────────────────────────────┐
│  ┌─────────────┐    ┌──────────────────────┐    ┌─────────────┐ │
│  │   Obsidian  │◄──►│   AI Agent (三选一)   │◄──►│  知识库规则 │ │
│  │  (笔记软件)  │    │ OpenCode/Claude/Codex│    │ (AGENTS.md) │ │
│  └─────────────┘    └──────────────────────┘    └─────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

| 组件 | 作用 | 对你意味着什么 |
|------|------|----------------|
| **Obsidian** | 本地笔记软件 | 像用普通笔记本一样写笔记 |
| **AI Agent** | AI 大模型接口 | 在 Obsidian 里和 AI 对话（OpenCode / Claude Code / Codex 三选一） |
| **知识库规则** | AI 行为指南（`AGENTS.md`） | AI 知道怎么帮你整理、查询、体检 |

> 三个 agent 共用同一套规则和技能，差异仅在安装方式和配置格式。详见 [`docs/agents.md`](docs/agents.md)。

---

## 📁 目录结构

安装完成后，你的知识库结构如下：

```
我的知识库/
├── 📄 AGENTS.md               # AI 规则（由系统维护）
├── 📄 AI_CONFIG.md            # ⚙️ AI 配置文件（用户可自定义）
├── 📁 raw/                   # 原始素材（PDF/文章/截图等）
│   ├── 按主题分类存放...
│   └── 📁 social/            # 社交媒体原始内容（按知识域分类）
│       ├── 消费研究/          # 探店、测评、好物推荐
│       ├── 技能方法/          # 教程、攻略、经验分享
│       ├── 行业洞察/          # 趋势分析、商业观察
│       ├── 生活方式/          # 旅行、美食、穿搭
│       ├── 观点思考/          # 深度评论、价值观输出
│       ├── 创意灵感/          # 设计、文案、营销案例
│       └── 资源收藏/          # 工具推荐、书单、资源清单
├── 📁 wiki/                  # AI 整理的笔记
│   ├── index.md              # 📇 全局索引（AI 自动更新）
│   ├── log.md                # 📝 操作日志（AI 自动记录）
│   └── 各主题笔记...         # 含社交媒体消化后的知识文章
├── 📁 assets/                # 配图资源
└── 📁 .opencode/            # AI 技能目录（opencode）
  │                          #   claude-code 用 .claude/skills/
  │                          #   codex 用 ~/.codex/skills/（用户级）
    └── 📁 skill/             # AI 技能（内容三者通用）
        ├── obsidian-cli/     # Obsidian 操作能力
        ├── obsidian-markdown/ # Markdown 生成能力
        ├── defuddle/         # 网页内容提取能力
        ├── opencli-usage/    # OpenCLI 命令参考（100+ 网站适配器）
        ├── smart-search/     # 智能搜索路由器
        ├── opencli-browser/  # 浏览器自动化
        ├── opencli-autofix/  # 适配器自动修复
        ├── opencli-explorer/ # 适配器开发指南
        └── opencli-oneshot/  # 单点快速 CLI 生成
```

### 预装技能

模板预装 9 个技能（真相源在 `vault-template/.opencode/skill/`），部署时按所选 agent 分发到对应目录（`.opencode/skill/` / `.claude/skills/` / `~/.codex/skills/`）。技能内容三者通用：

| 技能 | 作用 |
|------|------|
| `obsidian-cli` | 读取、创建、搜索 Obsidian 笔记 |
| `obsidian-markdown` | 生成和编辑 Obsidian 风格 Markdown |
| `defuddle` | 提取网页正文内容 |
| `opencli-usage` | OpenCLI 命令参考（100+ 网站适配器） |
| `smart-search` | 多平台智能搜索路由 |
| `opencli-browser` | 浏览器自动化 |
| `opencli-autofix` | 自动修复站点适配器 |
| `opencli-explorer` | 新适配器开发指南 |
| `opencli-oneshot` | 单点快速 CLI 生成模板 |

---

## 📝 日常使用示例

### 📥 录入素材（Ingest）

把想保存的内容丢给 AI：

```
帮我把这个加到 wiki：
[粘贴文章内容 / 网页链接 / 描述你想记录的内容]
```

AI 会自动：
- 保存原始素材到 `raw/` 目录
- 整理成结构化笔记存入 `wiki/`
- 更新全局索引和操作日志

---

### 📱 社交媒体采集（Social Ingest）

用爬虫工具（如 opencli）抓取小红书、抖音、Twitter、微博等内容后：

```
爬了这个：
[粘贴爬取的笔记内容]
```

```
收录这条小红书
```

AI 会自动：
- 判断内容知识域（消费研究/技能方法/行业洞察/生活方式/观点思考/创意灵感/资源收藏）
- 评估可信度（是否软广、是否有实测细节）
- 归档原始内容到 `raw/social/<知识域>/`

> OpenCLI 支持通过 Chrome 浏览器自动抓取内容，复用你的登录状态，无需额外配置密码。详见 [OpenCLI 项目](https://github.com/jackwener/OpenCLI)。
>
> ⚠️ **合规与使用须知：** 自动化抓取可能违反部分平台的服务条款（ToS），尤其小红书、抖音、微博等国内平台。本项目仅供**个人学习与研究用途**；抓取频率、内容再分发、商用等行为的风险由用户自行承担。请遵守各平台条款、当地法律法规，并对账号风控（限流、封禁）风险有预期。本项目与 OpenCLI 均不对因违规使用导致的后果负责。
- 消化润色后合并或新建 wiki 文章（去除社交口语，保留有效信息）
- 同主题多篇自动合并（如多篇咖啡探店 → 一篇城市咖啡指南）
- 更新全局索引和操作日志

> 支持平台：小红书、抖音、Twitter/X、微博、B站、微信公众号等

---

### 🔍 查询知识（Query）

像聊天一样问 AI：

```
我的 wiki 里关于项目管理有什么内容？
```

```
根据我的笔记，总结一下我对 AI 工具的看法
```

```
对比我在 wiki 里写的两种学习方法
```

---

### 🏥 体检（Lint）

每周运行一次：

```
lint wiki
```

AI 会检查：
- ✅ 索引文件是否和实际文件一致
- ✅ 内部链接是否有效
- ✅ 有没有孤岛页面
- ✅ 跨文章的事实是否矛盾

---

## 🔧 高级选项（可选）

基础版已经能用了。以下功能按需添加，只需在你的 AI agent 里一句话安装：

| 功能 | 安装命令 | 用途 |
|------|----------|------|
| 📄 PDF 导出 | `安装 minimax-pdf 技能` | 把笔记导出为专业 PDF |
| 📝 Word 导出 | `安装 minimax-docx 技能` | 生成 Word 文档 |
| 📊 Excel 读取 | `安装 minimax-xlsx 技能` | 读取 Excel 数据 |
| 🎨 PPT 生成 | `安装 pptx-generator 技能` | 把笔记变成演示文稿 |
| 🖼️ 图片分析 | `安装 vision-analysis 技能` | 分析图片和截图 |

---

## ❓ 常见问题

### Q0：怎么自定义 AI 的行为？

编辑知识库根目录下的 `AI_CONFIG.md`，可以自定义：
- **知识域分类**：添加/删除/修改分类（如添加「学术笔记」）
- **触发词**：修改触发 AI 操作的关键词
- **输出语言**：改为英文消化内容
- **社交平台**：添加新平台
- **Lint 检查项**：开关各项体检功能
- **自定义规则**：在文件底部的 `user-custom-rules` 区域写额外规则

> 修改后下次对话自动生效，不需要重启。

### Q1：我没有技术背景，能用的起来吗？

完全可以！这是专门为非技术用户设计的方案。只需跟着 [`deployment-guide.md`](deployment-guide.md) 一步步操作，不需要懂编程。

---

### Q2：我的数据安全吗？

非常安全：
- ✅ **笔记文件保存在你自己的电脑上**，本项目本身不额外托管你的笔记数据
- ✅ **使用 AI 时**，当前对话内容会发送给你选择并配置的模型服务商
- ✅ `raw/` 目录里的原始素材**永远不会被 AI 修改**
- ✅ 笔记就是普通的 Markdown 文件，随时可以复制备份

---

### Q3：可以用其他 AI 服务吗？

可以！安装脚本支持 6 个 AI 服务提供商（provider），运行时自由选择：

| 服务 | 默认模型 | 特点 |
|------|---------|------|
| 智谱 GLM ⭐ | `glm-5.2` | 国内服务，中文好，推荐国内用户 |
| Anthropic | `claude-opus-4-8` | Claude 系列模型 |
| OpenAI | `gpt-5.5` | GPT 系列模型 |
| Google Gemini | `gemini-3.1-pro-preview` | Gemini 系列模型 |
| OpenRouter | `anthropic/claude-opus-4.8` | 多模型网关，一个 Key 用多个模型 |
| DeepSeek | `deepseek-v4-pro` | 国内服务，性价比高 |

选择后粘贴 API Key 即可自动配置（不同 agent 的配置文件路径不同，见 [`docs/agents.md`](docs/agents.md)）。后续想换？重跑 `setup.sh` 或手动编辑对应 agent 的配置文件：
- OpenCode：`~/.config/opencode/opencode.json`
- Claude Code：`~/.claude/settings.json`
- Codex：`~/.codex/config.toml`

---

### Q4：安装失败怎么办？

1. 确保你的 Mac 系统是 macOS 12 或更高版本
2. 确保电脑能正常上网
3. 先运行只读检查：`bash scripts/verify.sh`
4. 再把终端里的错误信息截图，发 Issue 给我们

---

### Q5：这和直接用 ChatGPT 有什么区别？

| 功能 | ChatGPT | 本方案 |
|------|---------|--------|
| 数据存储 | 云端 | 本地 |
| 长期记忆 | 会话级别 | 永久保存 |
| 结构化整理 | 手动 | AI 自动 |
| 文件关联 | 不支持 | 支持 |

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

- 发现 Bug？请提交 [Issue](../../issues)
- 想贡献代码？请参考 [CONTRIBUTING.md](CONTRIBUTING.md)
- 有功能建议？欢迎开 [Discussion](../../discussions)

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

你可以自由使用、修改、分发，只需保留版权声明。

---

## 🙏 致谢

感谢以下项目和团队的支持：

- **[OpenCode](https://opencode.ai)** — 让 AI 助手可以运行在本地终端
- **[Claude Code](https://www.anthropic.com/claude-code)** — Anthropic 官方 AI 编码 agent
- **[Codex](https://developers.openai.com/codex/)** — OpenAI 官方 AI 编码 agent
- **[Obsidian](https://obsidian.md)** — 优秀的本地笔记软件
- **[claudian](https://github.com/YishenTu/claudian)** — 在 Obsidian 内嵌入 AI agent 的通用插件
- **[opencode-obsidian](https://github.com/mtymek/opencode-obsidian)** — OpenCode 的 Obsidian 插件
- **[OpenCLI](https://github.com/jackwener/OpenCLI)** — 让任何网站变成命令行，支持 100+ 网站适配器
- **[智谱 GLM](https://open.bigmodel.cn)** / **[Anthropic](https://anthropic.com)** / **[OpenAI](https://openai.com)** / **[Google Gemini](https://ai.google)** / **[OpenRouter](https://openrouter.ai)** / **[DeepSeek](https://deepseek.com)** — 支持多种 AI 服务提供商
- **[helloianneo/obsidian-ai-second-brain](https://github.com/helloianneo/obsidian-ai-second-brain)** — 知识库架构灵感来源

---

<div align="center">

**Made with ❤️ for knowledge seekers**

[⭐ Star 这个项目](../../stargazers) · [🐛 提交 Issue](../../issues) · [💬 加入讨论](../../discussions)

</div>
