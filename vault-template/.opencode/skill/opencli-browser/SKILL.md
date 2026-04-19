---
name: opencli-browser
description: Make websites accessible for AI agents. Navigate, click, type, extract, wait — using Chrome with existing login sessions. No LLM API key needed.
allowed-tools: Bash(opencli:*), Read, Edit, Write
---

# OpenCLI Browser — Browser Automation for AI Agents

Control Chrome step-by-step via CLI. Reuses existing login sessions — no passwords needed.

## Prerequisites

```bash
opencli doctor    # Verify extension + daemon connectivity
```

Requires: Chrome running + OpenCLI Browser Bridge extension installed.

## Critical Rules

1. **ALWAYS use `state` to inspect the page, NEVER use `screenshot`** — `state` returns structured DOM with `[N]` element indices, is instant and costs zero tokens.
2. **ALWAYS use `click`/`type`/`select` for interaction, NEVER use `eval` to click or type** — `eval "el.click()"` bypasses scrollIntoView and CDP click pipeline.
3. **Verify inputs with `get value`, not screenshots** — after `type`, run `get value <index>` to confirm.
4. **Run `state` after every page change** — after `open`, `click` (on links), `scroll`, always run `state`.
5. **Chain commands aggressively with `&&`** — combine commands to reduce overhead.
6. **`eval` is read-only** — use `eval` ONLY for data extraction, never for clicking, typing, or navigating.
7. **Minimize total tool calls** — plan your sequence before acting.
8. **Prefer `network` to discover APIs** — most sites have JSON APIs. API-based adapters are more reliable than DOM scraping.

## Core Workflow

1. **Navigate**: `opencli browser open <url>`
2. **Inspect**: `opencli browser state` → elements with `[N]` indices
3. **Interact**: use indices — `click`, `type`, `select`, `keys`
4. **Wait** (if needed): `opencli browser wait selector ".loaded"` or `wait text "Success"`
5. **Verify**: `opencli browser state` or `opencli browser get value <N>`
6. **Repeat**: browser stays open between commands
7. **Save**: write a JS adapter to `~/.opencli/clis/<site>/<command>.js`

## Commands

### Navigation

```bash
opencli browser open <url>              # Open URL (page-changing)
opencli browser back                    # Go back (page-changing)
opencli browser scroll down             # Scroll (up/down, --amount N)
```

### Inspect (free & instant)

```bash
opencli browser state                   # Structured DOM with [N] indices — PRIMARY tool
opencli browser screenshot [path.png]   # Save visual to file — ONLY for user deliverables
```

### Get (free & instant)

```bash
opencli browser get title               # Page title
opencli browser get url                 # Current URL
opencli browser get text <index>        # Element text content
opencli browser get value <index>       # Input/textarea value (use to verify after type)
opencli browser get html                # Full page HTML
opencli browser get html --selector "h1" # Scoped HTML
opencli browser get attributes <index>  # Element attributes
```

### Interact

```bash
opencli browser click <index>           # Click element [N]
opencli browser type <index> "text"     # Type into element [N]
opencli browser select <index> "option" # Select dropdown
opencli browser keys "Enter"            # Press key (Enter, Escape, Tab, Control+a)
```

### Wait

```bash
opencli browser wait time 3                       # Wait N seconds
opencli browser wait selector ".loaded"            # Wait until element appears
opencli browser wait selector ".spinner" --timeout 5000  # With timeout
opencli browser wait text "Success"                # Wait until text appears
```

### Extract (free & instant, read-only)

```bash
opencli browser eval "document.title"
opencli browser eval "JSON.stringify([...document.querySelectorAll('h2')].map(e => e.textContent))"
```

### Network (API Discovery)

```bash
opencli browser network                  # Show captured API requests
opencli browser network --detail 3       # Show full response body of request #3
opencli browser network --all            # Include static resources
```

### Session

```bash
opencli browser close                   # Close automation window
```

## Action Chaining

Always chain when possible — fewer tool calls = faster completion:

```bash
# GOOD: open + inspect in one call
opencli browser open https://example.com && opencli browser state

# GOOD: fill form in one call
opencli browser type 3 "hello" && opencli browser type 4 "world" && opencli browser click 7

# GOOD: click + wait + state in one call
opencli browser click 12 && opencli browser wait time 1 && opencli browser state
```

## Tips

1. **Always `state` first** — never guess element indices
2. **Sessions persist** — browser stays open between commands
3. **Use `eval` for data extraction** — `eval "JSON.stringify(...)"` is faster than multiple `get` calls
4. **Use `network` to find APIs** — JSON APIs are more reliable than DOM scraping
5. **Alias**: `opencli op` is shorthand for `opencli browser`

## Troubleshooting

| Error | Fix |
|-------|-----|
| "Browser not connected" | Run `opencli doctor` |
| "attach failed: chrome-extension://" | Disable 1Password temporarily |
| Element not found | `opencli browser scroll down && opencli browser state` |
| Stale indices after page change | Run `opencli browser state` again |
