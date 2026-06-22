# AI Agent 选择指南

本知识库支持三个 AI agent 驱动。它们的规则文件（`AGENTS.md` / `CLAUDE.md`）和技能内容相同，差异在于**安装方式、配置格式、技能目录位置、Obsidian 集成程度**。

部署时用 `--agent` 选择：

```bash
bash setup.sh --agent opencode      # 默认
bash setup.sh --agent claude-code
bash setup.sh --agent codex
```

---

## 横向对比

| 维度 | OpenCode | Claude Code | Codex | Pi |
|------|----------|-------------|-------|----|
| **npm 包** | `opencode-ai` | `@anthropic-ai/claude-code` | `@openai/codex` | `@mariozechner/pi-coding-agent` |
| **二进制** | `opencode` | `claude` | `codex` | `pi` |
| **厂商** | 独立开源 | Anthropic 官方 | OpenAI 官方 | 开源（earendil-works） |
| **记忆文件** | `AGENTS.md` | `CLAUDE.md`（+ AGENTS.md） | `AGENTS.md` | `AGENTS.md` |
| **用户配置** | `~/.config/opencode/opencode.json`（JSON） | `~/.claude/settings.json`（JSON） | `~/.codex/config.toml`（TOML） | `~/.pi/config.json`（JSON，主要靠 `/login`） |
| **技能目录** | `.opencode/skill/`（项目级） | `.claude/skills/`（项目级） | `~/.codex/skills/`（用户级） | `~/.pi/skills/`（用户级） |
| **Obsidian 插件** | ✅ [claudian](https://github.com/YishenTu/claudian)（默认）/ [opencode-obsidian](https://github.com/mtymek/opencode-obsidian) | ✅ [claudian](https://github.com/YishenTu/claudian) | ✅ [claudian](https://github.com/YishenTu/claudian) | ✅ [claudian](https://github.com/YishenTu/claudian) |
| **serve 模式** | opencode-obsidian 时用 `opencode serve` | ❌（CLI 调用） | ❌（CLI 调用） | ❌（CLI 调用） |
| **原生 provider** | 智谱/Anthropic/OpenAI/Google/OpenRouter/DeepSeek | Anthropic（第三方走 base_url） | OpenAI（第三方走 base_url） | 15+ provider，OpenAI 兼容端点 |
| **Node 要求** | ≥ 21 | ≥ 18 | ≥ 22 | ≥ 18 |

> 四个 agent 的技能 `SKILL.md` 格式兼容（都是 name/description frontmatter），技能内容完全一致，只是目录位置不同。
> **claudian 是默认 Obsidian 插件**，支持全部四个 agent；OpenCode 还可选 `--plugin opencode-obsidian`（serve 后台服务模式）。

---

## 选哪个？

### 🏆 OpenCode（默认推荐）

**适合：** 大多数用户，尤其是想「在 Obsidian 里直接和 AI 对话」的人。

- 最成熟的 Obsidian 集成（`opencode serve` 后台服务 + 官方插件）
- 原生支持全部 6 个 provider，配置最简单
- 一键部署体验最顺滑

### 🎯 Claude Code

**适合：** 已经在用 Claude Code、或偏好 Anthropic 生态的用户。

- Anthropic 官方 CLI，能力最强
- 通过 [claudian](https://github.com/YishenTu/claudian) 插件也能在 Obsidian 内用
- 第三方 provider（智谱/DeepSeek）通过 `ANTHROPIC_BASE_URL` 接入，配 OpenAI/Google 兼容性有限

### ⚡ Codex

**适合：** 已经在用 OpenAI Codex、或偏好 OpenAI 生态的用户。

- OpenAI 官方 CLI
- 通过 [claudian](https://github.com/YishenTu/claudian) 插件也能在 Obsidian 内用
- 配置是 TOML 格式；技能装在用户级 `~/.codex/skills/`

### 🪶 Pi

**适合：** 喜欢轻量、开源、可扩展 agent 的用户。

- 开源（[earendil-works/pi](https://github.com/earendil-works/pi)），TypeScript 工具集
- 支持 15+ provider，任何 OpenAI 兼容端点
- 主要靠 `pi` → `/login` 交互配置；技能装在用户级 `~/.pi/skills/`
- 通过 [claudian](https://github.com/YishenTu/claudian) 插件也能在 Obsidian 内用

---

## 能力边界说明

### Obsidian 集成

三个 agent 都能在 Obsidian 内使用：
- **OpenCode**：默认用 [opencode-obsidian](https://github.com/mtymek/opencode-obsidian)（最成熟，`opencode serve` 后台服务）；也可用 claudian
- **Claude Code**：用 [claudian](https://github.com/YishenTu/claudian)
- **Codex**：用 [claudian](https://github.com/YishenTu/claudian)（Codex 走自己的 CLI-managed MCP）

claudian 是一个通用插件，支持 Claude Code / Codex / OpenCode 等多个 agent。

### Provider 兼容性

| Provider | OpenCode | Claude Code | Codex |
|----------|----------|-------------|-------|
| 智谱 GLM | ✅ 原生 | ⚠️ 走 base_url | ⚠️ 走 base_url |
| Anthropic | ✅ 原生 | ✅ 原生（最佳） | ⚠️ 走 base_url |
| OpenAI | ✅ 原生 | ⚠️ 兼容性有限 | ✅ 原生（最佳） |
| Google | ✅ 原生 | ⚠️ 兼容性有限 | ⚠️ 走 base_url |
| OpenRouter | ✅ 原生 | ⚠️ 走 base_url | ⚠️ 走 base_url |
| DeepSeek | ✅ 原生 | ⚠️ 走 base_url | ⚠️ 走 base_url |

> 「走 base_url」表示通过自定义端点接入，功能可用但可能有兼容性细节差异。
> 想要最大兼容性，选 **OpenCode**（6 个 provider 全原生支持）。

---

## 切换 agent

想换 agent？重新运行 setup 并指定新的 `--agent`：

```bash
bash setup.sh --agent claude-code --provider anthropic --api-key <KEY> --overwrite-config
```

> 切换会重新生成对应 agent 的配置和技能目录，但**不会删除你已有的 raw/ wiki/ 笔记**。

卸载某个 agent 的配置：

```bash
bash scripts/uninstall.sh --agent codex
```

---

## 技术细节参考

- **OpenCode 配置**：`~/.config/opencode/opencode.json`，用 `$schema: opencode.ai/config.json`，`provider/model` 格式 + `@ai-sdk/*`。
- **Claude Code 配置**：`~/.claude/settings.json` 的 `env` 段注入 `ANTHROPIC_API_KEY` / `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN`。
- **Codex 配置**：`~/.codex/config.toml`，`[model_providers.<id>]` 段定义 base_url/wire_api/env_key。

各 agent 的具体配置示例见 [`GUIDE_FOR_AI.md`](../GUIDE_FOR_AI.md)。排障见：
- OpenCode: [`opencode-obsidian-setup-troubleshooting.md`](../opencode-obsidian-setup-troubleshooting.md)
- Claude Code: [`claude-code-setup-troubleshooting.md`](../claude-code-setup-troubleshooting.md)
- Codex: [`codex-setup-troubleshooting.md`](../codex-setup-troubleshooting.md)
