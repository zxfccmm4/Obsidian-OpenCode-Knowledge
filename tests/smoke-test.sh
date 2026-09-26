#!/usr/bin/env bash
# ============================================================
# smoke-test.sh — setup.sh / upgrade.sh / uninstall.sh 端到端冒烟测试
#
# 在临时 HOME 里运行真实脚本，用桩命令替代 npm、各 agent CLI 和 sudo：
# 不联网、不安装任何东西、不碰你的真实配置。需要 node（脚本用它写 JSON）。
#
# 用法：
#   bash tests/smoke-test.sh
#   BASH_BIN=/bin/bash /bin/bash tests/smoke-test.sh   # 用 macOS 自带的 bash 3.2 跑
# ============================================================
# 断言函数都经由 check "$@" 间接调用（新版 shellcheck 用 SC2329 报这种情况）
# shellcheck disable=SC2317,SC2329
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_ROOT
BASH_BIN="${BASH_BIN:-bash}"
readonly BASH_BIN

REAL_NODE="$(command -v node || true)"
if [[ -z "$REAL_NODE" ]]; then
  echo "[ERR] node is required to run the smoke tests" >&2
  exit 1
fi
readonly REAL_NODE

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

FAILURES=0
CASE_COUNT=0
SANDBOX=""
OUTPUT=""

pass() {
  printf '  [OK] %s\n' "$1"
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  if [[ -n "$OUTPUT" ]]; then
    printf '%s\n' "$OUTPUT" | tail -n 8 | sed 's/^/    | /' >&2
  fi
  FAILURES=$((FAILURES + 1))
}

check() {
  local description="$1"
  shift
  if "$@"; then
    pass "$description"
  else
    fail "$description"
  fi
}

not() {
  ! "$@"
}

exists_any() {
  [[ -e "$1" ]]
}

contains() {
  [[ "$1" == *"$2"* ]]
}

not_contains() {
  [[ "$1" != *"$2"* ]]
}

file_mode() {
  "$REAL_NODE" -e 'process.stdout.write((require("fs").statSync(process.argv[1]).mode & 0o777).toString(8))' "$1"
}

# json_is <文件> <JS 表达式，c 为解析后的对象> <期望值>
json_is() {
  local actual
  actual="$("$REAL_NODE" -e '
    const c = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    process.stdout.write(String(eval(process.argv[2])));
  ' "$1" "$2" 2>&1)" || {
    echo "    cannot evaluate $2 in $1: $actual" >&2
    return 1
  }
  if [[ "$actual" != "$3" ]]; then
    echo "    expected $2 == '$3', got '$actual'" >&2
    return 1
  fi
}

# 每个用例一个全新的 HOME，外加替代 npm / agent CLI / sudo 的桩命令
new_sandbox() {
  CASE_COUNT=$((CASE_COUNT + 1))
  SANDBOX="$TMP_ROOT/case-$CASE_COUNT"
  OUTPUT=""
  mkdir -p "$SANDBOX/home" "$SANDBOX/bin" "$SANDBOX/npm-global"
  write_stubs "$SANDBOX/bin"
  printf '\n== %s ==\n' "$1"
}

