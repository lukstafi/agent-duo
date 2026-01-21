# agent-duo

Shell scripts and skill prompts to coordinate two AI coding agents (e.g. Claude Code + Codex CLI) to produce **two alternative solutions** in parallel.

The system uses:

- **git worktrees** for isolation (`.worktrees/claude`, `.worktrees/codex`)
- A simple **file-based protocol** for coordination (`.peer-sync/`)
- An **orchestrator loop** (`./orchestrate.sh`) that alternates `work` → `review`

## Requirements

- `git`
- Optional: `tmux` (for `./start.sh --tmux`)
- Optional: `gh` (for `./agent-duo pr <agent>`)

## Quick Start

```bash
./start.sh
./orchestrate.sh
```

Sanity-check setup:

```bash
./agent-duo doctor
```

Or with tmux:

```bash
./start.sh --tmux
```

Or with ttyd (web terminals on localhost):

```bash
./start.sh --ttyd
```

## Coordination Protocol

The shared coordination directory is `.peer-sync/` in the **controller repo** (the directory you ran `./start.sh` from).

To make this work across git worktrees, `./agent-duo init` writes the controller path into your git common dir as `agent-duo-home` (e.g. `.git/agent-duo-home`).

For convenience, `./agent-duo init` also symlinks the controller `.peer-sync/` into each worktree as `.peer-sync`.

- `.peer-sync/phase`: `work` or `review`
- `.peer-sync/round`: round number
- `.peer-sync/<agent>.status`: `phase|state|epoch|message`
- `.peer-sync/rounds/<round>/from-<agent>.{txt,patch}`: snapshots for peer review

Agents signal end-of-phase with:

```bash
./agent-duo signal claude work done "implemented feature X"
./agent-duo signal codex review done "reviewed claude snapshot"
```

## Review Flow

During `review`, each agent reviews the other agent’s snapshot files:

- `.peer-sync/rounds/<round>/from-claude.txt`
- `.peer-sync/rounds/<round>/from-codex.txt`

Snapshots include `git status`, `git diff --stat`, and full diffs.

## PR Creation

When ready:

```bash
./agent-duo pr claude
./agent-duo pr codex
```

This pushes each agent’s branch and opens a PR via the GitHub CLI.
