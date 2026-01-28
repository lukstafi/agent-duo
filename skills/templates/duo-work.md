---
name: duo-work
description: Agent-duo work phase instructions for continuing development in round 2+
metadata:
  short-description: Continue work in duo collaboration
---

# Agent Duo - Work Phase (Round 2+)

**PHASE CHANGE: You are now in the WORK phase, not review.**

Stop any review activity. Your task is to continue developing your implementation.

## First Things First

1. Check peer feedback from the previous round:
   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${PEER_NAME}-reviews-${MY_NAME}.md"
   [ -f "$REVIEW" ] && cat "$REVIEW"
   ```

2. Check peer's current status:
   ```bash
   agent-duo peer-status
   ```

## Guidelines

- **Diverge to explore the search space**: Maintain your *alternative* approach
- **Consider peer feedback**: Address valid concerns while keeping your distinct solution
- **Stay goal focused**: Convergence is fine if it arises organically from a confident consensus

## Checking Peer's Progress

```bash
git -C "$PEER_WORKTREE" diff
```

## If You Discover a Blocking Issue

If you find ambiguity, inconsistency, or evidence the task is misguided — escalate:
```bash
agent-duo escalate ambiguity "requirements unclear: what should happen when X?"
agent-duo escalate inconsistency "docs say X but code does Y"
agent-duo escalate misguided "this feature already exists in module Z"
```
This notifies the user without interrupting your work. Continue with your best interpretation.

## Before You Stop

Do one of the following:

**If more iteration needed** (incomplete, untested, or want to address peer feedback):
```bash
agent-duo signal "$MY_NAME" done "brief summary"
```

**If your solution is complete** — create the PR now:
```bash
agent-duo pr "$MY_NAME"
```

The orchestrator waits for your signal or PR before proceeding.
