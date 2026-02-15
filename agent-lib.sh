#!/usr/bin/env bash
# agent-lib.sh - Shared library for agent-duo and agent-solo
#
# Requires Bash 4.0+ (for associative arrays, regex matching, etc.)
# macOS users: install modern bash via Homebrew: brew install bash
#
# This file contains common functions used by both agent coordination modes.
# Source this file from agent-duo or agent-solo scripts.

#------------------------------------------------------------------------------
# Bash version check
#------------------------------------------------------------------------------

if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash 4.0+ required (found ${BASH_VERSION})" >&2
    echo "macOS users: brew install bash && add /opt/homebrew/bin to PATH" >&2
    exit 1
fi

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
# Reads from .peer-sync/feature in the session's root worktree
get_feature() {
    local root
    root="$(get_project_root)"
    if [ -f "$root/.peer-sync/feature" ]; then
        cat "$root/.peer-sync/feature"
    else
        die "No active session (missing .peer-sync/feature)"
    fi
}

#------------------------------------------------------------------------------
# Multi-session discovery (for parallel task execution)
#------------------------------------------------------------------------------

# Get the main project root (where .agent-sessions registry lives)
# This walks up to find the actual git root (not a worktree)
# Returns: path to main project root
get_main_project_root() {
    local dir="${1:-$PWD}"

    # Walk up to find .git directory (not .git file, which indicates worktree)
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ] && [ ! -f "$dir/.git" ]; then
            # Found actual git repo (not worktree)
            echo "$dir"
            return 0
        elif [ -f "$dir/.git" ]; then
            # This is a worktree - read the gitdir to find main repo
            local gitdir
            gitdir="$(grep '^gitdir:' "$dir/.git" | cut -d' ' -f2-)"
            # gitdir points to .git/worktrees/<name>, go up to find main .git
            local main_git
            main_git="$(cd "$dir" && cd "$gitdir/../.." && pwd)"
            echo "$(dirname "$main_git")"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    die "Not in a git repository"
}

# Registry prefix for session files. Set by each entry point:
#   agent-duo sets SESSION_REGISTRY_PREFIX="duo"
#   agent-solo sets SESSION_REGISTRY_PREFIX="solo"
# When set, session files are named ${prefix}-${feature}.session
SESSION_REGISTRY_PREFIX="${SESSION_REGISTRY_PREFIX:-}"

# List all active sessions from .agent-sessions registry
# Usage: list_active_sessions [main_project_root]
# Output: feature_name:root_worktree_path:state (one per line)
# Respects SESSION_REGISTRY_PREFIX if set (scans only matching prefix)
list_active_sessions() {
    local main_root="${1:-$(get_main_project_root)}"
    local sessions_dir="$main_root/.agent-sessions"

    [ -d "$sessions_dir" ] || return 0

    # Build list of session files to scan.
    # When prefix is set, scan prefixed files first, then unprefixed for backward compat.
    # Quote globs properly to handle paths with spaces.
    local session_files=()
    if [ -n "$SESSION_REGISTRY_PREFIX" ]; then
        for f in "$sessions_dir/${SESSION_REGISTRY_PREFIX}-"*.session; do
            [ -L "$f" ] && session_files+=("$f")
        done
        # Backward compat: also pick up legacy unprefixed symlinks
        for f in "$sessions_dir/"*.session; do
            [ -L "$f" ] || continue
            local base; base="$(basename "$f")"
            # Skip if it has any known prefix (duo-/solo-/claude-/codex-)
            case "$base" in duo-*|solo-*|claude-*|codex-*) continue ;; esac
            session_files+=("$f")
        done
    else
        for f in "$sessions_dir/"*.session; do
            [ -L "$f" ] && session_files+=("$f")
        done
    fi

    for session_link in "${session_files[@]}"; do
        # Extract feature name from filename
        local filename
        filename="$(basename "$session_link")"
        local feature="${filename%.session}"
        # Strip prefix if present
        if [ -n "$SESSION_REGISTRY_PREFIX" ]; then
            feature="${feature#${SESSION_REGISTRY_PREFIX}-}"
        fi

        # Resolve symlink to get root worktree path
        local peer_sync_path
        peer_sync_path="$(readlink "$session_link" 2>/dev/null)" || continue

        # peer_sync_path is absolute path to .peer-sync in root worktree
        local root_worktree
        root_worktree="$(dirname "$peer_sync_path")"

        # Verify session is still active
        if [ -d "$peer_sync_path" ] && [ -f "$peer_sync_path/session" ]; then
            local state
            state="$(cat "$peer_sync_path/session" 2>/dev/null)"
            echo "$feature:$root_worktree:$state"
        fi
    done
}

# Get session root worktree path for a specific feature
# Usage: get_session_root <feature> [main_project_root]
# Returns: path to root worktree for this feature
# Tries prefixed filename first if SESSION_REGISTRY_PREFIX is set,
# then falls back to unprefixed for backward compatibility
get_session_root() {
    local feature="$1"
    local main_root="${2:-$(get_main_project_root)}"
    local sessions_dir="$main_root/.agent-sessions"

    # Try prefixed filename first
    if [ -n "$SESSION_REGISTRY_PREFIX" ]; then
        local prefixed_link="$sessions_dir/${SESSION_REGISTRY_PREFIX}-${feature}.session"
        if [ -L "$prefixed_link" ]; then
            local peer_sync_path
            peer_sync_path="$(readlink "$prefixed_link")"
            if [ -d "$peer_sync_path" ]; then
                dirname "$peer_sync_path"
                return 0
            fi
        fi
    fi

    # Fall back to unprefixed (backward compat with existing sessions)
    local session_link="$sessions_dir/${feature}.session"
    if [ -L "$session_link" ]; then
        local peer_sync_path
        peer_sync_path="$(readlink "$session_link")"
        if [ -d "$peer_sync_path" ]; then
            dirname "$peer_sync_path"
            return 0
        fi
    fi

    return 1
}

# Discover feature name from current working directory
# Works when in an agent worktree or root worktree (uses .peer-sync)
# Returns: feature name
discover_feature_from_cwd() {
    # First check PEER_SYNC environment variable
    if [ -n "$PEER_SYNC" ] && [ -f "$PEER_SYNC/feature" ]; then
        cat "$PEER_SYNC/feature"
        return 0
    fi

    # Check for .peer-sync in current or parent directories
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.peer-sync" ] && [ -f "$dir/.peer-sync/feature" ]; then
            cat "$dir/.peer-sync/feature"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    return 1
}

# Check if we're in the main project root (vs a worktree)
# Returns: 0 if in main project, 1 if in worktree
is_main_project() {
    local dir="${1:-$PWD}"

    # If .git is a directory (not file), we're in main project
    if [ -d "$dir/.git" ] && [ ! -f "$dir/.git" ]; then
        return 0
    fi

    return 1
}

# Resolve session for commands that need it
# Usage: resolve_session [--feature <name>]
# Sets global variables: RESOLVED_FEATURE, RESOLVED_PEER_SYNC, RESOLVED_ROOT
# Returns: 0 on success, dies on error
resolve_session() {
    local feature_arg=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --feature) feature_arg="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # If feature explicitly specified, use it
    if [ -n "$feature_arg" ]; then
        local main_root
        main_root="$(get_main_project_root)"
        RESOLVED_ROOT="$(get_session_root "$feature_arg" "$main_root")" || \
            die "No session found for feature: $feature_arg"
        RESOLVED_FEATURE="$feature_arg"
        RESOLVED_PEER_SYNC="$RESOLVED_ROOT/.peer-sync"
        return 0
    fi

    # Try to discover from current directory
    if RESOLVED_FEATURE="$(discover_feature_from_cwd 2>/dev/null)"; then
        RESOLVED_ROOT="$(get_project_root)"
        RESOLVED_PEER_SYNC="$RESOLVED_ROOT/.peer-sync"
        return 0
    fi

    # Check if we're in main project with sessions
    if is_main_project; then
        local main_root="$PWD"
        local sessions
        sessions="$(list_active_sessions "$main_root")"

        if [ -z "$sessions" ]; then
            die "No active sessions found. Start one with: agent-duo start <feature> or agent-solo start <feature>"
        fi

        # Count sessions
        local count=0
        local single_feature="" single_root=""
        while IFS=: read -r feat root state; do
            [ -z "$feat" ] && continue
            count=$((count + 1))
            single_feature="$feat"
            single_root="$root"
        done <<< "$sessions"

        if [ "$count" -eq 1 ]; then
            # Only one session - use it
            RESOLVED_FEATURE="$single_feature"
            RESOLVED_ROOT="$single_root"
            RESOLVED_PEER_SYNC="$RESOLVED_ROOT/.peer-sync"
            return 0
        fi

        # Multiple sessions - caller needs to handle this
        # Return special code to indicate multiple sessions
        return 2
    fi

    die "Not in an agent session. Use --feature <name> or cd to a session worktree."
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

