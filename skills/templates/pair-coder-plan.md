---
name: pair-coder-plan
description: Pair mode coder plan phase - write concise implementation plan before coding
metadata:
  short-description: Write implementation plan (pair coder)
---

# Agent Pair - Plan Phase (Coder)

**PHASE: PLAN**

## Purpose

Produce a clear plan for reviewer approval before implementation.

## Output

Write: `$PEER_SYNC/plan-coder.md`

Minimum sections:
- Goal
- Approach
- Planned file changes
- Steps
- Risks and tests

## Steps

1. Read task and prior plan feedback (if any):

```bash
cat "$FEATURE.md"
PLAN_ROUND=$(cat "$PEER_SYNC/plan-round" 2>/dev/null || echo "1")
[ "$PLAN_ROUND" -gt 1 ] && cat "$PEER_SYNC/plan-review.md"
```

2. Inspect code:

```bash
rg -n -- "pattern|keyword|module"
```

3. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Read task and prior plan-review feedback
- Draft a concise, executable implementation plan
- Explicitly cover risks/tests tied to requirements

4. Write `plan-coder.md`.

5. Signal completion:

```bash
agent-pair signal coder plan-done "implementation plan submitted"
```

Then stop and wait.

## Clarification Path

If blocked by ambiguity:

```bash
agent-pair signal coder needs-clarify "question: what should happen when X?"
```
