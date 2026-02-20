---
name: pair-coder-clarify
description: Pair mode coder clarify phase for approach sketch and key questions
metadata:
  short-description: Propose approach before starting work
---

# Agent Pair - Coder Clarify Phase

**PHASE: CLARIFY**

## Purpose

Give a short approach sketch and only high-impact questions.

## Output

Write: `$PEER_SYNC/clarify-coder.md`

Minimum sections:
- Approach sketch (2-4 sentences)
- Key questions (0-2)

## Steps

1. Read task:

```bash
cat "$FEATURE.md"
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Summarize task intent and constraints
- Propose one implementation direction
- Identify top unanswered questions

3. Write clarify file and signal completion:

```bash
agent-pair signal coder clarify-done "approach and questions submitted"
```

Then stop and wait.