# Generate a task file from a PR's metadata and comments
# Usage: feature_name=$(generate_followup_task "$project_root" "$pr_number")
generate_followup_task() {
    local project_root="$1"
    local pr_number="$2"

    # Fetch PR metadata via gh
    local pr_json
    pr_json="$(gh pr view "$pr_number" --json title,body,url,headRefName,comments,reviews)" \
        || die "Failed to fetch PR #$pr_number. Is gh installed and authenticated?"

    # Extract fields
    local pr_title pr_url pr_branch pr_body
    pr_title="$(echo "$pr_json" | jq -r '.title')"
    pr_url="$(echo "$pr_json" | jq -r '.url')"
    pr_branch="$(echo "$pr_json" | jq -r '.headRefName')"
    pr_body="$(echo "$pr_json" | jq -r '.body // ""')"

    # Derive feature name: strip agent suffix from branch if present, add -followup
    local feature
    feature="$(echo "$pr_branch" | sed -E 's/-(claude|codex|coder|reviewer)$//')-followup"

    # Build task file content
    local task_file="$project_root/${feature}.md"
    {
        echo "# Follow-up: ${pr_title}"
        echo ""
        echo "This is a follow-up task based on feedback from PR #${pr_number}."
        echo "PR: ${pr_url}"
        echo ""
        echo "## Original PR Description"
        echo ""
        echo "$pr_body"
        echo ""
        echo "## PR Comments and Reviews"
        echo ""
        echo "The comments below (most recent last) describe what needs to be done."
        echo "Focus especially on the last comment(s) for the actionable task."
        echo ""
        # Extract comments chronologically
        echo "$pr_json" | jq -r '.comments[] | "### Comment by \(.author.login) (\(.createdAt))\n\n\(.body)\n"'
        # Extract review comments
        echo "$pr_json" | jq -r '.reviews[] | select(.body != "") | "### Review by \(.author.login) (\(.state), \(.createdAt))\n\n\(.body)\n"'
    } > "$task_file"

    # Return feature name (caller uses it)
    echo "$feature"
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
            # Disable update prompts via -c to avoid interactive prompts in automation
            if [ -n "$codex_model" ]; then
                echo "codex --yolo -m \"$codex_model\" -c model_reasoning_effort=\"$thinking\" -c check_for_update_on_startup=false"
            else
                echo "codex --yolo -c model_reasoning_effort=\"$thinking\" -c check_for_update_on_startup=false"
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

# Set the terminal title for a tmux session (visible in terminal emulators and VS Code)
# Uses set-titles for standard terminals; also sets pane title so the title is
# available via #{pane_title} for status lines and similar.
tmux_set_title() {
    local session="$1" title="$2"
    tmux set-option -t "$session" set-titles on 2>/dev/null || true
    tmux set-option -t "$session" set-titles-string "$title" 2>/dev/null || true
    tmux select-pane -t "$session" -T "$title" 2>/dev/null || true
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
    ttyd -p "$port" -t titleFixed="$name ($tmux_session)" -W tmux attach -t "$tmux_session" &
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

# Restart an agent TUI in its tmux session
# Usage: restart_agent_tui <agent> <session> [thinking_effort] [display_name]
# agent: agent name like "claude" or "codex" (used for get_agent_cmd and agent_tui_is_running)
# session: tmux session name
# thinking_effort: optional, for codex reasoning effort (low/medium/high)
# display_name: optional, for display purposes (e.g., "coder (claude)")
restart_agent_tui() {
    local agent="$1"
    local session="$2"
    local thinking="${3:-$DEFAULT_CODEX_THINKING}"
    local display_name="${4:-$agent}"

    # Check if tmux session exists
    if ! tmux_session_exists "$session"; then
        warn "tmux session $session does not exist"
        return 1
    fi

    # Check if TUI is already running
    if agent_tui_is_running "$session" "$agent"; then
        info "$display_name TUI already running"
        return 0
    fi

    info "Starting $display_name TUI..."

    # Note: Environment variables should already be set by cmd_restart or cmd_start
    # when the tmux session is created. We don't re-export here to avoid duplication.

    # Clear any stale input before sending command
    tmux send-keys -t "$session" C-c
    tmux send-keys -t "$session" C-u
    sleep 0.2

    # Start the agent CLI
    local agent_cmd
    agent_cmd="$(get_agent_cmd "$agent" "$thinking")"
    tmux send-keys -t "$session" -l "$agent_cmd"
    tmux send-keys -t "$session" Enter

    sleep 2

    # Verify it started
    if agent_tui_is_running "$session" "$agent"; then
        success "Started $display_name TUI"
        return 0
    else
        warn "Failed to start $display_name TUI (may still be initializing)"
        return 0  # Don't treat as failure - CLI may take time to start
    fi
}

#------------------------------------------------------------------------------
# Status protocol
#------------------------------------------------------------------------------

# Default timeouts in seconds
DEFAULT_WORK_TIMEOUT=3600    # 1 hour
DEFAULT_REVIEW_TIMEOUT=1800  # 30 minutes
DEFAULT_GATHER_TIMEOUT=600   # 10 minutes
DEFAULT_CLARIFY_TIMEOUT=600  # 10 minutes
DEFAULT_PUSHBACK_TIMEOUT=600 # 10 minutes
DEFAULT_PLAN_TIMEOUT=600     # 10 minutes
DEFAULT_INTEGRATE_TIMEOUT=600 # 10 minutes
DEFAULT_DOCS_UPDATE_TIMEOUT=600 # 10 minutes
DEFAULT_POLL_INTERVAL=10     # Check every 10 seconds
DEFAULT_TUI_EXIT_BEHAVIOR="pause"  # What to do on TUI exit: pause, quit, or ignore
DEFAULT_AUTO_FINISH_TIMEOUT=1800   # 30 minutes (auto-finish mode inactivity timeout)

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

    # Derive worktree from peer_sync path
    # peer_sync is either worktree/.peer-sync or a symlink pointing there
    local worktree
    worktree="$(cd "$peer_sync" && cd .. && pwd)"

    # Check if there's a PR for this branch
    # We verify the PR belongs to the current session by checking:
    # 1. PR's head branch name matches our branch
    # 2. PR was created after our session started (using last-main-commit timestamp as proxy)
    local pr_info pr_url pr_created
    # Run gh pr view from worktree so it can find the repo
    pr_info="$(cd "$worktree" && gh pr view "$branch" --json url,createdAt -q '.url + " " + .createdAt' 2>/dev/null)" || return 1
    pr_url="${pr_info% *}"
    pr_created="${pr_info##* }"

    if [ -z "$pr_url" ]; then
        return 1
    fi

    # Verify this isn't a stale PR from a previous session with the same branch name
    # Check if PR was created after our session started
    local session_time=""
    if [ -f "$peer_sync/last-main-commit" ]; then
        local session_commit
        session_commit="$(cat "$peer_sync/last-main-commit")"
        # Get commit timestamp in ISO format (run from worktree)
        session_time="$(cd "$worktree" && git log -1 --format=%cI "$session_commit" 2>/dev/null)" || session_time=""
    fi
    # Fallback: use the feature file's modification time as session start indicator
    if [ -z "$session_time" ] && [ -f "$peer_sync/feature" ]; then
        # Get file mtime in ISO format (works on macOS and Linux)
        session_time="$(date -r "$peer_sync/feature" +%Y-%m-%dT%H:%M:%S%z 2>/dev/null)" || \
            session_time="$(stat -c %y "$peer_sync/feature" 2>/dev/null | cut -d. -f1 | tr ' ' 'T')" || \
            session_time=""
    fi
    if [ -n "$session_time" ] && [ -n "$pr_created" ]; then
        # Compare timestamps (ISO format sorts correctly)
        if [[ "$pr_created" < "$session_time" ]]; then
            # PR was created before our session started - it's stale
            return 1
        fi
    fi

    # Cache the result in the .pr file
    echo "$pr_url" > "$peer_sync/${agent}.pr"
    # Send notification (low priority since GitHub email is primary)
    send_pr_notification "$agent" "$feature" "$pr_url" "$mode"
    return 0
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
# Note: tmux send-keys can fail if pane is in copy mode (user scrolled).
# We exit copy mode first via send-keys -X cancel, then send normally.
# All tmux commands are guarded with || true to avoid set -e crashes.
trigger_skill() {
    local agent="$1"
    local session="$2"
    local skill="$3"

    # Exit copy mode if active (ignore error if not in a mode)
    tmux send-keys -t "$session" -X cancel 2>/dev/null || true

    case "$agent" in
        claude)
            tmux send-keys -t "$session" -l "/$skill" || true
            sleep 0.5
            tmux send-keys -t "$session" Enter || true
            ;;
        codex)
            # Use $skill invocation with double Enter (workaround for input buffering)
            tmux send-keys -t "$session" -l "\$$skill" || true
            sleep 0.5
            tmux send-keys -t "$session" Enter || true
            sleep 0.3
            tmux send-keys -t "$session" Enter || true
            ;;
    esac
}

#------------------------------------------------------------------------------
# Unified Agent Communication
#------------------------------------------------------------------------------

