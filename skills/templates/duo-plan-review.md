---
name: duo-plan-review
description: Agent-duo plan-review phase - review peer's plan before work
metadata:
  short-description: Review peer plan in duo collaboration
---

# Agent Duo - Plan-Review Phase

**PHASE: PLAN-REVIEW** - Review your peer's implementation plan before starting work.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read-only)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Your Task

Review your peer's plan and provide constructive feedback.

## Steps

### 1. Read Your Peer's Plan

```bash
cat "$PEER_SYNC/plan-${PEER_NAME}.md"
```

### 2. Write Your Review

```bash
cat > "$PEER_SYNC/plan-review-${MY_NAME}.md" << 'REVIEW_EOF'
# Plan Review from [MY_NAME]

Reviewing: [PEER_NAME]'s implementation plan

## Completeness

[Does the plan cover all requirements?]

## Simplicity

[Is there a simpler approach?]

## Risks and Gaps

[What edge cases or failure modes are missing?]

## Feasibility

[Will this approach work?]

## Suggestions

1. [Suggestion 1]
2. [Suggestion 2]

## Overall Assessment

[Brief summary]

REVIEW_EOF
```

Edit the file to fill in actual content (don't leave placeholders).

### 3. Signal Completion

```bash
agent-duo signal "$MY_NAME" plan-review-done "plan review submitted"
```

### 4. Read Their Review of Your Plan

```bash
[ -f "$PEER_SYNC/plan-review-${PEER_NAME}.md" ] && cat "$PEER_SYNC/plan-review-${PEER_NAME}.md"
```

Then **STOP and wait**. The orchestrator will proceed to the work phase.

## If You Need Clarification

If you discover ambiguity or need user input while reviewing:

```bash
agent-duo signal "$MY_NAME" needs-clarify "question: what should happen when X?"
```

The orchestrator will pause and notify the user. After they respond, continue reviewing and signal `plan-review-done` when ready.

## Guidelines

- **Analyze, don't prescribe**: Describe their approach objectively
- **Note tradeoffs, not defects**: Different isn't wrong
- **Stay on your path**: Use this to inform your own approach, not adopt wholesale
