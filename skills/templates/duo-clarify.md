---
name: duo-clarify
description: Agent-duo clarify phase - propose approach and questions before starting work
metadata:
  short-description: Clarify approach and ask questions before starting
---

# Agent Duo - Clarify Phase

**PHASE: CLARIFY** - Before starting implementation, you must propose your high-level approach and ask clarifying questions.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read-only - peer is also clarifying)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Your Task

Read the task file and produce TWO outputs:

1. **High-level approach** - Not a detailed plan, but a sketch: the key idea, first couple of things to explore, or the general direction you're considering
2. **Clarifying questions** - Questions for the user (task creator) that would help you start more effectively

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Write Your Approach and Questions

Create your clarify file:

```bash
cat > "$PEER_SYNC/clarify-${MY_NAME}.md" << 'EOF'
# Clarification from [MY_NAME]

## Proposed Approach

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
agent-duo signal "$MY_NAME" clarify-done "approach and questions submitted"
```

Then **STOP and wait**. The user will receive both agents' approaches and questions, and will respond in your terminal. After the user confirms in the orchestrator, the work phase will begin.

## Guidelines

- **Be concise**: This is a high-level sketch, not a detailed plan
- **Be specific with questions**: Ask about things that would materially affect your approach
- **Don't start implementing**: Wait for user confirmation before writing any code
- **Diverge early**: If you can see the peer's clarify file, consider a different angle
