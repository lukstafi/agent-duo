---
name: pair-coder-work
description: Pair mode - coder work phase instructions for implementing the solution
metadata:
  short-description: Continue coding work in pair collaboration
---

# Agent Pair - Coder Work Phase (Round 2+)

**PHASE CHANGE: You are now in the WORK phase.**

You are the **CODER** in a pair workflow. A reviewer will examine your work.

## First Things First

1. Check reviewer feedback from the previous round (if any):
   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   if [ "$ROUND" -gt 1 ]; then
       PREV_ROUND=$((ROUND - 1))
       REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-review.md"
       [ -f "$REVIEW" ] && cat "$REVIEW"
   else
       echo "Round 1 — no previous review to read."
   fi
   ```

2. Check current phase:
   ```bash
   agent-pair phase
   ```

## Your Task

Implement the solution, addressing any feedback from the reviewer.

## Guidelines

- **Address reviewer feedback**: Fix issues mentioned in the review
- **Follow best practices**: Write clean, tested code
- **Stay focused**: Implement the requested feature
- **Annotate the task spec**: Record design decisions and rationale directly in `$FEATURE.md` as you work — this serves as a living design doc and helps you recover after context compaction

## If Your Context Was Compacted

If you notice your context was compacted mid-work, re-orient using commit history:

```bash
git log --oneline main..HEAD   # Round-by-round progression and decisions
git diff --stat                # Files modified (uncommitted changes)
git diff main..HEAD --stat     # All files changed across rounds
```

## If You Discover a Blocking Issue

If you find ambiguity, inconsistency, or evidence the task is misguided — escalate:
```bash
agent-pair escalate ambiguity "requirements unclear: what should happen when X?"
agent-pair escalate inconsistency "docs say X but code does Y"
agent-pair escalate misguided "this feature already exists in module Z"
```
This notifies the user without interrupting your work. Continue with your best interpretation.

## When Done

Signal completion and **STOP**:
```bash
agent-pair signal coder done "brief summary of what you did"
```

The reviewer will examine your work next.
