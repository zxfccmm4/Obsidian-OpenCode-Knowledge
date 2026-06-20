[English](README.en.md) | [中文](README.md)

# 🧠 Obsidian + AI Agent Knowledge Base

> A local AI knowledge management solution for non-technical users. Supports OpenCode / Claude Code / Codex. No coding required, one-click deployment, ready to use out of the box.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/zxfccmm4/Obsidian-OpenCode-Knowledge?style=social)](https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/stargazers)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-000000?logo=apple&logoColor=white)](#-quick-start)
[![Agents](https://img.shields.io/badge/Agents-OpenCode%20%7C%20Claude%20Code%20%7C%20Codex-blue)](docs/agents.md)

> **Note:** This project was originally designed for Chinese users, but international users are welcome! The interface and documentation can be adapted for English usage.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 📥 **Auto Ingest** | Drop articles, PDFs, screenshots to AI, automatically organized into structured notes |
| 📱 **Social Media Collection** | Xiaohongshu, Douyin, Twitter, Weibo and more — auto-classify, analyze, and digest into knowledge (powered by [OpenCLI](https://github.com/jackwener/OpenCLI)) |
| 🔍 **Smart Query** | Chat with AI: "Have I written about XX before?" |
| 🏥 **Regular Health Check** | AI automatically checks knowledge base health, finds broken links, duplicates, orphaned pages |
| 🔒 **Local Storage** | Your note files stay on your computer; when you use AI, content is sent to your configured model provider |
| 🛠️ **One-Click Deploy** | Run the script, setup completes in 5 minutes |

---

## 🚀 Quick Start

> 📌 **Platform support:** The one-click script currently supports **macOS** only (it relies on `open`, Homebrew, etc.).
> Linux users can run `setup.sh` manually after replacing `open` with `xdg-open`; Windows users should use WSL2.

### Option 1: Let AI Deploy for You (Zero Effort)

Send this message to any AI assistant (ChatGPT, Claude, GLM, etc.) and it will handle the entire deployment automatically:

```
Deploy an AI knowledge base for me: https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge/blob/main/GUIDE_FOR_AI.md
```

> 📖 The AI assistant will read [`GUIDE_FOR_AI.md`](GUIDE_FOR_AI.md) for the complete deployment procedure, including environment checks, installation, and configuration.

### Option 2: Manual Installation (3 Steps)

```bash
# Step 1: Clone the repository
git clone https://github.com/zxfccmm4/Obsidian-OpenCode-Knowledge.git
cd Obsidian-OpenCode-Knowledge

# Step 2: Run the setup script (macOS)
bash setup.sh

# Step 3: Open the generated "My Knowledge Base" folder in Obsidian
```

> 📖 For detailed steps, see [`deployment-guide.md`](deployment-guide.md) (Chinese deployment guide)

### Choose an AI Agent

The knowledge base supports three AI agents. Pick one with `--agent` during deployment (default: `opencode`):

| Agent | Obsidian Plugin | Best For |
|-------|-----------------|----------|
| **OpenCode** ⭐ (default) | ✅ opencode-obsidian | Chat directly inside Obsidian |
| **Claude Code** | ✅ claudian | Anthropic ecosystem users |
| **Codex** | ✅ claudian | OpenAI ecosystem users |

```bash
bash setup.sh --agent opencode        # default, recommended for most users
bash setup.sh --agent claude-code     # Claude Code
bash setup.sh --agent codex           # OpenAI Codex
```

> 📖 For a detailed comparison and selection guide, see [`docs/agents.md`](docs/agents.md)

### Start With a Read-Only Check

If you do not want to install anything yet, or you just want to verify the repo and local environment first, run:

```bash
bash scripts/verify.sh
```

### What `setup.sh` Does

The setup script handles everything automatically:

1. **Choose AI Agent** — pick one of opencode / claude-code / codex (default: opencode)
2. **Checks Node.js** — verifies Node.js is installed, offers to install via Homebrew if missing
3. **Installs the Chosen Agent** — installs the corresponding CLI globally via npm (opencode-ai / @anthropic-ai/claude-code / @openai/codex)
4. **Installs OpenCLI** — installs the CLI tool for web automation and social media scraping (100+ site adapters)
5. **Creates Your Vault** — copies the `vault-template/` to your chosen location
6. **Distributes Skills & Rules** — places skills into the agent-specific directory; generates `AGENTS.md` (claude-code also generates `CLAUDE.md`)
7. **Configures AI Service** — choose from 6 providers and generate the config file for the chosen agent
8. **Handles Existing Config** — if the agent config already exists, the script asks before overwriting and creates a backup first
9. **Sets Up Obsidian Plugin** — generates plugin `data.json` for the chosen agent (opencode → opencode-obsidian; claude-code/codex → claudian)

### Automation Mode

If you're letting an AI agent, script, or CI run the installer, these options help:

- `--non-interactive`: skips prompts and relies on explicit flags or safe defaults
- `--dry-run`: previews the flow without installing dependencies or writing files

Example:

```bash
bash setup.sh --dry-run --non-interactive --vault "$HOME/Desktop/My Knowledge Base" --provider skip
```

For a real non-interactive install, a common flag combination looks like:

```bash
bash setup.sh --non-interactive --vault "$HOME/Desktop/My Knowledge Base" --provider openai --api-key "<KEY>" --overwrite-existing --overwrite-config
```

### 🔄 Upgrade & Uninstall

After deployment, to get the latest rules, skills, or scripts:

```bash
# Update the repo first, then upgrade your knowledge base (only rules/skills, never touches your notes)
git pull
bash scripts/upgrade.sh --agent <your-agent> --vault "$HOME/Desktop/My Knowledge Base"
# e.g.: bash scripts/upgrade.sh --agent claude-code --vault "$HOME/Desktop/My Knowledge Base"
```

> `upgrade.sh` only refreshes `AGENTS.md`/`CLAUDE.md`, skills, and helper scripts; `raw/` `wiki/` `assets/` are left untouched; `AI_CONFIG.md` is backed up first. Omitting `--agent` defaults to opencode.

To clean up (remove the agent config / plugin config / optionally delete the vault and npm packages):

```bash
bash scripts/uninstall.sh --agent <your-agent> --vault "$HOME/Desktop/My Knowledge Base"
# Full clean: bash scripts/uninstall.sh --agent codex --vault <path> --remove-vault --remove-packages --non-interactive
```

> ⚠️ `--remove-vault` permanently deletes all your notes and requires a second confirmation.

See [`CHANGELOG.md`](CHANGELOG.md) for version history.

---

## 🏗️ Architecture Overview

This solution works with three components, with the AI Agent being one of three choices:

```
┌──────────────────────────────────────────────────────────────────┐
│  ┌─────────────┐    ┌──────────────────────┐    ┌─────────────┐ │
│  │   Obsidian  │◄──►│   AI Agent (pick 1)   │◄──►│   AGENTS.md │ │
│  │ (Notes App) │    │ OpenCode/Claude/Codex│    │  (AI Rules) │ │
│  └─────────────┘    └──────────────────────┘    └─────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

| Component | Purpose | What It Means for You |
|-----------|---------|----------------------|
| **Obsidian** | Local note-taking app | Write notes like using a regular notebook |
| **AI Agent** | AI model interface | Chat with AI directly in Obsidian (pick one of OpenCode / Claude Code / Codex) |
| **AGENTS.md** | AI behavior guide | AI knows how to organize, query, and check your knowledge base |

> All three agents share the same rules and skills; they differ only in installation method and config format. See [`docs/agents.md`](docs/agents.md).

---

## 📁 Directory Structure

After installation, your knowledge base structure looks like this:

```
My Knowledge Base/
├── 📄 AGENTS.md              # AI rules (system-maintained)
├── 📄 AI_CONFIG.md           # ⚙️ AI configuration (user-customizable)
├── 📁 raw/                   # Raw materials (PDFs/articles/screenshots)
│   ├── organized by topic...
│   └── 📁 social/            # Social media raw content (by knowledge domain)
│       ├── consumer-research/ # Reviews, comparisons, recommendations
│       ├── skills-methods/    # Tutorials, guides, best practices
│       ├── industry-insights/ # Trends, business analysis
│       ├── lifestyle/         # Travel, food, fashion, home
│       ├── opinions/          # Commentary, value perspectives
│       ├── creative/          # Design, copywriting, marketing cases
│       └── resources/         # Tool recommendations, book lists
├── 📁 wiki/                  # AI-organized notes
│   ├── index.md              # 📇 Global index (auto-updated by AI)
│   ├── log.md                # 📝 Operation log (auto-recorded by AI)
│   └── topic notes...        # Including digested social media knowledge
├── 📁 assets/                # Image assets
└── 📁 .opencode/            # AI skills dir (opencode)
  │                          #   claude-code uses .claude/skills/
  │                          #   codex uses ~/.codex/skills/ (user-level)
    └── 📁 skill/             # AI skills (shared across all agents)
        ├── obsidian-cli/     # Obsidian operation capabilities
        ├── obsidian-markdown/ # Markdown generation capabilities
        ├── defuddle/         # Web content extraction capabilities
        ├── opencli-usage/    # OpenCLI command reference (100+ adapters)
        ├── smart-search/     # Intelligent search router
        ├── opencli-browser/  # Browser automation
        ├── opencli-autofix/  # Adapter auto-repair
        ├── opencli-explorer/ # Adapter development guide
        └── opencli-oneshot/  # Quick CLI generation
```

### Pre-installed Skills

The template comes with 9 pre-installed skills (source of truth: `vault-template/.opencode/skill/`). At deploy time they are distributed to the agent-specific directory (`.opencode/skill/` / `.claude/skills/` / `~/.codex/skills/`). The skill content is shared across all three agents:

| Skill | Purpose |
|-------|---------|
| `obsidian-cli` | Read, create, search notes in your Obsidian vault |
| `obsidian-markdown` | Generate and edit Obsidian-flavored Markdown |
| `defuddle` | Extract clean content from web pages |
| `opencli-usage` | OpenCLI command reference (100+ site adapters) |
| `smart-search` | Intelligent search router across multiple platforms |
| `opencli-browser` | Browser automation for AI agents |
| `opencli-autofix` | Automatically fix broken site adapters |
| `opencli-explorer` | Guide for creating new site adapters |
| `opencli-oneshot` | Quick 4-step template for adding a single command |

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

### 📱 Social Media Collection (Social Ingest)

After scraping content from Xiaohongshu, Douyin, Twitter, Weibo, etc. (using tools like opencli):

```
Scraped this:
[paste scraped note content]
```

```
Add this Xiaohongshu post
```

AI will automatically:
- Classify by knowledge domain (consumer research / skills & methods / industry insights / lifestyle / opinions / creative inspiration / resources)
- Assess credibility (sponsored content detection, evidence quality)
- Archive raw content to `raw/social/<domain>/`

> OpenCLI supports automatic content scraping via Chrome browser, reusing your login sessions. See [OpenCLI project](https://github.com/jackwener/OpenCLI).
>
> ⚠️ **Compliance & responsible use:** Automated scraping may violate the Terms of Service of some platforms — especially Chinese ones like Xiaohongshu, Douyin, and Weibo. This project is for **personal learning and research only**. You bear the risk of scraping frequency, content redistribution, and commercial use. Respect platform ToS and local laws, and be aware of account risk-control (rate limiting, suspension). Neither this project nor OpenCLI is liable for consequences of misuse.
- Digest and merge or create wiki articles (removing social media slang, keeping useful info)
- Auto-merge multiple posts on the same topic (e.g., multiple café reviews → city café guide)
- Update global index and operation log

> Supported platforms: Xiaohongshu, Douyin, Twitter/X, Weibo, Bilibili, WeChat, etc.

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

The basic version works great. Add these features on demand by simply telling your AI agent to install them:

| Feature | Install Command | Purpose |
|---------|-----------------|---------|
| 📄 PDF Export | "Install minimax-pdf skill" | Export notes to professional PDF |
| 📝 Word Export | "Install minimax-docx skill" | Generate Word documents |
| 📊 Excel Reading | "Install minimax-xlsx skill" | Read Excel data |
| 🎨 PPT Generation | "Install pptx-generator skill" | Turn notes into presentations |
| 🖼️ Image Analysis | "Install vision-analysis skill" | Analyze images and screenshots |

---

## ❓ FAQ

### Q0: How do I customize AI behavior?

Edit `AI_CONFIG.md` in your knowledge base root directory. You can customize:
- **Knowledge domains**: Add/remove/modify categories (e.g., add "Academic Notes")
- **Trigger words**: Change keywords that activate AI operations
- **Output language**: Switch to English content processing
- **Social platforms**: Add new platforms
- **Lint checks**: Enable/disable individual health checks
- **Custom rules**: Write additional rules in the `user-custom-rules` section

> Changes take effect on the next conversation — no restart needed.

### Q1: I don't have a technical background. Can I still use this?

Absolutely! This is designed specifically for non-technical users. Just follow the [`deployment-guide.md`](deployment-guide.md) step by step. No programming knowledge needed.

---

### Q2: Is my data secure?

Very secure:
- ✅ **Your note files stay on your own computer**; this project does not additionally host your notes
- ✅ **When you use AI**, the active conversation content is sent to the model provider you configured
- ✅ **Raw materials in `raw/` are never modified by AI**
- ✅ Notes are plain Markdown files, easy to copy and backup anytime

---

### Q3: Can I use other AI services?

Yes! The setup script supports 6 providers — choose your preferred one during installation:

| Provider | Default Model | Highlights |
|----------|---------------|------------|
| Zhipu GLM ⭐ | `glm-5.2` | Chinese service, great for Chinese users |
| Anthropic | `claude-opus-4-8` | Claude series models |
| OpenAI | `gpt-5.5` | GPT series models |
| Google Gemini | `gemini-3.1-pro-preview` | Gemini series models |
| OpenRouter | `anthropic/claude-opus-4.8` | Multi-model gateway, one key for many models |
| DeepSeek | `deepseek-v4-pro` | Chinese service, cost-effective |

Just paste your API Key and the config is generated automatically (the config file path differs per agent, see [`docs/agents.md`](docs/agents.md)). Want to switch later? Re-run `setup.sh` or manually edit your agent's config file:
- OpenCode: `~/.config/opencode/opencode.json`
- Claude Code: `~/.claude/settings.json`
- Codex: `~/.codex/config.toml`

---

### Q4: What if installation fails?

1. Make sure your Mac is running macOS 12 or later
2. Make sure your computer has internet access
3. Run the read-only check first: `bash scripts/verify.sh`
4. Then take a screenshot of the error message in terminal and open an Issue

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
- **[Claude Code](https://www.anthropic.com/claude-code)** — Anthropic's official AI coding agent
- **[Codex](https://developers.openai.com/codex/)** — OpenAI's official AI coding agent
- **[Obsidian](https://obsidian.md)** — Excellent local note-taking software
- **[claudian](https://github.com/YishenTu/claudian)** — A universal plugin that embeds AI agents in Obsidian
- **[opencode-obsidian](https://github.com/mtymek/opencode-obsidian)** — The OpenCode Obsidian plugin
- **[OpenCLI](https://github.com/jackwener/OpenCLI)** — Make any website your CLI, 100+ site adapters
- **[Zhipu GLM](https://open.bigmodel.cn)** / **[Anthropic](https://anthropic.com)** / **[OpenAI](https://openai.com)** / **[Google Gemini](https://ai.google)** / **[OpenRouter](https://openrouter.ai)** / **[DeepSeek](https://deepseek.com)** — Multiple AI service providers supported
- **[helloianneo/obsidian-ai-second-brain](https://github.com/helloianneo/obsidian-ai-second-brain)** — Inspiration for the knowledge base architecture

---

<div align="center">

**Made with ❤️ for knowledge seekers**

[⭐ Star this project](../../stargazers) · [🐛 Submit Issue](../../issues) · [💬 Join Discussion](../../discussions)

</div>