write_stubs() {
  local bin="$1"
  local name

  for name in opencode claude codex pi opencli; do
    printf '#!/bin/sh\necho "%s 0.0.0-test"\n' "$name" > "$bin/$name"
  done

  # npm root -g 返回一个可写目录（所以不会走 sudo），其他子命令一律假装成功
  cat > "$bin/npm" <<'EOF'
#!/bin/sh
if [ "$1" = "root" ]; then
  echo "$STUB_NPM_ROOT"
fi
exit 0
EOF

  # 版本号固定报告满足要求的 v22，其余交给真实 node（setup.sh 用它写 JSON）
  cat > "$bin/node" <<EOF
#!/bin/sh
if [ "\$1" = "-v" ] || [ "\$1" = "--version" ]; then
  echo v22.0.0
  exit 0
fi
exec "$REAL_NODE" "\$@"
EOF

  cat > "$bin/sudo" <<'EOF'
#!/bin/sh
echo "unexpected sudo call: $*" >&2
exit 97
EOF

  chmod +x "$bin"/*
}

# 在沙箱里运行仓库脚本；输出保存在 OUTPUT，返回脚本的退出码
run_script() {
  local status=0
  OUTPUT="$(cd "$SANDBOX" && env HOME="$SANDBOX/home" PATH="$SANDBOX/bin:$PATH" \
    STUB_NPM_ROOT="$SANDBOX/npm-global" OPENCODE_API_KEY="" \
    "$BASH_BIN" "$@" 2>&1 < /dev/null)" || status=$?
  return "$status"
}

test_opencode_zhipu() {
  new_sandbox "setup: opencode + zhipu creates a vault and a private config"
  local vault="$SANDBOX/home/kb vault"
  local cfg="$SANDBOX/home/.config/opencode/opencode.json"
  local plugin="$vault/.obsidian/plugins/claudian/data.json"
  local key='sk-"quote"\back'

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent opencode --provider zhipu --api-key "$key"
  check "vault has AGENTS.md" test -f "$vault/AGENTS.md"
  check "vault has wiki/index.md" test -f "$vault/wiki/index.md"
  check "skills live in .opencode/skill" test -f "$vault/.opencode/skill/defuddle/SKILL.md"
  check "no .gitkeep left behind" test -z "$(find "$vault" -name .gitkeep 2>/dev/null)"
  check "default model uses the zhipuglm provider" json_is "$cfg" 'c.model.startsWith("zhipuglm/")' true
  check "API key with quotes and backslash round-trips" json_is "$cfg" 'c.provider.zhipuglm.options.apiKey' "$key"
  check "config file is private (600)" test "$(file_mode "$cfg" 2>/dev/null)" = 600
  check "claudian points at the opencode binary" json_is "$plugin" 'c.cliPathsByHost.darwin.opencode' "$SANDBOX/bin/opencode"
}

test_claude_code_merge() {
  new_sandbox "setup: claude-code + deepseek merges into an existing settings.json"
  local vault="$SANDBOX/home/kb"
  local cfg="$SANDBOX/home/.claude/settings.json"

  mkdir -p "$(dirname "$cfg")"
  printf '%s\n' '{"permissions":{"allow":["Bash(ls)"]},"env":{"FOO":"bar","ANTHROPIC_API_KEY":"old-key"}}' > "$cfg"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent claude-code --provider deepseek --api-key sk-deepseek --overwrite-config
  check "existing permissions are kept" json_is "$cfg" 'c.permissions.allow[0]' 'Bash(ls)'
  check "existing env vars are kept" json_is "$cfg" 'c.env.FOO' bar
  check "uses the Anthropic-compatible endpoint" json_is "$cfg" 'c.env.ANTHROPIC_BASE_URL' 'https://api.deepseek.com/anthropic'
  check "key goes to ANTHROPIC_AUTH_TOKEN" json_is "$cfg" 'c.env.ANTHROPIC_AUTH_TOKEN' sk-deepseek
  check "old ANTHROPIC_API_KEY is blanked" json_is "$cfg" 'c.env.ANTHROPIC_API_KEY' ''
  check "old config was backed up" exists_any "$cfg".backup-*
  check "skills live in .claude/skills" test -f "$vault/.claude/skills/defuddle/SKILL.md"
  check "CLAUDE.md is generated" test -f "$vault/CLAUDE.md"
  check "no .opencode directory in the vault" test ! -e "$vault/.opencode"
}

test_claude_code_rejects_openai() {
  new_sandbox "setup: claude-code + openai is rejected before touching anything"
  local vault="$SANDBOX/home/kb"

  check "setup exits non-zero" not run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent claude-code --provider openai --api-key sk-x
  check "no vault was created" test ! -e "$vault"
  check "no Claude settings were written" test ! -e "$SANDBOX/home/.claude/settings.json"
}

test_codex_openrouter() {
  new_sandbox "setup: codex + openrouter keeps foreign skills and never prints the key"
  local vault="$SANDBOX/home/kb"
  local skills="$SANDBOX/home/.codex/skills"
  local cfg="$SANDBOX/home/.codex/config.toml"

  mkdir -p "$skills/my-own-skill"
  echo "mine" > "$skills/my-own-skill/SKILL.md"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent codex --provider openrouter --api-key sk-or-SECRET-123
  check "user's own skill survives" test -f "$skills/my-own-skill/SKILL.md"
  check "project skills installed at the top level" test -f "$skills/defuddle/SKILL.md"
  check "skills are not nested under skills/skill" test ! -e "$skills/skill"
  check "model_provider is openrouter" grep -q '^model_provider = "openrouter"$' "$cfg"
  check "model has no provider prefix" not grep -q '^model = "openrouter/' "$cfg"
  check "API key never appears in the output" not_contains "$OUTPUT" "SECRET-123"
  check "no .opencode directory in the vault" test ! -e "$vault/.opencode"
}

test_skip_provider() {
  new_sandbox "setup: --provider skip still writes the plugin config and finishes"
  local vault="$SANDBOX/home/kb"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive --vault "$vault" --provider skip
  check "plugin config is written" test -f "$vault/.obsidian/plugins/claudian/data.json"
  check "setup reaches the final instructions" contains "$OUTPUT" "scripts/verify.sh"
}

test_replace_existing() {
  new_sandbox "setup: --overwrite-existing renames the old vault instead of deleting it"
  local vault="$SANDBOX/home/kb"

  mkdir -p "$vault/wiki"
  echo "my note" > "$vault/wiki/note.md"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --provider skip --overwrite-existing
  check "old note is in the backup" exists_any "$vault".backup-*/wiki/note.md
  check "new vault is fresh" test ! -e "$vault/wiki/note.md"
  check "new vault has AGENTS.md" test -f "$vault/AGENTS.md"
}

