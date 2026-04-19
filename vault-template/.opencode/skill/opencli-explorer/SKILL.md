---
name: opencli-explorer
description: Use when creating a new OpenCLI adapter from scratch, adding support for a new website or platform, exploring a site's API endpoints via browser DevTools, or when a user asks to automatically generate a CLI for a website. Covers automated generation, API discovery workflow, authentication strategy selection, TS adapter writing, and testing.
tags: [opencli, adapter, browser, api-discovery, cli, web-scraping, automation, generate]
---

# CLI-EXPLORER — 适配器探索式开发完全指南

> 从零到发布：API 发现 → 认证策略 → 写适配器 → 测试验证。

## 先选路径

| 情况 | 走这里 |
|------|--------|
| 只要为一个具体页面生成一个命令 | [opencli-oneshot skill](../opencli-oneshot/SKILL.md) |
| 想先让机器自动试一遍 | `opencli generate <url> [--goal <goal>]`，失败再回来 |
| 新站点 / 多个命令 / oneshot 卡住了 | 继续往下读本文档 |

## 核心流程

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐     ┌────────┐
│ 1. 发现 API  │ ──▶ │ 2. 选择策略  │ ──▶ │ 3. 写适配器   │ ──▶ │ 4. 测试 │
└─────────────┘     └─────────────┘     └──────────────┘     └────────┘
  browser explore     cascade             TS cli() API         verify
```

## AI Agent 必读：必须用浏览器探索

> **必须通过浏览器打开目标网站去探索！** 不要只靠静态分析。
> 很多 API 是懒加载的——字幕、评论、关注列表等深层数据只有点击后才触发。

### 浏览器探索工作流

| 步骤 | 命令 | 做什么 |
|------|------|--------|
| 0. 打开页面 | `opencli browser open <url>` | 导航到目标页面 |
| 1. 观察元素 | `opencli browser state` | 查看可交互元素 |
| 2. 首次抓包 | `opencli browser network` | 列出捕获的 JSON API |
| 3. 模拟交互 | `opencli browser click <N>` | 点击按钮触发懒加载 |
| 4. 二次抓包 | `opencli browser network` | 找出新触发的 API |
| 5. 查看响应 | `opencli browser network --detail <N>` | 查看完整响应体 |

## Step 1: 发现 API

关注：URL pattern、Method、Request Headers、Response Body 路径

### 高阶捷径

1. **后缀爆破法 (`.json`)**：Reddit、雪球等，URL 加 `.json` 直接拿 REST 数据
2. **全局状态法 (`__INITIAL_STATE__`)**：SSR 站点首页数据挂载在 window 上
3. **主动交互触发法**：懒加载 API 需要点击按钮才触发
4. **框架 Store 截断**：Vue + Pinia 站点，Store Action 绕过签名
5. **XHR/Fetch 拦截**：最后手段

## Step 2: 选择认证策略

```bash
opencli cascade https://api.example.com/hot   # 自动探测
```

| Tier | 策略 | 速度 | 实例 |
|------|------|------|------|
| 1 | `public` | ⚡ ~1s | Hacker News, V2EX |
| 2 | `cookie` | 🔄 ~7s | Bilibili, Zhihu, Reddit |
| 2.5 | `localStorage Bearer` | 🔄 ~7s | Slock, Linear, Notion |
| 3 | `header` | 🔄 ~7s | Twitter GraphQL |
| 4 | `intercept` | 🔄 ~10s | 小红书 (Pinia + XHR) |
| 5 | `ui` | 🐌 ~15s+ | 遗留网站 |

## Step 3: 编写适配器

所有适配器统一使用 `cli()` API，放入 `clis/<site>/<name>.js` 即自动注册。

```typescript
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
    await page.goto('https://www.example.com');
    const data = await page.evaluate(`(async () => {
      const res = await fetch('/api/items', { credentials: 'include' });
      const d = await res.json();
      return d.data?.items || [];
    })()`);
    return (data as any[]).slice(0, kwargs.limit).map((item, i) => ({
      rank: i + 1,
      title: item.title || '',
      value: item.value || '',
    }));
  },
});
```

## Step 4: 测试

```bash
# Repo 贡献
npm run build
opencli list | grep mysite
opencli mysite mycommand --limit 3 -v

# 私人 adapter
opencli browser verify <site>/<name>
```

## 常见陷阱

| 陷阱 | 解决方案 |
|------|---------|
| 缺少 `navigate` | 在 evaluate 前加 `page.goto()` |
| 缺少 `strategy: public` | 加 `strategy: Strategy.PUBLIC` + `browser: false` |
| 风控被拦截（伪 200） | 断言数据，`throw new AuthRequiredError(domain)` |
| SPA 返回 HTML | 搜 JS bundle 找 baseURL |
| TS evaluate 格式 | 必须用 IIFE：`(async () => { ... })()` |

## 用 AI Agent 自动生成

```bash
opencli generate https://www.example.com --goal "hot"
# 或分步：
opencli explore https://www.example.com --site mysite
opencli synthesize mysite
opencli verify mysite/hot --smoke
```
