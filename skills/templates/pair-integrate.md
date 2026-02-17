---
name: pair-integrate
description: Pair mode integrate phase for rebasing onto updated main
metadata:
  short-description: Rebase your branch onto updated main
---

# Agent Pair - Integrate Phase

**The main branch has been updated** (another feature was merged). Your branch needs to be rebased to incorporate those changes.

## Your Environment

- **Working directory**: Your worktree
- **Your branch**: `$FEATURE`
- **Sync directory**: `$PEER_SYNC`

## Your Task

### 1. Fetch the Latest Main

```bash
git fetch origin main
```

### 2. Rebase Your Branch onto Main

```bash
git rebase origin/main
```

### 3. Handle Conflicts (if any)

If conflicts occur during rebase:

1. **Review each conflict carefully** — Understand what changed on main
2. **Preserve your feature's intent** — The other feature is already merged; adapt your code
3. **Resolve conflicts**:
   ```bash
   # Edit conflicting files to resolve
   git add <resolved-files>
   git rebase --continue
   ```
4. **If stuck**, you can abort and try again:
   ```bash
   git rebase --abort
   ```

### 4. Verify Everything Works

Run your tests to ensure the rebase didn't break anything:

```bash
# Run project-specific test command
# e.g., npm test, pytest, cargo test, etc.
```

### 5. Force Push to Update Your PR

```bash
git push --force-with-lease
```

This updates your PR with the rebased commits.

### 6. Signal Completion

```bash
agent-pair signal coder integrate-done "rebased onto main"
```

## Important Guidelines

- **Do NOT modify the merged feature's code** — It's already accepted
- **Keep your feature's changes intact** — Only resolve conflicts, don't refactor
- **Test thoroughly** — Rebasing can introduce subtle bugs
- **Use `--force-with-lease`** — Safer than `--force`, fails if remote has unexpected changes

## If Rebase Fails Badly

If you get into a bad state:

```bash
# Abort the rebase
git rebase --abort

# Reset to your remote branch
git fetch origin
git reset --hard origin/$FEATURE

# Try again or signal for help
agent-pair signal coder integrate-done "rebase failed, needs manual intervention"
```
