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

## 在 Obsidian 内使用 Codex

Codex 通过 [claudian](https://github.com/YishenTu/claudian) 插件也能在 Obsidian 内使用。`--agent codex` 部署时，setup 会自动生成 claudian 的 `data.json`，用 `cliPathsByHost` 指向你的 `codex` 二进制。

**安装步骤：**
1. Obsidian 设置 → 第三方插件 → 搜索安装「BRAT」
2. BRAT 设置 → Add Plugin → 输入 `YishenTu/claudian`
3. 启用 claudian，在插件设置里选择 Codex 作为 agent

> claudian 是通用插件，支持 Claude Code / Codex / OpenCode 等多个 agent。Codex 走自己的 CLI-managed MCP。

如果插件连不上 Codex，检查 `data.json` 的 `cliPathsByHost.darwin.codex` 是否指向真实路径（`which codex` 确认）。

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
model = "glm-5.2"
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

setup 生成配置时会提示你需要设置哪个环境变量（出于安全考虑，不会在终端里显示你的 Key）。

### Q4：技能不生效

Codex 的技能在**用户级** `~/.codex/skills/`（不是项目级）。检查：

```bash
ls ~/.codex/skills/
```

应看到 9 个技能目录。如果没有，重新运行 upgrade：

```bash
bash scripts/upgrade.sh --agent codex
```

> 不传 `--vault` 时默认升级 `~/Desktop/我的知识库`；知识库在别处时加上 `--vault <路径>`。技能按名字逐个更新，`~/.codex/skills/` 里你自己装的其他技能不受影响。

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

setup 会自动选择：OpenAI provider 用 `responses`，其他用 `chat`。OpenAI 生成的 provider 名叫 `openai-api`，避免和 Codex 内置的 `openai` 重名，确保 `env_key` 生效。

---

## 重新部署

```bash
bash setup.sh --agent codex --provider openai --api-key <KEY> --overwrite-config --keep-existing
```

只读检查：

```bash
bash scripts/verify.sh --vault <你的vault>
```
