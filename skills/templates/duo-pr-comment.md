---
name: duo-pr-comment
description: Agent-duo PR comment phase for addressing GitHub PR feedback
metadata:
  short-description: Address PR comments from GitHub
---

# Agent Duo - PR Comment Phase

**New comments or reviews have been posted on your PR.** The orchestrator detected fresh feedback that needs your attention.

## Your PR

```bash
cat "$PEER_SYNC/${MY_NAME}.pr"
```

## Fetch All PR Feedback

Run the helper script to fetch all comments and reviews (PR-level comments, inline code review comments, and review summaries):

```bash
PR_URL=$(cat "$PEER_SYNC/${MY_NAME}.pr")
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

**You must post a PR comment explaining why** — e.g., the issue is already addressed elsewhere in the codebase, or the reviewer's concern is based on a misunderstanding. This keeps the conversation transparent.

```bash
gh pr comment "$PR_URL" --body "Regarding the feedback: <your explanation of why no changes are needed>"
```

## Before You Stop

Signal completion:

```bash
agent-duo signal "$MY_NAME" done "addressed PR comments, [amended / no changes needed]"
```

The orchestrator continues monitoring your PR for new comments.
