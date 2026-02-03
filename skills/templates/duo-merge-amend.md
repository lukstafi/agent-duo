---
name: duo-merge-amend
description: Agent-duo merge phase - address review feedback on merge
metadata:
  short-description: Address feedback from cherry-pick review
---

# Agent Duo - Merge Amend Phase

**PHASE: MERGE AMEND** - The reviewer has requested changes to your cherry-pick work. Address their feedback.

## Your Environment

- **Your original worktree**: `$MY_WORKTREE` (losing PR's code, for reference)
- **Working directory**: `$PEER_WORKTREE` (winning PR's branch, where you continue working)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

**IMPORTANT**: You continue working in the winning agent's worktree (`$PEER_WORKTREE`), where you did the original cherry-pick work. Your original worktree (`$MY_WORKTREE`) is still available for reference.

## Your Task

### 1. Ensure You're in the Right Directory

```bash
cd "$PEER_WORKTREE"
pwd  # Verify you're in the winning worktree
```

### 2. Read the Review Feedback

```bash
cat "$PEER_SYNC/merge-review-${PEER_NAME}.md"
```

### 3. Understand What's Requested

Look for:
- Missing cherry-picks that should have been included
- Cherry-picks that introduced issues
- Test failures or regressions
- Code quality concerns

### 4. Address the Issues

Make the necessary changes:

```bash
# If you need to cherry-pick additional commits from your original branch
git cherry-pick <commit-sha>

# Or manually copy code from your original worktree
cat "$MY_WORKTREE/src/missing-feature.ts"
# Then edit the local file to incorporate it

# If you need to fix issues in cherry-picked code
# Edit files as needed

# If you need to revert a problematic cherry-pick
git revert <commit-sha>
```

### 5. Verify Your Fixes

```bash
# Run tests
# (use project-specific test command)

# Review your changes
git diff HEAD~1
git log --oneline -5
```

### 6. Commit and Push Your Amendments

```bash
git add -A
git commit -m "Address cherry-pick review feedback

Changes:
- [List what you fixed/added/removed]

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to update the winning PR
git push origin
```

### 7. Signal Completion

```bash
agent-duo signal "$MY_NAME" merge-done "addressed review feedback"
```

Then **STOP and wait**. The reviewer will verify your changes.

## Guidelines

- **Stay in `$PEER_WORKTREE`**: All commits go to the winning branch
- **Reference `$MY_WORKTREE`**: Your original code is available if you need to cherry-pick more
- **Be responsive**: Address all the reviewer's concerns
- **Don't over-correct**: Only make changes that were requested
- **Test thoroughly**: Ensure your fixes don't introduce new issues
- **Communicate**: If you disagree with a suggestion, explain why in your commit message
