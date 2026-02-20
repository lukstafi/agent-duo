---
name: duo-merge-debate
description: Agent-duo merge phase - debate and revise vote when votes differ
metadata:
  short-description: Review peer vote and revise or defend position
---

# Agent Duo - Merge Debate Phase

**PHASE: MERGE DEBATE**

## Purpose

Resolve disagreement by engaging with peer reasoning and either changing or defending your vote.

## Output

Write: `$PEER_SYNC/merge-votes/round-${ROUND}-${MY_NAME}-vote.md`

Required line for parser:
- `## My Vote: claude` or `## My Vote: codex`

## Steps

1. Read previous-round votes:

```bash
ROUND=$(cat "$PEER_SYNC/merge-round")
PREV_ROUND=$((ROUND - 1))
cat "$PEER_SYNC/merge-votes/round-${PREV_ROUND}-${PEER_NAME}-vote.md" 2>/dev/null || true
cat "$PEER_SYNC/merge-votes/round-${PREV_ROUND}-${MY_NAME}-vote.md" 2>/dev/null || true
```

2. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Extract strongest arguments from both votes
- Identify which concerns materially change winner selection
- Draft a revised rationale and suggested cherry-picks

3. Write updated vote file:

```bash
ROUND=$(cat "$PEER_SYNC/merge-round")
cat > "$PEER_SYNC/merge-votes/round-${ROUND}-${MY_NAME}-vote.md" << EOF_VOTE
# Merge Vote from ${MY_NAME} (Debate Round ${ROUND})

## Response to Peer Arguments

## My Vote: claude

## Position: UNCHANGED

## Rationale

## Optional Features to Cherry-Pick from Losing PR
EOF_VOTE
```

Replace vote/position values as needed.

4. Signal completion:

```bash
agent-duo signal "$MY_NAME" debate-done "debate response submitted"
```

Then stop and wait.
