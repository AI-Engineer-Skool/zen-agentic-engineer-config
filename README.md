# Zen Agentic Engineer

A lightweight agentic engineering workflow for Claude Code, built around the original
[**Zen Agentic Engineer**](https://github.com/AI-Engineer-Skool/zen-agentic-engineer-config)
four-grid tmux setup — with a Claude Code usage/session monitor added on top of the
existing status line. The four-grid workflow itself is unchanged; the monitor is this
version's contribution.

Explainer video: https://youtu.be/ElYxdpYi4U0

My personal simple agentic engineer workflow: tmux + zsh helpers + Claude Code status line + slash commands.
Feel free to adapt to your OS or other AI tool with an AI Agent if you need to ;)

Tested on Mac and Claude Code:

```sh
./install.sh && exec zsh
```

**Requirements:** [`jq`](https://jqlang.org/). This is a pre-existing dependency of the
project, not something introduced by the usage monitor below — `install.sh` uses it to
merge Claude Code settings, and `statusline.sh` uses it to parse the status-line JSON.
`install.sh` resolves its own repository path dynamically, including when that path
contains spaces.

## What's New

This version adds a lightweight **Claude Code usage/session monitor** to the existing
status line, without changing the four-grid workflow in any way. It surfaces:

- the active model
- context usage and context window size
- five-hour rate-limit usage
- time remaining until that rate-limit window resets

Everything under "Claude Code Usage Monitor" below is new; everything above it is the
original project.

## The four-grid workflow (unchanged)

Running `t` (or its alias `cwork`) in any project directory opens a fresh tmux session
split into four panes, each running its own Claude Code instance:

| Pane | Effort level |
|---|---|
| Top-left | default |
| Top-right | default |
| Bottom-left | `CLAUDE_CODE_EFFORT_LEVEL=medium` |
| Bottom-right | `CLAUDE_CODE_EFFORT_LEVEL=low` |

`tmux.conf` adds mouse support, drag/double/triple-click-to-copy (via `bin/clip`), and
pane borders showing index + running command. None of this — `tmux.conf`, `shell.zsh`,
pane layout, keybindings — changed in this version.

## Claude Code Usage Monitor

The status line (`statusline.sh`) additionally shows Claude Code's own session/rate-limit
data, on top of the existing model + git + context segments.

Example output (illustrative — not real account data):

```text
Sonnet 4.5  │  main  │  [████░░░░░░░░░░░░░░░░] 21% (42k/200k)  │  5h 45%  │  reset 2h 42m
```

| Indicator | Meaning | Source |
|---|---|---|
| `Sonnet 4.5` | Active Claude model | `model.display_name` |
| `main` | Current git branch (pre-existing, unchanged) | local git |
| `42k/200k` | Current context usage / maximum context window | `context_window.total_input_tokens` + `total_output_tokens`, `context_window.context_window_size` |
| `21%` | Percentage of context consumed | `context_window.used_percentage` |
| `5h` | The current five-hour rate-limit window | `rate_limits.five_hour` |
| `45%` | Percentage used within that window | `rate_limits.five_hour.used_percentage` |
| `reset 2h 42m` | Time remaining until that window resets | `rate_limits.five_hour.resets_at` |

### What "5h" actually means

Claude Code's statusLine JSON does **not** expose your subscription's message/token quota.
It exposes usage against a rolling **five-hour rate-limit window** (`rate_limits.five_hour`)
and a **seven-day window** (`rate_limits.seven_day`, not shown here). `5h` names that
window — it is not a literal message count, and it is not your subscription quota. The
reset countdown comes from `rate_limits.five_hour.resets_at`, an authoritative Unix
timestamp from Claude Code — never from how long the local process has been running.

### Limitations / fallback behavior

- `rate_limits` is only populated for Claude.ai Pro/Max subscribers, and only after the
  first API response of the session. It's absent for API-key/console-billed usage and for
  older Claude Code versions — when absent, the status line shows `5h N/A` rather than a
  fabricated number.
- If usage is known but the reset timestamp isn't, it shows `5h 45%  │  reset N/A` rather
  than guessing a countdown.
- If `context_window` itself is missing (older Claude Code versions), the status line
  shows `ctx N/A` instead of a misleading `0/200k`.
- The reset countdown can't go negative — it clamps to `0`/`<1m` once the window has
  already elapsed by render time.

### Refresh behavior

No new daemon or polling loop was added. The existing `statusline-daemon.sh` already
recomputes the status line from the last-seen input every ~2 seconds; the reset countdown
is computed from `resets_at` at render time, so it ticks down live using that existing
2-second cadence with no extra processes or network calls.

### Architecture

```
Original:                            Enhanced (this version):

Four-grid tmux workflow              Four-grid tmux workflow    (unchanged)
        +                                     +
Claude Code status line              Claude Code status line
(model / git / context)              (model / git / context / 5h usage / reset)
```

```
Claude Code
   │ statusLine JSON (stdin)
   ▼
statusline.sh (unchanged: model / git / context logic)
   │
   └── + rate_limits.five_hour → "5h <used%>  │  reset <time to resets_at>"
   ▼
existing status line (bottom of Claude Code)
```

The usage monitor does not add another tmux pane and does not modify `tmux.conf`,
`shell.zsh`, or the four-grid layout in any way.