# Send content to an agent TUI and track for potential retry
# This is the primary function for sending messages/skills to agents
#
# Usage: send_to_agent <agent> <session> <peer_sync> <send_type> <content> [skill_name]
#   agent: "claude", "codex", "coder", or "reviewer"
#   session: tmux session target
#   peer_sync: path to .peer-sync directory
#   send_type: "message" for multi-line content, "skill" for skill invocation
#   content: the message text or skill name (without / or $ prefix)
#   skill_name: (optional) logical name for retry tracking (defaults to content for skills)
#
# For skills: content is the skill name (e.g., "duo-work")
# For messages: content is the full message text
#
# This function:
# 1. Sends the content appropriately based on agent type
# 2. Stores what was sent in .peer-sync for retry purposes
# 3. Clears any previous retry state (fresh send = fresh retry counter)
send_to_agent() {
    local agent="$1"
    local session="$2"
    local peer_sync="$3"
    local send_type="$4"
    local content="$5"
    local skill_name="${6:-$content}"

    # Determine the underlying agent type (claude or codex) for send mechanics
    local agent_type="$agent"
    case "$agent" in
        coder|reviewer)
            # Solo mode - look up which CLI this role uses
            local coder_agent reviewer_agent
            coder_agent="$(cat "$peer_sync/coder-agent" 2>/dev/null)" || coder_agent="claude"
            reviewer_agent="$(cat "$peer_sync/reviewer-agent" 2>/dev/null)" || reviewer_agent="codex"
            [ "$agent" = "coder" ] && agent_type="$coder_agent" || agent_type="$reviewer_agent"
            ;;
    esac

    # Clear any previous retry state for this agent (fresh send)
    rm -f "$peer_sync/${agent}.retry-state"

    # Store what we're sending for retry purposes
    # Format: send_type|skill_name|timestamp
    echo "${send_type}|${skill_name}|$(date +%s)" > "$peer_sync/${agent}.last-send"

    # For message sends, also store the full content (for retry)
    if [ "$send_type" = "message" ]; then
        echo "$content" > "$peer_sync/${agent}.last-message"
    fi

    # Send based on type
    case "$send_type" in
        skill)
            trigger_skill "$agent_type" "$session" "$content"
            ;;
        message)
            # Send message content (exit copy mode first, guard against set -e)
            tmux send-keys -t "$session" -X cancel 2>/dev/null || true
            tmux send-keys -t "$session" "$content" || true
            sleep 0.5
            tmux send-keys -t "$session" C-m || true
            ;;
        *)
            warn "Unknown send_type: $send_type"
            return 1
            ;;
    esac
}

# Retry the last send to an agent (used by check_and_retry_on_error)
# Usage: retry_last_send <agent> <session> <peer_sync>
# Returns: 0 if retried, 1 if nothing to retry
retry_last_send() {
    local agent="$1"
    local session="$2"
    local peer_sync="$3"

    local last_send_file="$peer_sync/${agent}.last-send"
    [ -f "$last_send_file" ] || return 1

    local send_type skill_name timestamp
    IFS='|' read -r send_type skill_name timestamp < "$last_send_file"

    # Determine agent type for send mechanics
    local agent_type="$agent"
    case "$agent" in
        coder|reviewer)
            local coder_agent reviewer_agent
            coder_agent="$(cat "$peer_sync/coder-agent" 2>/dev/null)" || coder_agent="claude"
            reviewer_agent="$(cat "$peer_sync/reviewer-agent" 2>/dev/null)" || reviewer_agent="codex"
            [ "$agent" = "coder" ] && agent_type="$coder_agent" || agent_type="$reviewer_agent"
            ;;
    esac

    case "$send_type" in
        skill)
            info "Retrying skill $skill_name for $agent..."
            trigger_skill "$agent_type" "$session" "$skill_name"
            ;;
        message)
            local last_msg_file="$peer_sync/${agent}.last-message"
            if [ -f "$last_msg_file" ]; then
                info "Retrying message for $agent..."
                local content
                content="$(cat "$last_msg_file")"
                tmux send-keys -t "$session" -X cancel 2>/dev/null || true
                tmux send-keys -t "$session" "$content" || true
                sleep 0.5
                tmux send-keys -t "$session" C-m || true
            else
                warn "No saved message to retry for $agent"
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

#------------------------------------------------------------------------------
# API Error Detection and Retry
#------------------------------------------------------------------------------

# Default retry settings
DEFAULT_API_RETRY_BACKOFF=30      # Initial backoff in seconds
DEFAULT_API_MAX_RETRIES=3         # Maximum retry attempts
DEFAULT_API_BACKOFF_MULTIPLIER=2  # Exponential backoff multiplier

# Check if an agent's tmux pane shows API errors
# Usage: agent_has_api_error <session>
# Returns: 0 if API error detected, 1 otherwise
agent_has_api_error() {
    local session="$1"

    # Capture recent lines from the tmux pane (last 30 lines should catch recent errors)
    local buffer
    buffer="$(tmux capture-pane -t "$session" -p -S -30 2>/dev/null)" || return 1

    # Look for common API error patterns
    # Claude Code shows: "API Error: 500 {...}"
    # Also check for rate limit errors, timeouts, etc.
    if echo "$buffer" | grep -qE 'API Error: (5[0-9]{2}|429)|Internal server error|rate.?limit|timeout.*error'; then
        return 0
    fi

    return 1
}

# Get the timestamp of the last API error from pane (for deduplication)
# Usage: get_api_error_signature <session>
# Returns: A signature string based on error content, or empty if no error
get_api_error_signature() {
    local session="$1"

    local buffer
    buffer="$(tmux capture-pane -t "$session" -p -S -30 2>/dev/null)" || return 1

    # Extract the error line and request_id if present (for deduplication)
    local error_line
    error_line="$(echo "$buffer" | grep -oE 'API Error: [0-9]+.*request_id[^}]+' | tail -1)"

    if [ -n "$error_line" ]; then
        echo "$error_line"
    fi
}

# Check if agent is stuck at prompt after API error (ready for retry)
# Usage: agent_ready_for_retry <session>
# Returns: 0 if at prompt and ready, 1 otherwise
agent_ready_for_retry() {
    local session="$1"

    # Capture last few lines to see if we're at a prompt
    local buffer
    buffer="$(tmux capture-pane -t "$session" -p -S -5 2>/dev/null)" || return 1

    # Look for prompt indicators (❯ for Claude, $ or > for Codex)
    # The prompt should be at the end of the buffer (last non-empty line)
    local last_line
    last_line="$(echo "$buffer" | grep -v '^$' | tail -1)"

    # Check for various prompt patterns
    if echo "$last_line" | grep -qE '^[❯$>]|^[[:space:]]*[❯$>]'; then
        return 0
    fi

    return 1
}

# Check and handle API errors for an agent during wait loop
# Uses the last-send tracking from send_to_agent to know what to retry
# Usage: check_and_retry_on_error <agent> <session> <peer_sync>
# Returns: 0 if no action needed or retry triggered, 1 if max retries exceeded
check_and_retry_on_error() {
    local agent="$1"
    local session="$2"
    local peer_sync="$3"

    # Only check if agent appears stuck (not progressing)
    local status
    status="$(get_agent_status "$agent" "$peer_sync")"

    # If agent is in a terminal state, no need to check for errors
    case "$status" in
        done|review-done|pr-created|clarify-done|gather-done|pushback-done|plan-done|plan-review-done|docs-update-done)
            # Clear any retry state
            rm -f "$peer_sync/${agent}.retry-state"
            rm -f "$peer_sync/${agent}.last-send"
            rm -f "$peer_sync/${agent}.last-message"
            return 0
            ;;
    esac

    # Check for API error and agent ready for retry
    if ! agent_has_api_error "$session" || ! agent_ready_for_retry "$session"; then
        return 0
    fi

    # We have an error and agent is at prompt - check retry state
    local retry_file="$peer_sync/${agent}.retry-state"
    local last_send_file="$peer_sync/${agent}.last-send"

    # Need last-send info to know what to retry
    [ -f "$last_send_file" ] || return 0

    local send_type skill_name send_timestamp
    IFS='|' read -r send_type skill_name send_timestamp < "$last_send_file"

    # Read retry state
    local attempt=1
    local backoff="$DEFAULT_API_RETRY_BACKOFF"
    local last_error_sig=""

    if [ -f "$retry_file" ]; then
        IFS='|' read -r attempt backoff last_error_sig < "$retry_file"
    fi

    # Check if we've exceeded max retries
    if [ "$attempt" -gt "$DEFAULT_API_MAX_RETRIES" ]; then
        warn "Agent $agent: max retries ($DEFAULT_API_MAX_RETRIES) exceeded for $skill_name"
        rm -f "$retry_file"
        return 1
    fi

    # Get current error signature
    local current_error_sig
    current_error_sig="$(get_api_error_signature "$session")"

    # Only retry if this is a different error or we haven't retried this error yet
    if [ "$current_error_sig" = "$last_error_sig" ]; then
        return 0  # Same error, already retried
    fi

    warn "Agent $agent: API error detected, attempt $attempt/$DEFAULT_API_MAX_RETRIES"
    warn "Waiting ${backoff}s before retry..."

    # Send notification about retry
    send_ntfy \
        "[agent-duo] API error - retrying" \
        "Agent $agent hit API error during $skill_name. Retry $attempt/$DEFAULT_API_MAX_RETRIES in ${backoff}s." \
        "default" \
        "warning,repeat" 2>/dev/null || true

    sleep "$backoff"

    # Retry the last send
    retry_last_send "$agent" "$session" "$peer_sync"

    # Update retry state with exponential backoff
    local new_backoff=$((backoff * DEFAULT_API_BACKOFF_MULTIPLIER))
    echo "$((attempt + 1))|$new_backoff|$current_error_sig" > "$retry_file"

    return 0
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
        gathering|gather-done|clarifying|clarify-done|pushing-back|pushback-done|planning|plan-done|plan-reviewing|plan-review-done|needs-clarify|working|done|reviewing|review-done|updating-docs|docs-update-done|integrating|integrate-done|final-merging|final-merge-done|suggest-refactor-done|interrupted|error|pr-created|escalated) ;;
        *) die "Invalid status: $status (valid: gathering, gather-done, clarifying, clarify-done, pushing-back, pushback-done, planning, plan-done, plan-reviewing, plan-review-done, needs-clarify, working, done, reviewing, review-done, updating-docs, docs-update-done, integrating, integrate-done, final-merging, final-merge-done, suggest-refactor-done, interrupted, error, pr-created, escalated)" ;;
    esac

    local content="${status}|$(date +%s)|${message}"
    atomic_write "$peer_sync/${agent}.status" "$content"
    if [ "$status" = "docs-update-done" ]; then
        touch "$peer_sync/docs-update-${agent}.done"
    fi

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

    local mode_cap="${mode^}"  # Bash 4+ capitalize first letter
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
    local agent_cap="${agent^}"  # Bash 4+ capitalize first letter
    local message="${agent_cap} has created a PR for ${feature}

