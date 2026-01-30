---
name: solo-pr-comment
description: Solo mode - PR comment phase for addressing GitHub PR feedback
metadata:
  short-description: Address PR comments from GitHub
---

# Agent Solo - PR Comment Phase

**New comments or reviews have been posted on your PR.** The orchestrator detected fresh feedback that needs your attention.

## Your PR

```bash
cat "$PEER_SYNC/coder.pr"
```

## Fetch All PR Feedback

Run the helper script to fetch all comments and reviews (PR-level comments, inline code review comments, and review summaries):

```bash
PR_URL=$(cat "$PEER_SYNC/coder.pr")
~/.local/share/agent-duo/fetch-pr-feedback.sh "$PR_URL"
```

## Your Task

1. **Review the feedback**: Read through all comments and reviews
2. **Address concerns**: Make code changes if the feedback is valid
3. **Respond if needed**: You can reply to comments via `gh pr comment`

### If amendments are warranted:

Make changes, then commit and push:

```bash
git add -A
git commit -m "Address PR feedback: <brief description>"
git push
```

### If no changes needed:

That's fine — just signal done. You may want to reply to comments explaining your reasoning.

## Before You Stop

Signal completion:

```bash
agent-solo signal coder done "addressed PR comments, [amended / no changes needed]"
```

The orchestrator continues monitoring your PR for new comments.
