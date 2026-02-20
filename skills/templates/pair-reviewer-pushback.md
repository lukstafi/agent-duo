---
name: pair-reviewer-pushback
description: Pair mode reviewer pushback stage for improving task framing before coding
metadata:
  short-description: Propose task improvements before coder starts work
---

# Agent Pair - Reviewer Pushback Stage

**STAGE: PUSHBACK**

## Purpose

Improve task framing before coding starts.

## Output

Write: `$PEER_SYNC/pushback-reviewer.md`

Minimum sections:
- Proposed changes (or "No changes")
- Rationale

## Steps

1. Read task and coder clarify file (if present):

```bash
cat "$FEATURE.md"
cat "$PEER_SYNC/clarify-coder.md" 2>/dev/null || true
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Critique task for ambiguity, missing edge cases, and unnecessary constraints
- Propose minimal edits with highest impact

3. If needed, edit `$FEATURE.md` directly.

4. Write pushback rationale and signal completion:

```bash
agent-pair signal reviewer pushback-done "proposed task modifications submitted"
```

Then stop and wait for user decision.
