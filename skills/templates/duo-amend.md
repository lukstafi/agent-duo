---
name: duo-amend
description: Agent-duo amend phase for agents who already have a PR
metadata:
  short-description: Review feedback and amend PR if needed
---

# Agent Duo - Amend Phase

You already have a PR and should stay responsive to peer review while they iterate.

## Preflight

```bash
cat "$PEER_SYNC/${MY_NAME}.pr"
"$HOME/.local/share/agent-duo/phase-preflight.sh" duo-amend
```

## Steps

1. Decide whether feedback requires changes.
2. If yes, implement, commit, and push.
3. If no, note that in your signal message.

## Signal

```bash
agent-duo signal "$MY_NAME" done "reviewed feedback, amended PR or no changes needed"
```