test_keep_existing_switch_agent() {
  new_sandbox "setup: --keep-existing keeps notes while switching opencode -> claude-code"
  local vault="$SANDBOX/home/kb"
  local plugin="$vault/.obsidian/plugins/claudian/data.json"

  check "first setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent opencode --provider skip
  mkdir -p "$vault/wiki"
  echo "my note" > "$vault/wiki/note.md"
  echo "my custom rule" >> "$vault/AI_CONFIG.md"

  check "second setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent claude-code --provider skip --keep-existing
  check "note is kept" test -f "$vault/wiki/note.md"
  check "customized AI_CONFIG.md is kept" grep -q "my custom rule" "$vault/AI_CONFIG.md"
  check "new template saved as AI_CONFIG.md.new" test -f "$vault/AI_CONFIG.md.new"
  check "Claude Code skills installed" test -f "$vault/.claude/skills/defuddle/SKILL.md"
  check "CLAUDE.md is generated" test -f "$vault/CLAUDE.md"
  check "claudian gains the claude path" json_is "$plugin" 'c.cliPathsByHost.darwin.claude' "$SANDBOX/bin/claude"
  check "claudian keeps the opencode path" json_is "$plugin" 'c.cliPathsByHost.darwin.opencode' "$SANDBOX/bin/opencode"
}

test_existing_needs_explicit_choice() {
  new_sandbox "setup: an existing directory is left alone without --keep/--overwrite"
  local vault="$SANDBOX/home/kb"

  mkdir -p "$vault"
  echo "x" > "$vault/note.md"
  check "setup exits non-zero" not run_script "$REPO_ROOT/setup.sh" --non-interactive --vault "$vault" --provider skip
  check "existing file untouched" test -f "$vault/note.md"
}

