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
| 🔍 **智能查询** | 像聊天一样问 AI：「我之前写过关于 XX 的内容吗？」 |
| 🏥 **定期体检** | AI 自动检查知识库健康度，发现死链、重复、孤岛页面 |
| 🔒 **完全本地** | 所有数据存在你的电脑上，不上传云端 |
| 🛠️ **一键部署** | 运行脚本，5 分钟搞定安装 |

---

## 🚀 快速开始

### 3 步完成安装

```bash
# 第 1 步：克隆仓库
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git
cd Obsidian-OpenCode-Knowledge/deploy

# 第 2 步：运行安装脚本（macOS）
bash setup.sh

# 第 3 步：在 Obsidian 中打开生成的「我的知识库」文件夹
```

> 📖 详细步骤请参考 [`部署指南.md`](部署指南.md)

---

## 🏗️ 架构概览

这套方案由三个组件协同工作：

```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   Obsidian  │◄──►│  OpenCode   │◄──►│  知识库规则 │ │
│  │  (笔记软件)  │    │  (AI 助手)  │    │ (CLAUDE.md) │ │
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
├── 📄 CLAUDE.md              # AI 规则（由系统维护）
├── 📁 raw/                   # 原始素材（PDF/文章/截图等）
│   └── 按主题分类存放...
├── 📁 wiki/                  # AI 整理的笔记
│   ├── index.md              # 📇 全局索引（AI 自动更新）
│   ├── log.md                # 📝 操作日志（AI 自动记录）
│   └── 各主题笔记...
├── 📁 assets/                # 配图资源
└── 📁 .opencode/
    └── 📁 skill/             # AI 技能
        ├── obsidian-cli/     # Obsidian 操作能力
        ├── obsidian-markdown/ # Markdown 生成能力
        └── defuddle/         # 网页内容提取能力
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

完全可以！这是专门为非技术用户设计的方案。只需跟着 [`部署指南.md`](部署指南.md) 一步步操作，不需要懂编程。

---

### Q2：我的数据安全吗？

非常安全：
- ✅ **所有数据都在你自己的电脑上**，不会上传到云端
- ✅ `raw/` 目录里的原始素材**永远不会被 AI 修改**
- ✅ 笔记就是普通的 Markdown 文件，随时可以复制备份

---

### Q3：可以用其他 AI 服务吗？

可以！默认使用智谱 GLM（国内服务，注册简单），但你可以编辑配置文件 `~/.config/opencode/opencode.json` 切换到其他服务，如 GitHub Copilot、OpenAI 等。

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
- **[智谱 GLM](https://open.bigmodel.cn)** — 提供中文友好的大模型服务
- **[helloianneo/obsidian-ai-second-brain](https://github.com/helloianneo/obsidian-ai-second-brain)** — 知识库架构灵感来源

---

<div align="center">

**Made with ❤️ for knowledge seekers**

[⭐ Star 这个项目](../../stargazers) · [🐛 提交 Issue](../../issues) · [💬 加入讨论](../../discussions)

</div>
