---
name: duo-plan
description: Agent-duo plan phase - write a concise implementation plan before coding
metadata:
  short-description: Write implementation plan in duo collaboration
---

# Agent Duo - Plan Phase

**PHASE: PLAN**

## Purpose

Produce a concrete plan file another engineer could execute.

## Output

Write: `$PEER_SYNC/plan-${MY_NAME}.md`

Minimum sections:
- Goal
- Approach
- Planned file changes
- Step sequence
- Risks and tests

## Steps

1. Read the task:

```bash
cat "$FEATURE.md"
```

2. Inspect relevant code quickly:

```bash
rg -n -- "pattern|keyword|module"
```

3. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Read `$FEATURE.md`
- Identify impacted files/modules
- Draft a concise implementation plan with risks and tests
- Return only actionable steps (no filler)

4. Write and finalize your plan file.

5. Signal completion:

```bash
agent-duo signal "$MY_NAME" plan-done "implementation plan submitted"
```

Then stop and wait.

## Clarification Path

If blocked by ambiguity:

```bash
agent-duo signal "$MY_NAME" needs-clarify "question: what should happen when X?"
```
