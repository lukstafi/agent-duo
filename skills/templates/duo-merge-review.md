---
name: duo-merge-review
description: Agent-duo merge phase - review merge execution
metadata:
  short-description: Review peer's cherry-pick work on winning PR
---

# Agent Duo - Merge Review Phase

**PHASE: MERGE REVIEW** - Your ancestor's PR won. Your peer has cherry-picked features from the losing PR into your branch. Review their work.

## Your Environment

- **Your worktree**: `$MY_WORKTREE` (winning PR's branch, where cherry-picks were made)
- **Peer's worktree**: `$PEER_WORKTREE` (losing PR's code, for reference)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Context

Since your "ancestor" (the agent whose name matches yours from the original duo session) had the winning PR, you are the reviewer for this merge phase. Your peer cherry-picked features from the losing PR into your branch.

Your job is to verify the cherry-picks were done correctly and the features are properly integrated.

**IMPORTANT**: The cherry-pick work was done in your worktree (`$MY_WORKTREE`). You can also reference the losing agent's original worktree (`$PEER_WORKTREE`) to verify correct incorporation.

## Your Task

### 1. Go to Your Worktree and Pull Latest Changes

```bash
cd "$MY_WORKTREE"
git pull origin
```

### 2. Review What Was Cherry-Picked

```bash
# See recent commits (cherry-picks should be visible)
git log --oneline -10

# See the cherry-pick details
git show HEAD

# Review the changes made
git diff HEAD~3..HEAD  # Adjust number based on commits
```

### 3. Compare with Original Implementation

Reference the losing agent's worktree to verify correct incorporation:

```bash
# View the original implementation
ls "$PEER_WORKTREE/src/"
cat "$PEER_WORKTREE/path/to/relevant/file"

# Compare how a feature was adapted
diff "$PEER_WORKTREE/src/feature.ts" "$MY_WORKTREE/src/feature.ts"
```

### 4. Verify Integration

```bash
# Check the code compiles/lints
# (use project-specific commands)

# Run tests
# (use project-specific test command)
```

### 5. Check Cherry-Pick Completeness

Compare against what was recommended:

```bash
# Read the final round of votes to see cherry-pick recommendations
FINAL_ROUND=$(cat "$PEER_SYNC/merge-round")
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-claude-vote.md"
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-codex-vote.md"
```

Were all recommended features cherry-picked? If not, is the omission justified?

### 6. Write Your Review

```bash
cat > "$PEER_SYNC/merge-review-${MY_NAME}.md" << 'EOF'
# Merge Review from [MY_NAME]

## Cherry-Pick Review: APPROVED

(Change to "CHANGES REQUESTED" if issues need fixing)

## Verification Checklist

- [ ] Recommended cherry-picks were incorporated
- [ ] Code integrates cleanly with winning PR
- [ ] Tests pass
- [ ] Code quality is maintained
- [ ] No regressions introduced

## Cherry-Pick Assessment

[Were the right features picked? Anything missing or unnecessary?]

## Issues Found (if any)

[List any problems that need to be addressed]

## Overall Assessment

[1-2 sentences summarizing the cherry-pick quality]

EOF
```

Edit the file with actual content.

### 7. Signal Completion

If approved:
```bash
agent-duo signal "$MY_NAME" merge-review-done "cherry-picks approved"
```

If changes are needed:
```bash
agent-duo signal "$MY_NAME" merge-review-done "changes requested - see review"
```

Then **STOP and wait**. If changes were requested, your peer will address them and another review cycle may occur. Once approved, the orchestrator will notify the user that the winning PR is ready for merge.

## Guidelines

- **Verify, don't rubber-stamp**: Actually run tests and review the code
- **Reference both worktrees**: Your worktree has the merged result, peer's has the original
- **Be constructive**: If something's wrong, explain what and how to fix it
- **Acknowledge good work**: If the cherry-picks were well done, say so
- **Focus on correctness**: The goal is a clean, consolidated PR ready for human merge
