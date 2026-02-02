---
name: solo-reviewer-gather
description: Solo mode - reviewer gather phase for collecting task context
metadata:
  short-description: Gather codebase context for the coder
---

# Agent Solo - Reviewer Gather Phase

**PHASE: GATHER** - Collect relevant context from the codebase to help the coder.

You are the **REVIEWER** in a solo workflow.

## Your Environment

- **Worktree**: Current directory
- **Sync directory**: `$PEER_SYNC`
- **Feature**: `$FEATURE`

## Your Task

Before the coder starts implementing, you will gather relevant context from the codebase to help them understand what files and code sections are relevant to this task.

## Steps

### 1. Read the Task

```bash
cat "$FEATURE.md"
```

### 2. Explore the Codebase

Search for relevant files and code sections:
- Source files that will need to be modified or help in understanding relevant concepts
- Documentation explaining relevant systems
- Tests demonstrating expected or related behavior
- Dependencies the implementation must integrate with

Use tools like grep, find, or the agent's search capabilities to locate relevant code.

### 3. Write the Task Context

Create a context file with your findings:

```bash
cat > "$PEER_SYNC/task-context.md" << 'EOF'
# Task Context

## Relevant Source Files

- [path/to/file.ext:line-range](path/to/file.ext) - Brief note on why this is relevant
- [path/to/another.ext:42-60](path/to/another.ext) - What this code does and why it matters

## Documentation

- [docs/relevant.md](docs/relevant.md) - Description of relevant documentation

## Tests

- [tests/relevant_test.ext](tests/relevant_test.ext) - Tests that demonstrate expected behavior

## Key Dependencies

- [path/to/dependency.ext](path/to/dependency.ext) - How this relates to the task

## Notes

[Any additional context, gotchas, or suggestions for the coder]

EOF
```

Edit the file to fill in actual content based on your exploration. Use specific file:line references.

### 4. Signal Completion

```bash
agent-solo signal reviewer gather-done "task context collected"
```

Then **STOP and wait**. The coder will read your context file before starting work.

## Guidelines

- **Be thorough**: The coder will rely on this context to understand the codebase
- **Use specific references**: Include file paths with line numbers/ranges
- **Explain relevance**: Brief notes help the coder understand why each file matters
- **Include gotchas**: Warn about tricky areas or non-obvious dependencies
- **Don't implement**: Your job is to gather context, not to write code
