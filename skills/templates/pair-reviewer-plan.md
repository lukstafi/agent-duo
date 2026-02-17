---
name: pair-reviewer-plan
description: Pair mode reviewer plan-review phase - review coder plan
metadata:
  short-description: Review coder plan with verdict (pair reviewer)
---

# Agent Pair - Plan-Review Phase (Reviewer)

**PHASE: PLAN-REVIEW** - Review the coder's plan before implementation begins.

## Your Environment

- **Your worktree**: Current directory
- **Sync directory**: `$PEER_SYNC`
- **Your role**: Reviewer
- **Feature**: `$FEATURE`

## Your Task

Review the coder's plan, provide feedback, and give a verdict: **APPROVE** or **REQUEST_CHANGES**.

## Steps

### 1. Read the Coder's Plan

```bash
cat "$PEER_SYNC/plan-coder.md"
```

### 2. Write Your Review with Verdict

```bash
cat > "$PEER_SYNC/plan-review.md" << 'REVIEW_EOF'
# Plan Review

## Completeness

[Does the plan cover all requirements?]

## Simplicity

[Is there a simpler approach?]

## Risks and Gaps

[What edge cases or failure modes are missing?]

## Feasibility

[Will this approach work?]

## Feedback

1. [Feedback item 1]
2. [Feedback item 2]

---

## Verdict

**APPROVE** / **REQUEST_CHANGES**

[If REQUEST_CHANGES: Explain what must be addressed before approval]

REVIEW_EOF
```

Edit the file to fill in actual content (don't leave placeholders). Include a clear verdict.

### 3. Signal Completion

Include the verdict in your signal message:

```bash
agent-pair signal reviewer plan-review-done "verdict: APPROVE"
# or
agent-pair signal reviewer plan-review-done "verdict: REQUEST_CHANGES"
```

Then **STOP and wait**.

- If **APPROVE**: The coder proceeds to implementation
- If **REQUEST_CHANGES**: The coder revises their plan (up to 3 rounds)

## If You Need Clarification

If you discover ambiguity or need user input while reviewing:

```bash
agent-pair signal reviewer needs-clarify "question: what should happen when X?"
```

The orchestrator will pause and notify the user. After they respond, continue reviewing and signal `plan-review-done` when ready.
