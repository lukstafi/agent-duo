---
name: duo-merge-vote
description: Agent-duo merge phase - vote on which PR to merge
metadata:
  short-description: Analyze both PRs and vote on merge decision
---

# Agent Duo - Merge Vote Phase

**PHASE: MERGE VOTE** - Both PRs are created. You must analyze them and vote on which one to merge.

## Your Environment

- **Working directory**: Main branch (not a worktree)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Context

This is a **fresh session** - you are not the agent who created either PR. Your job is to objectively evaluate both solutions and vote on which one should be merged.

## Your Task

### 1. Get PR Information

```bash
CLAUDE_PR="$(cat "$PEER_SYNC/claude.pr")"
CODEX_PR="$(cat "$PEER_SYNC/codex.pr")"
echo "Claude's PR: $CLAUDE_PR"
echo "Codex's PR:  $CODEX_PR"
```

### 2. Read the Original Task

```bash
cat "$FEATURE.md"
```

### 3. Analyze Both PRs

For each PR, examine:

```bash
# View PR details and discussion
gh pr view "$CLAUDE_PR"
gh pr view "$CODEX_PR"

# Compare code changes
gh pr diff "$CLAUDE_PR"
gh pr diff "$CODEX_PR"
```

### 4. Read Previous Reviews (if available)

```bash
ls "$PEER_SYNC/reviews/" 2>/dev/null && cat "$PEER_SYNC/reviews/"*.md
```

### 5. Write Your Vote

Create your vote file with analysis and decision:

```bash
cat > "$PEER_SYNC/merge-vote-${MY_NAME}.md" << 'EOF'
# Merge Vote from [MY_NAME]

## Summary of Claude's PR

[2-3 sentences: What approach did Claude take? Key design decisions?]

## Summary of Codex's PR

[2-3 sentences: What approach did Codex take? Key design decisions?]

## Comparison

| Aspect | Claude's PR | Codex's PR |
|--------|-------------|------------|
| Code quality | | |
| Test coverage | | |
| Alignment with task | | |
| Maintainability | | |

## My Vote: [claude / codex]

### Rationale

[3-5 sentences explaining why this PR better serves the task requirements. Consider:
- Which solution better addresses the core requirements?
- Which is more maintainable long-term?
- Which has better test coverage?
- Are there valuable features in the losing PR that should be cherry-picked?]

### Features to Cherry-Pick from Losing PR

[List specific commits, functions, or features from the non-chosen PR that should be incorporated after merge. Be specific about what and why.]

EOF
```

Edit the file to fill in actual analysis (don't leave placeholders).

### 6. Signal Completion

```bash
agent-duo signal "$MY_NAME" vote-done "merge vote submitted"
```

Then **STOP and wait**. The orchestrator will check if both agents agree, or trigger a debate round if votes differ.

## Guidelines

- **Be objective**: You didn't write either solution - evaluate them fairly
- **Focus on requirements**: Which solution better addresses the actual task?
- **Consider cherry-picking**: The losing PR may have valuable features worth preserving
- **Be specific**: Vague rationale helps no one
