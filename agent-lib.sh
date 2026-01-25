#!/bin/bash
# agent-lib.sh - Shared library for agent-duo and agent-solo
#
# This file contains common functions used by both agent coordination modes.
# Source this file from agent-duo or agent-solo scripts.

#------------------------------------------------------------------------------
# Colors for output
#------------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#------------------------------------------------------------------------------
# Output helpers
#------------------------------------------------------------------------------

die() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

#------------------------------------------------------------------------------
# Project/session discovery
#------------------------------------------------------------------------------

# Get project root (where .peer-sync is)
get_project_root() {
    if [ -n "$PEER_SYNC" ]; then
        dirname "$PEER_SYNC"
    elif [ -d ".peer-sync" ]; then
        pwd
    else
        # Look for .peer-sync in parent directories
        local dir="$PWD"
        while [ "$dir" != "/" ]; do
            if [ -d "$dir/.peer-sync" ]; then
                echo "$dir"
                return
            fi
            dir="$(dirname "$dir")"
        done
        die "Not in an agent session (no .peer-sync found)"
    fi
}

# Get feature name from session
get_feature() {
    local root
    root="$(get_project_root)"
    if [ -f "$root/.peer-sync/feature" ]; then
        cat "$root/.peer-sync/feature"
    else
        die "No active session (missing .peer-sync/feature)"
    fi
}

# Get session mode (duo or solo)
get_mode() {
    local root
    root="$(get_project_root)"
    if [ -f "$root/.peer-sync/mode" ]; then
        cat "$root/.peer-sync/mode"
    else
        echo "duo"  # Default to duo for backwards compatibility
    fi
}

# Find task file for a feature
# Searches in order: <feature>.md, doc/<feature>.md, docs/<feature>.md, **/<feature>.md
find_task_file() {
    local project_root="$1"
    local feature="$2"

    # Check standard locations first
    for path in "$project_root/$feature.md" \
                "$project_root/doc/$feature.md" \
                "$project_root/docs/$feature.md"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    # Fall back to searching anywhere in the project
    local found
    found="$(find "$project_root" -name "$feature.md" -type f 2>/dev/null | head -1)"
    if [ -n "$found" ]; then
        echo "$found"
        return 0
    fi

    return 1
}

#------------------------------------------------------------------------------
# Atomic file operations
#------------------------------------------------------------------------------

# Atomic file write with locking
atomic_write() {
    local file="$1"
    local content="$2"
    local lockdir
    lockdir="$(dirname "$file")/.lock"

    # Acquire lock
    while ! mkdir "$lockdir" 2>/dev/null; do
        sleep 0.05
    done

    # Write file
    echo "$content" > "$file"

    # Release lock
    rmdir "$lockdir"
}

#------------------------------------------------------------------------------
# Agent commands
#------------------------------------------------------------------------------

# Default thinking effort for Codex (low, medium, high)
DEFAULT_CODEX_THINKING="high"

# Commands to launch each agent
CLAUDE_CMD="claude --dangerously-skip-permissions"
# CODEX_CMD is built dynamically with thinking effort via get_agent_cmd()

# Get agent command
# Usage: get_agent_cmd <agent> [thinking_effort]
# thinking_effort is only used for codex (low, medium, high)
get_agent_cmd() {
    local agent="$1"
    local thinking="${2:-$DEFAULT_CODEX_THINKING}"
    case "$agent" in
        claude) echo "$CLAUDE_CMD" ;;
        codex) echo "codex --yolo -c model_reasoning_effort=\"$thinking\"" ;;
        *) echo "$agent" ;;  # Allow custom agents
    esac
}

#------------------------------------------------------------------------------
# Port management
#------------------------------------------------------------------------------

# Default base port for ttyd (actual ports allocated dynamically)
DEFAULT_BASE_PORT=7680

# Check if a port is available
is_port_available() {
    local port="$1"
    ! nc -z localhost "$port" 2>/dev/null
}

# Check if a port is in use (opposite of is_port_available)
is_port_in_use() {
    local port="$1"
    nc -z localhost "$port" 2>/dev/null
}

# Find next available port starting from base
find_available_port() {
    local base="$1"
    local port="$base"
    local max_attempts=100
    local attempt=0

    while [ "$attempt" -lt "$max_attempts" ]; do
        if is_port_available "$port"; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
        attempt=$((attempt + 1))
    done

    return 1
}

