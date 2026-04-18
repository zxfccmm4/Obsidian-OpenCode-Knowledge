# OpenCode-Obsidian 标准安装与排障

这份文档补充 `setup.sh` 和 `deployment-guide.md` 中关于 `opencode-obsidian` 插件的配置与故障排查细节。

适用场景：

- 你已经跑完 `bash setup.sh`
- Obsidian 里的 OpenCode 面板显示 `Error`
- 插件提示 `Process exited unexpectedly (exit code 1)`
- 你想手动确认插件配置是否正确

---

## 一、标准安装清单

### 1. 确认基础依赖

先在终端里确认 `node` 和 `opencode` 都能用：

```bash
which node
which opencode
node --version
opencode --version
```

推荐结果：

- `node` 有可执行路径，例如 `/opt/homebrew/bin/node`
- `opencode` 有可执行路径，例如 `/opt/homebrew/bin/opencode`

---

### 2. 跑部署脚本

```bash
bash setup.sh
```

脚本会自动：

- 安装 Node.js
- 安装 OpenCode CLI
- 创建 Vault
- 生成 `~/.config/opencode/opencode.json`
- 在 Vault 里生成 `opencode-obsidian` 的 `data.json`

---

### 3. 在 Obsidian 中完成插件安装

`setup.sh` 不会自动帮你安装第三方插件，这一步要手动完成。

推荐使用 BRAT 安装：

1. 安装并启用 `BRAT`
2. `Cmd + P`
3. 执行 `BRAT: Add a plugin`
4. 输入 `mtymek/opencode-obsidian`

---

### 4. 推荐插件配置

`setup.sh` 生成的推荐配置如下：

```json
{
  "port": 14096,
  "hostname": "127.0.0.1",
  "autoStart": true,
  "opencodePath": "/path/to/opencode",
  "startupTimeout": 45000,
  "defaultViewLocation": "sidebar",
  "injectWorkspaceContext": false,
  "maxNotesInContext": 20,
  "maxSelectionLength": 2000,
  "customCommand": "/path/to/node /path/to/opencode serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md",
  "useCustomCommand": true
}
```

关键点只有 4 个：

- `useCustomCommand` 必须是 `true`
- `customCommand` 必须能在终端里单独跑通
- `hostname` 推荐固定为 `127.0.0.1`
- `port` 推荐固定为 `14096`

---

### 5. 首次启动前的手动验证

如果你想先确认服务本身没问题，直接手动跑一次：

```bash
"$(which node)" "$(which opencode)" serve --port 14096 --hostname 127.0.0.1 --cors app://obsidian.md
```

另开一个终端检查：

```bash
curl http://127.0.0.1:14096/global/health
```

正常应返回：

```json
{"healthy":true,"version":"..."}
```

---

## 二、快速排障顺序

遇到插件报错时，优先按这个顺序查：

### 1. 看端口是否被旧进程占住

```bash
lsof -nP -iTCP:14096 -sTCP:LISTEN
```

如果有输出，说明旧的 `opencode` 还在占端口。

先正常结束：

```bash
kill <PID>
```

如果不退出，再强制结束：

```bash
kill -9 <PID>
```

---

### 2. 检查健康接口

```bash
curl http://127.0.0.1:14096/global/health
```

- 如果返回 `healthy: true`，说明 `opencode` 服务本身正常
- 如果连不上，优先排查 CLI 启动失败、端口冲突或配置错误

---

### 3. 直接看 OpenCode 日志

```bash
ls -lt ~/.local/share/opencode/log | head
sed -n '1,120p' ~/.local/share/opencode/log/<最新日志文件>
```

重点看这些报错：

- `Failed to start server on port 14096`
- `EADDRINUSE`
- `command not found`
- `permission denied`

---

### 4. 用 doctor 脚本快速诊断

仓库里已经附带诊断脚本：

```bash
bash /path/to/deploy/scripts/opencode-obsidian-doctor.sh
```

默认检查 `~/Desktop/我的知识库`。

如果你的 Vault 在别处：

```bash
bash /path/to/deploy/scripts/opencode-obsidian-doctor.sh --vault "/你的/Vault/路径"
```

如果要自动清理占用端口的旧进程：

```bash
bash /path/to/deploy/scripts/opencode-obsidian-doctor.sh --vault "/你的/Vault/路径" --kill-port
```

如果要用当前环境做一次前台启动验证：

```bash
bash /path/to/deploy/scripts/opencode-obsidian-doctor.sh --vault "/你的/Vault/路径" --start-test
```

---

## 三、一个常见坑：插件健康检查误判

如果出现下面这种情况：

- `opencode serve` 手动启动正常
- `curl http://127.0.0.1:14096/global/health` 也正常
- 但 Obsidian 插件里还是显示 `Error`

那通常不是 `opencode` 坏了，而是插件自己的健康检查逻辑和你当前版本不兼容。

可以检查：

```bash
<你的Vault>/.obsidian/plugins/opencode-obsidian/main.js
```

如果里面是这种旧写法：

```js
fetch(`${this.getUrl()}/global/health`, ...)
```

它可能会误判。

更稳妥的写法应该直接检查：

```js
fetch(`http://${this.settings.hostname}:${this.settings.port}/global/health`, ...)
```

改完之后，必须：

- 重载插件，或
- 重启 Obsidian

否则修改不会生效。

---

## 四、建议的验收命令

部署完成后，建议至少检查一次：

```bash
node --version
opencode --version
ls ~/Desktop/我的知识库/.obsidian/plugins/opencode-obsidian/
cat ~/.config/opencode/opencode.json
```

如果你已经打开插件面板，再补一次：

```bash
curl http://127.0.0.1:14096/global/health
```

---

## 五、推荐用法

以后每次遇到 `OpenCode` 面板异常，先跑：

```bash
bash /path/to/deploy/scripts/opencode-obsidian-doctor.sh --vault "/你的/Vault/路径"
```

先让脚本把二进制、端口、健康接口、插件配置和日志都看一遍，再决定是重启 Obsidian、杀旧进程，还是修插件配置。
