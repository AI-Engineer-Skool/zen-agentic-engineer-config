#!/usr/bin/env bash
# Claude Code statusLine: model | git branch (+worktree) | context bar
# Reads cache written by statusline-daemon.sh for a true ~2s refresh cadence;
# computes inline as fallback if the cache is stale or missing.

set -u

INPUT="$(cat)"
CACHE_DIR="$HOME/.claude"
CACHE_FILE="$CACHE_DIR/.statusline.cache"
INPUT_FILE="$CACHE_DIR/.statusline.input"
STALE_AFTER=3   # seconds

compute_line() {
  local input="$1"
  local model_name cwd used ctx_max
  model_name=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')
  cwd=$(printf '%s'        "$input" | jq -r '.workspace.current_dir // .cwd // empty')
  # Authoritative context-window data populated by Claude Code (v2.0.65+).
  # used_percentage is precomputed; total_input/output_tokens reflect the
  # current in-context tokens. Both are null/0 until the first API call
  # completes, then populate after every assistant turn.
  # NOTE: current_usage is an OBJECT (input_tokens, output_tokens, cache_*),
  # not a scalar — do NOT try to use it directly in arithmetic.
  local pct_pre
  ctx_max=$(printf '%s'    "$input" | jq -r '.context_window.context_window_size // 200000')
  used=$(printf '%s'       "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)')
  pct_pre=$(printf '%s'    "$input" | jq -r '.context_window.used_percentage // empty')

  # --- model slug: strip "Claude " prefix and any "(...)" suffix, lowercase, space->dash ---
  local slug
  slug=$(printf '%s' "$model_name" | awk '
    {
      n = $0
      sub(/[[:space:]]*\([^)]*\)[[:space:]]*$/, "", n)   # drop trailing (...)
      sub(/^[Cc]laude[[:space:]]+/, "", n)
      n = tolower(n)
      gsub(/[[:space:]]+/, "-", n)
      print n
    }')

  # --- git segment ---
  local git_seg=""
  if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch gd cd_path
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    gd=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    cd_path=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
    # Normalize to absolute for comparison
    case "$gd" in /*) ;; *) gd="$cwd/$gd";; esac
    case "$cd_path" in /*) ;; *) cd_path="$cwd/$cd_path";; esac
    git_seg="$branch"
    if [ "$gd" != "$cd_path" ]; then
      local wt
      wt=$(basename "$gd")
      git_seg="$branch +wt:$wt"
    fi
  fi

  # --- context bar ---
  [ "$ctx_max" -le 0 ] && ctx_max=200000
  local pct
  if [ -n "$pct_pre" ]; then
    pct=$(awk -v p="$pct_pre" 'BEGIN { printf("%d", p + 0.5) }')
  else
    pct=$(( used * 100 / ctx_max ))
  fi
  [ $pct -gt 100 ] && pct=100
  [ $pct -lt 0 ] && pct=0
  local filled=$(( pct * 20 / 100 ))
  [ $filled -gt 20 ] && filled=20
  local empty=$(( 20 - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty;  i++)); do bar="${bar}░"; done

  fmt_k() {
    local n=$1
    if [ $n -ge 1000 ]; then
      awk -v n="$n" 'BEGIN { printf("%.0fk", n/1000) }'
    else
      printf '%d' "$n"
    fi
  }
  local used_s max_s
  used_s=$(fmt_k "$used")
  max_s=$(fmt_k "$ctx_max")
  local ctx_seg
  ctx_seg=$(printf '[%s] %d%% (%s/%s)' "$bar" "$pct" "$used_s" "$max_s")

  if [ -n "$git_seg" ]; then
    printf '%s  │  %s  │  %s\n' "$slug" "$git_seg" "$ctx_seg"
  else
    printf '%s  │  %s\n' "$slug" "$ctx_seg"
  fi
}

file_mtime() {
  # GNU stat first (Linux), then BSD stat (macOS).
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

# Stash latest stdin FIRST so the daemon always has current input, and so
# cache freshness can be measured against this file's mtime. Only rewrite
# when the payload actually changed — otherwise an unchanged input would
# keep bumping mtime and permanently invalidate the cache.
mkdir -p "$CACHE_DIR"
if [ ! -f "$INPUT_FILE" ] || [ "$INPUT" != "$(cat "$INPUT_FILE" 2>/dev/null)" ]; then
  printf '%s' "$INPUT" >"$INPUT_FILE" 2>/dev/null || true
fi

# Prefer fresh cache if available AND newer than the latest input we've seen.
# If input changed (e.g. after /clear or a new assistant turn), the input file
# is newer than the cache, so we fall through and recompute immediately.
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  cache_mtime=$(file_mtime "$CACHE_FILE")
  input_mtime=$(file_mtime "$INPUT_FILE")
  now=$(date +%s)
  age=$(( now - cache_mtime ))
  if [ $age -le $STALE_AFTER ] && [ "$cache_mtime" -ge "$input_mtime" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Fallback: compute inline (also seeds the cache for the daemon)
line=$(compute_line "$INPUT")
printf '%s\n' "$line" | tee "$CACHE_FILE" >/dev/null
printf '%s\n' "$line"
