---
name: pair-reviewer-work
description: Pair mode - reviewer review phase instructions for examining coder's work
metadata:
  short-description: Review coder's work in pair collaboration
---

# Agent Pair - Reviewer Phase

**PHASE CHANGE: You are now in the REVIEW phase.**

Stop any other activity. Your task is to review the coder's solution.

You are the **REVIEWER** in a pair workflow. Your job is to review code, NOT to write code.

## Your Environment

- **Worktree**: Current directory (READ-ONLY for you - do not modify code)
- **Sync directory**: `$PEER_SYNC`
- **Current round**: Check `$PEER_SYNC/round`

## Current Phase: REVIEW

The coder has completed their work. Now you review it.

### First Things First

Signal that you're reviewing:

```bash
agent-pair signal reviewer reviewing "examining coder's work"
```

### Your Tasks

1. **Examine the coder's changes**:

   ```bash
   # See commits on the feature branch
   git log --oneline main..HEAD

   # See the full feature diff (all rounds combined)
   git diff main...HEAD

   # See just the latest round's changes
   git diff HEAD~1
   ```

2. **Read your previous review** (round 2+ only, to avoid repeating feedback):

   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   if [ "$ROUND" -gt 1 ]; then
       PREV_ROUND=$((ROUND - 1))
       PREV_REVIEW="$PEER_SYNC/reviews/round-${PREV_ROUND}-review.md"
       [ -f "$PREV_REVIEW" ] && cat "$PREV_REVIEW"
   fi
   ```

   Focus on what changed since your last review. Only re-raise prior issues if still unaddressed.

3. **Write your review**: Create a review file with your analysis

   ```bash
   ROUND=$(cat "$PEER_SYNC/round")
   mkdir -p "$PEER_SYNC/reviews"

   cat > "$PEER_SYNC/reviews/round-${ROUND}-review.md" << 'EOF'
   # Code Review (Round [ROUND])

   ## Summary
   [What was implemented? What approach did they take?]

   ## Issues Found
   - [ ] Issue 1 (severity: high/medium/low)
   - [ ] Issue 2

   ## Suggestions
   [Optional improvements that aren't blocking]

   ## Verdict
   **APPROVE** / **REQUEST_CHANGES**

   [If REQUEST_CHANGES: Explain what needs to be fixed before approval]
   EOF
   ```

   Edit the file to fill in actual observations (don't leave placeholders).

4. **Check previous rounds** are addressed (verify your prior feedback was acted on)

### Review Philosophy

- **Be constructive**: Point out issues clearly with suggestions for fixes
- **Focus on important issues**: Don't nitpick minor style issues
- **Use clear verdict**: APPROVE means ready for PR, REQUEST_CHANGES means another round needed
- **Do NOT modify code**: You review only, the coder implements

### If You Discover a Blocking Issue

If blocked by ambiguity or inconsistency, use: `agent-pair escalate <type> "<message>"` (types: ambiguity, inconsistency, misguided). Continue with your review.

### Verdict Guidelines

- **APPROVE**: Code is correct, follows best practices, and is ready to merge
- **REQUEST_CHANGES**: There are bugs, missing requirements, or significant issues

### When Done

Signal that your review is complete:

```bash
agent-pair signal reviewer review-done "verdict: APPROVE"
# or
agent-pair signal reviewer review-done "verdict: REQUEST_CHANGES"
```

Then **STOP and wait**. If you approved, the coder will create a PR. If you requested changes, there will be another work round.
