---
name: duo-amend
description: Agent-duo amend phase for agents who already have a PR
metadata:
  short-description: Review feedback and amend PR if needed
---

# Agent Duo - Amend Phase

**You have already created a PR.** Your peer is still iterating.

You continue participating in work/review cycles until your peer also has a PR. This ensures you can respond to their feedback on your solution.

## Your PR

```bash
cat "$PEER_SYNC/${MY_NAME}.pr"
```

## Check Peer Feedback

Read your peer's most recent review of your work:

```bash
ROUND=$(cat "$PEER_SYNC/round")
if [ "$ROUND" -gt 1 ]; then
    PREV_ROUND=$((ROUND - 1))
    REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${PEER_NAME}-reviews-${MY_NAME}.md"
    [ -f "$REVIEW" ] && cat "$REVIEW"
else
    echo "Round 1 — no previous review to read."
fi
```

## Your Task

1. **Consider the feedback**: Does your peer raise valid concerns?
2. **Decide**: Amend your PR or acknowledge the feedback

### If amendments are warranted:

Make changes, then commit and push:

```bash
git add -A
git commit -m "Address review feedback: <brief description>"
git push
```

### If no changes needed:

That's fine — just signal done.

## Before You Stop

Signal completion:

```bash
agent-duo signal "$MY_NAME" done "reviewed feedback, [amended PR / no changes needed]"
```

The orchestrator waits for your signal before proceeding.
