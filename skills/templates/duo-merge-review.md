---
name: duo-merge-review
description: Agent-duo merge phase - review merge execution
metadata:
  short-description: Review peer's merge and cherry-pick work
---

# Agent Duo - Merge Review Phase

**PHASE: MERGE REVIEW** - Your ancestor's PR won. Your peer has merged it and cherry-picked from the losing PR. Review their work.

## Your Environment

- **Working directory**: Main branch
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Context

Since your "ancestor" (the agent whose name matches yours from the original duo session) had the winning PR, you are the reviewer for this merge phase. Your peer merged the winning PR and cherry-picked features from the losing PR.

Your job is to verify the merge was done correctly and the cherry-picked features are properly integrated.

## Your Task

### 1. Pull Latest Changes

```bash
git checkout main
git pull origin main
```

### 2. Review What Was Merged

```bash
# See recent commits
git log --oneline -10

# See the merge details
git show HEAD

# If cherry-picks were made, review them
git log --oneline main@{1}..HEAD
```

### 3. Verify Integration

```bash
# Check the code compiles/lints
# (use project-specific commands)

# Run tests
# (use project-specific test command)

# Review the final diff against pre-merge state
git diff main@{upstream}..HEAD
```

### 4. Check Cherry-Pick Completeness

Compare against what was recommended:

```bash
# Read the final round of votes to see cherry-pick recommendations
FINAL_ROUND=$(cat "$PEER_SYNC/merge-round")
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-claude-vote.md"
cat "$PEER_SYNC/merge-votes/round-${FINAL_ROUND}-codex-vote.md"
```

Were all recommended features cherry-picked? If not, is the omission justified?

### 5. Write Your Review

```bash
cat > "$PEER_SYNC/merge-review-${MY_NAME}.md" << 'EOF'
# Merge Review from [MY_NAME]

## Merge Execution: APPROVED

(Change to "CHANGES REQUESTED" if issues need fixing)

## Verification Checklist

- [ ] Winning PR was correctly merged
- [ ] Recommended cherry-picks were incorporated
- [ ] Tests pass
- [ ] Code quality is maintained
- [ ] No regressions introduced

## Cherry-Pick Assessment

[Were the right features picked? Anything missing or unnecessary?]

## Issues Found (if any)

[List any problems that need to be addressed]

## Overall Assessment

[1-2 sentences summarizing the merge quality]

EOF
```

Edit the file with actual content.

### 6. Signal Completion

If approved:
```bash
agent-duo signal "$MY_NAME" merge-review-done "merge approved"
```

If changes are needed:
```bash
agent-duo signal "$MY_NAME" merge-review-done "changes requested - see review"
```

Then **STOP and wait**. If changes were requested, your peer will address them and another review cycle may occur.

## Guidelines

- **Verify, don't rubber-stamp**: Actually run tests and review the code
- **Be constructive**: If something's wrong, explain what and how to fix it
- **Acknowledge good work**: If the cherry-picks were well done, say so
- **Focus on correctness**: The goal is a working, clean main branch