$pr_url"

    if send_ntfy "$title" "$message" "low" "rocket,link"; then
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

    local mode_cap="${mode^}"  # Bash 4+ capitalize first letter
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

# Get the path to skill templates (installed or development)
# Usage: get_templates_dir
# Returns: path to templates directory
get_templates_dir() {
    local install_dir="$HOME/.local/bin"
    local installed_templates="$install_dir/skills/templates"

    # Prefer installed templates
    if [ -d "$installed_templates" ]; then
        echo "$installed_templates"
    else
        die "Skill templates not found. Run 'agent-duo setup' or 'agent-solo setup' first."
    fi
}

# Install duo skills to a worktree for both Claude and Codex
# Usage: install_duo_skills_to_worktree <worktree_path> <templates_dir>
install_duo_skills_to_worktree() {
    local worktree="$1"
    local templates_dir="$2"

    # Install Claude skills
    local claude_skills="$worktree/.claude/commands"
    mkdir -p "$claude_skills"

    install_skill "$templates_dir/duo-work.md" "$claude_skills/duo-work.md" "/duo-work"
    install_skill "$templates_dir/duo-review.md" "$claude_skills/duo-review.md" "/duo-review"
    install_skill "$templates_dir/duo-clarify.md" "$claude_skills/duo-clarify.md" "/duo-clarify"
    install_skill "$templates_dir/duo-pushback.md" "$claude_skills/duo-pushback.md" "/duo-pushback"
    install_skill "$templates_dir/duo-plan.md" "$claude_skills/duo-plan.md" "/duo-plan"
    install_skill "$templates_dir/duo-plan-review.md" "$claude_skills/duo-plan-review.md" "/duo-plan-review"
    install_skill "$templates_dir/duo-amend.md" "$claude_skills/duo-amend.md" "/duo-amend"
    install_skill "$templates_dir/duo-update-docs.md" "$claude_skills/duo-update-docs.md" "/duo-update-docs"
    install_skill "$templates_dir/duo-pr-comment.md" "$claude_skills/duo-pr-comment.md" "/duo-pr-comment"
    install_skill "$templates_dir/duo-merge-vote.md" "$claude_skills/duo-merge-vote.md" "/duo-merge-vote"
    install_skill "$templates_dir/duo-merge-debate.md" "$claude_skills/duo-merge-debate.md" "/duo-merge-debate"
    install_skill "$templates_dir/duo-merge-execute.md" "$claude_skills/duo-merge-execute.md" "/duo-merge-execute"
    install_skill "$templates_dir/duo-merge-review.md" "$claude_skills/duo-merge-review.md" "/duo-merge-review"
    install_skill "$templates_dir/duo-merge-amend.md" "$claude_skills/duo-merge-amend.md" "/duo-merge-amend"
    install_skill "$templates_dir/duo-integrate.md" "$claude_skills/duo-integrate.md" "/duo-integrate"
    install_skill "$templates_dir/duo-final-merge.md" "$claude_skills/duo-final-merge.md" "/duo-final-merge"
    install_skill "$templates_dir/duo-suggest-refactor.md" "$claude_skills/duo-suggest-refactor.md" "/duo-suggest-refactor"

    # Install Codex skills (project-scoped path is .agents/skills/)
    local codex_skills="$worktree/.agents/skills"
    mkdir -p "$codex_skills/duo-work" "$codex_skills/duo-review" "$codex_skills/duo-clarify"
    mkdir -p "$codex_skills/duo-pushback" "$codex_skills/duo-plan" "$codex_skills/duo-plan-review"
    mkdir -p "$codex_skills/duo-amend" "$codex_skills/duo-update-docs" "$codex_skills/duo-pr-comment"
    mkdir -p "$codex_skills/duo-merge-vote" "$codex_skills/duo-merge-debate" "$codex_skills/duo-merge-execute"
    mkdir -p "$codex_skills/duo-merge-review" "$codex_skills/duo-merge-amend"
    mkdir -p "$codex_skills/duo-integrate" "$codex_skills/duo-final-merge"
    mkdir -p "$codex_skills/duo-suggest-refactor"

    install_skill "$templates_dir/duo-work.md" "$codex_skills/duo-work/SKILL.md" "\$duo-work"
    install_skill "$templates_dir/duo-review.md" "$codex_skills/duo-review/SKILL.md" "\$duo-review"
    install_skill "$templates_dir/duo-clarify.md" "$codex_skills/duo-clarify/SKILL.md" "\$duo-clarify"
    install_skill "$templates_dir/duo-pushback.md" "$codex_skills/duo-pushback/SKILL.md" "\$duo-pushback"
    install_skill "$templates_dir/duo-plan.md" "$codex_skills/duo-plan/SKILL.md" "\$duo-plan"
    install_skill "$templates_dir/duo-plan-review.md" "$codex_skills/duo-plan-review/SKILL.md" "\$duo-plan-review"
    install_skill "$templates_dir/duo-amend.md" "$codex_skills/duo-amend/SKILL.md" "\$duo-amend"
    install_skill "$templates_dir/duo-update-docs.md" "$codex_skills/duo-update-docs/SKILL.md" "\$duo-update-docs"
    install_skill "$templates_dir/duo-pr-comment.md" "$codex_skills/duo-pr-comment/SKILL.md" "\$duo-pr-comment"
    install_skill "$templates_dir/duo-merge-vote.md" "$codex_skills/duo-merge-vote/SKILL.md" "\$duo-merge-vote"
    install_skill "$templates_dir/duo-merge-debate.md" "$codex_skills/duo-merge-debate/SKILL.md" "\$duo-merge-debate"
    install_skill "$templates_dir/duo-merge-execute.md" "$codex_skills/duo-merge-execute/SKILL.md" "\$duo-merge-execute"
    install_skill "$templates_dir/duo-merge-review.md" "$codex_skills/duo-merge-review/SKILL.md" "\$duo-merge-review"
    install_skill "$templates_dir/duo-merge-amend.md" "$codex_skills/duo-merge-amend/SKILL.md" "\$duo-merge-amend"
    install_skill "$templates_dir/duo-integrate.md" "$codex_skills/duo-integrate/SKILL.md" "\$duo-integrate"
    install_skill "$templates_dir/duo-final-merge.md" "$codex_skills/duo-final-merge/SKILL.md" "\$duo-final-merge"
    install_skill "$templates_dir/duo-suggest-refactor.md" "$codex_skills/duo-suggest-refactor/SKILL.md" "\$duo-suggest-refactor"
}

# Install solo skills to a worktree for both Claude and Codex
# Usage: install_solo_skills_to_worktree <worktree_path> <templates_dir>
install_solo_skills_to_worktree() {
    local worktree="$1"
    local templates_dir="$2"

    # Install Claude skills
    local claude_skills="$worktree/.claude/commands"
    mkdir -p "$claude_skills"

    install_skill "$templates_dir/solo-coder-work.md" "$claude_skills/solo-coder-work.md" "/solo-coder-work"
    install_skill "$templates_dir/solo-coder-clarify.md" "$claude_skills/solo-coder-clarify.md" "/solo-coder-clarify"
    install_skill "$templates_dir/solo-coder-plan.md" "$claude_skills/solo-coder-plan.md" "/solo-coder-plan"
    install_skill "$templates_dir/solo-reviewer-work.md" "$claude_skills/solo-reviewer-work.md" "/solo-reviewer-work"
    install_skill "$templates_dir/solo-reviewer-clarify.md" "$claude_skills/solo-reviewer-clarify.md" "/solo-reviewer-clarify"
    install_skill "$templates_dir/solo-reviewer-gather.md" "$claude_skills/solo-reviewer-gather.md" "/solo-reviewer-gather"
    install_skill "$templates_dir/solo-reviewer-pushback.md" "$claude_skills/solo-reviewer-pushback.md" "/solo-reviewer-pushback"
    install_skill "$templates_dir/solo-reviewer-plan.md" "$claude_skills/solo-reviewer-plan.md" "/solo-reviewer-plan"
    install_skill "$templates_dir/solo-pr-comment.md" "$claude_skills/solo-pr-comment.md" "/solo-pr-comment"
    install_skill "$templates_dir/solo-integrate.md" "$claude_skills/solo-integrate.md" "/solo-integrate"
    install_skill "$templates_dir/solo-final-merge.md" "$claude_skills/solo-final-merge.md" "/solo-final-merge"
    install_skill "$templates_dir/solo-suggest-refactor.md" "$claude_skills/solo-suggest-refactor.md" "/solo-suggest-refactor"

    # Install Codex skills (project-scoped path is .agents/skills/)
    local codex_skills="$worktree/.agents/skills"
    mkdir -p "$codex_skills/solo-coder-work" "$codex_skills/solo-coder-clarify" "$codex_skills/solo-coder-plan"
    mkdir -p "$codex_skills/solo-reviewer-work" "$codex_skills/solo-reviewer-clarify"
    mkdir -p "$codex_skills/solo-reviewer-gather" "$codex_skills/solo-reviewer-pushback" "$codex_skills/solo-reviewer-plan"
    mkdir -p "$codex_skills/solo-pr-comment" "$codex_skills/solo-integrate" "$codex_skills/solo-final-merge"
    mkdir -p "$codex_skills/solo-suggest-refactor"

    install_skill "$templates_dir/solo-coder-work.md" "$codex_skills/solo-coder-work/SKILL.md" "\$solo-coder-work"
    install_skill "$templates_dir/solo-coder-clarify.md" "$codex_skills/solo-coder-clarify/SKILL.md" "\$solo-coder-clarify"
    install_skill "$templates_dir/solo-coder-plan.md" "$codex_skills/solo-coder-plan/SKILL.md" "\$solo-coder-plan"
    install_skill "$templates_dir/solo-reviewer-work.md" "$codex_skills/solo-reviewer-work/SKILL.md" "\$solo-reviewer-work"
    install_skill "$templates_dir/solo-reviewer-clarify.md" "$codex_skills/solo-reviewer-clarify/SKILL.md" "\$solo-reviewer-clarify"
    install_skill "$templates_dir/solo-reviewer-gather.md" "$codex_skills/solo-reviewer-gather/SKILL.md" "\$solo-reviewer-gather"
    install_skill "$templates_dir/solo-reviewer-pushback.md" "$codex_skills/solo-reviewer-pushback/SKILL.md" "\$solo-reviewer-pushback"
    install_skill "$templates_dir/solo-reviewer-plan.md" "$codex_skills/solo-reviewer-plan/SKILL.md" "\$solo-reviewer-plan"
    install_skill "$templates_dir/solo-pr-comment.md" "$codex_skills/solo-pr-comment/SKILL.md" "\$solo-pr-comment"
    install_skill "$templates_dir/solo-integrate.md" "$codex_skills/solo-integrate/SKILL.md" "\$solo-integrate"
    install_skill "$templates_dir/solo-final-merge.md" "$codex_skills/solo-final-merge/SKILL.md" "\$solo-final-merge"
    install_skill "$templates_dir/solo-suggest-refactor.md" "$codex_skills/solo-suggest-refactor/SKILL.md" "\$solo-suggest-refactor"
}

