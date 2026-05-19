#!/usr/bin/env bash
# Background updater that keeps ~/.claude/.statusline.cache fresh every 2s.
# Started by Claude Code SessionStart hook, stopped by Stop hook.
# Re-uses the compute logic from statusline.sh by invoking it with cached stdin.

set -u

CACHE_DIR="$HOME/.claude"
CACHE_FILE="$CACHE_DIR/.statusline.cache"
INPUT_FILE="$CACHE_DIR/.statusline.input"
PID_FILE="$CACHE_DIR/.statusline.pid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

start() {
  mkdir -p "$CACHE_DIR"
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
  fi
  (
    while true; do
      if [ -s "$INPUT_FILE" ]; then
        # Bypass the cache-read fast path: invoke compute by removing/staling cache,
        # then call statusline.sh which writes a fresh cache file.
        rm -f "$CACHE_FILE" 2>/dev/null
        "$STATUSLINE" <"$INPUT_FILE" >/dev/null 2>&1 || true
      fi
      sleep 2
    done
  ) >/dev/null 2>&1 &
  echo $! >"$PID_FILE"
  disown 2>/dev/null || true
}

stop() {
  if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
}

case "${1:-start}" in
  start) start ;;
  stop)  stop  ;;
  restart) stop; start ;;
  *) echo "usage: $0 {start|stop|restart}" >&2; exit 2 ;;
esac

# Read and discard hook stdin so Claude Code's hook pipe doesn't block
cat >/dev/null 2>&1 || true
exit 0
