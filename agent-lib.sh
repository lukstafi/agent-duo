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

# Default models (can be overridden via config or environment)
DEFAULT_CODEX_MODEL=""  # Empty means use Codex's default
DEFAULT_CLAUDE_MODEL="" # Empty means use Claude's default

# Commands to launch each agent
# CLAUDE_CMD and CODEX_CMD are built dynamically via get_agent_cmd()

# Configuration file path (same as notifications config)
AGENT_DUO_CONFIG="${AGENT_DUO_CONFIG:-$HOME/.config/agent-duo/config}"

# Get Codex model from config or environment
# Returns empty string if not configured (uses Codex's default)
get_codex_model() {
    if [ -n "$AGENT_DUO_CODEX_MODEL" ]; then
        echo "$AGENT_DUO_CODEX_MODEL"
        return 0
    fi

    if [ -f "$AGENT_DUO_CONFIG" ]; then
        local model
        model="$(grep -E '^codex_model=' "$AGENT_DUO_CONFIG" 2>/dev/null | cut -d= -f2-)"
        if [ -n "$model" ]; then
            echo "$model"
            return 0
        fi
    fi

    echo "$DEFAULT_CODEX_MODEL"
}

# Get Claude model from config or environment
# Returns empty string if not configured (uses Claude's default)
get_claude_model() {
    if [ -n "$AGENT_DUO_CLAUDE_MODEL" ]; then
        echo "$AGENT_DUO_CLAUDE_MODEL"
        return 0
    fi

    if [ -f "$AGENT_DUO_CONFIG" ]; then
        local model
        model="$(grep -E '^claude_model=' "$AGENT_DUO_CONFIG" 2>/dev/null | cut -d= -f2-)"
        if [ -n "$model" ]; then
            echo "$model"
            return 0
        fi
    fi

    echo "$DEFAULT_CLAUDE_MODEL"
}

# Get agent command
# Usage: get_agent_cmd <agent> [thinking_effort]
# thinking_effort is only used for codex (low, medium, high)
get_agent_cmd() {
    local agent="$1"
    local thinking="${2:-$DEFAULT_CODEX_THINKING}"
    local codex_model claude_model
    codex_model="$(get_codex_model)"
    claude_model="$(get_claude_model)"

    case "$agent" in
        claude)
            if [ -n "$claude_model" ]; then
                echo "claude --dangerously-skip-permissions --model $claude_model"
            else
                echo "claude --dangerously-skip-permissions"
            fi
            ;;
        codex)
            if [ -n "$codex_model" ]; then
                echo "codex --yolo -m \"$codex_model\" -c model_reasoning_effort=\"$thinking\""
            else
                echo "codex --yolo -c model_reasoning_effort=\"$thinking\""
            fi
            ;;
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