test_dangerous_paths() {
  new_sandbox "setup: refuses HOME, Desktop and paths that resolve to them"
  mkdir -p "$SANDBOX/home/Desktop"
  echo "keep me" > "$SANDBOX/home/Desktop/file.txt"

  check "refuses HOME" not run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$SANDBOX/home" --provider skip --overwrite-existing
  check "refuses Desktop" not run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$SANDBOX/home/Desktop" --provider skip --overwrite-existing
  check "refuses Desktop/.. (resolves to HOME)" not run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$SANDBOX/home/Desktop/.." --provider skip --overwrite-existing
  check "Desktop is untouched" test -f "$SANDBOX/home/Desktop/file.txt"
}

test_dry_run() {
  new_sandbox "setup: --dry-run writes nothing"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --dry-run --non-interactive \
    --vault "$SANDBOX/home/kb" --agent codex --provider zhipu
  check "HOME is still empty" test -z "$(ls -A "$SANDBOX/home")"
}

test_upgrade() {
  new_sandbox "upgrade: detects the agent, refreshes skills, keeps user files"
  local vault="$SANDBOX/home/kb"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive \
    --vault "$vault" --agent claude-code --provider skip
  mkdir -p "$vault/.claude/skills/my-skill" "$vault/.claude/skills/defuddle"
  echo "mine" > "$vault/.claude/skills/my-skill/SKILL.md"
  echo "STALE-MARKER-7f3a" > "$vault/.claude/skills/defuddle/SKILL.md"
  rm -f "$vault/wiki/log.md"

  check "upgrade exits 0 without --agent" run_script "$REPO_ROOT/scripts/upgrade.sh" --vault "$vault" --non-interactive
  check "detected claude-code (no .opencode created)" test ! -e "$vault/.opencode"
  check "project skill refreshed" not grep -q STALE-MARKER-7f3a "$vault/.claude/skills/defuddle/SKILL.md"
  check "user's own skill kept" test -f "$vault/.claude/skills/my-skill/SKILL.md"
  check "missing wiki/log.md restored" test -f "$vault/wiki/log.md"
  check "untouched AI_CONFIG.md produces no .new file" test ! -e "$vault/AI_CONFIG.md.new"
}

test_uninstall() {
  new_sandbox "uninstall: --remove-vault only deletes real vaults"
  local vault="$SANDBOX/home/kb"
  local notes="$SANDBOX/home/notes"

  mkdir -p "$notes"
  echo "x" > "$notes/file.txt"
  check "refuses a directory without AGENTS.md" not run_script "$REPO_ROOT/scripts/uninstall.sh" \
    --agent opencode --vault "$notes" --remove-vault --non-interactive
  check "that directory is untouched" test -f "$notes/file.txt"

  check "setup exits 0" run_script "$REPO_ROOT/setup.sh" --non-interactive --vault "$vault" --provider skip
  check "uninstall exits 0 for a real vault" run_script "$REPO_ROOT/scripts/uninstall.sh" \
    --vault "$vault" --remove-vault --non-interactive
  check "the vault is removed" test ! -e "$vault"
}

test_doctor_empty_logs() {
  new_sandbox "doctor: survives an empty log directory"
  mkdir -p "$SANDBOX/home/.local/share/opencode/log"

  check "doctor exits 0" run_script "$REPO_ROOT/scripts/opencode-obsidian-doctor.sh" --vault "$SANDBOX/home/kb"
}

# 单引号是故意的：让被测的 bash 自己展开 $BASH_VERSION
# shellcheck disable=SC2016
echo "Using bash: $("$BASH_BIN" -c 'echo "$BASH_VERSION"')"

test_opencode_zhipu
test_claude_code_merge
test_claude_code_rejects_openai
test_codex_openrouter
test_skip_provider
test_replace_existing
test_keep_existing_switch_agent
test_existing_needs_explicit_choice
test_dangerous_paths
test_dry_run
test_upgrade
test_uninstall
test_doctor_empty_logs

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "[FAIL] $FAILURES check(s) failed" >&2
  exit 1
fi
echo "[OK] all smoke tests passed"
