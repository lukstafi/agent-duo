---
name: duo-final-merge
description: Agent-duo final merge phase - rebase and merge the PR
metadata:
  short-description: Perform final rebase and merge of your PR
---

# Agent Duo - Final Merge Phase

**AUTO-FINISH MODE**: The session is completing automatically. Your PR is the only remaining PR (or has won the merge vote) and needs to be merged.

## Your Environment

- **Working directory**: Your worktree
- **Your branch**: `$FEATURE-$MY_NAME`
- **Sync directory**: `$PEER_SYNC`
- **Your PR**: Read from `$PEER_SYNC/$MY_NAME.pr`

## Your Task

### 1. Get Your PR URL

```bash
PR_URL=$(cat "$PEER_SYNC/$MY_NAME.pr")
echo "PR to merge: $PR_URL"
```

### 2. Ensure Branch is Up-to-Date with Main

```bash
git fetch origin main
git rebase origin/main
```

If conflicts occur, resolve them carefully:

```bash
# Edit conflicting files to resolve
git add <resolved-files>
git rebase --continue
```

### 3. Run Tests to Verify

```bash
# Run project-specific test command if available
# e.g., npm test, pytest, cargo test, make test, etc.
```

### 4. Force Push the Rebased Branch

```bash
git push --force-with-lease
```

### 5. Wait for CI Checks to Pass

Check the PR status and wait for CI to complete:

```bash
# Check PR status
gh pr view "$PR_URL" --json state,mergeable,mergeStateStatus

# Wait for checks to complete (poll every 30 seconds, up to 10 minutes)
for i in {1..20}; do
    CHECKS=$(gh pr checks "$PR_URL" 2>&1)
    if echo "$CHECKS" | grep -q "All checks were successful"; then
        echo "CI checks passed!"
        break
    elif echo "$CHECKS" | grep -q "fail\|error"; then
        echo "CI checks failed:"
        echo "$CHECKS"
        break
    fi
    echo "Waiting for CI checks... (attempt $i/20)"
    sleep 30
done
```

### 6. Merge the PR

Attempt to merge using squash (preferred) or regular merge:

```bash
gh pr merge "$PR_URL" --squash --delete-branch
```

If squash merge is not allowed by the repository settings:

```bash
gh pr merge "$PR_URL" --merge --delete-branch
```

### 7. Signal Completion

```bash
agent-duo signal "$MY_NAME" final-merge-done "PR merged to main"
```

## If CI Checks Fail

If CI checks are failing and cannot be fixed quickly:

1. Post a comment explaining the issue:
   ```bash
   gh pr comment "$PR_URL" --body "Auto-merge attempted but CI checks are failing. Manual intervention needed."
   ```

2. Signal completion with the issue noted:
   ```bash
   agent-duo signal "$MY_NAME" final-merge-done "merge blocked by failing CI"
   ```

## If Merge is Blocked

If the merge is blocked (e.g., requires review approval, branch protection):

```bash
gh pr comment "$PR_URL" --body "Auto-merge attempted but blocked by repository settings. Manual merge required."
agent-duo signal "$MY_NAME" final-merge-done "merge blocked, needs manual intervention"
```

## Important Guidelines

- **Always rebase before merging** — Ensures clean history and no conflicts
- **Use `--force-with-lease`** — Safer than `--force`, fails if remote changed unexpectedly
- **Wait for CI** — Don't merge if checks are still running
- **Prefer squash merge** — Cleaner history for feature branches
- **Delete branch after merge** — Keeps repository clean