# Find N consecutive available ports starting from base
# Args: base count
# Returns: the first port of the consecutive range (ports are base..base+count-1)
find_consecutive_ports() {
    local base="$1"
    local count="$2"
    local port="$base"
    local max_attempts=100
    local attempt=0

    while [ "$attempt" -lt "$max_attempts" ]; do
        local all_available=true
        for ((i = 0; i < count; i++)); do
            if ! is_port_available "$((port + i))"; then
                all_available=false
                break
            fi
        done

        if [ "$all_available" = true ]; then
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

# Extract Codex resume key from tmux pane buffer
# Returns the resume key if found, empty string otherwise
get_codex_resume_key() {
    local session="$1"

    # Capture recent lines from the tmux pane (last 50 lines should be enough)
    local buffer
    buffer="$(tmux capture-pane -t "$session" -p -S -50 2>/dev/null)" || return 1

    # Look for "codex resume <key>" pattern
    # Codex outputs: "To continue this session, run codex resume <uuid>"
    # UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    local resume_key
    resume_key="$(echo "$buffer" | grep -oE 'codex resume [a-zA-Z0-9-]+' | tail -1 | awk '{print $3}')"

    echo "$resume_key"
}

# Attempt to resume Codex session using the resume key from terminal output
# Returns 0 if resume was attempted, 1 if no resume key found
attempt_codex_resume() {
    local session="$1"
    local peer_sync="$2"

    local resume_key
    resume_key="$(get_codex_resume_key "$session")"

    if [ -z "$resume_key" ]; then
        return 1
    fi

    info "Found Codex resume key: $resume_key"
    info "Attempting to resume Codex session..."

    # Save the resume key for reference
    echo "$resume_key" > "$peer_sync/codex-resume-key"

    # Send the resume command to the tmux session (with --yolo for cross-worktree access)
    tmux send-keys -t "$session" "codex resume --yolo $resume_key"
    tmux send-keys -t "$session" C-m

    # Wait a moment for it to start
    sleep 2

    return 0
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
DEFAULT_WORK_TIMEOUT=1200    # 20 minutes
DEFAULT_REVIEW_TIMEOUT=600   # 10 minutes
DEFAULT_CLARIFY_TIMEOUT=600  # 10 minutes
DEFAULT_PUSHBACK_TIMEOUT=600 # 10 minutes
DEFAULT_POLL_INTERVAL=10     # Check every 10 seconds
DEFAULT_TUI_EXIT_BEHAVIOR="pause"  # What to do on TUI exit: pause, quit, or ignore

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

    # Send Escape to interrupt the current operation
    # Note: We avoid Ctrl-C because it exits Codex when the prompt is empty
    tmux send-keys -t "$session" Escape
    sleep 1

    # Update status
    atomic_write "$peer_sync/${agent}.status" "interrupted|$(date +%s)|timed out by orchestrator"
}

# Check if agent TUI has exited and handle according to behavior setting
# Returns 0 if TUI is running (or was resumed), 1 if TUI exited and not recovered
check_tui_health() {
    local agent="$1"
    local session="$2"
    local peer_sync="$3"
    local behavior="${4:-$DEFAULT_TUI_EXIT_BEHAVIOR}"

    # Check if TUI is still running
    if agent_tui_is_running "$session" "$agent"; then
        return 0  # TUI is running, all good
    fi

    # TUI has exited
    warn "Agent $agent TUI has exited unexpectedly!"

    # For Codex, try to auto-resume using the resume key from terminal output
    if [ "$agent" = "codex" ]; then
        if attempt_codex_resume "$session" "$peer_sync"; then
            # Wait and check if resume worked
            sleep 3
            if agent_tui_is_running "$session" "$agent"; then
                success "Codex session resumed successfully!"
                atomic_write "$peer_sync/${agent}.status" "working|$(date +%s)|resumed from exit"
                return 0
            else
                warn "Codex resume attempted but TUI still not running"
            fi
        else
            warn "No Codex resume key found in terminal output"
        fi
    fi

    # Resume failed or not applicable - fall back to configured behavior
    atomic_write "$peer_sync/${agent}.status" "tui-exited|$(date +%s)|TUI process exited"

    case "$behavior" in
        ignore)
            # Just warn and continue waiting (will eventually timeout)
            warn "Ignoring TUI exit for $agent (--on-tui-exit=ignore)"
            return 0
            ;;
        quit)
            # Exit the orchestrator
            echo ""
            warn "Agent $agent TUI exited. Stopping orchestrator (--on-tui-exit=quit)"
            echo ""
            info "To recover, run: agent-duo restart --auto-run"
            exit 1
            ;;
        pause|*)
            # Default: pause and wait for user intervention
            echo ""
            warn "Agent $agent TUI has exited. Orchestrator paused."
            echo ""

            # Send ntfy notification so user knows intervention is needed
            local feature="${FEATURE:-unknown}"
            local resume_info=""
            if [ "$agent" = "codex" ] && [ -f "$peer_sync/codex-resume-key" ]; then
                resume_info=$'\n'"Resume key: $(cat "$peer_sync/codex-resume-key")"
            fi
            send_ntfy \
                "[agent-duo] $agent TUI exited - intervention needed" \
                "Agent $agent has exited unexpectedly during feature: $feature

