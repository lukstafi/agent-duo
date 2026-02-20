---
name: duo-review
description: Agent-duo review phase instructions for reviewing peer work
metadata:
  short-description: Review peer's work in duo collaboration
---

# Agent Duo - Review Phase

**PHASE: REVIEW**

## Purpose

Review peer changes, focusing on deltas since last round and high-impact feedback.

## Output

Write: `$PEER_SYNC/reviews/round-${ROUND}-${MY_NAME}-reviews-${PEER_NAME}.md`

Minimum sections:
- Delta since last round
- Strengths
- Risks or questions

## Steps

1. Signal start:

```bash
agent-duo signal "$MY_NAME" reviewing "examining peer's work"
```

2. Run preflight:

```bash
"$HOME/.local/share/agent-duo/phase-preflight.sh" duo-review
```

3. Inspect peer changes:

```bash
git -C "$PEER_WORKTREE" log --oneline main..HEAD
git -C "$PEER_WORKTREE" diff main...HEAD
git -C "$PEER_WORKTREE" diff HEAD~1
```

4. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Compare peer changes vs previous-round review
- Identify resolved issues and remaining high-risk gaps
- Draft a concise review focused on actionable deltas

5. Write your review file:

```bash
ROUND=$(cat "$PEER_SYNC/round")
mkdir -p "$PEER_SYNC/reviews"
cat > "$PEER_SYNC/reviews/round-${ROUND}-${MY_NAME}-reviews-${PEER_NAME}.md" << EOF_REVIEW
# Review of ${PEER_NAME}'s Approach (Round ${ROUND})

## Delta Since Last Round

## Strengths

## Risks / Questions

## Optional Suggestions
EOF_REVIEW
```

6. Signal completion:

```bash
agent-duo signal "$MY_NAME" review-done "review written"
```

Then stop.
