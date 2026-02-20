---
name: pair-coder-work
description: Pair mode coder work phase instructions for implementation
metadata:
  short-description: Continue coding work in pair collaboration
---

# Agent Pair - Coder Work Phase (Round 2+)

**PHASE: WORK**

## Purpose

Implement the feature and address reviewer feedback.

## Preflight

```bash
"$HOME/.local/share/agent-duo/phase-preflight.sh" pair-coder-work
```

If unavailable, manually read `$PEER_SYNC/reviews/round-<prev>-review.md`.

## Steps

1. Implement highest-priority fixes/features.
2. Keep `$FEATURE.md` updated with key decisions.
3. Run relevant tests.

## Optional Delegation

If your agent supports sub-agents, delegate preflight/context gathering with this activity brief:

- Summarize latest reviewer feedback
- Map feedback to likely files/changes
- Return top 3 implementation priorities

## Escalation

If blocked by ambiguity/inconsistency/misguided framing:

```bash
agent-pair escalate ambiguity "requirements unclear: what should happen when X?"
agent-pair escalate inconsistency "docs say X but code does Y"
agent-pair escalate misguided "this feature already exists in module Z"
```

## Signal

```bash
agent-pair signal coder done "brief summary of what you did"
```
