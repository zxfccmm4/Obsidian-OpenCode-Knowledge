[English](README.en.md) | 中文

# 🧠 Obsidian + OpenCode AI 知识库

> 面向非技术用户的本地 AI 知识管理方案。无需编程，一键部署，开箱即用。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/zxfccmm4/Obsidian-OpenCode-Knowledge?style=social)](https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/stargazers)
[![OpenCode](https://img.shields.io/badge/Powered%20by-OpenCode-blue)](https://opencode.ai)

---

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 📥 **自动录入** | 文章、PDF、截图直接丢给 AI，自动整理成结构化笔记 |
| 📱 **社交媒体采集** | 小红书、抖音、Twitter、微博等平台内容一键归类、分析、消化（通过 [OpenCLI](https://github.com/jackwener/OpenCLI) 驱动） |
| 🔍 **智能查询** | 像聊天一样问 AI：「我之前写过关于 XX 的内容吗？」 |
| 🏥 **定期体检** | AI 自动检查知识库健康度，发现死链、重复、孤岛页面 |
| 🔒 **完全本地** | 所有数据存在你的电脑上，不上传云端 |
| 🛠️ **一键部署** | 运行脚本，5 分钟搞定安装 |

---

## 🚀 快速开始

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
cd Obsidian-OpenCode-Knowledge/deploy

# 第 2 步：运行安装脚本（macOS）
bash setup.sh

# 第 3 步：在 Obsidian 中打开生成的「我的知识库」文件夹
```

> 📖 详细步骤请参考 [`deployment-guide.md`](deployment-guide.md)

---

## 🏗️ 架构概览

这套方案由三个组件协同工作：

```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   Obsidian  │◄──►│  OpenCode   │◄──►│  知识库规则 │ │
│  │  (笔记软件)  │    │  (AI 助手)  │    │ (AGENTS.md) │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

| 组件 | 作用 | 对你意味着什么 |
|------|------|----------------|
| **Obsidian** | 本地笔记软件 | 像用普通笔记本一样写笔记 |
| **OpenCode** | AI 大模型接口 | 在 Obsidian 里和 AI 对话 |
| **知识库规则** | AI 行为指南 | AI 知道怎么帮你整理、查询、体检 |

---

## 📁 目录结构

安装完成后，你的知识库结构如下：

```
我的知识库/
├── 📄 AGENTS.md               # AI 规则（由系统维护）
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
└── 📁 .opencode/
    └── 📁 skill/             # AI 技能
        ├── obsidian-cli/     # Obsidian 操作能力
        ├── obsidian-markdown/ # Markdown 生成能力
        ├── defuddle/         # 网页内容提取能力
        ├── opencli-usage/    # OpenCLI 命令参考（87+ 网站适配器）
        ├── smart-search/     # 智能搜索路由器
        ├── opencli-browser/  # 浏览器自动化
        ├── opencli-autofix/  # 适配器自动修复
        ├── opencli-explorer/ # 适配器开发指南
        └── opencli-oneshot/  # 单点快速 CLI 生成
```

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

基础版已经能用了。以下功能按需添加，只需在 OpenCode 里一句话安装：

| 功能 | 安装命令 | 用途 |
|------|----------|------|
| 📄 PDF 导出 | `安装 minimax-pdf 技能` | 把笔记导出为专业 PDF |
| 📝 Word 导出 | `安装 minimax-docx 技能` | 生成 Word 文档 |
| 📊 Excel 读取 | `安装 minimax-xlsx 技能` | 读取 Excel 数据 |
| 🎨 PPT 生成 | `安装 pptx-generator 技能` | 把笔记变成演示文稿 |
| 🖼️ 图片分析 | `安装 vision-analysis 技能` | 分析图片和截图 |

---

## ❓ 常见问题

### Q1：我没有技术背景，能用的起来吗？

完全可以！这是专门为非技术用户设计的方案。只需跟着 [`deployment-guide.md`](deployment-guide.md) 一步步操作，不需要懂编程。

---

### Q2：我的数据安全吗？

非常安全：
- ✅ **所有数据都在你自己的电脑上**，不会上传到云端
- ✅ `raw/` 目录里的原始素材**永远不会被 AI 修改**
- ✅ 笔记就是普通的 Markdown 文件，随时可以复制备份

---

### Q3：可以用其他 AI 服务吗？

可以！安装脚本支持 6 个 AI 服务提供商，运行时自由选择：

| 服务 | 特点 |
|------|------|
| 智谱 GLM ⭐ | 国内服务，中文好，推荐国内用户 |
| Anthropic | Claude 系列模型 |
| OpenAI | GPT 系列模型 |
| Google Gemini | Gemini 系列模型 |
| OpenRouter | 多模型网关，一个 Key 用多个模型 |
| DeepSeek | 国内服务，性价比高 |

选择后粘贴 API Key 即可自动配置。后续想换？编辑 `~/.config/opencode/opencode.json` 即可。

---

### Q4：安装失败怎么办？

1. 确保你的 Mac 系统是 macOS 12 或更高版本
2. 确保电脑能正常上网
3. 把终端里的错误信息截图，发 Issue 给我们

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
- **[Obsidian](https://obsidian.md)** — 优秀的本地笔记软件
- **[OpenCLI](https://github.com/jackwener/OpenCLI)** — 让任何网站变成命令行，支持 87+ 网站适配器
- **[智谱 GLM](https://open.bigmodel.cn)** / **[Anthropic](https://anthropic.com)** / **[OpenAI](https://openai.com)** / **[Google Gemini](https://ai.google)** / **[OpenRouter](https://openrouter.ai)** / **[DeepSeek](https://deepseek.com)** — 支持多种 AI 服务提供商
- **[helloianneo/obsidian-ai-second-brain](https://github.com/helloianneo/obsidian-ai-second-brain)** — 知识库架构灵感来源

---

<div align="center">

**Made with ❤️ for knowledge seekers**

[⭐ Star 这个项目](../../stargazers) · [🐛 提交 Issue](../../issues) · [💬 加入讨论](../../discussions)

</div>
