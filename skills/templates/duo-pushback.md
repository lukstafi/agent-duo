---
name: duo-pushback
description: Agent-duo pushback stage - propose improvements to task framing before coding
metadata:
  short-description: Propose task improvements before starting work
---

# Agent Duo - Pushback Stage

**STAGE: PUSHBACK**

## Purpose

Improve the task spec when it is ambiguous, over-constrained, or missing critical requirements.

## Output

Write: `$PEER_SYNC/pushback-${MY_NAME}.md`

Minimum sections:
- Proposed changes (or "No changes")
- Rationale

## Steps

1. Read task:

```bash
cat "$FEATURE.md"
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Critique task framing for ambiguity, missing edge cases, and unnecessary constraints
- Suggest minimal edits that improve implementation quality

3. If needed, edit `$FEATURE.md` directly.

4. Write pushback rationale and signal completion:

```bash
agent-duo signal "$MY_NAME" pushback-done "proposed task modifications submitted"
```

Then stop and wait for user decision.
