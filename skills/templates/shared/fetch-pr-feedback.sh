#!/usr/bin/env bash
# fetch-pr-feedback.sh - Fetch all PR feedback (comments, code reviews, review summaries)
# Usage: fetch-pr-feedback.sh <pr_url>
#
# Fetches three types of feedback:
# 1. PR-level comments (general discussion)
# 2. Code review comments (attached to specific lines in the diff)
# 3. Review summaries (approve/request changes/comment with body text)

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: fetch-pr-feedback.sh <pr_url>" >&2
    exit 1
fi

PR_URL="$1"

# Extract PR number and repo from URL
PR_NUMBER=$(gh pr view "$PR_URL" --json number -q '.number')
REPO=$(gh pr view "$PR_URL" --json url -q '.url' | sed -E 's|https://github.com/([^/]+/[^/]+)/pull/.*|\1|')

echo "=============================================="
echo "PR FEEDBACK FOR: $PR_URL"
echo "=============================================="
echo ""

# 1. PR-level comments (general discussion)
echo "## PR-Level Comments (General Discussion)"
echo "-------------------------------------------"
PR_COMMENTS=$(gh pr view "$PR_URL" --json comments -q '.comments[] | "Author: \(.author.login)\nDate: \(.createdAt)\n\(.body)\n---"')
if [[ -n "$PR_COMMENTS" ]]; then
    echo "$PR_COMMENTS"
else
    echo "(No PR-level comments)"
fi
echo ""

# 2. Code review comments (attached to specific lines in the diff)
echo "## Code Review Comments (Inline on Diff)"
echo "-------------------------------------------"
REVIEW_COMMENTS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --jq '.[] | "File: \(.path):\(.line // .original_line // "N/A")\nAuthor: \(.user.login)\nDate: \(.created_at)\n\(.body)\n---"')
if [[ -n "$REVIEW_COMMENTS" ]]; then
    echo "$REVIEW_COMMENTS"
else
    echo "(No inline code review comments)"
fi
echo ""

# 3. Review summaries (approve/request changes/comment)
echo "## Review Summaries"
echo "-------------------------------------------"
REVIEWS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" --jq '.[] | "Reviewer: \(.user.login)\nState: \(.state)\nDate: \(.submitted_at)\nBody: \(.body // "(no comment)")\n---"')
if [[ -n "$REVIEWS" ]]; then
    echo "$REVIEWS"
else
    echo "(No reviews submitted)"
fi
echo ""
echo "=============================================="
echo "END OF PR FEEDBACK"
echo "=============================================="
