#!/bin/bash
# orchestrate.sh - Main loop for agent-duo
#
# Coordinates the two agents through work/review cycles until both have PRs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load config
source .peer-sync/config

AGENT_A="${1:-$AGENT_A}"
AGENT_B="${2:-$AGENT_B}"

PEER_SYNC="$(pwd)/.peer-sync"

echo "=== Agent Duo Orchestrator ==="
echo "Coordinating: $AGENT_A and $AGENT_B"
echo ""

# Check tmux sessions exist
if ! tmux has-session -t "duo-${AGENT_A}" 2>/dev/null; then
    echo "Error: tmux session duo-${AGENT_A} not found. Run ./start.sh first."
    exit 1
fi

if ! tmux has-session -t "duo-${AGENT_B}" 2>/dev/null; then
    echo "Error: tmux session duo-${AGENT_B} not found. Run ./start.sh first."
    exit 1
fi

# Load the bootstrap prompt
if [ ! -f ".peer-sync/prompt.md" ]; then
    echo "Error: No prompt found at .peer-sync/prompt.md"
    echo "Create a prompt file describing the task for both agents."
    exit 1
fi

PROMPT=$(cat .peer-sync/prompt.md)

# Function to send prompt to an agent
send_to_agent() {
    local session="$1"
    local agent_name="$2"
    local agent_cmd="$3"
    local prompt="$4"

    # Start the agent CLI with the prompt
    # Using heredoc-style input via tmux
    tmux send-keys -t "$session" "$agent_cmd" Enter
    sleep 2  # Let the agent start

    # Send the prompt (escaped for tmux)
    tmux send-keys -t "$session" "$prompt" Enter
}

# Function to check if agent has created a PR
has_pr() {
    local agent="$1"
    [ -f "$PEER_SYNC/${agent}-pr" ]
}

# Function to get agent status
get_status() {
    local agent="$1"
    cat "$PEER_SYNC/${agent}-status" 2>/dev/null || echo "unknown"
}

# Function to wait for both agents to reach a status
wait_for_status() {
    local target="$1"
    echo "Waiting for both agents to reach status: $target"

    while true; do
        local status_a=$(get_status "$AGENT_A")
        local status_b=$(get_status "$AGENT_B")

        echo "  $AGENT_A: $status_a, $AGENT_B: $status_b"

        if [ "$status_a" = "$target" ] && [ "$status_b" = "$target" ]; then
            break
        fi

        # Check if both have PRs (termination condition)
        if has_pr "$AGENT_A" && has_pr "$AGENT_B"; then
            echo "Both agents have created PRs. Terminating."
            return 1
        fi

        sleep 10
    done
    return 0
}

# Function to trigger review phase
trigger_review_phase() {
    local turn="$1"

    echo ""
    echo "=== Turn $turn: Review Phase ==="
    echo ""

    echo "reviewing" > "$PEER_SYNC/phase"
    echo "reviewing" > "$PEER_SYNC/${AGENT_A}-status"
    echo "reviewing" > "$PEER_SYNC/${AGENT_B}-status"

    # Notify agents to start review
    # They should be watching their status file or we send a command

    if ! has_pr "$AGENT_A"; then
        tmux send-keys -t "duo-${AGENT_A}" "/duo-review" Enter
    fi

    if ! has_pr "$AGENT_B"; then
        tmux send-keys -t "duo-${AGENT_B}" "\$duo-review" Enter
    fi
}

# Function to trigger work phase
trigger_work_phase() {
    local turn="$1"

    echo ""
    echo "=== Turn $turn: Work Phase ==="
    echo ""

    echo "working" > "$PEER_SYNC/phase"
    echo "working" > "$PEER_SYNC/${AGENT_A}-status"
    echo "working" > "$PEER_SYNC/${AGENT_B}-status"

    # Notify agents to continue work
    if ! has_pr "$AGENT_A"; then
        tmux send-keys -t "duo-${AGENT_A}" "/duo-work" Enter
    fi

    if ! has_pr "$AGENT_B"; then
        tmux send-keys -t "duo-${AGENT_B}" "\$duo-work" Enter
    fi
}

# === Main Loop ===

echo "Starting agents with bootstrap prompt..."
echo ""

# Send initial prompt to both agents
tmux send-keys -t "duo-${AGENT_A}" "$AGENT_A_CMD" Enter
tmux send-keys -t "duo-${AGENT_B}" "$AGENT_B_CMD" Enter

sleep 3

# Send the prompt to both (they'll read it as their first task)
# For Claude, we send directly. For Codex, same approach.
echo "Sending prompt to $AGENT_A..."
tmux send-keys -t "duo-${AGENT_A}" "$(cat .peer-sync/prompt.md | head -c 2000)" Enter

echo "Sending prompt to $AGENT_B..."
tmux send-keys -t "duo-${AGENT_B}" "$(cat .peer-sync/prompt.md | head -c 2000)" Enter

TURN=1
echo "$TURN" > "$PEER_SYNC/turn"

echo ""
echo "Agents started. Entering coordination loop..."
echo "Termination: when both agents have created PRs"
echo ""

while true; do
    # Check termination condition
    if has_pr "$AGENT_A" && has_pr "$AGENT_B"; then
        echo ""
        echo "=== Both PRs Created ==="
        echo "$AGENT_A PR: $(cat $PEER_SYNC/${AGENT_A}-pr)"
        echo "$AGENT_B PR: $(cat $PEER_SYNC/${AGENT_B}-pr)"
        echo ""
        echo "Agent Duo complete!"
        break
    fi

    # Wait for agents to signal done with current phase
    echo "Turn $TURN: Waiting for agents to complete work phase..."

    if ! wait_for_status "done"; then
        # Terminated due to both PRs existing
        break
    fi

    # Trigger review phase
    trigger_review_phase "$TURN"

    echo "Turn $TURN: Waiting for agents to complete review phase..."

    if ! wait_for_status "review-done"; then
        break
    fi

    # Next turn
    TURN=$((TURN + 1))
    echo "$TURN" > "$PEER_SYNC/turn"

    # Trigger next work phase
    trigger_work_phase "$TURN"
done

echo ""
echo "=== Final State ==="
echo "Turns completed: $TURN"
[ -f "$PEER_SYNC/${AGENT_A}-pr" ] && echo "$AGENT_A PR: $(cat $PEER_SYNC/${AGENT_A}-pr)"
[ -f "$PEER_SYNC/${AGENT_B}-pr" ] && echo "$AGENT_B PR: $(cat $PEER_SYNC/${AGENT_B}-pr)"