# Get allocated ports from .peer-sync/ports
get_ports() {
    local peer_sync="$1"
    local ports_file="$peer_sync/ports"

    if [ -f "$ports_file" ]; then
        # shellcheck source=/dev/null
        source "$ports_file"
    else
        die "Ports not allocated. Run start command first."
    fi
}

#------------------------------------------------------------------------------
# tmux/ttyd helpers
#------------------------------------------------------------------------------

# Check if a tmux session exists
tmux_session_exists() {
    local session="$1"
    tmux has-session -t "$session" 2>/dev/null
}

# Check if a ttyd process is running and serving a specific tmux session
ttyd_is_running() {
    local pidfile="$1"
    if [ -f "$pidfile" ]; then
        local pid
        pid="$(cat "$pidfile")"
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check if an agent TUI is running in the tmux session
# by checking if there's an active process beyond just the shell
agent_tui_is_running() {
    local session="$1"
    local agent="$2"

    # Capture the pane's current command
    local pane_cmd
    pane_cmd="$(tmux display-message -t "$session" -p '#{pane_current_command}' 2>/dev/null)" || return 1

    # The TUI is running if it's not just bash/zsh
    case "$pane_cmd" in
        bash|zsh|sh|-bash|-zsh|-sh) return 1 ;;
        *) return 0 ;;
    esac
}

# Restart ttyd for a specific session
# Returns 0 on success, 1 on failure
restart_ttyd_for_session() {
    local name="$1"        # e.g., "orchestrator", "claude", "codex"
    local port="$2"
    local tmux_session="$3"
    local pidfile="$4"

    # Check if port is already in use by something else
    if is_port_in_use "$port"; then
        # Check if it's our ttyd process
        if ttyd_is_running "$pidfile"; then
            info "$name ttyd already running on port $port"
            return 0
        else
            # Port occupied by something else
            warn "Port $port is occupied but not by our ttyd process"
            return 1
        fi
    fi

    # Check if tmux session exists
    if ! tmux_session_exists "$tmux_session"; then
        warn "tmux session $tmux_session does not exist - cannot start ttyd"
        return 1
    fi

    # Start ttyd
    info "Starting ttyd for $name on port $port..."
    ttyd -p "$port" -W tmux attach -t "$tmux_session" &
    echo $! > "$pidfile"
    sleep 0.5

    # Verify it started
    if ttyd_is_running "$pidfile"; then
        success "Started ttyd for $name on port $port"
        return 0
    else
        warn "Failed to start ttyd for $name"
        return 1
    fi
}

# Restart an agent TUI in its tmux session (duo mode)
# Usage: restart_agent_tui <agent> <session> <worktree> <peer_sync> <peer_worktree> <feature> [thinking_effort]
restart_agent_tui() {
    local agent="$1"
    local session="$2"
    local worktree="$3"
    local peer_sync="$4"
    local peer_worktree="$5"
    local feature="$6"
    local thinking="${7:-$DEFAULT_CODEX_THINKING}"

    # Check if tmux session exists
    if ! tmux_session_exists "$session"; then
        warn "tmux session $session does not exist"
        return 1
    fi

    # Check if TUI is already running
    if agent_tui_is_running "$session" "$agent"; then
        info "$agent TUI already running"
        return 0
    fi

    info "Starting $agent TUI..."

    # Re-export environment variables (in case session was recreated)
    local peer_name
    case "$agent" in
        claude) peer_name="codex" ;;
        codex) peer_name="claude" ;;
        *) peer_name="unknown" ;;
    esac

    for var in "PEER_SYNC='$peer_sync'" "MY_NAME='$agent'" "PEER_NAME='$peer_name'" "PEER_WORKTREE='$peer_worktree'" "FEATURE='$feature'"; do
        tmux send-keys -t "$session" "export $var"
        tmux send-keys -t "$session" C-m
    done

    # Start the agent CLI
    local agent_cmd
    agent_cmd="$(get_agent_cmd "$agent" "$thinking")"
    tmux send-keys -t "$session" "$agent_cmd"
    tmux send-keys -t "$session" C-m

    sleep 2

    # Verify it started
    if agent_tui_is_running "$session" "$agent"; then
        success "Started $agent TUI"
        return 0
    else
        warn "Failed to start $agent TUI (may still be initializing)"
        return 0  # Don't treat as failure - CLI may take time to start
    fi
}

