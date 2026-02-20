---
name: duo-merge-review
description: Agent-duo merge phase - review cherry-pick integration on winning branch
metadata:
  short-description: Review peer's cherry-pick work on winning PR
---

# Agent Duo - Merge Review Phase

**PHASE: MERGE REVIEW**

## Purpose

Verify cherry-picked work is correct, complete, and safe to merge.

## Output

Write: `$PEER_SYNC/merge-review-${MY_NAME}.md`

Required marker:
- Include `APPROVED` to pass
- Include `CHANGES REQUESTED` to request another amend round

## Steps

1. Move to winning worktree and update:

```bash
cd "$MY_WORKTREE"
git pull origin
```

2. Review recent integration changes:

```bash
git log --oneline -10
git show HEAD
```

3. Check against recommendations:

```bash
FINAL_ROUND=$(cat "$PEER_SYNC/merge-round")
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-claude-vote.md"
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-codex-vote.md"
```

4. Run relevant tests/lint for this repo.

5. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Compare integrated branch vs losing-worktree intent
- Confirm cherry-pick completeness and highlight regressions
- Draft concise approval/change-request review

6. Write review file with explicit outcome:

```bash
cat > "$PEER_SYNC/merge-review-${MY_NAME}.md" << EOF_REVIEW
# Merge Review from ${MY_NAME}

## Cherry-Pick Review: APPROVED

## Findings

## Verification Run

## Follow-ups (if any)
EOF_REVIEW
```

Use `CHANGES REQUESTED` instead of `APPROVED` when needed.

7. Signal completion:

```bash
agent-duo signal "$MY_NAME" merge-review-done "merge review submitted"
```

Then stop and wait.
