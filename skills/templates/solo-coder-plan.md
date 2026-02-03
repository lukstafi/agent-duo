---
name: solo-coder-plan
description: Solo mode coder plan phase - write implementation plan before work
metadata:
  short-description: Write implementation plan (solo coder)
---

# Agent Solo - Plan Phase (Coder)

**PHASE: PLAN** - Before starting implementation, write a detailed implementation plan.

## Your Environment

- **Your worktree**: Current directory
- **Sync directory**: `$PEER_SYNC`
- **Your role**: Coder
- **Feature**: `$FEATURE`

## Your Task

Write a detailed implementation plan before starting to code. The reviewer will evaluate your plan.

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Check for Previous Feedback (if this is a plan revision)

```bash
PLAN_ROUND=$(cat "$PEER_SYNC/plan-round" 2>/dev/null || echo "1")
if [ "$PLAN_ROUND" -gt 1 ]; then
    echo "=== Previous Plan Review Feedback ==="
    cat "$PEER_SYNC/plan-review.md"
fi
```

### 3. Explore the Codebase

Understand the existing code structure relevant to your task:

```bash
rg -n "pattern|keyword|module"
cat path/to/relevant-file
```

### 4. Write Your Implementation Plan

```bash
cat > "$PEER_SYNC/plan-coder.md" << 'PLAN_EOF'
# Implementation Plan

## Approach

[Describe your high-level strategy in 3-5 sentences. What is the core idea?]

## Key Decisions

1. **Decision 1**: [What and why]
2. **Decision 2**: [What and why]

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `path/to/file.ext` | Create/Modify | Brief description |

## Implementation Steps

1. [ ] Step 1: Description
2. [ ] Step 2: Description
3. [ ] Step 3: Description

## Risks and Edge Cases

- **Risk 1**: [Description and mitigation]
- **Edge case**: [Description and handling]

## Test Strategy

- [ ] Unit tests for X
- [ ] Integration test for Y
- [ ] Manual verification of Z

PLAN_EOF
```

Edit the file to fill in actual content (don't leave placeholders).

If you're revising based on feedback, address each point raised in the previous review.

### 5. Signal Completion

```bash
agent-solo signal coder plan-done "implementation plan submitted"
```

Then **STOP and wait**. The reviewer will examine your plan before you start implementation.

## If You Need Clarification

If you discover ambiguity or need user input while planning:

```bash
agent-solo signal coder needs-clarify "question: what should happen when X?"
```

The orchestrator will pause and notify the user. After they respond, continue planning and signal `plan-done` when ready.

## Guidelines

- **Be specific**: Vague plans lead to vague implementations
- **Be realistic**: Don't promise what you can't deliver
- **Consider the existing code**: Your plan should integrate cleanly
- **Think about testing**: Every feature needs verification
- **Address feedback**: If revising, explicitly address each prior concern
