#!/bin/bash
# start.sh - Launch agent-duo with two AI agents in parallel worktrees
#
# Usage: ./start.sh [agent_a] [agent_b]
# Defaults to claude and codex if not specified

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load config
source .peer-sync/config

# Override from args if provided
AGENT_A="${1:-$AGENT_A}"
AGENT_B="${2:-$AGENT_B}"

echo "=== Agent Duo ==="
echo "Agent A: $AGENT_A"
echo "Agent B: $AGENT_B"
echo ""

# Create worktrees if they don't exist
WORKTREE_A="../project-${AGENT_A}"
WORKTREE_B="../project-${AGENT_B}"

if [ ! -d "$WORKTREE_A" ]; then
    echo "Creating worktree for $AGENT_A at $WORKTREE_A..."
    # Create worktree on a new branch based on main
    git worktree add -b "${AGENT_A}-work" "$WORKTREE_A" main
else
    echo "Worktree $WORKTREE_A already exists"
fi

if [ ! -d "$WORKTREE_B" ]; then
    echo "Creating worktree for $AGENT_B at $WORKTREE_B..."
    # Create worktree on a new branch based on main
    git worktree add -b "${AGENT_B}-work" "$WORKTREE_B" main
else
    echo "Worktree $WORKTREE_B already exists"
fi

# Resolve absolute paths
WORKTREE_A_ABS="$(cd "$WORKTREE_A" && pwd)"
WORKTREE_B_ABS="$(cd "$WORKTREE_B" && pwd)"
PEER_SYNC_ABS="$(pwd)/.peer-sync"

echo ""
echo "Worktree A: $WORKTREE_A_ABS"
echo "Worktree B: $WORKTREE_B_ABS"
echo "Peer sync:  $PEER_SYNC_ABS"
echo ""

# Initialize sync state
echo "1" > .peer-sync/turn
echo "working" > .peer-sync/phase
echo "working" > .peer-sync/${AGENT_A}-status
echo "working" > .peer-sync/${AGENT_B}-status
rm -f .peer-sync/${AGENT_A}-pr .peer-sync/${AGENT_B}-pr

# Write agent identities for skills to read
echo "$AGENT_A" > .peer-sync/agent-a-name
echo "$AGENT_B" > .peer-sync/agent-b-name

# Kill any existing tmux sessions
tmux kill-session -t "duo-${AGENT_A}" 2>/dev/null || true
tmux kill-session -t "duo-${AGENT_B}" 2>/dev/null || true

# Create tmux sessions (for scrollback + session persistence)
echo "Creating tmux sessions..."

tmux new-session -d -s "duo-${AGENT_A}" -c "$WORKTREE_A_ABS"
tmux new-session -d -s "duo-${AGENT_B}" -c "$WORKTREE_B_ABS"

# Set environment variables in each session
tmux send-keys -t "duo-${AGENT_A}" "export PEER_SYNC=\"$PEER_SYNC_ABS\"" Enter
tmux send-keys -t "duo-${AGENT_A}" "export MY_NAME=\"$AGENT_A\"" Enter
tmux send-keys -t "duo-${AGENT_A}" "export PEER_NAME=\"$AGENT_B\"" Enter
tmux send-keys -t "duo-${AGENT_A}" "export PEER_WORKTREE=\"$WORKTREE_B_ABS\"" Enter

tmux send-keys -t "duo-${AGENT_B}" "export PEER_SYNC=\"$PEER_SYNC_ABS\"" Enter
tmux send-keys -t "duo-${AGENT_B}" "export MY_NAME=\"$AGENT_B\"" Enter
tmux send-keys -t "duo-${AGENT_B}" "export PEER_NAME=\"$AGENT_A\"" Enter
tmux send-keys -t "duo-${AGENT_B}" "export PEER_WORKTREE=\"$WORKTREE_A_ABS\"" Enter

echo ""
echo "Tmux sessions created: duo-${AGENT_A}, duo-${AGENT_B}"
echo ""

# Start ttyd instances
echo "Starting ttyd servers..."

ttyd -p ${AGENT_A_PORT} -W tmux attach -t "duo-${AGENT_A}" &
TTYD_A_PID=$!

ttyd -p ${AGENT_B_PORT} -W tmux attach -t "duo-${AGENT_B}" &
TTYD_B_PID=$!

echo ""
echo "=== Agent Duo Ready ==="
echo ""
echo "$AGENT_A: http://localhost:${AGENT_A_PORT}"
echo "$AGENT_B: http://localhost:${AGENT_B_PORT}"
echo ""
echo "To start the agents with the bootstrap prompt, run:"
echo "  ./orchestrate.sh"
echo ""
echo "Press Ctrl+C to stop ttyd servers"

# Cleanup on exit
trap "kill $TTYD_A_PID $TTYD_B_PID 2>/dev/null; echo 'Stopped ttyd servers'" EXIT

wait
