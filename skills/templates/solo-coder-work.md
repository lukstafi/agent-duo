---
name: solo-coder-work
description: Solo mode - coder work phase instructions for implementing the solution
metadata:
  short-description: Continue coding work in solo collaboration
---

# Agent Solo - Coder Work Phase (Round 2+)

**PHASE CHANGE: You are now in the WORK phase.**

You are the **CODER** in a solo workflow. A reviewer will examine your work.

## First Things First

1. Check reviewer feedback from the previous round:
   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-review.md"
   [ -f "$REVIEW" ] && cat "$REVIEW"
   ```

2. Check current phase:
   ```bash
   agent-solo phase
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
agent-solo escalate ambiguity "requirements unclear: what should happen when X?"
agent-solo escalate inconsistency "docs say X but code does Y"
agent-solo escalate misguided "this feature already exists in module Z"
```
This notifies the user without interrupting your work. Continue with your best interpretation.

## When Done

Signal completion and **STOP**:
```bash
agent-solo signal coder done "brief summary of what you did"
```

The reviewer will examine your work next.
