#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_ROOT

VAULT_PATH=""
FAILURES=0

usage() {
  cat <<'EOF'
Usage:
  bash scripts/verify.sh [--vault PATH]

Options:
  --vault PATH    额外检查一个已经部署好的 Vault 目录
  -h, --help      显示帮助
EOF
}

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

err() {
  printf '[ERR] %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

check_path() {
  local path="$1"
  local description="$2"

  if [[ -e "$path" ]]; then
    ok "$description"
  else
    err "$description missing: $path"
  fi
}

run_required_check() {
  local description="$1"
  shift

  if "$@"; then
    ok "$description"
  else
    err "$description failed"
  fi
}

check_script_exists() {
  local path="$1"
  check_path "$path" "$path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      VAULT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

cd "$REPO_ROOT"

echo "== Repo Files =="
check_script_exists "setup.sh"
check_script_exists "scripts/upgrade.sh"
check_script_exists "scripts/uninstall.sh"
check_script_exists "vault-template/scripts/organize-social-assets.sh"
check_path "README.md" "README.md"
check_path "README.en.md" "README.en.md"
check_path "CHANGELOG.md" "CHANGELOG.md"
check_path "deployment-guide.md" "deployment-guide.md"
check_path "GUIDE_FOR_AI.md" "GUIDE_FOR_AI.md"
check_script_exists "scripts/opencode-obsidian-doctor.sh"
check_script_exists "scripts/check-doc-links.sh"
check_script_exists "scripts/validate-docs.sh"
check_script_exists "scripts/verify.sh"
check_path "vault-template/AGENTS.md" "vault template AGENTS"
check_path "vault-template/AI_CONFIG.md" "vault template AI_CONFIG"
check_path "vault-template/wiki/index.md" "vault template wiki index"
check_path "vault-template/wiki/log.md" "vault template wiki log"

echo ""
echo "== Script Syntax =="
run_required_check "setup.sh syntax" bash -n setup.sh
run_required_check "upgrade.sh syntax" bash -n scripts/upgrade.sh
run_required_check "uninstall.sh syntax" bash -n scripts/uninstall.sh
run_required_check "organize-social-assets.sh syntax" bash -n vault-template/scripts/organize-social-assets.sh
run_required_check "doctor script syntax" bash -n scripts/opencode-obsidian-doctor.sh
run_required_check "doc link checker syntax" bash -n scripts/check-doc-links.sh
run_required_check "doc validation syntax" bash -n scripts/validate-docs.sh
run_required_check "verify script syntax" bash -n scripts/verify.sh

echo ""
echo "== Doc Checks =="
run_required_check "markdown link validation" bash scripts/check-doc-links.sh

if command -v shellcheck &>/dev/null; then
  echo ""
  echo "== Shellcheck =="
  run_required_check \
    "shellcheck" \
    shellcheck setup.sh scripts/upgrade.sh scripts/uninstall.sh vault-template/scripts/organize-social-assets.sh scripts/opencode-obsidian-doctor.sh scripts/check-doc-links.sh scripts/validate-docs.sh scripts/verify.sh
else
  warn "shellcheck not installed; skipping shell lint"
fi

echo ""
echo "== Environment =="
if command -v node &>/dev/null; then
  ok "node found: $(node --version)"
else
  warn "node not found"
fi

if command -v npm &>/dev/null; then
  ok "npm found: $(npm --version)"
else
  warn "npm not found"
fi

if command -v opencode &>/dev/null; then
  ok "opencode found: $(opencode --version 2>/dev/null || echo "version unknown")"
else
  warn "opencode not found"
fi

if command -v opencli &>/dev/null; then
  ok "opencli found: $(opencli --version 2>/dev/null || echo "version unknown")"
else
  warn "opencli not found"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -d "/Applications/Obsidian.app" ]]; then
    ok "Obsidian.app found"
  else
    warn "Obsidian.app not found in /Applications"
  fi
else
  warn "Non-macOS environment detected; skipping Obsidian.app check"
fi

if [[ -n "$VAULT_PATH" ]]; then
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

  echo ""
  echo "== Vault Checks =="
  check_path "$VAULT_PATH" "vault directory"
  check_path "$VAULT_PATH/AGENTS.md" "vault AGENTS.md"
  check_path "$VAULT_PATH/AI_CONFIG.md" "vault AI_CONFIG.md"
  check_path "$VAULT_PATH/raw" "vault raw directory"
  check_path "$VAULT_PATH/wiki" "vault wiki directory"
  check_path "$VAULT_PATH/assets" "vault assets directory"
  check_path "$VAULT_PATH/.opencode" "vault .opencode directory"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  err "verification finished with $FAILURES failure(s)"
  exit 1
fi

ok "verification finished successfully"