Run 'agent-duo restart' to recover.$resume_info" \
                "high" \
                "warning,robot" 2>/dev/null || true

            info "Options to recover:"
            echo "  1. Run 'agent-duo restart' to restart the agent TUI"
            echo "  2. Press Enter to continue waiting (will timeout eventually)"
            echo "  3. Press Ctrl-C to stop the orchestrator"
            if [ -n "$resume_info" ]; then
                echo "  4. Resume key saved: $(cat "$peer_sync/codex-resume-key")"
            fi
            echo ""
            read -r -p "Press Enter to continue or Ctrl-C to stop: " || true
            # After user presses Enter, return and continue polling
            return 0
            ;;
    esac
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
        clarifying|clarify-done|pushing-back|pushback-done|working|done|reviewing|review-done|interrupted|error|pr-created|escalated) ;;
        *) die "Invalid status: $status (valid: clarifying, clarify-done, pushing-back, pushback-done, working, done, reviewing, review-done, interrupted, error, pr-created, escalated)" ;;
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

# Escalate an issue to the user
# Usage: lib_cmd_escalate <reason>
# Reasons: ambiguity, inconsistency, misguided
lib_cmd_escalate() {
    local reason="$1"
    local message="${2:-}"

    [ -z "$reason" ] && die "Usage: escalate <reason> [message]
Reasons:
  ambiguity     - Requirements are unclear, need clarification
  inconsistency - Conflicting requirements or code/docs mismatch
  misguided     - Evidence the task approach is wrong"

    # Validate reason
    case "$reason" in
        ambiguity|inconsistency|misguided) ;;
        *) die "Invalid reason: $reason (valid: ambiguity, inconsistency, misguided)" ;;
    esac

    local agent="${AGENT_NAME:-}"
    [ -z "$agent" ] && die "AGENT_NAME not set. Are you in an agent session?"

    local root
    root="$(get_project_root)"
    local peer_sync="$root/.peer-sync"

    # Write escalation file with details
    local escalation_file="$peer_sync/escalation-${agent}.md"
    {
        echo "# Escalation from $agent"
        echo ""
        echo "**Reason:** $reason"
        echo "**Time:** $(date)"
        echo ""
        if [ -n "$message" ]; then
            echo "## Details"
            echo ""
            echo "$message"
        fi
    } > "$escalation_file"

    # Update agent status to escalated
    local content="escalated|$(date +%s)|$reason: ${message:-no details}"
    atomic_write "$peer_sync/${agent}.status" "$content"

    success "Escalation filed: $reason"
    info "The orchestrator will pause before advancing phases."
    info "Continue your current work - you won't be interrupted."
}

#------------------------------------------------------------------------------
# Notifications (ntfy.sh and email)
#------------------------------------------------------------------------------

# Note: AGENT_DUO_CONFIG is defined earlier in the Agent commands section

# Get ntfy topic from config or environment
get_ntfy_topic() {
    # Check environment variable first
    if [ -n "$AGENT_DUO_NTFY_TOPIC" ]; then
        echo "$AGENT_DUO_NTFY_TOPIC"
        return 0
    fi

    # Check config file
    if [ -f "$AGENT_DUO_CONFIG" ]; then
        local topic
        topic="$(grep -E '^ntfy_topic=' "$AGENT_DUO_CONFIG" 2>/dev/null | cut -d= -f2-)"
        if [ -n "$topic" ]; then
            echo "$topic"
            return 0
        fi
    fi

    return 1
}

# Get ntfy server URL (default: ntfy.sh)
get_ntfy_server() {
    if [ -n "$AGENT_DUO_NTFY_SERVER" ]; then
        echo "$AGENT_DUO_NTFY_SERVER"
        return 0
    fi

    if [ -f "$AGENT_DUO_CONFIG" ]; then
        local server
        server="$(grep -E '^ntfy_server=' "$AGENT_DUO_CONFIG" 2>/dev/null | cut -d= -f2-)"
        if [ -n "$server" ]; then
            echo "$server"
            return 0
        fi
    fi

    echo "https://ntfy.sh"
}

