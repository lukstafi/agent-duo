#!/usr/bin/env bash
# cleanup.sh - Clean up agent-duo worktrees and tmux session
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
PEER_SYNC="$PROJECT_ROOT/.peer-sync"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CLEANUP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[CLEANUP]${NC} $1"; }

# Kill tmux session
cleanup_tmux() {
    log_info "Stopping tmux session..."
    tmux kill-session -t agent-duo 2>/dev/null && log_info "Killed tmux session 'agent-duo'" || log_warn "No tmux session found"
}

# Kill ttyd processes
cleanup_ttyd() {
    log_info "Stopping ttyd processes..."
    pkill -f "ttyd.*7681" 2>/dev/null || true
    pkill -f "ttyd.*7682" 2>/dev/null || true
}

# Remove worktrees
cleanup_worktrees() {
    log_info "Removing worktrees..."

    local claude_worktree="$PROJECT_ROOT/../agent-duo-claude"
    local codex_worktree="$PROJECT_ROOT/../agent-duo-codex"

    cd "$PROJECT_ROOT"

    if [[ -d "$claude_worktree" ]]; then
        git worktree remove --force "$claude_worktree" 2>/dev/null || rm -rf "$claude_worktree"
        log_info "Removed Claude worktree"
    fi

    if [[ -d "$codex_worktree" ]]; then
        git worktree remove --force "$codex_worktree" 2>/dev/null || rm -rf "$codex_worktree"
        log_info "Removed Codex worktree"
    fi

    # Prune stale worktree entries
    git worktree prune
}

# Clean peer-sync state (optional)
cleanup_state() {
    if [[ "${1:-}" == "--full" ]]; then
        log_info "Cleaning peer-sync state..."
        rm -f "$PEER_SYNC"/*.state
        rm -f "$PEER_SYNC"/*.diff
        rm -f "$PEER_SYNC"/*.files
        rm -f "$PEER_SYNC"/*.review
        rm -f "$PEER_SYNC"/*_worktree_path
        rm -f "$PEER_SYNC"/turn
        rm -f "$PEER_SYNC"/current_phase
        rm -f "$PEER_SYNC"/phase_start
        log_info "State files cleaned"
    else
        log_info "Keeping peer-sync state (use --full to remove)"
    fi
}

main() {
    log_info "=== Agent Duo Cleanup ==="

    cleanup_tmux
    cleanup_ttyd
    cleanup_worktrees
    cleanup_state "$@"

    log_info "Cleanup complete!"
}

main "$@"
