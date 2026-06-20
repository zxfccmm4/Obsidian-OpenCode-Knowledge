# 更新日志 / Changelog

本项目版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。
已部署用户可用 `bash scripts/upgrade.sh --vault <你的知识库路径>` 升级规则与技能（不会动你的笔记）。

---

## [Unreleased]

---

## [0.5.0] - 2026-06-20

### 新增
- **多 AI Agent 支持**：除默认的 OpenCode 外，新增 **Claude Code** 和 **Codex** 两种 agent 驱动。部署时用 `--agent opencode|claude-code|codex` 选择。
- **`resolve_agent()` 抽象层**：所有 agent 差异（二进制、配置路径、技能目录、记忆文件、Obsidian 插件）收敛到一组变量，单一事实源驱动。
- **三套配置生成**：
  - OpenCode：`~/.config/opencode/opencode.json`（JSON）
  - Claude Code：`~/.claude/settings.json`（JSON + env 段）
  - Codex：`~/.codex/config.toml`（TOML）
- **技能目录按 agent 分发**：`.opencode/skill/`（opencode）/ `.claude/skills/`（claude-code）/ `~/.codex/skills/`（codex 用户级）。技能内容一致，格式兼容。
- **AGENTS.md / CLAUDE.md 双写**：claude-code 额外生成 CLAUDE.md；AGENTS.md 措辞泛化为「由 AI agent 自动加载」。
- **Obsidian 插件按 agent 分发**：opencode → opencode-obsidian（默认）；claude-code / codex → [claudian](https://github.com/YishenTu/claudian)（通用插件，用 `cliPathsByHost` 配置）。**三个 agent 都能在 Obsidian 内使用**。
- **[`docs/agents.md`](docs/agents.md)**：三 agent 横向对比、选型建议、能力边界。
- **两篇排障文档**：[`claude-code-setup-troubleshooting.md`](claude-code-setup-troubleshooting.md)、[`codex-setup-troubleshooting.md`](codex-setup-troubleshooting.md)。

### 变更
- `setup.sh` / `upgrade.sh` / `uninstall.sh` / `verify.sh` 全部支持 `--agent` 参数。
- README 标题改为「Obsidian + AI Agent 知识库」，加三 agent 对比与 `--agent` 说明。
- `GUIDE_FOR_AI.md` 手动部署段加 agent 选择表。
- bug_report 模板字段改为「使用的 Agent + 版本」。
- `.markdownlint-cli2.jsonc` / `check-doc-links.sh` 纳入新文档。

---

## [0.4.0] - 2026-06-19

### 新增
- **升级脚本 `scripts/upgrade.sh`**：一键把仓库里的规则、技能、辅助脚本同步到已部署的 vault，**绝不触碰** `raw/` `wiki/` `assets/`。`AI_CONFIG.md` 会先备份再覆盖。
- **卸载脚本 `scripts/uninstall.sh`**：清理 OpenCode 配置和 Obsidian 插件配置；`--remove-vault` 可连同 vault 一起删，`--remove-packages` 卸载全局 npm 包。默认保留用户数据，高风险操作需二次确认。
- **资产整理脚本 `vault-template/scripts/organize-social-assets.sh`**：封装 Social Ingest 里易错的 ID 目录 → 标题目录提升 + 相对路径图片引用生成。AI 调用脚本而非手动拼路径。
- **AGENTS.md 触发词消歧规则**：多触发词同时命中时（如带素材的"查一下"）给出优先级判定，避免误触发。
- **平台与合规标识**：README 加 macOS 平台徽章与跨平台说明；社交媒体采集章节加 ToS / 合规免责声明。

### 变更
- **更新全部 AI 模型到 2026 当前版本**（按各 provider 官方文档一手源核实，`setup.sh` 顶部沉淀为单一事实源）：
  - 智谱 GLM：`glm-4.5` → **`glm-5.2`**（旗舰，100万上下文）/ `glm-5.1` / `glm-5`
  - Anthropic：`claude-sonnet-4-20250514` → **`claude-opus-4-8`**（当前旗舰）/ `claude-sonnet-4-6`
  - OpenAI：`gpt-4.1` → **`gpt-5.5`**（当前旗舰）/ `gpt-5.4-mini`
  - Google：`gemini-2.5-pro` → **`gemini-3.1-pro-preview`**（原 `gemini-3-pro` 已 shut down）
  - DeepSeek：`deepseek-chat` → **`deepseek-v4-pro`** / `deepseek-v4-flash`（⚠️ 旧模型名 2026-07-24 下线）
- **Node.js 要求提升到 v21+**（OpenCode 运行时要求）；`setup.sh` 现在会检查版本并提示升级。
- OpenCLI 适配器数量描述统一更新为 **100+**（原 87+）。
- Social Ingest 流程改为调用 `organize-social-assets.sh`，移除让 AI 手动 `mv`/数相对层数的步骤。

---

## [0.3.0] - 2026-05-17

### 新增
- `setup.sh` 支持 `--non-interactive` / `--dry-run` 自动化模式，以及 `--provider` / `--api-key` 等显式参数。
- `scripts/verify.sh` 只读检查（仓库结构 + 脚本语法 + 文档链接 + 本机环境）。
- `scripts/opencode-obsidian-doctor.sh` 排障脚本（端口、健康检查、日志、插件配置）。
- GitHub Actions CI：bash 语法 + shellcheck + 文档校验。

### 变更
- wiki 文章的 Sources 必须链接到本地 raw 文件，禁止使用外部 URL。
- 新增 `AI_CONFIG.md`，支持用户自定义知识域 / 触发词 / 输出语言 / lint 检查项。

---

## [0.2.0] - 2026-04

### 新增
- 支持 6 个 AI 服务提供商（智谱 GLM / Anthropic / OpenAI / Google / OpenRouter / DeepSeek）。
- `GUIDE_FOR_AI.md`：面向 AI agent 的机器可读部署指南，支持"让 AI 帮你部署"零门槛路径。
- Social Ingest 触发行为 + opencli 抓取管线。
- 预装 9 个技能（obsidian-cli、obsidian-markdown、defuddle、opencli-*、smart-search）。

---

## [0.1.0] - 2026-04-14

### 新增
- 初始版本：Obsidian + OpenCode AI 知识库模板。
- `setup.sh` 一键部署（macOS）。
- `AGENTS.md` 定义四个触发行为：Ingest / Query / Lint / Social Ingest。
