---
name: duo-plan-review
description: Agent-duo plan-review phase - review peer's implementation plan
metadata:
  short-description: Review peer's implementation plan in duo collaboration
---

# Agent Duo - Plan Review Phase

**PHASE: PLAN-REVIEW** - Review your peer's implementation plan before starting work.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read-only)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Your Task

Review your peer's implementation plan and provide constructive feedback. Your goal is to help them produce a better solution, not to criticize.

## Steps

### 1. Read the Task

Refresh your understanding of the requirements:

```bash
cat "$FEATURE.md"
```

### 2. Read Your Peer's Plan

```bash
cat "$PEER_SYNC/plan-${PEER_NAME}.md"
```

### 3. Write Your Review

Create your review file:

```bash
cat > "$PEER_SYNC/plan-review-${MY_NAME}.md" << 'EOF'
# Plan Review from [MY_NAME]

Reviewing: [PEER_NAME]'s implementation plan

## Completeness

[Does the plan cover all requirements from the task?]

- [ ] Requirement 1: Covered / Missing
- [ ] Requirement 2: Covered / Missing

## Simplicity

[Is there a simpler approach? Is the plan over-engineered?]

[Your analysis]

## Risks and Gaps

[What edge cases or failure modes are missing?]

- **Gap 1**: [Description]
- **Gap 2**: [Description]

## Feasibility

[Will this approach actually work? Are there technical blockers?]

[Your assessment]

## Suggestions

[Constructive suggestions for improvement]

1. [Suggestion 1]
2. [Suggestion 2]

## Overall Assessment

[Brief summary: What's good about the plan? What needs attention?]

EOF
```

Edit the file to fill in actual observations (don't leave placeholders).

### 4. Read Peer's Review of Your Plan

If available, check what your peer thought of your plan:

```bash
[ -f "$PEER_SYNC/plan-review-${PEER_NAME}.md" ] && cat "$PEER_SYNC/plan-review-${PEER_NAME}.md"
```

Consider this feedback when you start implementing.

### 5. Signal Completion

```bash
agent-duo signal "$MY_NAME" plan-review-done "plan review submitted"
```

Then **STOP and wait**. The orchestrator will proceed to the work phase.

## If You Need Clarification

If you discover ambiguity or need user input while reviewing:

```bash
agent-duo signal "$MY_NAME" needs-clarify "question: what should happen when X?"
```

The orchestrator will pause and notify the user. After they respond, continue reviewing and signal `plan-review-done` when ready.

## Guidelines

- **Be constructive**: Help your peer succeed, don't just criticize
- **Be specific**: Point to concrete issues, not vague concerns
- **Stay objective**: Focus on the plan's merits, not whose plan it is
- **Consider trade-offs**: Different approaches have different strengths
- **Keep divergence in mind**: Your plans should remain distinct
