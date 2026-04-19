---
name: opencli-oneshot
description: Use when quickly generating a single OpenCLI command from a specific URL and goal description. 4-step process — open page, capture API, write TS adapter, test. For full site exploration, use opencli-explorer instead.
tags: [opencli, adapter, quick-start, ts, cli, one-shot, automation]
---

# CLI-ONESHOT — 单点快速 CLI 生成

> 给一个 URL + 一句话描述，4 步生成一个 CLI 命令。
> 完整探索式开发请看 [opencli-explorer skill](../opencli-explorer/SKILL.md)。

**遇到以下情况立即切换到 explorer：**
- Step 3 验证 fetch 始终拿不到数据
- 需要 Pinia Store Action 触发 API
- 同一站点要生成 2 个以上命令

## 输入

| 项目 | 示例 |
|------|------|
| **URL** | `https://x.com/jakevin7/lists` |
| **Goal** | 获取我的 Twitter Lists |

## 流程

### Step 1: 打开页面 + 抓包

```bash
opencli browser open <目标 URL>
opencli browser wait time 3
opencli browser network
```

### Step 2: 锁定一个接口

```bash
opencli browser network --detail <N>     # 查看第 N 条请求的完整响应体
```

### Step 3: 验证接口能复现

```bash
# Tier 2 (Cookie)
opencli browser eval "fetch('/api/endpoint', { credentials: 'include' }).then(r => r.json())"

# Tier 2.5 (localStorage Bearer)
opencli browser eval "(async () => {
  const token = localStorage.getItem('access_token');
  const res = await fetch('https://api.example.com/endpoint', {
    headers: { 'Authorization': 'Bearer ' + token },
    credentials: 'include'
  });
  return res.json();
})()"
```

### Step 4: 套模板，生成 adapter

```javascript
// clis/<site>/<name>.js
import { cli, Strategy } from '@jackwener/opencli/registry';

cli({
  site: 'mysite',
  name: 'mycommand',
  description: '一句话描述',
  domain: 'www.example.com',
  strategy: Strategy.COOKIE,
  browser: true,
  args: [{ name: 'limit', type: 'int', default: 20 }],
  columns: ['rank', 'title', 'value'],
  func: async (page, kwargs) => {
    await page.goto('https://www.example.com/target-page');
    const data = await page.evaluate(`(async () => {
      const res = await fetch('/api/target', { credentials: 'include' });
      const d = await res.json();
      return (d.data?.items || []).map(item => ({
        title: item.title,
        value: item.value,
      }));
    })()`);
    return (data as any[]).slice(0, kwargs.limit).map((item, i) => ({
      rank: i + 1,
      title: item.title || '',
      value: item.value || '',
    }));
  },
});
```

## 认证速查

```
fetch(url) 直接能拿到？                        → Tier 1: public   (browser: false)
fetch(url, {credentials:'include'})？          → Tier 2: cookie
localStorage 有 token + Bearer header 能拿到？  → Tier 2.5: localStorage Bearer
加 CSRF/Bearer header 后拿到？                 → Tier 3: header
都不行，但页面自己能请求成功？                    → Tier 4: intercept
```

## 测试

```bash
# Repo 贡献
npm run build
opencli list | grep mysite
opencli mysite mycommand --limit 3 -v

# 私人 adapter
opencli browser verify <site>/<name>
```