# Get ntfy access token from config or environment
get_ntfy_token() {
    if [ -n "$AGENT_DUO_NTFY_TOKEN" ]; then
        echo "$AGENT_DUO_NTFY_TOKEN"
        return 0
    fi

    if [ -f "$AGENT_DUO_CONFIG" ]; then
        local token
        token="$(grep -E '^ntfy_token=' "$AGENT_DUO_CONFIG" 2>/dev/null | cut -d= -f2-)"
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi

    return 1
}

# Send notification via ntfy.sh
# Usage: send_ntfy <title> <message> [priority] [tags]
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"
    local tags="${4:-}"

    local topic
    topic="$(get_ntfy_topic)" || return 1

    local server
    server="$(get_ntfy_server)"

    local curl_args=(
        -s
        -H "Title: $title"
        -H "Priority: $priority"
        -d "$message"
    )

    if [ -n "$tags" ]; then
        curl_args+=(-H "Tags: $tags")
    fi

    # Add authentication if token is configured
    local token
    if token="$(get_ntfy_token 2>/dev/null)"; then
        curl_args+=(-H "Authorization: Bearer $token")
    fi

    if curl "${curl_args[@]}" "$server/$topic" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Send clarify phase notification via ntfy
send_clarify_ntfy() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    local topic
    topic="$(get_ntfy_topic)" || {
        # ntfy not configured, silently skip
        return 1
    }

    local title="[agent-${mode}] Clarify phase complete: $feature"
    local message=""

    message+="Feature: $feature"
    message+=$'\n\n'

    if [ "$mode" = "solo" ]; then
        if [ -f "$peer_sync/clarify-coder.md" ]; then
            message+="CODER'S APPROACH:"
            message+=$'\n'
            # Truncate for notification (ntfy has limits)
            message+="$(head -20 "$peer_sync/clarify-coder.md")"
            message+=$'\n\n'
        fi
        if [ -f "$peer_sync/clarify-reviewer.md" ]; then
            message+="REVIEWER'S COMMENTS:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/clarify-reviewer.md")"
            message+=$'\n\n'
        fi
    else
        if [ -f "$peer_sync/clarify-claude.md" ]; then
            message+="CLAUDE'S APPROACH:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/clarify-claude.md")"
            message+=$'\n\n'
        fi
        if [ -f "$peer_sync/clarify-codex.md" ]; then
            message+="CODEX'S APPROACH:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/clarify-codex.md")"
            message+=$'\n\n'
        fi
    fi

    message+="Run 'agent-${mode} confirm' to proceed"

    if send_ntfy "$title" "$message" "default" "robot,clipboard"; then
        success "Notification sent via ntfy"
        return 0
    else
        warn "Failed to send ntfy notification"
        return 1
    fi
}

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

    local mode_cap="$(echo "$mode" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    body+="Agent $mode_cap - Clarify Phase Results"
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
        success "Email queued to $email"
        return 0
    else
        warn "Failed to send email"
        return 1
    fi
}

# Send clarify notification via all configured methods
# Tries ntfy first (instant), then email (may not work)
send_clarify_notification() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    local ntfy_ok=false
    local email_ok=false

    # Try ntfy first (more reliable, instant delivery)
    if get_ntfy_topic >/dev/null 2>&1; then
        if send_clarify_ntfy "$peer_sync" "$feature" "$mode"; then
            ntfy_ok=true
        fi
    fi

    # Also try email (as backup or if ntfy not configured)
    if command -v mail >/dev/null 2>&1; then
        if send_clarify_email "$peer_sync" "$feature" "$mode"; then
            email_ok=true
        fi
    fi

    # Return success if at least one method worked
    if [ "$ntfy_ok" = true ] || [ "$email_ok" = true ]; then
        return 0
    else
        warn "No notification sent (configure ntfy or email)"
        return 1
    fi
}

