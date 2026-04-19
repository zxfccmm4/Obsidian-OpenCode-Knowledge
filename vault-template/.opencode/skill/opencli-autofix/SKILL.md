---
name: opencli-autofix
description: Automatically fix broken OpenCLI adapters when commands fail. Load this skill when an opencli command fails — it guides you through diagnosing the failure via OPENCLI_DIAGNOSTIC, patching the adapter, retrying, and filing an upstream GitHub issue after a verified fix. Works with any AI agent.
allowed-tools: Bash(opencli:*), Bash(gh:*), Read, Edit, Write
---

# OpenCLI AutoFix — Automatic Adapter Self-Repair

When an `opencli` command fails because a website changed its DOM, API, or response schema, **automatically diagnose, fix the adapter, and retry**.

## Safety Boundaries

- **`AUTH_REQUIRED`** (exit code 77) — **STOP.** Tell user to log into the site in Chrome.
- **`BROWSER_CONNECT`** (exit code 69) — **STOP.** Tell user to run `opencli doctor`.
- **CAPTCHA / rate limiting** — **STOP.** Not an adapter issue.
- **Only modify** `RepairContext.adapter.sourcePath` — never modify `src/`, `extension/`, `tests/`
- **Max 3 repair rounds** per failure

## Step 1: Collect Diagnostic Context

```bash
OPENCLI_DIAGNOSTIC=1 opencli <site> <command> [args...] 2>diagnostic.json
```

## Step 2: Analyze the Failure

| Error Code | Likely Cause | Repair Strategy |
|-----------|-------------|-----------------|
| SELECTOR | DOM restructured | Explore current DOM → find new selector |
| EMPTY_RESULT | API response schema changed | Check network → find new response path |
| API_ERROR | Endpoint URL changed | Discover new API via network intercept |
| AUTH_REQUIRED | Login flow changed, cookies expired | **STOP** — tell user to log in |
| TIMEOUT | Page loads differently | Add/update wait conditions |
| PAGE_CHANGED | Major redesign | May need full adapter rewrite |

## Step 3: Explore the Current Website

Use `opencli browser` to inspect the live website. Never use the broken adapter.

```bash
# DOM changed
opencli browser open https://example.com/target-page && opencli browser state

# API changed
opencli browser open https://example.com/target-page && opencli browser network
```

## Step 4: Patch the Adapter

Read the adapter source file at `RepairContext.adapter.sourcePath` and make targeted fixes.

### Common Fixes

**Selector update:**
```typescript
// Before: page.evaluate('document.querySelector(".old-class")...')
// After:  page.evaluate('document.querySelector(".new-class")...')
```

**API endpoint change:**
```typescript
// Before: fetch('/api/v1/old-endpoint')
// After:  fetch('/api/v2/new-endpoint')
```

**Response schema change:**
```typescript
// Before: const items = data.results
// After:  const items = data.data.items
```

## Step 5: Verify the Fix

```bash
opencli <site> <command> [args...]
```

If still fails, go back to Step 1. Max 3 rounds.

## Step 6: File an Upstream Issue

Only after a verified local fix:

```bash
gh issue create --repo jackwener/OpenCLI \
  --title "[autofix] <site>/<command>: <error_code>" \
  --body "<fix summary>"
```

Ask the user before filing.
