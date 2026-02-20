---
name: duo-merge-execute
description: Agent-duo merge phase - cherry-pick valuable features into winning PR branch
metadata:
  short-description: Cherry-pick from losing PR into winning PR branch
---

# Agent Duo - Merge Execute Phase

**PHASE: MERGE EXECUTE**

## Purpose

Integrate valuable parts of the losing PR into the winning PR branch, then hand off for review.

## Steps

1. Read decision and PR ids:

```bash
DECISION="$(cat "$PEER_SYNC/merge-decision")"
WINNING_PR="$(cat "$PEER_SYNC/${DECISION}.pr")"
LOSING_AGENT=$([[ "$DECISION" == "claude" ]] && echo "codex" || echo "claude")
LOSING_PR="$(cat "$PEER_SYNC/${LOSING_AGENT}.pr")"
```

2. Work in winning worktree:

```bash
cd "$PEER_WORKTREE"
git pull origin
```

3. Review vote recommendations and losing PR diff:

```bash
FINAL_ROUND=$(cat "$PEER_SYNC/merge-round")
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-claude-vote.md"
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-codex-vote.md"
gh pr diff "$LOSING_PR"
```

4. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Identify concrete commit/file-level candidates worth porting
- Provide integration notes and conflict-risk hotspots
- Return prioritized cherry-pick plan

5. Apply selected changes (cherry-pick or manual port), resolve conflicts, run tests.

6. Commit and push winning branch updates.

7. Close losing PR with a short consolidation note:

```bash
gh pr close "$LOSING_PR" --comment "Consolidated into $WINNING_PR; valuable changes were integrated."
```

8. Signal completion:

```bash
agent-duo signal "$MY_NAME" merge-done "cherry-picks integrated into $DECISION PR"
```

Then stop and wait for merge review.
