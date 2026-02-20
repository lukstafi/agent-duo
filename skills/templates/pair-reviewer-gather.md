---
name: pair-reviewer-gather
description: Pair mode reviewer gather phase for collecting implementation context
metadata:
  short-description: Gather codebase context for the coder
---

# Agent Pair - Reviewer Gather Phase

**PHASE: GATHER**

## Purpose

Provide the coder with high-signal context before implementation starts.

## Output

Write: `$PEER_SYNC/task-context.md`

Minimum sections:
- Relevant files (with line references when useful)
- Related tests/docs
- Gotchas/dependencies

## Steps

1. Read task:

```bash
cat "$FEATURE.md"
```

2. Explore codebase for likely touchpoints.

3. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Find candidate source files, tests, docs, and integration points
- Provide short relevance notes for each
- Highlight risky areas and dependency constraints

4. Write `task-context.md` and signal completion:

```bash
agent-pair signal reviewer gather-done "task context collected"
```

Then stop and wait.
