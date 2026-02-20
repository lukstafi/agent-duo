---
name: duo-plan-review
description: Agent-duo plan-review phase - review peer plan before coding
metadata:
  short-description: Review peer plan in duo collaboration
---

# Agent Duo - Plan-Review Phase

**PHASE: PLAN-REVIEW**

## Purpose

Review your peer's plan for feasibility, risk coverage, and clarity.

## Output

Write: `$PEER_SYNC/plan-review-${MY_NAME}.md`

Minimum sections:
- What works
- Risks or gaps
- Suggestions

## Steps

1. Read peer plan:

```bash
cat "$PEER_SYNC/plan-${PEER_NAME}.md"
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Review `$PEER_SYNC/plan-${PEER_NAME}.md`
- Flag missing requirements, risky assumptions, and over-complex steps
- Draft concise feedback prioritized by impact

3. Write your review file.

4. Signal completion:

```bash
agent-duo signal "$MY_NAME" plan-review-done "plan review submitted"
```

5. If present, read peer's review of your plan:

```bash
[ -f "$PEER_SYNC/plan-review-${PEER_NAME}.md" ] && cat "$PEER_SYNC/plan-review-${PEER_NAME}.md"
```

Then stop and wait.

## Clarification Path

If blocked by ambiguity:

```bash
agent-duo signal "$MY_NAME" needs-clarify "question: what should happen when X?"
```
