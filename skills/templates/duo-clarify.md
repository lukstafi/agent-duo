---
name: duo-clarify
description: Agent-duo clarify phase - propose an approach sketch and key questions
metadata:
  short-description: Clarify approach and ask questions before starting
---

# Agent Duo - Clarify Phase

**PHASE: CLARIFY**

## Purpose

Produce a short approach sketch and only the questions that materially affect implementation.

## Output

Write: `$PEER_SYNC/clarify-${MY_NAME}.md`

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

- Summarize task intent and likely constraints
- Propose one viable implementation direction
- Identify the top unanswered questions

3. Write the clarify file and signal completion:

```bash
agent-duo signal "$MY_NAME" clarify-done "approach and questions submitted"
```

Then stop and wait.
