# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is agent-duo

A shell-based system for coordinating two AI coding agents (Claude, Codex, etc.) working in parallel on the same task, producing alternative solutions as separate PRs. See [DESIGN.md](DESIGN.md) for full architecture.

## Key Commands

```bash
agent-duo setup              # Install CLI and skills
agent-duo start <feature>    # Start session (looks for <feature>.md)
agent-duo status             # Show current state
agent-duo pr <agent>         # Create PR for agent
agent-duo cleanup            # Remove worktrees
```

## Development

The main implementation is `agent-duo` (bash script). Key areas:
- CLI commands: `start`, `stop`, `status`, `pr`, `cleanup`, `setup`
- Agent commands: `signal`, `peer-status`, `phase`
- Coordination: `.peer-sync/` state files, mkdir-based locking
- Skills: installed to `~/.claude/commands/` and `~/.codex/skills/`

## Conventions

- Feature-based naming: `<project>-<feature>-<agent>` for worktrees, `<feature>-<agent>` for branches
- Status format: `status|epoch|message` in `.peer-sync/<agent>.status`
- Phases: `work` → `review` → `work` (repeat until PRs created)

## Testing Changes

```bash
# Test in a separate project directory
cd /tmp && mkdir test-project && cd test-project && git init
agent-duo start test-feature
```

## Agent Quirks

- Claude Code: skills in `~/.claude/commands/`, use `--dangerously-skip-permissions`
- Codex: needs `--yolo` for cross-worktree access, skills in `~/.codex/skills/`
- tmux: send text and `C-m` separately (not `"text" Enter`)
- Nudging: send "Continue." not empty Enter
