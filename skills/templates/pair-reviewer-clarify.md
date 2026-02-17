---
name: pair-reviewer-clarify
description: Pair mode - reviewer clarify phase for reviewing coder's proposed approach
metadata:
  short-description: Review coder's approach and add comments
---

# Agent Pair - Reviewer Clarify Phase

**PHASE: CLARIFY** - Review the coder's proposed approach and add your own questions or comments.

You are the **REVIEWER** in a pair workflow.

## Your Environment

- **Worktree**: Current directory
- **Sync directory**: `$PEER_SYNC`
- **Feature**: `$FEATURE`

## Your Task

The coder has proposed an approach. Review it and add your comments.

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Read the Coder's Proposed Approach

```bash
cat "$PEER_SYNC/clarify-coder.md"
```

### 3. Write Your Comments

Create your clarify file with comments on the approach and any additional questions:

```bash
cat > "$PEER_SYNC/clarify-reviewer.md" << 'EOF'
# Reviewer's Comments

## Comments on Coder's Approach

[What do you think of the proposed approach? Any concerns, risks, or suggestions?]

## Additional Questions for the User

1. [Any additional questions not covered by the coder?]
2. [Questions about edge cases or requirements?]

EOF
```

Edit the file to fill in actual content (don't leave placeholders).

### 4. Signal Completion

```bash
agent-pair signal reviewer clarify-done "comments submitted"
```

Then **STOP and wait**. The user will review both the coder's approach and your comments, then respond.

## Guidelines

- **Be constructive**: Offer helpful feedback on the approach
- **Identify risks**: Point out potential issues early
- **Ask relevant questions**: Help clarify requirements before implementation starts
- **Don't be prescriptive**: The coder will make implementation decisions
