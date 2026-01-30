---
name: duo-merge-amend
description: Agent-duo merge phase - address review feedback on merge
metadata:
  short-description: Address feedback from merge review
---

# Agent Duo - Merge Amend Phase

**PHASE: MERGE AMEND** - The reviewer has requested changes to your merge/cherry-pick work. Address their feedback.

## Your Environment

- **Working directory**: Main branch
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Your Task

### 1. Read the Review Feedback

```bash
cat "$PEER_SYNC/merge-review-${PEER_NAME}.md"
```

### 2. Understand What's Requested

Look for:
- Missing cherry-picks that should have been included
- Cherry-picks that introduced issues
- Test failures or regressions
- Code quality concerns

### 3. Address the Issues

Make the necessary changes:

```bash
# If you need to cherry-pick additional commits
git cherry-pick <commit-sha>

# If you need to fix issues
# Edit files as needed

# If you need to revert a problematic cherry-pick
git revert <commit-sha>
```

### 4. Verify Your Fixes

```bash
# Run tests
# (use project-specific test command)

# Review your changes
git diff HEAD~1
git log --oneline -5
```

### 5. Commit Your Amendments

```bash
git add -A
git commit -m "Address merge review feedback

Changes:
- [List what you fixed/added/removed]

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to main
git push origin main
```

### 6. Signal Completion

```bash
agent-duo signal "$MY_NAME" merge-done "addressed review feedback"
```

Then **STOP and wait**. The reviewer will verify your changes.

## Guidelines

- **Be responsive**: Address all the reviewer's concerns
- **Don't over-correct**: Only make changes that were requested
- **Test thoroughly**: Ensure your fixes don't introduce new issues
- **Communicate**: If you disagree with a suggestion, explain why in your commit message
