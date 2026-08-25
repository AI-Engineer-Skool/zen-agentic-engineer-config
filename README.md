# Zen Agentic Engineer

A lightweight agentic engineering workflow for Claude Code: tmux + zsh helpers + a
Claude Code status line + slash commands.

This repository builds on the original
[**Zen Agentic Engineer**](https://github.com/AI-Engineer-Skool/zen-agentic-engineer-config)
four-grid workflow and adds a **Claude Code usage/session monitor** on top of the
existing status line. The four-grid workflow itself is unchanged — the monitor is this
version's contribution.

Explainer video (original project): https://youtu.be/ElYxdpYi4U0

---

## ✨ What's New

This version adds a lightweight usage monitor to the existing status line. It surfaces:

- the active Claude model
- context-window usage and size
- context percentage consumed
- five-hour rate-limit usage
- time remaining until that window resets

> The original four-grid workflow remains unchanged.

Here's what it looks like (illustrative example, not real account data):

```text
Sonnet 4.5  │  main  │  [████░░░░░░░░░░░░░░░░] 21% (42k/200k)  │  5h 45%  │  reset 2h 42m
```

Reading left to right: active model, current git branch, context usage as a bar/percentage/
token count, and the five-hour rate-limit window's usage and reset countdown.

---

## Original vs. enhanced

```text
Original:                              Enhanced (this version):

Zen Agentic Engineer                   Zen Agentic Engineer
        │                                      │
        └── Four-grid Claude Code workflow     ├── Four-grid Claude Code workflow
                                                │       └── unchanged
                                                │
                                                └── Claude Code usage monitor
                                                        ├── Model
                                                        ├── Context
                                                        ├── Five-hour usage
                                                        └── Reset countdown
```

The enhancement lives entirely in the status line — it does not add, remove, or resize
any tmux pane.

---

## 🧠 Why this exists

Long agentic coding sessions can consume a meaningful chunk of context and rate-limit
capacity, but there's often no obvious way to see that while you're working. This adds
that visibility by surfacing Claude Code's own session/context metadata directly in the
terminal status line you're already looking at — nothing new to open or check.

---

## 📊 What it shows

| Indicator | What it means |
|---|---|
| Model | Active Claude model |
| Context | Tokens used / maximum context window |
| Context % | Percentage of context currently consumed |
| 5h | Current five-hour rate-limit window |
| Usage % | Percentage used in that window |
| Reset | Time remaining until the current window resets |

---

## 🔬 How it works

```text
Claude Code
   │  status-line JSON
   ▼
statusline.sh
   │
   ├── model.display_name
   ├── context_window
   └── rate_limits.five_hour
           ├── used_percentage
           └── resets_at
   │
   ▼
Terminal status line
```

The monitor reads only the JSON that Claude Code already sends to its configured
`statusLine` command on every update. There's no separate API call, no scraping, and no
new data source involved.

---

## ⚠️ What "5h" means

> `5h` refers to the five-hour rate-limit window exposed by Claude Code. It is not a
> direct representation of your subscription quota, and not a guaranteed count of
> messages remaining.

This field is only populated for Claude.ai Pro/Max subscribers, and only after the first
API response of a session — it's absent for API-key/console-billed usage and for older
Claude Code versions. When it's unavailable, the status line gracefully shows:

```text
5h N/A
```

rather than guessing a number. The same applies to the reset countdown: if usage is known
but the reset timestamp isn't, it shows `reset N/A` instead of fabricating a duration.

---

## 🖥️ Four-grid workflow (unchanged)

Running `t` (or its alias `cwork`) in a project directory opens a fresh tmux session
split into four panes, each running its own Claude Code instance:

| Pane | Effort level |
|---|---|
| Top-left | default |
| Top-right | default |
| Bottom-left | `CLAUDE_CODE_EFFORT_LEVEL=medium` |
| Bottom-right | `CLAUDE_CODE_EFFORT_LEVEL=low` |

`tmux.conf` adds mouse support, drag/double/triple-click-to-copy (via `bin/clip`), and
pane borders showing index + running command.

This version does not touch any of it: no pane added, no pane removed, tmux configuration
untouched, existing keybindings unchanged, existing Claude Code launch behavior intact.

---

## 🚀 Installation

**Prerequisite:** [`jq`](https://jqlang.org/) — required by `install.sh` (to merge Claude
Code settings) and by `statusline.sh` (to parse the status-line JSON). This is a
pre-existing requirement of the project, not something the usage monitor introduced.

```sh
./install.sh && exec zsh
```

`install.sh` is idempotent and configures Claude Code's `statusLine` (plus the
`SessionStart`/`Stop` hooks that keep it refreshed) to point at this repository's
scripts, symlinks the tmux config and slash commands, and resolves its own path
dynamically — including when that path contains spaces.

Tested on Mac and Claude Code.

---

## 🧪 Testing

The usage monitor was tested against:

- complete status-line data
- missing `rate_limits`
- missing `context_window`
- missing `resets_at`
- an already-expired reset timestamp
- dynamic model-name formatting across different models
- real `jq` parsing (not just mocked input)
- a real interactive Claude Code session, where the live status line was observed
  rendering actual model, context, and rate-limit data

The four-grid tmux workflow was not modified by this change and was not re-tested as
part of it.

---

## 🛡️ Safety / privacy

- No Claude API credentials are required.
- No browser cookies or session data are read.
- No authentication tokens are scraped.
- No external usage API is called.
- The monitor only reads metadata Claude Code already provides to its own `statusLine`
  mechanism.

---

## 📁 Project structure

```text
.
├── .claude/
│   └── commands/
│       └── smell.md
├── bin/
│   └── clip
├── install.sh
├── shell.zsh
├── statusline.sh
├── statusline-daemon.sh
├── tmux.conf
└── README.md
```

---

## 🤝 Original project / attribution

This repository builds on
[**AI-Engineer-Skool/zen-agentic-engineer-config**](https://github.com/AI-Engineer-Skool/zen-agentic-engineer-config).
The four-grid tmux workflow, shell helpers, and slash commands are that project's work.

## 💡 This version's contribution

> A lightweight Claude Code usage/session monitor integrated into the existing status
> line, without modifying the original four-grid workflow.

---

## 🗺️ Roadmap

Possible future directions (not committed, not scheduled):

- configurable status-line display
- additional Claude Code metrics as they're officially exposed
- improved visual indicators
- broader platform testing
