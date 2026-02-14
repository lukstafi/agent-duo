---
name: duo-review
description: Agent-duo review phase instructions for examining peer's work
metadata:
  short-description: Review peer's work in duo collaboration
---

# Agent Duo - Review Phase

**PHASE CHANGE: You are now in the REVIEW phase, not work.**

Stop any implementation work. Your task is to review your peer's solution.

## Your Environment

- **Your worktree**: Current directory
- **Peer's worktree**: `$PEER_WORKTREE` (read their changes)
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Current round**: Check `$PEER_SYNC/round`

## Current Phase: REVIEW

Your peer has also completed their work phase. Now you review each other's work **in parallel**.

**Note**: You participate in reviews even if you already have a PR. This ensures your peer gets feedback on their evolving work, and you can see their review of your PR.

### First Things First

Signal that you're reviewing:

```bash
agent-duo signal "$MY_NAME" reviewing "examining peer's work"
```

### Your Tasks

1. **Examine peer's worktree**: Look at `$PEER_WORKTREE` to see their changes

   ```bash
   # See commits on the feature branch
   git -C "$PEER_WORKTREE" log --oneline main..HEAD

   # See the full feature diff (all rounds combined)
   git -C "$PEER_WORKTREE" diff main...HEAD

   # See just the latest round's changes
   git -C "$PEER_WORKTREE" diff HEAD~1

   # Explore specific files
   cat "$PEER_WORKTREE/path/to/interesting/file"
   ```

2. **Read your previous review** (if round 2+, to avoid repeating feedback):

   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   MY_PREV_REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${MY_NAME}-reviews-${PEER_NAME}.md"
   [ -f "$MY_PREV_REVIEW" ] && cat "$MY_PREV_REVIEW"
   ```

   Focus on what changed since your last review. Only re-raise prior issues if still unaddressed.

3. **Write your review**: Create a review file analyzing their approach

   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   mkdir -p "$PEER_SYNC/reviews"

   cat > "$PEER_SYNC/reviews/round-${ROUND}-${MY_NAME}-reviews-${PEER_NAME}.md" << 'EOF'
   # Review of [PEER_NAME]'s Approach (Round [ROUND])

   ## Summary
   [What did they build? What approach did they take?]

   ## Strengths
   [What's good about their approach?]

   ## Different Tradeoffs
   [How does their approach differ from yours? What did they trade off?]

   ## Ideas Worth Noting
   [Anything interesting you might learn from - while staying on your own path?]

   ## Questions
   [Anything unclear about their approach?]
   EOF
   ```

   Edit the file to fill in actual observations (don't leave placeholders).

4. **Read their review of you** (if available from previous round):

   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   PREV_ROUND=$((ROUND - 1))
   THEIR_REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-${PEER_NAME}-reviews-${MY_NAME}.md"
   [ -f "$THEIR_REVIEW" ] && cat "$THEIR_REVIEW"
   ```

### Review Philosophy

- **Analyze, don't prescribe**: Describe their approach objectively
- **Appreciate divergence**: Different isn't wrong
- **Note tradeoffs, not defects**: "They chose X which trades off Y for Z"
- **Stay on your path**: You're reviewing to understand, not to adopt their approach wholesale

### If You Discover a Blocking Issue

If blocked by ambiguity or inconsistency, use: `agent-duo escalate <type> "<message>"` (types: ambiguity, inconsistency, misguided). Continue with your best interpretation.

### When Done

Signal completion and **STOP**:

```bash
agent-duo signal "$MY_NAME" review-done "review written"
```
