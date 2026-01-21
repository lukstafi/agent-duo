# Agent Duo - Work Phase

You are participating in a **duo collaboration** with another AI agent. You both started from the same task and are developing **alternative solutions** in parallel.

## Your Environment

- **Your worktree**: Current directory (read/write)
- **Peer's worktree**: `$PEER_WORKTREE` (read-only - look but don't touch)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Feature**: `$FEATURE`

## Current Phase: WORK

You are in the **work phase**. Implement your solution while maintaining your distinct approach.

### First Things First

1. Signal that you're working:
   ```bash
   agent-duo signal "$MY_NAME" working "starting implementation"
   ```

2. Read the task description:
   ```bash
   cat "$FEATURE.md"
   ```

3. Check if there's peer feedback from a previous round:
   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${PEER_NAME}-reviews-${MY_NAME}.md"
   [ -f "$REVIEW" ] && cat "$REVIEW"
   ```

### Guidelines

1. **Diverge, don't converge**: Your goal is to produce an *alternative* solution, not to copy your peer
2. **Different tradeoffs are good**: If your peer chose approach A, consider if approach B has merit
3. **Read peer's code for insight, not imitation**: Understanding their approach helps you articulate why yours is different
4. **Focus on your implementation**: Make progress on your own solution

### Checking Peer's Progress (Optional)

You can peek at your peer's work to understand their approach:

```bash
# See their status
agent-duo peer-status

# See what files they changed
git -C "$PEER_WORKTREE" status

# See their changes
git -C "$PEER_WORKTREE" diff

# Read specific files
cat "$PEER_WORKTREE/path/to/file"
```

### Handling Interrupts

If you're interrupted (check `$PEER_SYNC/$MY_NAME.interrupt` exists), gracefully save your state and signal:

```bash
if [ -f "$PEER_SYNC/$MY_NAME.interrupt" ]; then
    # Save progress, commit WIP if needed
    git add -A && git commit -m "WIP: interrupted during $FEATURE"
    agent-duo signal "$MY_NAME" interrupted "saved WIP, ready for review"
fi
```

### When You're Done with This Phase

When you've made meaningful progress and want peer feedback:

```bash
agent-duo signal "$MY_NAME" done "completed initial implementation"
```

Then **STOP and wait**. The orchestrator will trigger the review phase.

### When You're Ready to Submit Final PR

If your solution is complete:

```bash
agent-duo pr "$MY_NAME"
```

This auto-commits, pushes, and creates the PR. The duo ends when both agents have PRs.