# List of all duo skill names (for cleanup of legacy global installs)
DUO_SKILLS=(
    "duo-work" "duo-review" "duo-clarify" "duo-pushback"
    "duo-plan" "duo-plan-review" "duo-amend" "duo-update-docs" "duo-pr-comment"
    "duo-merge-vote" "duo-merge-debate" "duo-merge-execute" "duo-merge-review" "duo-merge-amend"
    "duo-integrate" "duo-final-merge" "duo-suggest-refactor"
)

# List of all solo skill names (for cleanup of legacy global installs)
SOLO_SKILLS=(
    "solo-coder-work" "solo-coder-clarify" "solo-coder-plan"
    "solo-reviewer-work" "solo-reviewer-clarify" "solo-reviewer-gather" "solo-reviewer-pushback" "solo-reviewer-plan"
    "solo-pr-comment" "solo-integrate" "solo-final-merge" "solo-suggest-refactor"
)

# Check and warn about legacy global skill installations
# Usage: warn_legacy_global_skills <skill_list_name>
# skill_list_name is either "DUO_SKILLS" or "SOLO_SKILLS"
# Note: Uses case statement instead of nameref for Bash 3.2 compatibility (macOS default)
warn_legacy_global_skills() {
    local skill_list_name="$1"
    local found_claude=()
    local found_codex=()

    local claude_global="$HOME/.claude/commands"
    local codex_global="$HOME/.codex/skills"

    # Select the appropriate skill list (Bash 3.2 compatible - no namerefs)
    local skills=()
    case "$skill_list_name" in
        DUO_SKILLS)
            skills=("${DUO_SKILLS[@]}")
            ;;
        SOLO_SKILLS)
            skills=("${SOLO_SKILLS[@]}")
            ;;
        *)
            warn "Unknown skill list: $skill_list_name"
            return 1
            ;;
    esac

    for skill in "${skills[@]}"; do
        if [ -f "$claude_global/$skill.md" ]; then
            found_claude+=("$skill")
        fi
        if [ -d "$codex_global/$skill" ]; then
            found_codex+=("$skill")
        fi
    done

    if [ ${#found_claude[@]} -gt 0 ] || [ ${#found_codex[@]} -gt 0 ]; then
        echo ""
        warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        warn "LEGACY GLOBAL SKILLS DETECTED"
        warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        warn "Skills are now installed per-session into worktrees, not globally."
        warn "Legacy global skills may appear in all Claude/Codex sessions."
        echo ""
        if [ ${#found_claude[@]} -gt 0 ]; then
            warn "Claude global skills to remove from $claude_global:"
            for skill in "${found_claude[@]}"; do
                echo "  - $skill.md"
            done
        fi
        if [ ${#found_codex[@]} -gt 0 ]; then
            warn "Codex global skills to remove from $codex_global:"
            for skill in "${found_codex[@]}"; do
                echo "  - $skill/"
            done
        fi
        echo ""
        warn "To clean up legacy skills, run:"
        if [ ${#found_claude[@]} -gt 0 ]; then
            for skill in "${found_claude[@]}"; do
                echo "  rm \"$claude_global/$skill.md\""
            done
        fi
        if [ ${#found_codex[@]} -gt 0 ]; then
            for skill in "${found_codex[@]}"; do
                echo "  rm -rf \"$codex_global/$skill\""
            done
        fi
        warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
#!/usr/bin/env bash
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

# Read current status and its epoch
current_status="$(cut -d'|' -f1 < "$PEER_SYNC/${agent}.status" 2>/dev/null)"
status_epoch="$(cut -d'|' -f2 < "$PEER_SYNC/${agent}.status" 2>/dev/null)"
log_debug "phase=$phase status=$current_status epoch=$status_epoch"

# Guard against cross-phase race: if the phase changed since the last hook
# firing, this is likely a stale hook from the previous phase's idle transition
# executing after the orchestrator already advanced to the next phase.
# A stale hook "acknowledges" the new phase (stores it), so the subsequent
# legitimate hook (same phase) can proceed.
last_hook_file="$PEER_SYNC/${agent}.last-hook-phase"
last_hook_phase="$(cat "$last_hook_file" 2>/dev/null)" || last_hook_phase=""
echo "$phase" > "$last_hook_file"
if [ -n "$last_hook_phase" ] && [ "$phase" != "$last_hook_phase" ]; then
    log_debug "phase changed since last hook ($last_hook_phase -> $phase), likely cross-phase race"
    exit 0
fi

# Determine what status to signal based on phase
case "$phase" in
    gather)
        # Don't override if already gather-done or beyond
        case "$current_status" in
            gather-done|clarify-done|pushback-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only reviewer gathers in gather phase
        if [ "$mode" = "solo" ] && [ "$agent" != "reviewer" ]; then
            log_debug "skipping (not reviewer in gather phase)"
            exit 0
        fi
        # Guard: require output file before signaling (cross-phase race protection)
        if [ ! -f "$PEER_SYNC/task-context.md" ]; then
            log_debug "task-context.md not found yet, not signaling"
            exit 0
        fi
        log_debug "signaling gather-done"
        $signal_cmd signal "$agent" gather-done "completed via hook"
        ;;
    clarify)
        # Don't override if already clarify-done or beyond
        case "$current_status" in
            clarify-done|pushback-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # Guard: require output file before signaling (cross-phase race protection)
        if [ ! -f "$PEER_SYNC/clarify-${agent}.md" ]; then
            log_debug "clarify-${agent}.md not found yet, not signaling"
            exit 0
        fi
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
        # Guard: require output file before signaling (cross-phase race protection)
        if [ ! -f "$PEER_SYNC/pushback-${agent}.md" ]; then
            log_debug "pushback-${agent}.md not found yet, not signaling"
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
        # Guard: require review file before signaling (cross-phase race protection)
        review_round="$(cat "$PEER_SYNC/round" 2>/dev/null)" || review_round="1"
        if [ "$mode" = "solo" ]; then
            review_file="$PEER_SYNC/reviews/round-${review_round}-review.md"
        else
            # Duo: determine peer name for review file
            if [ "$agent" = "claude" ]; then review_peer="codex"; else review_peer="claude"; fi
            review_file="$PEER_SYNC/reviews/round-${review_round}-${agent}-reviews-${review_peer}.md"
        fi
        if [ ! -f "$review_file" ]; then
            log_debug "review file not found yet ($review_file), not signaling"
            exit 0
        fi
        log_debug "signaling review-done"
        $signal_cmd signal "$agent" review-done "completed via hook"
        ;;
    plan)
        # Don't override if already plan-done or beyond
        case "$current_status" in
            plan-done|plan-reviewing|plan-review-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only coder plans
        if [ "$mode" = "solo" ] && [ "$agent" != "coder" ]; then
            log_debug "skipping (not coder in plan phase)"
            exit 0
        fi
        # Guard: require output file before signaling (cross-phase race protection)
        if [ ! -f "$PEER_SYNC/plan-${agent}.md" ]; then
            log_debug "plan-${agent}.md not found yet, not signaling"
            exit 0
        fi
        log_debug "signaling plan-done"
        $signal_cmd signal "$agent" plan-done "completed via hook"
        ;;
    plan-review)
        # Don't override if already plan-review-done or beyond
        case "$current_status" in
            plan-review-done|done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # In solo mode, only reviewer reviews plans
        if [ "$mode" = "solo" ] && [ "$agent" != "reviewer" ]; then
            log_debug "skipping (not reviewer in plan-review phase)"
            exit 0
        fi
        # Guard: require output file before signaling (cross-phase race protection)
        if [ "$mode" = "solo" ]; then
            plan_review_file="$PEER_SYNC/plan-review.md"
        else
            plan_review_file="$PEER_SYNC/plan-review-${agent}.md"
        fi
        if [ ! -f "$plan_review_file" ]; then
            log_debug "plan-review file not found yet ($plan_review_file), not signaling"
            exit 0
        fi
        log_debug "signaling plan-review-done"
        $signal_cmd signal "$agent" plan-review-done "completed via hook"
        ;;
    update-docs)
        # Don't override if already docs-update-done or beyond
        case "$current_status" in
            docs-update-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # Guard: require output file before signaling (cross-phase race protection)
        if [ ! -f "$PEER_SYNC/workflow-feedback-${agent}.md" ]; then
            log_debug "workflow-feedback-${agent}.md not found yet, not signaling"
            exit 0
        fi
        log_debug "signaling docs-update-done"
        $signal_cmd signal "$agent" docs-update-done "completed via hook"
        ;;
    suggest-refactor)
        # Don't override if already suggest-refactor-done
        case "$current_status" in
            suggest-refactor-done) log_debug "skipping (already $current_status)"; exit 0 ;;
        esac
        # Only signal if the agent has actually written the suggestion file
        suggest_file="$PEER_SYNC/suggest-refactor-${agent}.md"
        if [ ! -f "$suggest_file" ]; then
            log_debug "suggest-refactor file not found yet ($suggest_file), not signaling"
            exit 0
        fi
        log_debug "signaling suggest-refactor-done"
        $signal_cmd signal "$agent" suggest-refactor-done "completed via hook"
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

#------------------------------------------------------------------------------
# PR Comment Monitoring
#------------------------------------------------------------------------------

# Default timeout for PR watch phase (in seconds)
DEFAULT_PR_WATCH_TIMEOUT=600  # 10 minutes per response cycle

# Get PR comment/review count and latest update timestamp as a hash
# Usage: get_pr_comment_hash <pr_url>
# Returns: "comment_count|review_count|updated_at" or empty if failed
get_pr_comment_hash() {
    local pr_url="$1"

    local json
    json="$(gh pr view "$pr_url" --json comments,reviews,updatedAt 2>/dev/null)" || return 1

    local comment_count review_count updated_at
    comment_count="$(echo "$json" | jq -r '.comments | length' 2>/dev/null)" || comment_count=0
    review_count="$(echo "$json" | jq -r '.reviews | length' 2>/dev/null)" || review_count=0
    updated_at="$(echo "$json" | jq -r '.updatedAt' 2>/dev/null)" || updated_at=""

    echo "${comment_count}|${review_count}|${updated_at}"
}

# Check if PR has new comments since last check
# Usage: pr_has_new_comments <agent> <peer_sync>
# Returns: 0 if new comments, 1 if no changes or error
pr_has_new_comments() {
    local agent="$1"
    local peer_sync="$2"

    local pr_file="$peer_sync/${agent}.pr"
    local hash_file="$peer_sync/${agent}.pr-hash"

    [ -f "$pr_file" ] || return 1

    local pr_url
    pr_url="$(cat "$pr_file")"

    local current_hash
    current_hash="$(get_pr_comment_hash "$pr_url")" || return 1

    # Check against last known hash
    if [ -f "$hash_file" ]; then
        local last_hash
        last_hash="$(cat "$hash_file")"
        # Only compare comment_count|review_count, not updatedAt
        # This avoids false positives from force pushes (rebase) which change updatedAt
        # but don't add new comments/reviews
        local current_counts="${current_hash%|*}"  # Remove updatedAt (after last |)
        local last_counts="${last_hash%|*}"
        if [ "$current_counts" = "$last_counts" ]; then
            # Update hash file even if counts unchanged (to track updatedAt for debugging)
            echo "$current_hash" > "$hash_file"
            return 1  # No new comments/reviews
        fi
    fi

    # Update hash file and return success (new comments)
    echo "$current_hash" > "$hash_file"
    return 0
}

# Check if PR is still open (not merged or closed)
# Usage: is_pr_open <pr_url>
# Returns: 0 if open, 1 if merged/closed
is_pr_open() {
    local pr_url="$1"

    local state
    state="$(gh pr view "$pr_url" --json state -q '.state' 2>/dev/null)" || return 1

    [ "$state" = "OPEN" ]
}

# Check if PR was merged (not just closed)
# Usage: is_pr_merged <pr_url>
# Returns: 0 if merged, 1 otherwise
is_pr_merged() {
    local pr_url="$1"
    local merged_at
    merged_at="$(gh pr view "$pr_url" --json mergedAt -q '.mergedAt' 2>/dev/null)" || return 1
    [ -n "$merged_at" ] && [ "$merged_at" != "null" ]
}

#------------------------------------------------------------------------------
# Integration detection (for parallel sessions rebasing onto updated main)
#------------------------------------------------------------------------------

# Get the main branch name for the repository
# Returns: main branch name (usually "main" or "master")
get_main_branch() {
    local peer_sync="$1"

    # Check if we have it cached
    if [ -f "$peer_sync/main-branch" ]; then
        cat "$peer_sync/main-branch"
        return 0
    fi

    # Try to detect from remote HEAD
    local main_branch
    main_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"

    # Fallback to common names
    if [ -z "$main_branch" ]; then
        if git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
            main_branch="main"
        elif git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
            main_branch="master"
        else
            main_branch="main"  # Default
        fi
    fi

    # Cache it
    echo "$main_branch" > "$peer_sync/main-branch"
    echo "$main_branch"
}

# Get current HEAD commit of origin/main
# Usage: get_main_head <peer_sync>
# Returns: commit SHA
get_main_head() {
    local peer_sync="$1"
    local main_branch
    main_branch="$(get_main_branch "$peer_sync")"

    git fetch origin "$main_branch" --quiet 2>/dev/null || true
    git rev-parse "origin/$main_branch" 2>/dev/null
}

# Check if main has advanced since we last checked
# Usage: main_has_advanced <peer_sync>
# Returns: 0 if main has new commits, 1 otherwise
# Side effect: updates last-main-commit file
main_has_advanced() {
    local peer_sync="$1"
    local last_main_file="$peer_sync/last-main-commit"

    local current_main
    current_main="$(get_main_head "$peer_sync")" || return 1

    if [ -f "$last_main_file" ]; then
        local previous
        previous="$(cat "$last_main_file")"
        if [ "$current_main" != "$previous" ]; then
            echo "$current_main" > "$last_main_file"
            return 0  # Main has advanced
        fi
        return 1  # No change
    else
        # First check - record current state
        echo "$current_main" > "$last_main_file"
        return 1
    fi
}

# Check if a branch needs rebasing (is behind origin/main)
# Usage: branch_needs_rebase <branch> <peer_sync>
# Returns: 0 if branch needs rebase, 1 if up-to-date
branch_needs_rebase() {
    local branch="$1"
    local peer_sync="$2"
    local main_branch
    main_branch="$(get_main_branch "$peer_sync")"

    # Check if origin/main is an ancestor of the branch
    # If it is, branch is up-to-date (no rebase needed)
    # If not, branch is behind and needs rebase
    if git merge-base --is-ancestor "origin/$main_branch" "$branch" 2>/dev/null; then
        return 1  # Up-to-date, no rebase needed
    fi
    return 0  # Behind, needs rebase
}

# Check if PR has "Proceed to merge" comment
# Usage: pr_has_merge_trigger <pr_url>
# Returns: 0 if trigger found, 1 otherwise
pr_has_merge_trigger() {
    local pr_url="$1"

    # Fetch all comments and look for the trigger phrase
    local comments
    comments="$(gh pr view "$pr_url" --json comments -q '.comments[].body' 2>/dev/null)" || return 1

    # Case-insensitive search for "Proceed to merge" or similar variations
    if echo "$comments" | grep -qi "proceed to merge"; then
        return 0
    fi

    return 1
}

# Send notification when new PR comments are detected
# Usage: send_pr_comment_notification <agent> <feature> <pr_url> <mode>
send_pr_comment_notification() {
    local agent="$1"
    local feature="$2"
    local pr_url="$3"
    local mode="${4:-duo}"

    # Only send via ntfy
    if ! get_ntfy_topic >/dev/null 2>&1; then
        return 0
    fi

    local title="[agent-${mode}] New PR comments: ${feature}"
    local agent_cap="${agent^}"
    local message="${agent_cap}'s PR has new comments/reviews

$pr_url"

    send_ntfy "$title" "$message" "default" "speech_balloon,link" 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Workflow Feedback (shared between duo and solo modes)
#------------------------------------------------------------------------------

workflow_feedback_dir() {
    echo "$HOME/.agent-duo/workflow-feedback"
}

# Get a config value by key
# Args: key
get_config_value() {
    local key="$1"
    local config_file="$HOME/.config/agent-duo/config"
    [ -f "$config_file" ] || return 1
    local val
    val="$(grep -E "^${key}=" "$config_file" 2>/dev/null | cut -d= -f2-)"
    [ -n "$val" ] || return 1
    echo "$val"
}

# Set a config value by key
# Args: key value
set_config_value() {
    local key="$1"
    local value="$2"
    local config_dir="$HOME/.config/agent-duo"
    local config_file="$config_dir/config"
    mkdir -p "$config_dir"
    if [ -f "$config_file" ] && grep -qE "^${key}=" "$config_file" 2>/dev/null; then
        local tmp="$config_file.tmp"
        sed "s|^${key}=.*|${key}=${value}|" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
    else
        echo "${key}=${value}" >> "$config_file"
    fi
}

# Persist workflow feedback files to shared location
# Args: peer_sync feature mode
persist_workflow_feedback() {
    local peer_sync="$1"
    local feature="$2"
    local mode="${3:-duo}"

    [ -f "$peer_sync/workflow-feedback-copied" ] && return 0

    local dest_dir
    dest_dir="$(workflow_feedback_dir)"
    mkdir -p "$dest_dir"

    local date_stamp
    date_stamp="$(date +%F)"

    local agents=()
    if [ "$mode" = "solo" ]; then
        agents=("coder" "reviewer")
    else
        agents=("claude" "codex")
    fi

    local copied_any=false
    for agent in "${agents[@]}"; do
        local src="$peer_sync/workflow-feedback-${agent}.md"
        if [ -f "$src" ]; then
            local dest="$dest_dir/${date_stamp}-${feature}-${agent}.md"
            if [ -f "$dest" ]; then
                local i=2
                while [ -f "$dest_dir/${date_stamp}-${feature}-${agent}-${i}.md" ]; do
                    i=$((i + 1))
                done
                dest="$dest_dir/${date_stamp}-${feature}-${agent}-${i}.md"
            fi
            cp "$src" "$dest"
            copied_any=true
        fi
    done

    if [ "$copied_any" = true ]; then
        touch "$peer_sync/workflow-feedback-copied"

        # Auto-digest if configured
        local auto_digest
        auto_digest="$(get_config_value "auto_digest" 2>/dev/null)" || auto_digest=""
        if [ "$auto_digest" = "true" ] && command -v ludics >/dev/null 2>&1; then
            local repo
            repo="$(get_config_value "feedback_repo" 2>/dev/null)" || repo=""
            if [ -n "$repo" ]; then
                ludics mag feedback-digest "$repo" &>/dev/null & disown
            fi
        fi
    fi
}

#------------------------------------------------------------------------------
# PR Creation (shared between duo and solo modes)
#------------------------------------------------------------------------------

# Ensure docs update is complete before PR creation
# Args: agent peer_sync feature mode
# mode: "duo" or "solo"
lib_ensure_docs_update() {
    local agent="$1"
    local peer_sync="$2"
    local feature="$3"
    local mode="${4:-duo}"

    if [ ! -f "$peer_sync/docs-update-mode" ]; then
        return 0
    fi

    local docs_update_mode
    docs_update_mode="$(cat "$peer_sync/docs-update-mode" 2>/dev/null)" || docs_update_mode="true"
    if [ "$docs_update_mode" != "true" ]; then
        return 0
    fi

    local current_status
    current_status="$(get_agent_status "$agent" "$peer_sync")"
    if [ -f "$peer_sync/docs-update-${agent}.done" ] || [ "$current_status" = "docs-update-done" ]; then
        return 0
    fi

    info "Docs update required before PR creation."
    local previous_phase
    previous_phase="$(cat "$peer_sync/phase" 2>/dev/null)"
    echo "update-docs" > "$peer_sync/phase"
    atomic_write "$peer_sync/${agent}.status" "updating-docs|$(date +%s)|capturing learnings"

    local session_name="${mode}-${feature}"
    local target=""
    if tmux has-session -t "$session_name" 2>/dev/null; then
        target="${session_name}:${agent}"
    elif tmux has-session -t "${session_name}-${agent}" 2>/dev/null; then
        target="${session_name}-${agent}"
    fi

    local in_agent_session=false
    if [ -n "$TMUX" ]; then
        local current_session current_window
        current_session="$(tmux display-message -p '#S' 2>/dev/null)" || current_session=""
        current_window="$(tmux display-message -p '#W' 2>/dev/null)" || current_window=""
        if [ "$current_session" = "$session_name" ] && [ "$current_window" = "$agent" ]; then
            in_agent_session=true
        elif [ "$current_session" = "${session_name}-${agent}" ]; then
            in_agent_session=true
        fi
    fi

    if [ "$in_agent_session" = true ] || [ -z "$target" ]; then
        warn "Run the ${mode}-update-docs skill, then re-run: agent-${mode} pr $agent"
        [ -n "$previous_phase" ] && echo "$previous_phase" > "$peer_sync/phase"
        return 1
    fi

    info "Triggering ${mode}-update-docs for $agent..."
    send_to_agent "$agent" "$target" "$peer_sync" skill "${mode}-update-docs"

    local timeout="${DEFAULT_DOCS_UPDATE_TIMEOUT:-600}"
    local start=$SECONDS
    while true; do
        if [ -f "$peer_sync/docs-update-${agent}.done" ]; then
            break
        fi
        local status
        status="$(get_agent_status "$agent" "$peer_sync")"
        [ "$status" = "docs-update-done" ] && break

        # Check for API errors and retry if needed
        check_and_retry_on_error "$agent" "$target" "$peer_sync"

        local elapsed=$((SECONDS - start))
        if [ "$elapsed" -ge "$timeout" ]; then
            warn "Docs update timeout (${timeout}s)"
            [ -n "$previous_phase" ] && echo "$previous_phase" > "$peer_sync/phase"
            return 1
        fi
        printf "\r  Waiting for %s to finish update-docs... (%ds/%ds)  " "$agent" "$elapsed" "$timeout"
        sleep 5
    done
    echo ""
    success "Docs update completed for $agent"
    [ -n "$previous_phase" ] && echo "$previous_phase" > "$peer_sync/phase"
    return 0
}

# Commit changes for a round, returning "committed" or "quiescent" via stdout
# Args: worktree round peer_sync agent
lib_commit_round() {
    local worktree="$1" round="$2" peer_sync="$3" agent="$4"

    [ -d "$worktree" ] || { echo "quiescent"; return 0; }

    # Verify it's a git repository
    if ! git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1; then
        warn "lib_commit_round: $worktree is not a git repository"
        echo "quiescent"
        return 0
    fi

    local has_uncommitted=false
    [ -n "$(git -C "$worktree" status --porcelain)" ] && has_uncommitted=true

    # Check for in-phase commits (agent may have committed during work)
    local has_new_commits=false
    local pre_round_head=""
    if [ -f "$peer_sync/${agent}.head-before-round" ]; then
        pre_round_head="$(cat "$peer_sync/${agent}.head-before-round")"
        local current_head
        current_head="$(git -C "$worktree" rev-parse HEAD 2>/dev/null)" || true
        if [ -n "$pre_round_head" ] && [ -n "$current_head" ] && [ "$pre_round_head" != "$current_head" ]; then
            has_new_commits=true
        fi
    fi

    # Quiescent only if no uncommitted changes AND no new commits this round
    if ! $has_uncommitted && ! $has_new_commits; then
        echo "quiescent"
        return 0
    fi

    # If agent committed during work but left nothing uncommitted, push if needed and report
    if ! $has_uncommitted; then
        # Still need to push in-phase commits for early-pr
        local early_pr=""
        early_pr="$(cat "$peer_sync/early-pr" 2>/dev/null)" || true
        if [ "$early_pr" = "true" ] && [ -f "$peer_sync/${agent}.pr" ]; then
            git -C "$worktree" push || true
        fi
        echo "committed"
        return 0
    fi

    # Extract signal message from agent status (field 3+)
    local signal_msg=""
    if [ -f "$peer_sync/${agent}.status" ]; then
        signal_msg="$(cut -d'|' -f3- < "$peer_sync/${agent}.status" 2>/dev/null)" || true
    fi

    # Build commit message: filter out orchestrator-set default messages
    local commit_msg=""
    if [ -n "$signal_msg" ] && ! [[ "$signal_msg" =~ ^round\ [0-9]+\ (work|review)\ phase$ ]] && [ "$signal_msg" != "starting" ]; then
        commit_msg="Round $round: $signal_msg"
    else
        commit_msg="Round $round changes"
    fi

    # Commit
    git -C "$worktree" add -A
    git -C "$worktree" commit -m "$commit_msg" || true

    # If early-pr mode and PR exists, push
    local early_pr=""
    early_pr="$(cat "$peer_sync/early-pr" 2>/dev/null)" || true
    if [ "$early_pr" = "true" ] && [ -f "$peer_sync/${agent}.pr" ]; then
        git -C "$worktree" push || true
    fi

    echo "committed"
    return 0
}

# Create PR for an agent's solution
# Args: pr_name agent worktree root peer_sync feature mode pr_title
# pr_name: branch name and PR identifier (e.g., "feature-alpha" or "feature-beta")
# agent: agent name (e.g., "alpha", "beta", "coder")
# worktree: path to worktree
# root: project root (for finding task files)
# peer_sync: path to .peer-sync directory
# feature: feature name
# mode: "duo" or "solo"
# pr_title: title for the PR (optional, defaults to "Solution for $feature")
lib_create_pr() {
    local pr_name="$1"
    local agent="$2"
    local worktree="$3"
    local root="$4"
    local peer_sync="$5"
    local feature="$6"
    local mode="${7:-duo}"
    local pr_title="${8:-Solution for $feature}"

    [ -d "$worktree" ] || die "Worktree not found: $worktree"

    # Verify it's a git repository
    if ! git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1; then
        die "Worktree is not a git repository: $worktree"
    fi

    info "Creating PR for $agent..."

    cd "$worktree"

    if ! lib_ensure_docs_update "$agent" "$peer_sync" "$feature" "$mode"; then
        return 1
    fi

    # Check if feature file should be removed from the PR
    # Only remove if: (1) it was copied into the worktree by the session (not on main),
    # and (2) the agent didn't modify it. Files already in the repo stay regardless.
    local feature_file="$worktree/${feature}.md"
    if [ -f "$feature_file" ]; then
        local main_branch
        main_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')" || true
        if [ -z "$main_branch" ]; then
            for candidate in main master; do
                if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
                    main_branch="$candidate"
                    break
                fi
            done
        fi
        if [ -z "$main_branch" ]; then
            main_branch="HEAD~1"
        fi

        # If the file exists on main, leave it alone — it's part of the repo
        if git show "${main_branch}:${feature}.md" >/dev/null 2>&1; then
            : # File exists on main, keep it (even if unmodified)
        else
            # File was added by session setup — remove if agent didn't modify it
            local file_modified=false
            local original_task_file
            if original_task_file="$(find_task_file "$root" "$feature")"; then
                if ! diff -q "$feature_file" "$original_task_file" >/dev/null 2>&1; then
                    file_modified=true
                fi
            fi

            if [ "$file_modified" = "false" ]; then
                info "Feature file ${feature}.md was not modified - removing it"
                if git ls-files --error-unmatch "${feature}.md" >/dev/null 2>&1; then
                    git rm "${feature}.md"
                    git commit -m "Remove unmodified feature file ${feature}.md"
                else
                    rm -f "${feature}.md"
                fi
            fi
        fi
    fi

    # Commit only leftover changes (docs-update, feature-file cleanup)
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "Pre-PR cleanup for $feature" || true
    fi

    # Push branch
    git push -u origin "$pr_name" 2>/dev/null || git push origin "$pr_name"

    # Look for PR body file
    local pr_body=""
    local pr_body_file="$root/${pr_name}-PR.md"
    if [ -f "$pr_body_file" ]; then
        pr_body="$(cat "$pr_body_file")"
    else
        pr_body="Solution from $agent for feature: $feature"
    fi

    # Create PR
    local pr_url
    pr_url="$(gh pr create --title "$pr_title" --body "$pr_body" --head "$pr_name" 2>/dev/null)" || \
        pr_url="$(gh pr view --json url -q '.url' 2>/dev/null)" || \
        die "Failed to create PR. Is gh installed and authenticated?"

    # Record PR
    echo "$pr_url" > "$peer_sync/${agent}.pr"
    atomic_write "$peer_sync/${agent}.status" "pr-created|$(date +%s)|$pr_url"

    success "PR created: $pr_url"

    # Send notification
    send_pr_notification "$agent" "$feature" "$pr_url" "$mode"

    # Return PR URL for caller
    echo "$pr_url"
}

#------------------------------------------------------------------------------
# Suggest-Refactor Phase (shared between duo and solo modes)
#------------------------------------------------------------------------------

# Run suggest-refactor phase for duo mode
# Called after session transitions to "accepted" (PR merged)
# Usage: run_suggest_refactor_duo <peer_sync> <claude_session> <codex_session> <feature>
run_suggest_refactor_duo() {
    local peer_sync="$1"
    local claude_session="$2"
    local codex_session="$3"
    local feature="$4"

    info "=== Suggest-Refactor Phase ==="
    echo "suggest-refactor" > "$peer_sync/phase"

    # Reset both agent statuses to working
    atomic_write "$peer_sync/claude.status" "working|$(date +%s)|writing refactoring suggestions"
    atomic_write "$peer_sync/codex.status" "working|$(date +%s)|writing refactoring suggestions"

    # Send skill to both agents in parallel
    info "Asking both agents for refactoring suggestions..."
    send_to_agent "claude" "$claude_session" "$peer_sync" skill "duo-suggest-refactor"
    send_to_agent "codex" "$codex_session" "$peer_sync" skill "duo-suggest-refactor"

    # Wait for both to signal suggest-refactor-done (5 min timeout)
    local sr_start=$SECONDS
    local sr_timeout=300
    local claude_done=false
    local codex_done=false

    while true; do
        local elapsed=$((SECONDS - sr_start))
        local claude_status codex_status
        claude_status="$(get_agent_status "claude" "$peer_sync")"
        codex_status="$(get_agent_status "codex" "$peer_sync")"

        [[ "$claude_status" == "suggest-refactor-done" ]] && claude_done=true
        [[ "$codex_status" == "suggest-refactor-done" ]] && codex_done=true

        if $claude_done && $codex_done; then
            success "Both agents completed suggest-refactor"
            break
        fi

        if [ "$elapsed" -ge "$sr_timeout" ]; then
            warn "Suggest-refactor timeout (${sr_timeout}s)"
            break
        fi

        printf "\r  Waiting for suggest-refactor... claude=%s codex=%s (%ds)  " "$claude_status" "$codex_status" "$elapsed"
        sleep 5
    done
    echo ""

    # Wait for actual files to appear (hook may signal done before files are written)
    local file_wait=0
    local all_files_found=false
    while [ "$file_wait" -lt 120 ]; do
        all_files_found=true
        for _agent in claude codex; do
            [ ! -f "$peer_sync/suggest-refactor-${_agent}.md" ] && all_files_found=false
        done
        $all_files_found && break
        sleep 3
        file_wait=$((file_wait + 3))
        printf "\r  Waiting for suggest-refactor files... (%ds)  " "$file_wait"
    done
    [ "$file_wait" -gt 0 ] && echo ""

    # Collect and post suggestions
    _post_suggest_refactor_comment "$peer_sync" "$feature" "duo" "claude" "codex"
}

# Run suggest-refactor phase for solo mode
# Called after session transitions to "accepted" (PR merged)
# Usage: run_suggest_refactor_solo <peer_sync> <coder_session> <feature>
run_suggest_refactor_solo() {
    local peer_sync="$1"
    local coder_session="$2"
    local feature="$3"

    info "=== Suggest-Refactor Phase ==="
    echo "suggest-refactor" > "$peer_sync/phase"

    # Reset coder status to working
    atomic_write "$peer_sync/coder.status" "working|$(date +%s)|writing refactoring suggestions"

    # Send skill to coder
    info "Asking coder for refactoring suggestions..."
    send_to_agent "coder" "$coder_session" "$peer_sync" skill "solo-suggest-refactor"

    # Wait for suggest-refactor-done (5 min timeout)
    local sr_start=$SECONDS
    local sr_timeout=300

    while true; do
        local elapsed=$((SECONDS - sr_start))
        local status
        status="$(get_agent_status "coder" "$peer_sync")"

        if [[ "$status" == "suggest-refactor-done" ]]; then
            success "Coder completed suggest-refactor"
            break
        fi

        if [ "$elapsed" -ge "$sr_timeout" ]; then
            warn "Suggest-refactor timeout (${sr_timeout}s)"
            break
        fi

        printf "\r  Waiting for suggest-refactor... coder=%s (%ds)  " "$status" "$elapsed"
        sleep 5
    done
    echo ""

    # Wait for the actual file to appear (hook may signal done before file is written)
    local file_wait=0
    local suggest_file="$peer_sync/suggest-refactor-coder.md"
    while [ ! -f "$suggest_file" ] && [ "$file_wait" -lt 120 ]; do
        sleep 3
        file_wait=$((file_wait + 3))
        printf "\r  Waiting for suggest-refactor file... (%ds)  " "$file_wait"
    done
    [ "$file_wait" -gt 0 ] && echo ""

    # Collect and post suggestions
    _post_suggest_refactor_comment "$peer_sync" "$feature" "solo" "coder"
}

# Internal helper: collect suggest-refactor files, post as PR comment, send ntfy
# Usage: _post_suggest_refactor_comment <peer_sync> <feature> <mode> <agent1> [agent2]
_post_suggest_refactor_comment() {
    local peer_sync="$1"
    local feature="$2"
    local mode="$3"
    shift 3
    local agents=("$@")

    # Combine suggestions from all agents
    local combined=""
    for agent in "${agents[@]}"; do
        local file="$peer_sync/suggest-refactor-${agent}.md"
        if [ -f "$file" ]; then
            local content
            content="$(cat "$file")"
            if [ -n "$combined" ]; then
                combined="${combined}

---

"
            fi
            combined="${combined}${content}"
        else
            if [ -n "$combined" ]; then
                combined="${combined}

---

"
            fi
            combined="${combined}*${agent} did not produce refactoring suggestions.*"
        fi
    done

    if [ -z "$combined" ]; then
        warn "No refactoring suggestions were produced"
        return 0
    fi

    # Save combined suggestions locally
    echo "$combined" > "$peer_sync/suggest-refactor-combined.md"
    info "Refactoring suggestions saved to $peer_sync/suggest-refactor-combined.md"

    # Find the merged PR URL
    local pr_url=""
    for agent in "${agents[@]}"; do
        local pr_file="$peer_sync/${agent}.pr"
        if [ -f "$pr_file" ]; then
            local candidate
            candidate="$(cat "$pr_file")"
            if is_pr_merged "$candidate" 2>/dev/null; then
                pr_url="$candidate"
                break
            fi
        fi
    done

    # Post as PR comment
    if [ -n "$pr_url" ]; then
        local comment_body="## Refactoring Suggestions

*Post-merge retrospective: what would we do differently if starting from scratch?*

${combined}"
        if gh pr comment "$pr_url" --body "$comment_body" >/dev/null 2>&1; then
            success "Posted refactoring suggestions as PR comment"
        else
            warn "Failed to post PR comment (suggestions saved locally)"
        fi
    else
        warn "No merged PR found to post comment on (suggestions saved locally)"
    fi

    # Send ntfy notification
    local summary
    summary="$(echo "$combined" | head -c 500)"
    send_ntfy "[agent-${mode}] Refactor Suggestions: ${feature}" "$summary" "low" "bulb,memo" 2>/dev/null || true
}