#------------------------------------------------------------------------------
# Status protocol
#------------------------------------------------------------------------------

# Default timeouts in seconds
DEFAULT_WORK_TIMEOUT=600    # 10 minutes
DEFAULT_REVIEW_TIMEOUT=300  # 5 minutes
DEFAULT_CLARIFY_TIMEOUT=300 # 5 minutes
DEFAULT_POLL_INTERVAL=10    # Check every 10 seconds

# Get agent status (just the status part, not timestamp/message)
get_agent_status() {
    local agent="$1"
    local peer_sync="$2"
    local status_file="$peer_sync/${agent}.status"

    if [ -f "$status_file" ]; then
        cut -d'|' -f1 < "$status_file"
    else
        echo "unknown"
    fi
}

# Check if agent has created a PR (from .pr file or by detecting on GitHub)
has_pr() {
    local agent="$1"
    local peer_sync="$2"

    # Fast path: check for .pr file first
    if [ -f "$peer_sync/${agent}.pr" ]; then
        return 0
    fi

    # Slow path: check GitHub for PR on agent's branch
    local feature
    feature="$(cat "$peer_sync/feature" 2>/dev/null)" || return 1

    # Determine branch name based on mode
    local mode branch
    mode="$(cat "$peer_sync/mode" 2>/dev/null)" || mode="duo"
    if [ "$mode" = "solo" ]; then
        branch="${feature}"  # Solo uses single branch
    else
        branch="${feature}-${agent}"  # Duo uses agent-specific branches
    fi

    # Check if there's an open PR for this branch
    local pr_url
    pr_url="$(gh pr view "$branch" --json url -q '.url' 2>/dev/null)" || return 1

    if [ -n "$pr_url" ]; then
        # Cache the result in the .pr file
        echo "$pr_url" > "$peer_sync/${agent}.pr"
        return 0
    fi

    return 1
}

# Send interrupt to agent via tmux
interrupt_agent() {
    local agent="$1"
    local session="$2"
    local peer_sync="$3"

    info "Interrupting $agent..."

    # Try Escape first (works for many CLI tools)
    tmux send-keys -t "$session" Escape
    sleep 0.5

    # Then Ctrl-C as backup
    tmux send-keys -t "$session" C-c
    sleep 1

    # Update status
    atomic_write "$peer_sync/${agent}.status" "interrupted|$(date +%s)|timed out by orchestrator"
}

# Send a nudge message to agent
nudge_agent() {
    local agent="$1"
    local session="$2"
    local message="$3"

    info "Nudging $agent: $message"
    tmux send-keys -t "$session" "$message"
    tmux send-keys -t "$session" C-m
}

# Trigger a skill for an agent
# Claude: /skill invocation
# Codex: $skill invocation (with double Enter workaround)
trigger_skill() {
    local agent="$1"
    local session="$2"
    local skill="$3"

    case "$agent" in
        claude)
            tmux send-keys -t "$session" -l "/$skill"
            sleep 0.5
            tmux send-keys -t "$session" Enter
            ;;
        codex)
            # Use $skill invocation with double Enter (workaround for input buffering)
            tmux send-keys -t "$session" -l "\$$skill"
            sleep 0.5
            tmux send-keys -t "$session" Enter
            sleep 0.3
            tmux send-keys -t "$session" Enter
            ;;
    esac
}

#------------------------------------------------------------------------------
# Shared commands (signal, peer-status, phase)
#------------------------------------------------------------------------------

# Signal a status change
# Usage: lib_cmd_signal <agent> <status> [message]
lib_cmd_signal() {
    local agent="$1"
    local status="$2"
    local message="${3:-}"

    [ -z "$agent" ] || [ -z "$status" ] && die "Usage: signal <agent> <status> [message]"

    local root
    root="$(get_project_root)"
    local peer_sync="$root/.peer-sync"

    # Validate status
    case "$status" in
        clarifying|clarify-done|working|done|reviewing|review-done|interrupted|error|pr-created) ;;
        *) die "Invalid status: $status (valid: clarifying, clarify-done, working, done, reviewing, review-done, interrupted, error, pr-created)" ;;
    esac

    local content="${status}|$(date +%s)|${message}"
    atomic_write "$peer_sync/${agent}.status" "$content"

    success "$agent status: $status"
}

