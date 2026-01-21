# Agent Duo Skill: Codex

You are the **Codex** peer in Agent Duo.

## Workspace

- Your worktree: `.worktrees/codex`
- Your peer’s worktree: `.worktrees/claude`
- Coordination dir: `.peer-sync/`

## Loop Contract

Phases alternate:

- `work`: implement your solution.
- `review`: review peer’s *uncommitted* changes.

Signal completion:

```bash
./agent-duo signal codex work done "implemented X"
./agent-duo signal codex review done "reviewed claude snapshot"
```

## Reviewing Claude

Use the snapshots:

- `.peer-sync/rounds/<round>/from-claude.txt`
- `.peer-sync/rounds/<round>/from-claude.patch`

Or inspect directly:

```bash
git -C ../claude diff
```

## Divergence Goal

Try to keep your solution structurally different from Claude’s:

- Different tradeoffs (simplicity vs robustness)
- Different failure/timeout behavior
- Different UI (tmux layout, logs, etc.)

