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
- **Annotate the task spec**: Record design decisions and rationale directly in `$FEATURE.md` as you work — this serves as a living design doc and helps you recover after context compaction

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

## If Your Context Was Compacted

If you notice your context was compacted mid-work, re-orient using commit history:

```bash
git log --oneline main..HEAD   # Round-by-round progression and decisions
git diff --stat                # Files modified (uncommitted changes)
git diff main..HEAD --stat     # All files changed across rounds
```

## When Done

Signal completion and **STOP**:
```bash
agent-duo signal "$MY_NAME" done "brief summary of what you did"
```

Note: You'll be asked to capture learnings before PR creation.
