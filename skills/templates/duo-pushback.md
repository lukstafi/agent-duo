---
name: duo-pushback
description: Agent-duo pushback stage - propose improvements to the task before implementing
metadata:
  short-description: Propose task improvements before starting work
---

# Agent Duo - Pushback Stage

**STAGE: PUSHBACK** - Before starting implementation, you may propose improvements to the task specification to improve the quality of the solution.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read-only - peer is also pushing back)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Purpose

The task file may specify both a goal and a plan. Sometimes the plan is suboptimal or could be improved. This is your opportunity to suggest modifications to the task that would lead to a better solution.

## Your Task

Read the task file carefully and consider:

1. **Is the stated plan the best approach to achieve the core goal?**
2. **Are there better alternatives or optimizations?**
3. **Are there missing requirements or edge cases?**
4. **Could the scope be refined to deliver more value?**

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Create Your Proposed Task Modification

If you believe the task could be improved, create a modified version:

```bash
cat > "$PEER_SYNC/pushback-${MY_NAME}.md" << 'EOF'
# Pushback from [MY_NAME]

## Summary of Proposed Changes

[1-3 sentences explaining what you're proposing to change and why]

## Reasoning

[Explain why this change would improve the solution quality]

## Proposed Task File

[Include the full modified task file here, with your improvements.
If you have no changes to propose, write "No changes proposed - the task is well-specified."]

EOF
```

Edit the file to fill in actual content.

### 3. Signal Completion

```bash
agent-duo signal "$MY_NAME" pushback-done "proposed task modifications submitted"
```

Then **STOP and wait**. The user will review both agents' pushbacks and decide:
- **Reject** - proceed with the original task
- **Accept** - use one of the proposed modifications
- **Modify** - make their own adjustments based on the feedback

Do NOT start implementing until the work phase begins.

## Guidelines

- **Focus on the goal, not just the plan**: The core objective matters more than the specific approach
- **Be constructive**: Explain why your changes would improve outcomes
- **Be specific**: Point to concrete issues or opportunities
- **It's OK to have no changes**: If the task is well-specified, say so
- **Diverge from peer**: If you see the peer's pushback, consider different angles
