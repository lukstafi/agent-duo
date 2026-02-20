---
name: duo-work
description: Agent-duo work phase instructions for continuing implementation
metadata:
  short-description: Continue work in duo collaboration
---

# Agent Duo - Work Phase (Round 2+)

**PHASE: WORK**

## Purpose

Continue implementing your solution while incorporating valid peer feedback.

## Preflight

Run the shared preflight helper:

```bash
"$HOME/.local/share/agent-duo/phase-preflight.sh" duo-work
```

If unavailable, manually read the previous round review and peer status.

## Steps

1. Implement the next highest-impact change.
2. Keep your approach distinct unless feedback reveals a clear defect.
3. Record key decisions in `$FEATURE.md` to aid recovery after compaction.
4. Check peer progress when useful:

```bash
git -C "$PEER_WORKTREE" diff
```

## Optional Delegation

If your agent supports sub-agents, delegate preflight/context gathering with this activity brief:

- Collect previous review feedback addressed to me
- Summarize peer status and recent peer diff
- Return top 3 priorities for this round

## Escalation

If blocked by ambiguity/inconsistency/misguided task framing:

```bash
agent-duo escalate ambiguity "requirements unclear: what should happen when X?"
agent-duo escalate inconsistency "docs say X but code does Y"
agent-duo escalate misguided "this feature already exists in module Z"
```

## Signal

```bash
agent-duo signal "$MY_NAME" done "brief summary of what you did"
```

Then stop.
