---
name: duo-merge-vote
description: Agent-duo merge phase - evaluate both PRs and cast a merge vote
metadata:
  short-description: Analyze both PRs and vote on merge decision
---

# Agent Duo - Merge Vote Phase

**PHASE: MERGE VOTE**

## Purpose

Evaluate both PRs objectively and cast a clear vote.

## Output

Write: `$PEER_SYNC/merge-votes/round-${ROUND}-${MY_NAME}-vote.md`

Required line for parser:
- `## My Vote: claude` or `## My Vote: codex`

## Steps

1. Load PR ids and task:

```bash
CLAUDE_PR="$(cat "$PEER_SYNC/claude.pr")"
CODEX_PR="$(cat "$PEER_SYNC/codex.pr")"
cat "$FEATURE.md"
```

2. Inspect both PRs:

```bash
gh pr view "$CLAUDE_PR" --json title,body,commits,files,reviews,comments
gh pr view "$CODEX_PR" --json title,body,commits,files,reviews,comments
gh pr diff "$CLAUDE_PR"
gh pr diff "$CODEX_PR"
```

3. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Build side-by-side comparison of both PRs
- Score requirement coverage, correctness, tests, maintainability
- Recommend one winner and optional cherry-picks from the other PR

4. Write vote file:

```bash
ROUND=$(cat "$PEER_SYNC/merge-round")
mkdir -p "$PEER_SYNC/merge-votes"
cat > "$PEER_SYNC/merge-votes/round-${ROUND}-${MY_NAME}-vote.md" << EOF_VOTE
# Merge Vote from ${MY_NAME} (Round ${ROUND})

## My Vote: claude

## Why This PR Wins

## Main Risks in Chosen PR

## Optional Features Worth Preserving from Other PR
EOF_VOTE
```

Replace `claude` with your actual vote.

5. Signal completion:

```bash
agent-duo signal "$MY_NAME" vote-done "merge vote submitted"
```

Then stop and wait.
