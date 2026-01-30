---
name: duo-merge-execute
description: Agent-duo merge phase - execute merge and cherry-pick
metadata:
  short-description: Merge winning PR and cherry-pick from losing PR
---

# Agent Duo - Merge Execute Phase

**PHASE: MERGE EXECUTE** - A decision has been made. Your ancestor's PR was not chosen, so you will merge the winning PR and cherry-pick valuable features from your ancestor's PR.

## Your Environment

- **Working directory**: Main branch
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Context

The merge decision is in `$PEER_SYNC/merge-decision`. Since your "ancestor" (the agent whose name matches yours from the original duo session) had the losing PR, you are responsible for:

1. Merging the winning PR into main
2. Cherry-picking valuable features from the losing PR
3. Resolving any conflicts
4. Creating a clean final state

Your peer (who has the winning PR's perspective) will review your work.

## Your Task

### 1. Understand the Decision

```bash
DECISION="$(cat "$PEER_SYNC/merge-decision")"
echo "Winning PR: $DECISION"

WINNING_PR="$(cat "$PEER_SYNC/${DECISION}.pr")"
LOSING_AGENT=$([[ "$DECISION" == "claude" ]] && echo "codex" || echo "claude")
LOSING_PR="$(cat "$PEER_SYNC/${LOSING_AGENT}.pr")"

echo "Merging: $WINNING_PR"
echo "Cherry-picking from: $LOSING_PR"
```

### 2. Review Cherry-Pick Recommendations

Read both agents' analyses to understand what to cherry-pick:

```bash
cat "$PEER_SYNC/merge-vote-claude.md"
cat "$PEER_SYNC/merge-vote-codex.md"
```

### 3. Merge the Winning PR

```bash
# Ensure we're on main and up-to-date
git checkout main
git pull origin main

# Merge the winning PR (squash to keep history clean)
gh pr merge "$WINNING_PR" --squash --delete-branch
```

### 4. Cherry-Pick from the Losing PR

Identify valuable commits or changes from the losing PR:

```bash
# View the losing PR's commits
gh pr view "$LOSING_PR" --json commits

# View the diff
gh pr diff "$LOSING_PR"
```

For each valuable change, either:
- Cherry-pick entire commits: `git cherry-pick <commit-sha>`
- Manually apply specific changes if commits are too coarse

### 5. Handle Conflicts (if any)

If conflicts occur:
1. Resolve them thoughtfully, preserving the intent of both solutions
2. Ensure tests still pass
3. Document significant conflict resolution decisions

### 6. Verify the Result

```bash
# Run tests to ensure nothing broke
# (use project-specific test command)

# Review the final state
git log --oneline -10
git diff HEAD~1
```

### 7. Commit Cherry-Picked Changes

```bash
git add -A
git commit -m "Cherry-pick features from $LOSING_AGENT's PR

Incorporated:
- [List specific features/changes picked]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 8. Close the Losing PR

```bash
gh pr close "$LOSING_PR" --comment "Superseded by $WINNING_PR. Valuable features have been cherry-picked into main:
- [List what was incorporated]

Thank you for the alternative approach!"
```

### 9. Signal Completion

```bash
agent-duo signal "$MY_NAME" merge-done "merged $DECISION's PR, cherry-picked from $LOSING_AGENT"
```

Then **STOP and wait**. Your peer will review the merge result.

### After Review

Your peer's review will be written to: `$PEER_SYNC/merge-review-${PEER_NAME}.md`

If they request changes, you'll be triggered again with the `duo-merge-amend` skill to address their feedback.

## Guidelines

- **Don't lose valuable work**: The losing PR had merit - extract what's good
- **Keep history clean**: Squash merge + cherry-pick keeps the git log readable
- **Test thoroughly**: The merge must not break anything
- **Document what you picked**: Future maintainers should understand what came from where