# Check if there are pending escalations
# Returns 0 if escalations exist, 1 otherwise
# Outputs the list of escalation files if any
has_pending_escalations() {
    local peer_sync="$1"
    local found=false

    for f in "$peer_sync"/escalation-*.md; do
        if [ -f "$f" ]; then
            echo "$f"
            found=true
        fi
    done

    [ "$found" = true ]
}

# Send escalation notification via ntfy
# Usage: send_escalation_ntfy <peer_sync> <feature> <mode>
send_escalation_ntfy() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    local topic
    topic="$(get_ntfy_topic)" || {
        return 1
    }

    local title="[agent-${mode}] ESCALATION: $feature"
    local message="One or more agents have escalated issues requiring your attention."
    message+=$'\n\n'

    # Include escalation details
    for f in "$peer_sync"/escalation-*.md; do
        if [ -f "$f" ]; then
            message+="$(head -30 "$f")"
            message+=$'\n\n---\n\n'
        fi
    done

    message+="Run 'agent-${mode} escalate-resolve' to review and resolve."

    if send_ntfy "$title" "$message" "high" "warning,robot"; then
        success "Escalation notification sent via ntfy"
        return 0
    else
        warn "Failed to send escalation notification"
        return 1
    fi
}

# Send escalation notification via all configured methods
send_escalation_notification() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    # Only ntfy for escalations (high priority, needs immediate attention)
    if get_ntfy_topic >/dev/null 2>&1; then
        send_escalation_ntfy "$peer_sync" "$feature" "$mode"
        return $?
    fi

    warn "Escalation notification not sent (configure ntfy for alerts)"
    return 1
}

# Handle pending escalations - blocks until resolved
# Returns 0 when escalations are resolved, 1 if user cancels
handle_escalation_block() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    # Check for pending escalations
    if ! has_pending_escalations "$peer_sync" >/dev/null; then
        return 0  # No escalations, continue
    fi

    echo ""
    warn "=== ESCALATION PENDING ==="
    echo ""

    # Display all escalations
    for f in "$peer_sync"/escalation-*.md; do
        if [ -f "$f" ]; then
            cat "$f"
            echo ""
            echo "---"
            echo ""
        fi
    done

    # Send notification
    send_escalation_notification "$peer_sync" "$feature" "$mode" 2>/dev/null || true

    echo "Options:"
    echo "  1. Resolve escalations (continue with phases)"
    echo "  2. Keep waiting (agents continue current phase)"
    echo "  3. Ctrl-C to stop orchestrator"
    echo ""
    read -r -p "Choice [1/2]: " choice

    case "$choice" in
        1)
            # Remove escalation files
            for f in "$peer_sync"/escalation-*.md; do
                [ -f "$f" ] && rm -f "$f"
            done
            echo "resolved|$(date +%s)" > "$peer_sync/escalation-resolved"
            success "Escalations resolved. Continuing..."
            return 0
            ;;
        2|*)
            info "Escalations remain pending. Will check again before next phase transition."
            return 1
            ;;
    esac
}

# Send notification when a PR is created
# Usage: send_pr_notification <agent> <feature> <pr_url> <mode>
send_pr_notification() {
    local agent="$1"
    local feature="$2"
    local pr_url="$3"
    local mode="${4:-duo}"

    # Only send via ntfy (email would be overkill for this)
    if ! get_ntfy_topic >/dev/null 2>&1; then
        return 0  # Silent skip if ntfy not configured
    fi

    local title="[agent-${mode}] PR created: ${feature}"
    local agent_cap="$(echo "$agent" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    local message="${agent_cap} has created a PR for ${feature}

$pr_url"

    if send_ntfy "$title" "$message" "default" "rocket,link"; then
        return 0
    else
        return 1
    fi
}

