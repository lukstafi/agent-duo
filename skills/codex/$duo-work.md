# Agent Duo - Work Phase

You are participating in a **duo collaboration** with another AI agent. You both started from the same prompt and are developing **alternative solutions** in parallel.

## Your Environment

- **Your worktree**: Current directory (read/write)
- **Peer's worktree**: `$PEER_WORKTREE` (read-only - look but don't touch)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`

## Current Phase: WORK

Continue implementing your solution. You can peek at your peer's worktree to see their approach, but **maintain your distinct perspective**.

### Guidelines

1. **Diverge, don't converge**: Your goal is to produce an *alternative* solution, not to copy your peer
2. **Different tradeoffs are good**: If your peer chose approach A, consider if approach B has merit
3. **Read peer's code for insight, not imitation**: Understanding their approach helps you articulate why yours is different
4. **Focus on your implementation**: Make progress on your own solution

### When You're Done with This Phase

When you've made meaningful progress and want peer feedback, signal completion:

```bash
echo "done" > "$PEER_SYNC/${MY_NAME}-status"
```

Then STOP and wait. The orchestrator will trigger the review phase.

### When You're Ready to Submit Final PR

If you believe your solution is complete (or you're stuck and want to submit WIP):

1. Commit your changes to a branch:
   ```bash
   git checkout -b ${MY_NAME}-solution
   git add -A
   git commit -m "Solution from ${MY_NAME}: <brief description>"
   git push -u origin ${MY_NAME}-solution
   ```

2. Create a PR:
   ```bash
   gh pr create --title "${MY_NAME}'s solution: <title>" --body "<description of approach and tradeoffs>"
   ```

3. Record the PR:
   ```bash
   gh pr view --json url -q '.url' > "$PEER_SYNC/${MY_NAME}-pr"
   ```

The duo ends when both agents have PRs.
