---
name: pair-suggest-refactor
description: Agent-pair suggest-refactor phase - reflect on what you'd do differently
metadata:
  short-description: Write refactoring suggestions after PR merge
---

# Agent Pair - Suggest Refactor Phase

The PR has been merged. Now take a step back and reflect on the work you did.

## Your Environment

- **Working directory**: Your worktree
- **Sync directory**: `$PEER_SYNC`

## Your Task

### 1. Reflect

Think about the entire session — the planning, coding, review, and merge phases. Consider:

- What would you do differently if starting from scratch?
- What architectural decisions would you change?
- What shortcuts did you take that you'd avoid next time?
- What patterns or abstractions would improve the code?
- What tests or documentation would you add?

### 2. Write Your Suggestions

Write your refactoring suggestions to a file:

```bash
cat > "$PEER_SYNC/suggest-refactor-coder.md" << 'SUGGESTIONS_EOF'
# Refactoring Suggestions

## If starting from scratch, I would...

[Your suggestions here — be specific and actionable]

SUGGESTIONS_EOF
```

Make sure to replace `[Your suggestions here]` with your actual reflections. Be specific and actionable — mention file names, function names, and concrete changes.

### 3. Signal Completion

```bash
agent-pair signal coder suggest-refactor-done "wrote refactoring suggestions"
```

## Important Guidelines

- **Be honest and specific** — This is a retrospective, not a defense of your choices
- **Focus on actionable improvements** — Not vague wishes
- **Keep it concise** — A few paragraphs, not an essay
- **Reference specific code** — Mention files, functions, patterns
