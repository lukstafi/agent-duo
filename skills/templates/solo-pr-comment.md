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

## Fetch PR Comments and Reviews

Get your PR number and repo:

```bash
PR_URL=$(cat "$PEER_SYNC/coder.pr")
PR_NUMBER=$(gh pr view "$PR_URL" --json number -q '.number')
REPO=$(gh pr view "$PR_URL" --json url -q '.url' | sed -E 's|https://github.com/([^/]+/[^/]+)/pull/.*|\1|')
```

### 1. PR-level comments (general discussion):

```bash
gh pr view "$PR_URL" --comments
```

### 2. Code review comments (attached to specific lines in the diff):

**This is critical** — most substantive feedback appears as inline code comments:

```bash
gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --jq '.[] | "---\nFile: \(.path):\(.line // .original_line)\nAuthor: \(.user.login)\nComment: \(.body)\n"'
```

### 3. Review summaries (approve/request changes/comment):

```bash
gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" --jq '.[] | select(.body != "") | "---\nReviewer: \(.user.login)\nState: \(.state)\nBody: \(.body)\n"'
```

## Your Task

1. **Review the feedback**: Read through the new comments and reviews
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
