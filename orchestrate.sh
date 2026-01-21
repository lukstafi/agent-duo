#!/usr/bin/env bash
# orchestrate.sh - Coordinate turn-based work between Claude and Codex agents
# This script runs in the main project directory and manages the work/review cycle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PEER_SYNC="$SCRIPT_DIR/.peer-sync"

# Configuration
MAX_TURNS=3
WORK_TIMEOUT=600      # 10 minutes per work phase
REVIEW_TIMEOUT=300    # 5 minutes per review phase
POLL_INTERVAL=5       # Check every 5 seconds

# Agent states
STATE_INITIALIZING="INITIALIZING"
STATE_WORKING="WORKING"
STATE_READY_FOR_REVIEW="READY_FOR_REVIEW"
STATE_REVIEWING="REVIEWING"
STATE_DONE="DONE"
STATE_ERROR="ERROR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[ORCH]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[ORCH]${NC} $1"; }
log_error() { echo -e "${RED}[ORCH]${NC} $1"; }
log_phase() { echo -e "${CYAN}[ORCH]${NC} ========== $1 =========="; }

# Read agent state
get_state() {
    local agent="$1"
    local state_file="$PEER_SYNC/${agent}.state"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "UNKNOWN"
    fi
}

# Set agent state
set_state() {
    local agent="$1"
    local state="$2"
    echo "$state" > "$PEER_SYNC/${agent}.state"
    log_info "$agent state -> $state"
}

# Get current turn
get_turn() {
    cat "$PEER_SYNC/turn" 2>/dev/null || echo "0"
}

# Increment turn
next_turn() {
    local current=$(get_turn)
    echo $((current + 1)) > "$PEER_SYNC/turn"
}

# Wait for both agents to reach a state
wait_for_state() {
    local target_state="$1"
    local timeout="${2:-$WORK_TIMEOUT}"
    local start_time=$(date +%s)

    log_info "Waiting for both agents to reach state: $target_state (timeout: ${timeout}s)"

    while true; do
        local claude_state=$(get_state "claude")
        local codex_state=$(get_state "codex")

        # Check for error states
        if [[ "$claude_state" == "$STATE_ERROR" ]] || [[ "$codex_state" == "$STATE_ERROR" ]]; then
            log_error "Agent error detected! Claude: $claude_state, Codex: $codex_state"
            return 1
        fi

        # Check if both reached target state
        if [[ "$claude_state" == "$target_state" ]] && [[ "$codex_state" == "$target_state" ]]; then
            log_info "Both agents reached $target_state"
            return 0
        fi

        # Check timeout
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -ge $timeout ]]; then
            log_warn "Timeout waiting for state $target_state"
            log_warn "  Claude: $claude_state"
            log_warn "  Codex:  $codex_state"
            return 2  # Timeout return code
        fi

        # Progress indicator
        printf "\r${BLUE}[ORCH]${NC} Claude: %-20s Codex: %-20s [%ds]" "$claude_state" "$codex_state" "$elapsed"
        sleep "$POLL_INTERVAL"
    done
}

# Generate diff for review
generate_review_diff() {
    local source_agent="$1"
    local worktree_path_file="$PEER_SYNC/${source_agent}_worktree_path"

    if [[ ! -f "$worktree_path_file" ]]; then
        log_error "Cannot find worktree path for $source_agent"
        return 1
    fi

    local worktree=$(cat "$worktree_path_file")
    local diff_file="$PEER_SYNC/${source_agent}.diff"
    local files_file="$PEER_SYNC/${source_agent}.files"

    cd "$worktree"

    # Capture staged and unstaged changes
    {
        echo "=== Changes by $source_agent (Turn $(get_turn)) ==="
        echo ""
        echo "--- Staged changes ---"
        git diff --cached 2>/dev/null || echo "(no staged changes)"
        echo ""
        echo "--- Unstaged changes ---"
        git diff 2>/dev/null || echo "(no unstaged changes)"
        echo ""
        echo "--- Untracked files ---"
        git ls-files --others --exclude-standard 2>/dev/null || echo "(none)"
    } > "$diff_file"

    # List changed files
    {
        git diff --cached --name-only 2>/dev/null
        git diff --name-only 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null
    } | sort -u > "$files_file"

    log_info "Generated diff for $source_agent: $diff_file"
    cd "$SCRIPT_DIR"
}

# Signal agents to start work phase
start_work_phase() {
    local turn=$(get_turn)
    log_phase "WORK PHASE - Turn $turn"

    # Write phase info
    echo "WORK" > "$PEER_SYNC/current_phase"
    date +%s > "$PEER_SYNC/phase_start"

    # Signal agents
    set_state "claude" "$STATE_WORKING"
    set_state "codex" "$STATE_WORKING"

    log_info "Agents signaled to start working (Turn $turn)"
}