# Send pushback stage notification via ntfy
send_pushback_ntfy() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    local topic
    topic="$(get_ntfy_topic)" || {
        return 1
    }

    local title="[agent-${mode}] Pushback stage complete: $feature"
    local message=""

    message+="Feature: $feature"
    message+=$'\n\n'

    if [ "$mode" = "solo" ]; then
        if [ -f "$peer_sync/pushback-reviewer.md" ]; then
            message+="REVIEWER'S PUSHBACK:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/pushback-reviewer.md")"
            message+=$'\n\n'
        fi
    else
        if [ -f "$peer_sync/pushback-claude.md" ]; then
            message+="CLAUDE'S PUSHBACK:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/pushback-claude.md")"
            message+=$'\n\n'
        fi
        if [ -f "$peer_sync/pushback-codex.md" ]; then
            message+="CODEX'S PUSHBACK:"
            message+=$'\n'
            message+="$(head -20 "$peer_sync/pushback-codex.md")"
            message+=$'\n\n'
        fi
    fi

    message+="Choose: reject (Enter), accept claude (c), accept codex (x)"

    if send_ntfy "$title" "$message" "default" "robot,memo"; then
        success "Pushback notification sent via ntfy"
        return 0
    else
        warn "Failed to send ntfy notification"
        return 1
    fi
}

# Send email notification with pushback stage results
send_pushback_email() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    if ! command -v mail >/dev/null 2>&1; then
        warn "mail command not found - skipping email notification"
        return 1
    fi

    local email
    email="$(git config user.email 2>/dev/null)"
    if [ -z "$email" ]; then
        warn "No git user.email configured - skipping email notification"
        return 1
    fi

    local subject="[agent-${mode}] Pushback stage complete: $feature"
    local body=""

    local mode_cap="$(echo "$mode" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    body+="Agent $mode_cap - Pushback Stage Results"
    body+=$'\n'
    body+="=================================="
    body+=$'\n\n'
    body+="Feature: $feature"
    body+=$'\n\n'

    if [ "$mode" = "solo" ]; then
        if [ -f "$peer_sync/pushback-reviewer.md" ]; then
            body+="--- REVIEWER'S PUSHBACK ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/pushback-reviewer.md")"
            body+=$'\n\n'
        else
            body+="Reviewer: No pushback submitted"
            body+=$'\n\n'
        fi
    else
        if [ -f "$peer_sync/pushback-claude.md" ]; then
            body+="--- CLAUDE'S PUSHBACK ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/pushback-claude.md")"
            body+=$'\n\n'
        else
            body+="Claude: No pushback submitted"
            body+=$'\n\n'
        fi

        if [ -f "$peer_sync/pushback-codex.md" ]; then
            body+="--- CODEX'S PUSHBACK ---"
            body+=$'\n\n'
            body+="$(cat "$peer_sync/pushback-codex.md")"
            body+=$'\n\n'
        else
            body+="Codex: No pushback submitted"
            body+=$'\n\n'
        fi
    fi

    body+="=================================="
    body+=$'\n\n'
    body+="In the orchestrator terminal, choose:"
    body+=$'\n'
    body+="  [Enter] - Reject pushbacks, use original task"
    body+=$'\n'
    body+="  [c]     - Accept Claude's pushback"
    body+=$'\n'
    body+="  [x]     - Accept Codex's pushback"
    body+=$'\n'

    echo "$body" | mail -s "$subject" "$email" 2>/dev/null

    if [ $? -eq 0 ]; then
        success "Email queued to $email"
        return 0
    else
        warn "Failed to send email"
        return 1
    fi
}

# Send pushback notification via all configured methods
send_pushback_notification() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    local ntfy_ok=false
    local email_ok=false

    if get_ntfy_topic >/dev/null 2>&1; then
        if send_pushback_ntfy "$peer_sync" "$feature" "$mode"; then
            ntfy_ok=true
        fi
    fi

    if command -v mail >/dev/null 2>&1; then
        if send_pushback_email "$peer_sync" "$feature" "$mode"; then
            email_ok=true
        fi
    fi

    if [ "$ntfy_ok" = true ] || [ "$email_ok" = true ]; then
        return 0
    else
        warn "No pushback notification sent (configure ntfy or email)"
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

