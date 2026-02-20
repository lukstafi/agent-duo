---
name: pair-reviewer-clarify
description: Pair mode reviewer clarify phase for commenting on coder approach
metadata:
  short-description: Review coder's approach and add comments
---

# Agent Pair - Reviewer Clarify Phase

**PHASE: CLARIFY**

## Purpose

Stress-test the coder's initial direction before implementation.

## Output

Write: `$PEER_SYNC/clarify-reviewer.md`

Minimum sections:
- Risks or concerns
- Additional questions (if any)

## Steps

1. Read task and coder clarify note:

```bash
cat "$FEATURE.md"
cat "$PEER_SYNC/clarify-coder.md"
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Critique coder approach for feasibility and risk
- Suggest the most important clarifications to request

3. Write reviewer clarify file and signal completion:

```bash
agent-pair signal reviewer clarify-done "comments submitted"
```

Then stop and wait.
