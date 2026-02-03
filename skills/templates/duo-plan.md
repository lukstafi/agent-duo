---
name: duo-plan
description: Agent-duo plan phase - write implementation plan before starting work
metadata:
  short-description: Write implementation plan in duo collaboration
---

# Agent Duo - Plan Phase

**PHASE: PLAN** - Before starting implementation, write a detailed implementation plan.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read-only - peer is also planning)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Your Task

Read the task file and produce a detailed implementation plan. Your plan should enable another developer to understand exactly what you intend to build.

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Explore the Codebase

Understand the existing code structure relevant to your task:

```bash
# Find relevant files
git ls-files | grep -E "(relevant|patterns)"

# Read key files
cat <relevant-file>
```

### 3. Write Your Implementation Plan

Create your plan file:

```bash
cat > "$PEER_SYNC/plan-${MY_NAME}.md" << 'EOF'
# Implementation Plan from [MY_NAME]

## Approach

[Describe your high-level strategy in 3-5 sentences. What is the core idea? How does it fit into the existing codebase?]

## Key Decisions

[List 2-4 key architectural or design decisions and why you made them]

1. **Decision 1**: [What and why]
2. **Decision 2**: [What and why]

## File Changes

[List the files you plan to create or modify]

| File | Action | Description |
|------|--------|-------------|
| `path/to/file.ext` | Create/Modify | Brief description |

## Implementation Steps

[Break down the work into concrete steps]

1. [ ] Step 1: Description
2. [ ] Step 2: Description
3. [ ] Step 3: Description

## Risks and Edge Cases

[Identify potential issues and how you'll handle them]

- **Risk 1**: [Description and mitigation]
- **Edge case**: [Description and handling]

## Test Strategy

[How will you verify correctness?]

- [ ] Unit tests for X
- [ ] Integration test for Y
- [ ] Manual verification of Z

EOF
```

Edit the file to fill in actual content (don't leave placeholders).

### 4. Signal Completion

```bash
agent-duo signal "$MY_NAME" plan-done "implementation plan submitted"
```

Then **STOP and wait**. The orchestrator will trigger the plan-review phase where you'll review your peer's plan.

## If You Need Clarification

If you discover ambiguity or need user input while planning:

```bash
agent-duo signal "$MY_NAME" needs-clarify "question: what should happen when X?"
```

The orchestrator will pause and notify the user. After they respond, continue planning and signal `plan-done` when ready.

## Guidelines

- **Be specific**: Vague plans lead to vague implementations
- **Be realistic**: Don't promise what you can't deliver
- **Consider the existing code**: Your plan should integrate cleanly
- **Think about testing**: Every feature needs verification
- **Diverge from peer**: If you see the peer's plan, consider different approaches
