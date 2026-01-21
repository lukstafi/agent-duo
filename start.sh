#!/usr/bin/env bash
# start.sh - Initialize agent-duo worktrees and launch agents
# Usage: ./start.sh <task-description-file>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
PEER_SYNC="$PROJECT_ROOT/.peer-sync"

# Configuration
CLAUDE_BRANCH="claude-work"
CODEX_BRANCH="codex-work"
TTYD_PORT_CLAUDE=7681
TTYD_PORT_CODEX=7682

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    local missing=()
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v tmux >/dev/null 2>&1 || missing+=("tmux")
    command -v ttyd >/dev/null 2>&1 || missing+=("ttyd")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        exit 1
    fi
}

# Setup worktrees for both agents
setup_worktrees() {
    log_info "Setting up worktrees..."

    # Ensure we're in the git repo root
    cd "$PROJECT_ROOT"

    # Create worktree directories if needed
    local claude_worktree="$PROJECT_ROOT/../agent-duo-claude"
    local codex_worktree="$PROJECT_ROOT/../agent-duo-codex"

    # Remove stale worktrees if they exist
    if [[ -d "$claude_worktree" ]]; then
        log_warn "Removing existing Claude worktree"
        git worktree remove --force "$claude_worktree" 2>/dev/null || rm -rf "$claude_worktree"
    fi
    if [[ -d "$codex_worktree" ]]; then
        log_warn "Removing existing Codex worktree"
        git worktree remove --force "$codex_worktree" 2>/dev/null || rm -rf "$codex_worktree"
    fi

    # Ensure branches exist
    git branch "$CLAUDE_BRANCH" 2>/dev/null || true
    git branch "$CODEX_BRANCH" 2>/dev/null || true

    # Create fresh worktrees
    git worktree add "$claude_worktree" "$CLAUDE_BRANCH"
    git worktree add "$codex_worktree" "$CODEX_BRANCH"

    # Create .peer-sync in each worktree (symlink to shared)
    mkdir -p "$PEER_SYNC"
    ln -sf "$PEER_SYNC" "$claude_worktree/.peer-sync"
    ln -sf "$PEER_SYNC" "$codex_worktree/.peer-sync"

    log_info "Worktrees created at:"
    log_info "  Claude: $claude_worktree"
    log_info "  Codex:  $codex_worktree"

    echo "$claude_worktree" > "$PEER_SYNC/claude_worktree_path"
    echo "$codex_worktree" > "$PEER_SYNC/codex_worktree_path"
}

# Initialize peer-sync state files
init_peer_sync() {
    log_info "Initializing peer-sync state..."

    # Clear any previous state
    rm -f "$PEER_SYNC"/*.state "$PEER_SYNC"/*.review "$PEER_SYNC"/*.ready

    # Initialize state files for both agents
    echo "INITIALIZING" > "$PEER_SYNC/claude.state"
    echo "INITIALIZING" > "$PEER_SYNC/codex.state"

    # Create turn counter
    echo "0" > "$PEER_SYNC/turn"

    # Copy task description if provided
    if [[ -n "${1:-}" ]] && [[ -f "$1" ]]; then
        cp "$1" "$PEER_SYNC/task.md"
        log_info "Task description copied to $PEER_SYNC/task.md"
    fi
}

# Launch ttyd servers in tmux
launch_agents() {
    local task_file="${1:-}"
    local claude_worktree=$(cat "$PEER_SYNC/claude_worktree_path")
    local codex_worktree=$(cat "$PEER_SYNC/codex_worktree_path")

    log_info "Launching agents in tmux session 'agent-duo'..."

    # Kill existing session if present
    tmux kill-session -t agent-duo 2>/dev/null || true

    # Create new tmux session with orchestrator
    tmux new-session -d -s agent-duo -n orchestrator

    # Create panes for agents
    tmux new-window -t agent-duo -n claude
    tmux new-window -t agent-duo -n codex

    # Start ttyd for Claude agent
    tmux send-keys -t agent-duo:claude "cd '$claude_worktree' && ttyd -p $TTYD_PORT_CLAUDE -W bash" Enter

    # Start ttyd for Codex agent
    tmux send-keys -t agent-duo:codex "cd '$codex_worktree' && ttyd -p $TTYD_PORT_CODEX -W bash" Enter

    log_info "ttyd servers starting..."
    log_info "  Claude: http://localhost:$TTYD_PORT_CLAUDE"
    log_info "  Codex:  http://localhost:$TTYD_PORT_CODEX"

    # Start orchestrator in the first window
    tmux send-keys -t agent-duo:orchestrator "cd '$PROJECT_ROOT' && ./orchestrate.sh" Enter

    # Attach to tmux session
    log_info "Attaching to tmux session. Use Ctrl-B D to detach."
    tmux attach-session -t agent-duo
}

# Main
main() {
    log_info "=== Agent Duo Startup ==="

    check_prerequisites
    setup_worktrees
    init_peer_sync "$@"
    launch_agents "$@"
}

main "$@"
