# agentic-config shell pieces
# Source of truth: this repo's shell.zsh
# Sourced from ~/.zshrc by install.sh

# Prevent Ctrl-S / Ctrl-Q from freezing the terminal
stty -ixon 2>/dev/null

# 4-pane Claude workspace in the current working directory
#   pane 0,1: default effort
#   pane 2:   CLAUDE_CODE_EFFORT_LEVEL=medium
#   pane 3:   CLAUDE_CODE_EFFORT_LEVEL=low
# Each invocation creates a fresh session (unique name per call).
t() {
  local dir="$PWD"
  # Always fresh: unique session name per invocation (basename + timestamp).
  local session="cwork-$(basename "$dir")-$$-$(date +%s)"

  # Launch claude as each pane's argv (not via send-keys) so we don't race
  # against .zshrc sourcing / instant-prompt plugins. `exec zsh` keeps the
  # pane alive with a shell prompt after claude exits.
  # After `select-layout tiled`, panes land as:
  #   index 0 = top-left  (high)
  #   index 1 = top-right (high)
  #   index 2 = bottom-left  (medium)
  #   index 3 = bottom-right (low)
  local p0 p1 p2 p3
  p0=$(tmux new-session  -d  -s "$session" -c "$dir" -n claude -P -F '#{pane_id}' \
       'claude; exec zsh')
  p1=$(tmux split-window -h -t "$p0" -c "$dir" -e CLAUDE_CODE_EFFORT_LEVEL=medium -P -F '#{pane_id}' \
       'claude; exec zsh')
  p2=$(tmux split-window -v -t "$p0" -c "$dir"                                    -P -F '#{pane_id}' \
       'claude; exec zsh')
  p3=$(tmux split-window -v -t "$p1" -c "$dir" -e CLAUDE_CODE_EFFORT_LEVEL=low    -P -F '#{pane_id}' \
       'claude; exec zsh')
  tmux select-layout -t "$session:0" tiled
  tmux select-pane -t "$p0"

  if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session"
  else
    tmux attach -t "$session"
  fi
}

alias cwork=t
