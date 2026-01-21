# Agent Duo - Review Phase

You are in the **review phase** of duo collaboration.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read their uncommitted changes)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Current turn**: Check `$PEER_SYNC/turn`

## Current Phase: REVIEW

Your peer has also completed their work phase. Now you review each other's work **in parallel**.

### Your Tasks

1. **Examine peer's worktree**: Look at `$PEER_WORKTREE` to see their uncommitted changes
   ```bash
   # See what files changed
   git -C "$PEER_WORKTREE" status

   # See the actual changes
   git -C "$PEER_WORKTREE" diff

   # Or just explore the files directly
   ls -la "$PEER_WORKTREE"
   ```

2. **Write your review**: Create a review file analyzing their approach
   ```bash
   # Get current turn
   TURN=$(cat "$PEER_SYNC/turn")

   # Write review
   cat > "$PEER_SYNC/reviews/turn-${TURN}-${MY_NAME}-reviews-${PEER_NAME}.md" << 'EOF'
   # Review of $PEER_NAME's Approach (Turn $TURN)

   ## Summary
   <What did they build? What approach did they take?>

   ## Strengths
   <What's good about their approach?>

   ## Different Tradeoffs
   <How does their approach differ from yours? What did they trade off?>

   ## Ideas Worth Noting
   <Anything interesting you might adapt - while staying on your own path?>

   ## Questions
   <Anything unclear about their approach?>
   EOF
   ```

3. **Read their review of you** (if available from previous turn):
   ```bash
   PREV_TURN=$((TURN - 1))
   THEIR_REVIEW="$PEER_SYNC/reviews/turn-${PREV_TURN}-${PEER_NAME}-reviews-${MY_NAME}.md"
   if [ -f "$THEIR_REVIEW" ]; then
       cat "$THEIR_REVIEW"
   fi
   ```

### Review Philosophy

- **Analyze, don't prescribe**: Describe their approach objectively
- **Appreciate divergence**: Different isn't wrong
- **Note tradeoffs, not defects**: "They chose X which trades off Y for Z"
- **Stay on your path**: You're reviewing to understand, not to adopt

### When Done

Signal that your review is complete:

```bash
echo "review-done" > "$PEER_SYNC/${MY_NAME}-status"
```

Then STOP and wait. The orchestrator will trigger the next work phase, where you'll incorporate insights from both reviews.