# Signal agents to start review phase
start_review_phase() {
    log_phase "REVIEW PHASE - Turn $(get_turn)"

    # Generate diffs for both agents to review
    generate_review_diff "claude"
    generate_review_diff "codex"

    echo "REVIEW" > "$PEER_SYNC/current_phase"
    date +%s > "$PEER_SYNC/phase_start"

    # Signal agents
    set_state "claude" "$STATE_REVIEWING"
    set_state "codex" "$STATE_REVIEWING"

    log_info "Agents signaled to start reviewing"
}

# Create final PRs
create_prs() {
    log_phase "CREATING PULL REQUESTS"

    local claude_worktree=$(cat "$PEER_SYNC/claude_worktree_path")
    local codex_worktree=$(cat "$PEER_SYNC/codex_worktree_path")
    local task_title="Agent Duo Implementation"

    if [[ -f "$PEER_SYNC/task.md" ]]; then
        task_title=$(head -1 "$PEER_SYNC/task.md" | sed 's/^#* *//')
    fi

    # Create Claude's PR
    log_info "Creating Claude's PR..."
    cd "$claude_worktree"
    if [[ -n "$(git status --porcelain)" ]]; then
        git add -A
        git commit -m "Claude's implementation: $task_title

Co-Authored-By: Claude <noreply@anthropic.com>"
    fi
    git push -u origin claude-work 2>/dev/null || true

    if command -v gh >/dev/null 2>&1; then
        gh pr create --title "[Claude] $task_title" \
            --body "## Claude's Alternative Solution

This PR contains Claude's implementation approach.

### Summary
See commits for detailed changes.

### Peer Reviews
$(cat "$PEER_SYNC/claude_received_reviews.md" 2>/dev/null || echo '(none recorded)')
" --base main 2>/dev/null || log_warn "PR may already exist for claude-work"
    fi

    # Create Codex's PR
    log_info "Creating Codex's PR..."
    cd "$codex_worktree"
    if [[ -n "$(git status --porcelain)" ]]; then
        git add -A
        git commit -m "Codex's implementation: $task_title

Co-Authored-By: Codex <noreply@openai.com>"
    fi
    git push -u origin codex-work 2>/dev/null || true

    if command -v gh >/dev/null 2>&1; then
        gh pr create --title "[Codex] $task_title" \
            --body "## Codex's Alternative Solution

This PR contains Codex's implementation approach.

### Summary
See commits for detailed changes.

### Peer Reviews
$(cat "$PEER_SYNC/codex_received_reviews.md" 2>/dev/null || echo '(none recorded)')
" --base main 2>/dev/null || log_warn "PR may already exist for codex-work"
    fi

    cd "$SCRIPT_DIR"
    log_info "PRs created successfully!"
}

# Main orchestration loop
main() {
    log_phase "AGENT DUO ORCHESTRATOR STARTING"

    if [[ ! -d "$PEER_SYNC" ]]; then
        log_error ".peer-sync directory not found. Run start.sh first."
        exit 1
    fi

    # Wait for agents to initialize
    log_info "Waiting for agents to connect and initialize..."
    log_info "Please start Claude and Codex in their respective terminals"
    log_info "  Claude should run: claude --skill peer-work"
    log_info "  Codex should run:  codex --skill peer-work"

    # Initial work phase
    sleep 5  # Give agents time to start
    start_work_phase

    # Main turn loop
    local turn=0
    while [[ $turn -lt $MAX_TURNS ]]; do
        turn=$((turn + 1))
        echo "$turn" > "$PEER_SYNC/turn"

        log_info "=== Turn $turn of $MAX_TURNS ==="

        # Wait for agents to finish work phase
        if ! wait_for_state "$STATE_READY_FOR_REVIEW" "$WORK_TIMEOUT"; then
            local result=$?
            if [[ $result -eq 2 ]]; then
                log_warn "Work phase timed out, proceeding to review anyway"
            else
                log_error "Error during work phase"
                break
            fi
        fi
        echo ""  # Newline after progress indicator

        # Review phase
        start_review_phase

        if ! wait_for_state "$STATE_READY_FOR_REVIEW" "$REVIEW_TIMEOUT"; then
            local result=$?
            if [[ $result -eq 2 ]]; then
                log_warn "Review phase timed out, proceeding to next turn"
            else
                log_error "Error during review phase"
                break
            fi
        fi
        echo ""

        # Continue to next work phase if not last turn
        if [[ $turn -lt $MAX_TURNS ]]; then
            start_work_phase
        fi
    done

    # Final phase
    set_state "claude" "$STATE_DONE"
    set_state "codex" "$STATE_DONE"

    create_prs

    log_phase "ORCHESTRATION COMPLETE"
    log_info "Review the PRs and choose the best solution!"
}

main "$@"
