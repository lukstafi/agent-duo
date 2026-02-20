---
name: duo-merge-amend
description: Agent-duo merge phase - address requested changes from merge review
metadata:
  short-description: Address feedback from cherry-pick review
---

# Agent Duo - Merge Amend Phase

**PHASE: MERGE AMEND**

## Purpose

Address issues called out in merge review and resubmit for approval.

## Steps

1. Work in winning worktree:

```bash
cd "$PEER_WORKTREE"
```

2. Read reviewer feedback:

```bash
cat "$PEER_SYNC/merge-review-${PEER_NAME}.md"
```

3. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Convert review findings into an ordered fix plan
- Identify minimal edits to satisfy each requested change

4. Implement fixes, run tests, commit, push.

5. Signal completion:

```bash
agent-duo signal "$MY_NAME" merge-done "addressed merge review feedback"
```

Then stop and wait.
