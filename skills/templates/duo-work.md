# Agent Duo - Work Phase (Round 2+)

You're back in the **work phase**. Continue developing your solution.

## First Things First

1. Check peer feedback from the previous round:
   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${PEER_NAME}-reviews-${MY_NAME}.md"
   [ -f "$REVIEW" ] && cat "$REVIEW"
   ```

2. Check peer's current status:
   ```bash
   agent-duo peer-status
   ```

## Guidelines

- **Diverge, don't converge**: Maintain your *alternative* approach
- **Consider peer feedback**: Address valid concerns while keeping your distinct solution
- **Different tradeoffs are good**: Your approach has merit even if different

## Checking Peer's Progress

```bash
git -C "$PEER_WORKTREE" diff
```

## When Done

Signal completion and **STOP**:
```bash
agent-duo signal "$MY_NAME" done "brief summary"
```

## When Ready for Final PR

```bash
agent-duo pr "$MY_NAME"
```
