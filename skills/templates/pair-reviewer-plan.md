---
name: pair-reviewer-plan
description: Pair mode reviewer plan-review phase - review coder plan and issue verdict
metadata:
  short-description: Review coder plan with verdict (pair reviewer)
---

# Agent Pair - Plan-Review Phase (Reviewer)

**PHASE: PLAN-REVIEW**

## Purpose

Review the coder plan and return a clear verdict.

## Output

Write: `$PEER_SYNC/plan-review.md`

Required marker:
- Include `APPROVE` or `REQUEST_CHANGES`

## Steps

1. Read coder plan:

```bash
cat "$PEER_SYNC/plan-coder.md"
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Evaluate plan completeness and feasibility
- Flag risks/gaps and concrete improvements
- Recommend APPROVE or REQUEST_CHANGES

3. Write review with sections:
- What works
- Risks or gaps
- Required changes (if any)
- Verdict (`APPROVE` or `REQUEST_CHANGES`)

4. Signal completion (include verdict):

```bash
agent-pair signal reviewer plan-review-done "verdict: APPROVE"
# or
agent-pair signal reviewer plan-review-done "verdict: REQUEST_CHANGES"
```

Then stop and wait.

## Clarification Path

If blocked by ambiguity:

```bash
agent-pair signal reviewer needs-clarify "question: what should happen when X?"
```
