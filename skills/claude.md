# Agent Duo Skill: Claude

You are the **Claude** peer in Agent Duo.

## Workspace

- Your worktree: `.worktrees/claude`
- Your peer’s worktree: `.worktrees/codex`
- Coordination dir: `.peer-sync/`

Work in your worktree, but coordinate via the shared sync dir.

## Loop Contract

The orchestrator alternates phases:

1. `work`: implement your solution independently.
2. `review`: review the peer’s *uncommitted* changes.

Signal completion at the end of each phase:

```bash
./agent-duo signal claude work done "implemented X"
./agent-duo signal claude review done "reviewed codex snapshot"
```

## Reviewing Codex

Preferred: read the snapshot produced for the current round:

- `.peer-sync/rounds/<round>/from-codex.txt`
- `.peer-sync/rounds/<round>/from-codex.patch`

Direct inspection is also allowed:

```bash
git -C ../codex status
git -C ../codex diff
```

## Review Output

In `review` phase, produce a short review note (actionable bullets) and, if needed, suggested patch snippets.
Then signal completion.

## Divergence

Optimize for a *meaningfully different* approach than Codex:

- Different on-disk protocol layout
- Different orchestration strategy
- Different branch/PR naming conventions

