---
name: solo-coder-clarify
description: Solo mode - coder clarify phase for proposing approach
metadata:
  short-description: Propose approach before starting work
---

# Agent Solo - Coder Clarify Phase

**PHASE: CLARIFY** - Before starting implementation, propose your high-level approach and ask clarifying questions.

You are the **CODER** in a solo workflow. A reviewer will review your code.

## Your Environment

- **Worktree**: Current directory
- **Sync directory**: `$PEER_SYNC`
- **Feature**: `$FEATURE`

## Your Task

Read the task file and produce TWO outputs:

1. **High-level approach** - Not a detailed plan, but a sketch: the key idea, first steps to explore, or general direction
2. **Clarifying questions** - Questions for the user that would help you start more effectively

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Write Your Approach and Questions

Create your clarify file:

```bash
cat > "$PEER_SYNC/clarify-coder.md" << 'EOF'
# Coder's Proposed Approach

## High-Level Approach

[Write 3-5 sentences describing your high-level approach. This is NOT a detailed plan - just a sketch of the direction you're considering, key ideas, or first steps to explore.]

## Questions for the User

1. [Question 1]
2. [Question 2]
3. [Question 3 - optional]

EOF
```

Edit the file to fill in actual content (don't leave placeholders).

### 3. Signal Completion

```bash
agent-solo signal coder clarify-done "approach and questions submitted"
```

Then **STOP and wait**. The reviewer will also provide comments, then the user will review both and respond.

## Guidelines

- **Be concise**: This is a high-level sketch, not a detailed plan
- **Be specific with questions**: Ask about things that would materially affect your approach
- **Don't start implementing**: Wait for user confirmation before writing any code