#------------------------------------------------------------------------------
# Setup helpers (shared between agent-duo and agent-solo setup commands)
#------------------------------------------------------------------------------

# Install the unified notify hook script
# Usage: install_notify_hook <install_dir>
# Returns the path to the installed script
install_notify_hook() {
    local install_dir="$1"
    local notify_script="$install_dir/agent-duo-and-solo-notify"

    cat > "$notify_script" << 'NOTIFY_EOF'
#!/bin/bash
# Unified notify hook for both agent-duo and agent-solo modes
# Called by agent hooks when they complete a turn
# Signals the appropriate status based on current phase and mode
# Usage: agent-duo-and-solo-notify <agent-type>
#   Agent type (claude or codex) is required as $1
#   PEER_SYNC is discovered from $PWD/.peer-sync symlink

agent_type="$1"
[ -z "$agent_type" ] && exit 0

# Debug logging (writes to .peer-sync/notify.log if PEER_SYNC found)
log_debug() {
    [ -d "$PEER_SYNC" ] && echo "$(date '+%H:%M:%S') [$agent_type] $*" >> "$PEER_SYNC/notify.log"
}

# Discover PEER_SYNC from working directory (worktrees have .peer-sync symlink)
if [ -z "$PEER_SYNC" ]; then
    if [ -d "$PWD/.peer-sync" ]; then
        PEER_SYNC="$PWD/.peer-sync"
    else
        # Try parent directory (in case we're in a subdirectory)
        parent="$PWD"
        while [ "$parent" != "/" ]; do
            if [ -d "$parent/.peer-sync" ]; then
                PEER_SYNC="$parent/.peer-sync"
                break
            fi
            parent="$(dirname "$parent")"
        done
        [ -z "$PEER_SYNC" ] && exit 0
    fi
fi
[ ! -d "$PEER_SYNC" ] && exit 0

log_debug "hook fired, PWD=$PWD"

# Check mode (duo or solo)
mode="$(cat "$PEER_SYNC/mode" 2>/dev/null)" || mode="duo"
log_debug "mode=$mode"

# Determine agent name based on mode
if [ "$mode" = "solo" ]; then
    # Solo mode: look up which role this agent type is playing
    coder_agent="$(cat "$PEER_SYNC/coder-agent" 2>/dev/null)"
    reviewer_agent="$(cat "$PEER_SYNC/reviewer-agent" 2>/dev/null)"

    if [ "$agent_type" = "$coder_agent" ]; then
        agent="coder"
    elif [ "$agent_type" = "$reviewer_agent" ]; then
        agent="reviewer"
    else
        log_debug "agent type $agent_type doesn't match coder ($coder_agent) or reviewer ($reviewer_agent)"
        exit 0
    fi
    signal_cmd="agent-solo"
else
    # Duo mode: agent type is the agent name (claude or codex)
    agent="$agent_type"
    signal_cmd="agent-duo"
fi

log_debug "resolved agent=$agent, signal_cmd=$signal_cmd"

# Read current phase
phase="$(cat "$PEER_SYNC/phase" 2>/dev/null)" || { log_debug "no phase file"; exit 0; }

# Read current status
current_status="$(cut -d'|' -f1 < "$PEER_SYNC/${agent}.status" 2>/dev/null)"
log_debug "phase=$phase status=$current_status"

# Determine what status to signal based on phase
case "$phase" in
    clarify)
        # Don't override if already clarify-done or beyond
        case "$current_status" in
            clarify-done|pushback-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        log_debug "signaling clarify-done"
        $signal_cmd signal "$agent" clarify-done "completed via hook"
        ;;
    pushback)
        # Don't override if already pushback-done or beyond
        case "$current_status" in
            pushback-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only reviewer pushes back
        if [ "$mode" = "solo" ] && [ "$agent" != "reviewer" ]; then
            log_debug "skipping (not reviewer in pushback phase)"
            exit 0
        fi
        log_debug "signaling pushback-done"
        $signal_cmd signal "$agent" pushback-done "completed via hook"
        ;;
    work)
        # Don't override if already done or beyond
        case "$current_status" in
            done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only coder works in work phase
        if [ "$mode" = "solo" ] && [ "$agent" != "coder" ]; then
            log_debug "skipping (not coder in work phase)"
            exit 0
        fi
        log_debug "signaling done"
        $signal_cmd signal "$agent" done "completed via hook"
        ;;
    review)
        # Don't override if already review-done or beyond
        case "$current_status" in
            review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only reviewer works in review phase
        if [ "$mode" = "solo" ] && [ "$agent" != "reviewer" ]; then
            log_debug "skipping (not reviewer in review phase)"
            exit 0
        fi
        log_debug "signaling review-done"
        $signal_cmd signal "$agent" review-done "completed via hook"
        ;;
    *)
        log_debug "unknown phase: $phase"
        ;;
