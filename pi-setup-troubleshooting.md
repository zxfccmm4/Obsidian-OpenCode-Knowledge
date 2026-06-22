# Pi 排障指南

> 配合 `--agent pi` 部署时的常见问题排查。

---

## 前置条件

| 组件 | 要求 | 检查命令 |
|------|------|----------|
| Node.js | ≥ 18 | `node -v` |
| Pi | 已安装 | `pi --version` |

如果 `pi` 命令找不到：

```bash
npm install -g @mariozechner/pi-coding-agent
```

---

## 在 Obsidian 内使用 Pi

Pi 通过 [claudian](https://github.com/YishenTu/claudian) 插件在 Obsidian 内使用。`--agent pi` 部署时，setup 会自动生成 claudian 的 `data.json`，用 `cliPathsByHost` 指向你的 `pi` 二进制。

**安装步骤：**
1. Obsidian 设置 → 第三方插件 → 搜索安装「BRAT」
2. BRAT 设置 → Add Plugin → 输入 `YishenTu/claudian`
3. 启用 claudian，在插件设置里选择 Pi 作为 agent

如果插件连不上 Pi，检查 `data.json` 的 `cliPathsByHost.darwin.pi` 是否指向真实路径（`which pi` 确认）。

---

## 常见问题

### Q1：首次使用如何配置

Pi 主要靠交互式 `/login` 配置：

```bash
pi
# 进入后输入 /login，按提示完成
```

setup 也会生成最小配置 `~/.pi/config.json`（含 model/baseUrl/apiKey），但推荐用 `/login` 完成 15+ provider 的完整配置。

### Q2：第三方 provider（智谱/DeepSeek）怎么配

Pi 支持任何 OpenAI 兼容端点。手动编辑 `~/.pi/config.json`：

```json
{
  "model": "glm-5.2",
  "baseUrl": "https://open.bigmodel.cn/api/paas/v4",
  "apiKey": "<你的智谱 API Key>"
}
```

或用 `/login` 走交互流程。

### Q3：技能不生效

Pi 技能在用户级 `~/.pi/skills/`。检查：

```bash
ls ~/.pi/skills/
```

应有 9 个技能目录。没有则重跑：

```bash
bash scripts/upgrade.sh --agent pi
```

> Pi 的 upgrade 不需要 `--vault`，因为技能装在用户目录。

---

## 重新部署

```bash
bash setup.sh --agent pi --provider openai --api-key <KEY> --overwrite-config
```

只读检查：

```bash
bash scripts/verify.sh --vault <你的vault>
```
