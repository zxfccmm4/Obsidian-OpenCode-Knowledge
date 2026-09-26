# Claude Code + claudian 排障指南

> 配合 `--agent claude-code` 部署时的常见问题排查。

---

## 前置条件

| 组件 | 要求 | 检查命令 |
|------|------|----------|
| Node.js | ≥ 18 | `node -v` |
| Claude Code | 已安装 | `claude --version` |
| Obsidian | 已安装 | `/Applications/Obsidian.app` |
| claudian 插件 | 已通过 BRAT 安装 | Obsidian 设置 → 第三方插件 |

如果 `claude` 命令找不到：

```bash
npm install -g @anthropic-ai/claude-code
```

---

## 常见问题

### Q1：claudian 插件在 Obsidian 里连不上 Claude Code

**症状：** 插件面板显示「连接失败」或空白。

**排查：**

1. 确认 `claude` 在终端能跑：

   ```bash
   claude --version
   ```

2. 检查插件的 `data.json` 里 `claudePath` 是否指向真实的 claude 二进制：

   ```bash
   cat <你的vault>/.obsidian/plugins/claudian/data.json
   ```

   `claudePath` 应为 `claude` 命令的绝对路径（如 `/opt/homebrew/bin/claude` 或 `/usr/local/bin/claude`）。若不对，用 `which claude` 找到正确路径后手动改。

3. 重启 Obsidian 或在插件设置里点「重新加载」。

### Q2：第三方 provider（智谱/DeepSeek）连不上

**症状：** Claude Code 报 401 / 403 / 连接超时。

Claude Code 通过环境变量接入第三方 provider。检查 `~/.claude/settings.json`：

```bash
cat ~/.claude/settings.json
```

应包含类似：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "<你的智谱 API Key>",
    "ANTHROPIC_API_KEY": ""
  },
  "model": "glm-5.2"
}
```

setup 只会改上面这几项，文件里的其他设置保持不变。

**注意：** Claude Code 只会说 Anthropic 协议，`ANTHROPIC_BASE_URL` 必须是服务商的 **Anthropic 兼容端点**；OpenAI 兼容地址（如 `/api/paas/v4`、`/v1`）它连不上：

| 服务商 | `ANTHROPIC_BASE_URL` |
|--------|----------------------|
| 智谱 GLM | `https://open.bigmodel.cn/api/anthropic` |
| DeepSeek | `https://api.deepseek.com/anthropic` |
| OpenRouter | `https://openrouter.ai/api` |

`ANTHROPIC_API_KEY` 置空，是为了防止把你 shell 环境里的 Anthropic Key 一并发给第三方。

### Q3：OpenAI / Google 模型用不了

OpenAI 和 Google 没有 Anthropic 兼容端点，Claude Code 连不上它们，所以 setup 会在开始前直接拒绝这个组合。

**建议：** 想用 GPT / Gemini，换用 **OpenCode**（`--agent opencode`，原生支持全部 6 个 provider）或 **Codex**。

### Q4：技能不生效

**症状：** Claude Code 不识别 obsidian-cli / smart-search 等技能。

Claude Code 的技能在 `.claude/skills/`（项目级）。检查：

```bash
ls <你的vault>/.claude/skills/
```

应看到 9 个技能目录。如果没有，重新运行 upgrade：

```bash
bash scripts/upgrade.sh --vault <你的vault> --agent claude-code
```

### Q5：CLAUDE.md 没被加载

确认 vault 根目录有 `CLAUDE.md`（setup 选 claude-code 时自动生成，内容与 AGENTS.md 相同）：

```bash
ls <你的vault>/CLAUDE.md
```

Claude Code 在 vault 目录启动时会自动加载它。

---

## 重新部署

如果配置乱了，最简单的办法是重新生成（`--keep-existing` 会保留你的笔记）：

```bash
bash setup.sh --agent claude-code --provider anthropic --api-key <KEY> --overwrite-config --keep-existing
```

或只读检查环境：

```bash
bash scripts/verify.sh --vault <你的vault>
```
