#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"

if [ -z "$mode" ]; then
    echo "Usage: $0 <duo-work|duo-review|duo-amend|pair-coder-work|pair-reviewer-work>" >&2
    exit 2
fi

if [ -z "${PEER_SYNC:-}" ]; then
    echo "PEER_SYNC is not set." >&2
    exit 2
fi

read_round() {
    cat "$PEER_SYNC/round" 2>/dev/null || echo "1"
}

print_if_exists() {
    local label="$1"
    local file="$2"
    if [ -f "$file" ]; then
        echo "=== $label: $file ==="
        cat "$file"
        echo
    else
        echo "=== $label: none ($file) ==="
    fi
}

print_main_diff_stat() {
    echo "=== Current change footprint (git diff --stat main...HEAD) ==="

    if ! command -v git >/dev/null 2>&1; then
        echo "git is not available."
        echo
        return 0
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Not in a git worktree."
        echo
        return 0
    fi

    local base_ref=""
    if git rev-parse --verify --quiet main >/dev/null 2>&1; then
        base_ref="main"
    elif git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null 2>&1; then
        base_ref="origin/main"
    fi

    if [ -z "$base_ref" ]; then
        echo "main branch not found (looked for main and origin/main)."
        echo
        return 0
    fi

    local diff_stat
    if diff_stat="$(git diff --stat "$base_ref...HEAD" 2>/dev/null)"; then
        if [ -n "$diff_stat" ]; then
            echo "$diff_stat"
        else
            echo "(No changes between $base_ref and HEAD.)"
        fi
    else
        echo "Could not compute diff stat for $base_ref...HEAD."
    fi
    echo
}

round="$(read_round)"

case "$mode" in
    duo-work)
        if [ "$round" -gt 1 ]; then
            prev_round=$((round - 1))
            print_if_exists "Previous peer review" "$PEER_SYNC/reviews/round-${prev_round}-${PEER_NAME}-reviews-${MY_NAME}.md"
        else
            echo "Round 1 - no previous peer review."
        fi
        print_main_diff_stat
        if command -v agent-duo >/dev/null 2>&1; then
            echo "=== Peer status ==="
            agent-duo peer-status || true
            echo
        fi
        ;;
    duo-review)
        if [ "$round" -gt 1 ]; then
            prev_round=$((round - 1))
            print_if_exists "Your previous review of peer" "$PEER_SYNC/reviews/round-${prev_round}-${MY_NAME}-reviews-${PEER_NAME}.md"
            print_if_exists "Peer's previous review of you" "$PEER_SYNC/reviews/round-${prev_round}-${PEER_NAME}-reviews-${MY_NAME}.md"
        else
            echo "Round 1 - no previous round reviews."
        fi
        ;;
    duo-amend)
        if [ "$round" -gt 1 ]; then
            prev_round=$((round - 1))
            print_if_exists "Most recent peer review" "$PEER_SYNC/reviews/round-${prev_round}-${PEER_NAME}-reviews-${MY_NAME}.md"
        else
            echo "Round 1 - no previous peer review."
        fi
        print_main_diff_stat
        ;;
    pair-coder-work)
        if [ "$round" -gt 1 ]; then
            prev_round=$((round - 1))
            print_if_exists "Previous reviewer feedback" "$PEER_SYNC/reviews/round-${prev_round}-review.md"
        else
            echo "Round 1 - no previous reviewer feedback."
        fi
        print_main_diff_stat
        if command -v agent-pair >/dev/null 2>&1; then
            echo "=== Current phase ==="
            agent-pair phase || true
            echo
        fi
        ;;
    pair-reviewer-work)
        if [ "$round" -gt 1 ]; then
            prev_round=$((round - 1))
            print_if_exists "Your previous review" "$PEER_SYNC/reviews/round-${prev_round}-review.md"
        else
            echo "Round 1 - no previous review."
        fi
        ;;
    *)
        echo "Unknown mode: $mode" >&2
        exit 2
        ;;
esac
