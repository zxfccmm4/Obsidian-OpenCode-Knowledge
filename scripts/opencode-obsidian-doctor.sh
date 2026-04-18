#!/usr/bin/env bash

set -u

PORT="${OPENCODE_PORT:-14096}"
HOST="${OPENCODE_HOST:-127.0.0.1}"
DEFAULT_VAULT="$HOME/Desktop/我的知识库"
VAULT_DIR="$DEFAULT_VAULT"
KILL_PORT=0
START_TEST=0

usage() {
  cat <<'EOF'
Usage:
  bash <deploy>/scripts/opencode-obsidian-doctor.sh [--vault PATH] [--port PORT] [--host HOST] [--kill-port] [--start-test]

Options:
  --vault PATH    Vault path. Default: ~/Desktop/我的知识库
  --port PORT     Server port. Default: 14096
  --host HOST     Server host. Default: 127.0.0.1
  --kill-port     Kill the process currently listening on the target port
  --start-test    Run opencode serve in the foreground with the recommended command
  --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)
      VAULT_DIR="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --kill-port)
      KILL_PORT=1
      shift
      ;;
    --start-test)
      START_TEST=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERR] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

PLUGIN_DIR="$VAULT_DIR/.obsidian/plugins/opencode-obsidian"
PLUGIN_DATA="$PLUGIN_DIR/data.json"
PLUGIN_MAIN="$PLUGIN_DIR/main.js"
LOG_DIR="$HOME/.local/share/opencode/log"
NODE_BIN="$(command -v node 2>/dev/null || true)"
OPENCODE_BIN="$(command -v opencode 2>/dev/null || true)"
HEALTH_URL="http://$HOST:$PORT/global/health"

hr() {
  printf '\n== %s ==\n' "$1"
}

ok() {
  printf '[OK] %s\n' "$1"
}

warn() {
  printf '[WARN] %s\n' "$1"
}

err() {
  printf '[ERR] %s\n' "$1"
}

hr "Environment"
echo "Vault: $VAULT_DIR"
echo "Host:  $HOST"
echo "Port:  $PORT"
echo "Node:  ${NODE_BIN:-<not found>}"
echo "OpenCode: ${OPENCODE_BIN:-<not found>}"

hr "Binary Checks"
if [[ -n "$NODE_BIN" ]]; then
  ok "node found"
  "$NODE_BIN" --version || warn "Failed to run node --version"
else
  err "node not found in PATH"
fi

if [[ -n "$OPENCODE_BIN" ]]; then
  ok "opencode found"
  "$OPENCODE_BIN" --version || warn "Failed to run opencode --version"
else
  err "opencode not found in PATH"
fi

hr "Vault Checks"
if [[ -d "$VAULT_DIR" ]]; then
  ok "Vault directory exists"
else
  err "Vault directory does not exist"
fi

if [[ -d "$PLUGIN_DIR" ]]; then
  ok "Plugin directory exists: $PLUGIN_DIR"
else
  warn "Plugin directory not found: $PLUGIN_DIR"
fi

hr "Port Check"
LSOF_OUTPUT="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
if [[ -n "$LSOF_OUTPUT" ]]; then
  warn "Port $PORT is in use"
  printf '%s\n' "$LSOF_OUTPUT"
else
  ok "Port $PORT is free"
fi

if [[ "$KILL_PORT" -eq 1 ]]; then
  hr "Kill Port"
  if [[ -z "$LSOF_OUTPUT" ]]; then
    warn "Nothing is listening on port $PORT"
  else
    PIDS="$(printf '%s\n' "$LSOF_OUTPUT" | awk 'NR > 1 { print $2 }' | sort -u)"
    if [[ -n "$PIDS" ]]; then
      echo "Trying to stop: $PIDS"
      kill $PIDS 2>/dev/null || kill -9 $PIDS 2>/dev/null || true
      sleep 1
      REMAINING="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
      if [[ -n "$REMAINING" ]]; then
        err "Port $PORT is still occupied"
        printf '%s\n' "$REMAINING"
      else
        ok "Port $PORT has been released"
      fi
    fi
  fi
fi

hr "Health Check"
HEALTH_BODY="$(curl -fsS --max-time 3 "$HEALTH_URL" 2>/dev/null || true)"
if [[ -n "$HEALTH_BODY" ]]; then
  ok "Health endpoint reachable: $HEALTH_URL"
  printf '%s\n' "$HEALTH_BODY"
else
  warn "Health endpoint is not reachable: $HEALTH_URL"
fi

hr "Plugin Config"
if [[ -f "$PLUGIN_DATA" ]]; then
  ok "Found plugin data.json"
  sed -n '1,80p' "$PLUGIN_DATA"
else
  warn "Plugin data.json not found"
fi

if [[ -f "$PLUGIN_MAIN" ]]; then
  if grep -Fq 'fetch(`http://${this.settings.hostname}:${this.settings.port}/global/health`' "$PLUGIN_MAIN"; then
    ok "Plugin uses direct /global/health check"
  elif grep -Fq 'getUrl()}/global/health' "$PLUGIN_MAIN"; then
    warn "Plugin appears to use the older project-scoped health check"
  else
    warn "Could not identify plugin health check implementation"
  fi
else
  warn "Plugin main.js not found"
fi

hr "Recommended Command"
if [[ -n "$NODE_BIN" && -n "$OPENCODE_BIN" ]]; then
  echo "$NODE_BIN $OPENCODE_BIN serve --port $PORT --hostname $HOST --cors app://obsidian.md"
else
  warn "Cannot build the recommended command because node/opencode is missing"
fi

hr "Recent Logs"
if [[ -d "$LOG_DIR" ]]; then
  LATEST_LOG="$(ls -1t "$LOG_DIR" 2>/dev/null | head -n 1)"
  if [[ -n "$LATEST_LOG" ]]; then
    ok "Latest log: $LOG_DIR/$LATEST_LOG"
    sed -n '1,80p' "$LOG_DIR/$LATEST_LOG"
  else
    warn "No log files found"
  fi
else
  warn "Log directory not found: $LOG_DIR"
fi

if [[ "$START_TEST" -eq 1 ]]; then
  hr "Start Test"
  if [[ -z "$NODE_BIN" || -z "$OPENCODE_BIN" ]]; then
    err "node or opencode is missing"
    exit 1
  fi
  exec "$NODE_BIN" "$OPENCODE_BIN" serve --port "$PORT" --hostname "$HOST" --cors "app://obsidian.md"
fi

hr "Done"
echo "If the health endpoint is healthy but Obsidian still shows Error,"
echo "reload the plugin or restart Obsidian, then re-check the plugin main.js health check."