esac
NOTIFY_EOF
    chmod +x "$notify_script"
    echo "$notify_script"
}

# Configure Codex notify hook in ~/.codex/config.toml
# IMPORTANT: notify must be at top level in TOML, not inside a [section]
# Usage: configure_codex_notify <notify_script_path>
configure_codex_notify() {
    local notify_script="$1"
    local codex_config="$HOME/.codex/config.toml"
    local notify_line="notify = [\"$notify_script\", \"codex\"]"

    if [ -f "$codex_config" ]; then
        if grep -q "^notify" "$codex_config"; then
            warn "Codex config already has 'notify' setting - not overwriting"
            warn "To enable auto-signaling, set: $notify_line"
        else
            # Insert at top level (before first [section] or at start of file)
            local tmp_config
            tmp_config="$(mktemp)"
            if grep -q '^\[' "$codex_config"; then
                # Insert before first section header
                awk -v notify="$notify_line" '
                    /^\[/ && !inserted {
                        print "# Unified notify hook for agent-duo and agent-solo"
                        print notify
                        print ""
                        inserted=1
                    }
                    { print }
                ' "$codex_config" > "$tmp_config"
                mv "$tmp_config" "$codex_config"
            else
                # No sections, safe to append
                echo "" >> "$codex_config"
                echo "# Unified notify hook for agent-duo and agent-solo" >> "$codex_config"
                echo "$notify_line" >> "$codex_config"
            fi
            success "Added notify hook to Codex config"
        fi
    else
        mkdir -p "$(dirname "$codex_config")"
        echo "# Unified notify hook for agent-duo and agent-solo" > "$codex_config"
        echo "$notify_line" >> "$codex_config"
        success "Created Codex config with notify hook"
    fi
}

# Configure Claude Stop hook in ~/.claude/settings.json
# Usage: configure_claude_notify <notify_script_path>
configure_claude_notify() {
    local notify_script="$1"
    local claude_settings="$HOME/.claude/settings.json"
    local hook_config="{\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"$notify_script claude\"}]}]}"

    if [ -f "$claude_settings" ]; then
        # Check if hooks already configured
        if grep -q '"hooks"' "$claude_settings"; then
            warn "Claude settings already has 'hooks' - not overwriting"
            warn "To enable auto-signaling, add Stop hook: $notify_script claude"
        else
            # Add hooks to existing settings using jq
            local tmp_settings
            tmp_settings="$(mktemp)"
            if command -v jq >/dev/null 2>&1; then
                jq --arg cmd "$notify_script claude" '.hooks = {"Stop":[{"hooks":[{"type":"command","command":$cmd}]}]}' "$claude_settings" > "$tmp_settings"
                mv "$tmp_settings" "$claude_settings"
                success "Added Stop hook to Claude settings"
            else
                warn "jq not found - please manually add hooks to $claude_settings:"
                echo "  \"hooks\": $hook_config"
            fi
        fi
    else
        mkdir -p "$(dirname "$claude_settings")"
        echo "{\"hooks\":$hook_config}" > "$claude_settings"
        success "Created Claude settings with Stop hook"
    fi
}
