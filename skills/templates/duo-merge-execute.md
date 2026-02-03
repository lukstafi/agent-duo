---
name: duo-merge-execute
description: Agent-duo merge phase - execute merge and cherry-pick
metadata:
  short-description: Cherry-pick from losing PR into winning PR's branch
---

# Agent Duo - Merge Execute Phase

**PHASE: MERGE EXECUTE** - A decision has been made. Your ancestor's PR was not chosen, so you will cherry-pick valuable features from your ancestor's PR into the winning PR's branch.

## Your Environment

- **Your original worktree**: `$MY_WORKTREE` (losing PR's code, for reference)
- **Winning worktree**: `$PEER_WORKTREE` (where you'll do the work)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Context

The merge decision is in `$PEER_SYNC/merge-decision`. Since your "ancestor" (the agent whose name matches yours from the original duo session) had the losing PR, you are responsible for:

1. Cherry-picking valuable features from the losing PR into the winning branch
2. Resolving any conflicts
3. Closing the losing PR
4. Preparing the winning PR for human merge

Your peer (who has the winning PR's perspective) will review your work.

**IMPORTANT**: You will work in the winning agent's worktree (`$PEER_WORKTREE`), not your own. Your original worktree remains available for reference.

## Your Task

### 1. Understand the Decision

```bash
DECISION="$(cat "$PEER_SYNC/merge-decision")"
echo "Winning PR: $DECISION"

WINNING_PR="$(cat "$PEER_SYNC/${DECISION}.pr")"
LOSING_AGENT=$([[ "$DECISION" == "claude" ]] && echo "codex" || echo "claude")
LOSING_PR="$(cat "$PEER_SYNC/${LOSING_AGENT}.pr")"

echo "Winning PR: $WINNING_PR"
echo "Cherry-picking from: $LOSING_PR"
```

### 2. Move to the Winning Worktree

**Change your working directory to the winning agent's worktree:**

```bash
cd "$PEER_WORKTREE"
pwd  # Verify you're in the right place
```

This worktree has the winning PR's branch checked out. All your work happens here.

### 3. Review Cherry-Pick Recommendations

Read both agents' final analyses to understand what to cherry-pick:

```bash
# Read the latest round of votes
FINAL_ROUND=$(cat "$PEER_SYNC/merge-round")
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-claude-vote.md"
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-codex-vote.md"
```

You can also reference your original worktree for context:

```bash
# View your original implementation
ls "$MY_WORKTREE/src/"
cat "$MY_WORKTREE/path/to/relevant/file"
```

### 4. Pull Latest and Identify Cherry-Pick Targets

```bash
# Ensure the winning branch is up-to-date
git pull origin

# View the losing PR's commits
gh pr view "$LOSING_PR" --json commits

# View the losing PR's diff
gh pr diff "$LOSING_PR"
```

### 5. Cherry-Pick Valuable Changes

For each valuable change from the losing PR, either:
- Cherry-pick entire commits: `git cherry-pick <commit-sha>`
- Manually apply specific changes if commits are too coarse (copy from `$MY_WORKTREE`)

```bash
# Example: cherry-pick a specific commit
git cherry-pick <commit-sha>

# Or manually copy and adapt code
cat "$MY_WORKTREE/src/useful-feature.ts"
# Then edit the local file to incorporate the feature
```

### 6. Handle Conflicts (if any)

If conflicts occur:
1. Resolve them thoughtfully, preserving the intent of both solutions
2. You can reference both worktrees:
   - `$PEER_WORKTREE` (current dir) — winning solution
   - `$MY_WORKTREE` — losing solution (your original)
3. Ensure tests still pass
4. Document significant conflict resolution decisions

### 7. Verify the Result

```bash
# Run tests to ensure nothing broke
# (use project-specific test command)

# Review the final state
git log --oneline -10
git diff origin/$(git branch --show-current)
```

### 8. Commit and Push Cherry-Picked Changes

```bash
git add -A
git commit -m "Cherry-pick features from $LOSING_AGENT's PR

Incorporated:
- [List specific features/changes picked]

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push to update the winning PR
git push origin
```

### 9. Close the Losing PR

```bash
gh pr close "$LOSING_PR" --comment "Consolidated into $WINNING_PR. Valuable features have been cherry-picked:
- [List what was incorporated]

Thank you for the alternative approach!"
```

### 10. Signal Completion

```bash
agent-duo signal "$MY_NAME" merge-done "cherry-picked into $DECISION's PR, closed $LOSING_AGENT's PR"
```

Then **STOP and wait**. Your peer will review the cherry-pick work.

### After Review

Your peer's review will be written to: `$PEER_SYNC/merge-review-${PEER_NAME}.md`

If they request changes, you'll be triggered again with the `duo-merge-amend` skill to address their feedback. You'll continue working in `$PEER_WORKTREE`.

## Guidelines

- **Work in `$PEER_WORKTREE`**: All commits go to the winning branch
- **Reference `$MY_WORKTREE`**: Your original code is still there for context
- **Don't lose valuable work**: The losing PR had merit - extract what's good
- **Test thoroughly**: The cherry-picks must not break anything
- **Document what you picked**: The commit message should list incorporated features
- **Don't merge to main**: The user will merge the winning PR when ready