# Read peer's status
# Usage: lib_cmd_peer_status (uses PEER_NAME env var)
lib_cmd_peer_status() {
    local peer="${PEER_NAME:-}"
    [ -z "$peer" ] && die "PEER_NAME not set. Are you in an agent session?"

    local root
    root="$(get_project_root)"
    local peer_sync="$root/.peer-sync"
    local status_file="$peer_sync/${peer}.status"

    if [ -f "$status_file" ]; then
        cat "$status_file"
    else
        echo "unknown"
    fi
}

# Read current phase
# Usage: lib_cmd_phase
lib_cmd_phase() {
    local root
    root="$(get_project_root)"
    local peer_sync="$root/.peer-sync"

    if [ -f "$peer_sync/phase" ]; then
        cat "$peer_sync/phase"
    else
        echo "unknown"
    fi
}

#------------------------------------------------------------------------------
# Email notifications
#------------------------------------------------------------------------------

# Send email notification with clarify phase results
send_clarify_email() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"  # duo or solo

    # Check if mail command is available
    if ! command -v mail >/dev/null 2>&1; then
        warn "mail command not found - skipping email notification"
        return 1
    fi

    # Get user email from git config
    local email
    email="$(git config user.email 2>/dev/null)"
    if [ -z "$email" ]; then
        warn "No git user.email configured - skipping email notification"
        return 1
    fi

    # Build email content
    local subject="[agent-${mode}] Clarify phase complete: $feature"
    local body=""

    body+="Agent ${mode^} - Clarify Phase Results"
    body+=$'\n'
    body+="=================================="
    body+=$'\n\n'
    body+="Feature: $feature"
    body+=$'\n\n'

    if [ "$mode" = "solo" ]; then
        # Solo mode: coder and reviewer
        if [ -f "$peer_sync/clarify-coder.md" ]; then
            body+="--- CODER'S APPROACH ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/clarify-coder.md")"
            body+=$'\n\n'
        else
            body+="Coder: No clarification submitted"
            body+=$'\n\n'
        fi

        if [ -f "$peer_sync/clarify-reviewer.md" ]; then
            body+="--- REVIEWER'S COMMENTS ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/clarify-reviewer.md")"
            body+=$'\n\n'
        else
            body+="Reviewer: No comments submitted"
            body+=$'\n\n'
        fi
    else
        # Duo mode: claude and codex
        if [ -f "$peer_sync/clarify-claude.md" ]; then
            body+="--- CLAUDE'S APPROACH ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/clarify-claude.md")"
            body+=$'\n\n'
        else
            body+="Claude: No clarification submitted"
            body+=$'\n\n'
        fi

        if [ -f "$peer_sync/clarify-codex.md" ]; then
            body+="--- CODEX'S APPROACH ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/clarify-codex.md")"
            body+=$'\n\n'
        else
            body+="Codex: No clarification submitted"
            body+=$'\n\n'
        fi
    fi

    body+="=================================="
    body+=$'\n\n'
    body+="Next steps:"
    body+=$'\n'
    body+="1. Review the approaches above"
    body+=$'\n'
    body+="2. Respond to each agent in their terminals (if needed)"
    body+=$'\n'
    body+="3. Run 'agent-${mode} confirm' to proceed to work phase"
    body+=$'\n'

    # Send email
    echo "$body" | mail -s "$subject" "$email" 2>/dev/null

    if [ $? -eq 0 ]; then
        success "Email sent to $email"
        return 0
    else
        warn "Failed to send email"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Skill installation helper
#------------------------------------------------------------------------------

# Install a skill from template with agent-specific replacements
install_skill() {
    local template="$1"
    local dest="$2"
    local skill_cmd="$3"  # e.g., "/duo-work" for Claude, "$duo-work" for Codex

    if [ -f "$template" ]; then
        # Replace {{SKILL_CMD}} placeholder with agent-specific command prefix
        sed "s|{{SKILL_CMD}}|${skill_cmd}|g" "$template" > "$dest"
    fi
}
