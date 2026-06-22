#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_ROOT

FILES=(
  "README.md"
  "README.en.md"
  "CHANGELOG.md"
  "deployment-guide.md"
  "GUIDE_FOR_AI.md"
  "CONTRIBUTING.md"
  "opencode-obsidian-setup-troubleshooting.md"
  "claude-code-setup-troubleshooting.md"
  "codex-setup-troubleshooting.md"
  "pi-setup-troubleshooting.md"
  "docs/agents.md"
)

should_skip_target() {
  case "$1" in
    ""|"#"*|http://*|https://*|mailto:*|tel:*)
      return 0
      ;;
    ../../issues|../../discussions|../../stargazers)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

extract_targets() {
  local file="$1"

  awk '
    BEGIN { in_fence = 0 }
    /^```/ { in_fence = !in_fence; next }
    !in_fence && $0 !~ /^```markdown/ { print }
  ' "$file" | perl -nE 'while (/\[[^][]+\]\(([^)]+)\)/g) { say $1 }'
}

main() {
  local file dir target clean_target resolved_path failed
  failed=0

  cd "$REPO_ROOT"

  for file in "${FILES[@]}"; do
    dir="$(dirname "$file")"

    while IFS= read -r target; do
      should_skip_target "$target" && continue

      if [[ "$target" == "./relative/path.md" || "$target" == "./other-article.md" ]]; then
        continue
      fi

      clean_target="${target%%#*}"
      clean_target="${clean_target#<}"
      clean_target="${clean_target%>}"

      if [[ -z "$clean_target" ]]; then
        continue
      fi

      resolved_path="$dir/$clean_target"
      if [[ ! -e "$resolved_path" ]]; then
        printf '[ERR] %s -> missing target: %s\n' "$file" "$target" >&2
        failed=1
      fi
    done < <(extract_targets "$file")
  done

  if [[ "$failed" -ne 0 ]]; then
    exit 1
  fi

  echo "[OK] Markdown file links look valid."
}

main "$@"
