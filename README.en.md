[English](README.en.md) | [中文](README.md)

# 🧠 Obsidian + OpenCode AI Knowledge Base

> A local AI knowledge management solution for non-technical users. No coding required, one-click deployment, ready to use out of the box.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/zxfccmm4/Obsidian-OpenCode-Knowledge?style=social)](https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/stargazers)
[![OpenCode](https://img.shields.io/badge/Powered%20by-OpenCode-blue)](https://opencode.ai)

> **Note:** This project was originally designed for Chinese users, but international users are welcome! The interface and documentation can be adapted for English usage.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 📥 **Auto Ingest** | Drop articles, PDFs, screenshots to AI, automatically organized into structured notes |
| 🔍 **Smart Query** | Chat with AI: "Have I written about XX before?" |
| 🏥 **Regular Health Check** | AI automatically checks knowledge base health, finds broken links, duplicates, orphaned pages |
| 🔒 **Fully Local** | All data stays on your computer, no cloud upload |
| 🛠️ **One-Click Deploy** | Run the script, setup completes in 5 minutes |

---

## 🚀 Quick Start

### 3-Step Installation

```bash
# Step 1: Clone the repository
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git
cd Obsidian-OpenCode-Knowledge/deploy

# Step 2: Run the setup script (macOS)
bash setup.sh

# Step 3: Open the generated "My Knowledge Base" folder in Obsidian
```

> 📖 For detailed steps, see [`部署指南.md`](部署指南.md) (Chinese deployment guide)

### What `setup.sh` Does

The setup script handles everything automatically:

1. **Checks Node.js** — verifies Node.js is installed, offers to install via Homebrew if missing
2. **Installs OpenCode** — installs the OpenCode CLI tool globally via npm
3. **Creates Your Vault** — copies the `vault-template/` to your chosen location
4. **Configures AI Service** — sets up API Key for Zhipu GLM (or your preferred provider)
5. **Sets Up Obsidian Plugin** — generates configuration for the opencode-obsidian plugin

---

## 🏗️ Architecture Overview

This solution works with three components:

```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │
│  │   Obsidian  │◄──►│  OpenCode   │◄──►│   CLAUDE.md │ │
│  │ (Notes App) │    │  (AI Agent) │    │  (AI Rules) │ │
│  └─────────────┘    └─────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

| Component | Purpose | What It Means for You |
|-----------|---------|----------------------|
| **Obsidian** | Local note-taking app | Write notes like using a regular notebook |
| **OpenCode** | AI model interface | Chat with AI directly in Obsidian |
| **CLAUDE.md** | AI behavior guide | AI knows how to organize, query, and check your knowledge base |

---

## 📁 Directory Structure

After installation, your knowledge base structure looks like this:

```
My Knowledge Base/
├── 📄 CLAUDE.md              # AI rules (system-maintained)
├── 📁 raw/                   # Raw materials (PDFs/articles/screenshots)
│   └── organized by topic...
├── 📁 wiki/                  # AI-organized notes
│   ├── index.md              # 📇 Global index (auto-updated by AI)
│   ├── log.md                # 📝 Operation log (auto-recorded by AI)
│   └── topic notes...
├── 📁 assets/                # Image assets
└── 📁 .opencode/
    └── 📁 skill/             # AI skills (3 pre-installed)
        ├── obsidian-cli/     # Obsidian operation capabilities
        ├── obsidian-markdown/ # Markdown generation capabilities
        └── defuddle/         # Web content extraction capabilities
```

### Pre-installed Skills

The template comes with 3 core skills in `vault-template/.opencode/skill/`:

| Skill | Purpose |
|-------|---------|
| `obsidian-cli` | Read, create, search notes in your Obsidian vault |
| `obsidian-markdown` | Generate and edit Obsidian-flavored Markdown |
| `defuddle` | Extract clean content from web pages |

---

## 📝 Daily Usage Examples

### 📥 Ingest (Add to Knowledge Base)

Drop content you want to save to AI:

```
Add this to my wiki:
[paste article content / web link / describe what you want to record]
```

AI will automatically:
- Save raw materials to the `raw/` directory
- Organize into structured notes in `wiki/`
- Update the global index and operation log

---

### 🔍 Query (Search Knowledge)

Ask AI like chatting:

```
What does my wiki have about project management?
```

```
Based on my notes, summarize my views on AI tools
```

```
Compare the two learning methods I wrote about in my wiki
```

---

### 🏥 Lint (Health Check)

Run weekly:

```
lint wiki
```

AI will check:
- ✅ Index file consistency with actual files
- ✅ Internal link validity
- ✅ Orphaned pages (pages no one links to)
- ✅ Cross-article fact consistency

---

## 🔧 Advanced Options (Optional)

The basic version works great. Add these features on demand by simply telling OpenCode to install them:

| Feature | Install Command | Purpose |
|---------|-----------------|---------|
| 📄 PDF Export | "Install minimax-pdf skill" | Export notes to professional PDF |
| 📝 Word Export | "Install minimax-docx skill" | Generate Word documents |
| 📊 Excel Reading | "Install minimax-xlsx skill" | Read Excel data |
| 🎨 PPT Generation | "Install pptx-generator skill" | Turn notes into presentations |
| 🖼️ Image Analysis | "Install vision-analysis skill" | Analyze images and screenshots |

---

## ❓ FAQ

### Q1: I don't have a technical background. Can I still use this?

Absolutely! This is designed specifically for non-technical users. Just follow the [`部署指南.md`](部署指南.md) step by step. No programming knowledge needed.

---

### Q2: Is my data secure?

Very secure:
- ✅ **All data stays on your own computer**, no cloud upload
- ✅ **Raw materials in `raw/` are never modified by AI**
- ✅ Notes are plain Markdown files, easy to copy and backup anytime

---

### Q3: Can I use other AI services?

Yes! The default uses Zhipu GLM (Chinese service, easy registration), but you can edit the config file `~/.config/opencode/opencode.json` to switch to other services like GitHub Copilot, OpenAI, etc.

---

### Q4: What if installation fails?

1. Make sure your Mac is running macOS 12 or later
2. Make sure your computer has internet access
3. Take a screenshot of the error message in terminal and open an Issue

---

### Q5: How is this different from using ChatGPT directly?

| Feature | ChatGPT | This Solution |
|---------|---------|---------------|
| Data Storage | Cloud | Local |
| Long-term Memory | Session-level | Permanent |
| Structured Organization | Manual | AI-auto |
| File Associations | Not supported | Supported |

---

## 🤝 Contributing

Issues and Pull Requests are welcome!

- Found a bug? Please submit an [Issue](../../issues)
- Want to contribute code? See [CONTRIBUTING.md](CONTRIBUTING.md)
- Have a feature suggestion? Start a [Discussion](../../discussions)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

You are free to use, modify, and distribute, just keep the copyright notice.

---

## 🙏 Acknowledgments

Thanks to these projects and teams for their support:

- **[OpenCode](https://opencode.ai)** — Enables AI assistants to run locally in the terminal
- **[Obsidian](https://obsidian.md)** — Excellent local note-taking software
- **[智谱 GLM (Zhipu GLM)](https://open.bigmodel.cn)** — Provides Chinese-friendly large language model services
- **[helloianneo/obsidian-ai-second-brain](https://github.com/helloianneo/obsidian-ai-second-brain)** — Inspiration for the knowledge base architecture

---

<div align="center">

**Made with ❤️ for knowledge seekers**

[⭐ Star this project](../../stargazers) · [🐛 Submit Issue](../../issues) · [💬 Join Discussion](../../discussions)

</div>
