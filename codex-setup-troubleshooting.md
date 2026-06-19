# Codex 排障指南

> 配合 `--agent codex` 部署时的常见问题排查。

---

## 前置条件

| 组件 | 要求 | 检查命令 |
|------|------|----------|
| Node.js | ≥ 22 | `node -v` |
| Codex | 已安装 | `codex --version` |

如果 `codex` 命令找不到：

```bash
npm install -g @openai/codex
```

---

## ⚠️ 关于 Obsidian 集成

**Codex 目前没有成熟的 Obsidian 插件**。选 codex 时，setup 不会生成插件配置，你主要在**终端**使用 `codex` 命令。

如果你非常需要在 Obsidian 里用，可关注社区插件进展；但当前建议把 Codex 当作终端工具，配合 Obsidian 仅做笔记编辑。

---

## 常见问题

### Q1：codex 命令找不到或版本过旧

```bash
codex --version
```

若找不到或版本低：

```bash
npm install -g @openai/codex
```

### Q2：第三方 provider（智谱/DeepSeek）连不上

Codex 的配置在 `~/.codex/config.toml`（TOML 格式）。检查：

```bash
cat ~/.codex/config.toml
```

应包含 `[model_providers.<id>]` 段，例如智谱：

```toml
model = "zhipuglm/glm-5.2"
model_provider = "zhipuglm"

[model_providers.zhipuglm]
name = "智谱 GLM"
base_url = "https://open.bigmodel.cn/api/paas/v4"
wire_api = "chat"
env_key = "ZHIPU_API_KEY"
```

然后设置环境变量（Codex 通过 env_key 读取密钥）：

```bash
export ZHIPU_API_KEY="<你的智谱 API Key>"
```

建议写入 `~/.zshrc` 或 `~/.bashrc` 持久化。

### Q3：API Key 怎么传给 Codex

Codex 通过 `env_key` 指定的环境变量读取密钥。两种方式：

1. **环境变量**（推荐）：`export <ENV_KEY>=<你的Key>`，写入 shell 配置持久化。
2. **auth.json**：Codex 也读 `~/.codex/auth.json`，但环境变量更通用。

setup 生成配置时会提示你需要设置哪个环境变量。

### Q4：技能不生效

Codex 的技能在**用户级** `~/.codex/skills/`（不是项目级）。检查：

```bash
ls ~/.codex/skills/
```

应看到 9 个技能目录。如果没有，重新运行 upgrade：

```bash
bash scripts/upgrade.sh --agent codex
```

> 注意：codex 的 upgrade 不需要 `--vault`，因为技能装在用户目录。

### Q5：AGENTS.md 没被加载

Codex 会自动加载项目根的 `AGENTS.md`。在 vault 目录运行 codex 时它会读取：

```bash
cd <你的vault>
codex
```

确认 vault 根有 `AGENTS.md`：

```bash
ls <你的vault>/AGENTS.md
```

### Q6：wire_api 该用 chat 还是 responses

- `chat`：OpenAI 兼容的 Chat Completions API（智谱/DeepSeek/OpenRouter 等第三方用这个）
- `responses`：OpenAI 原生 Responses API（仅 OpenAI 官方用）

setup 会自动选择：OpenAI provider 用 `responses`，其他用 `chat`。

---

## 重新部署

```bash
bash setup.sh --agent codex --provider openai --api-key <KEY> --overwrite-config
```

只读检查：

```bash
bash scripts/verify.sh --vault <你的vault>
```
