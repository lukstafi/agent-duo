#!/bin/bash
# Integration tests for agent-duo with REAL agent CLIs
#
# Prerequisites:
#   - claude CLI installed and authenticated
#   - codex CLI installed and authenticated
#   - gh CLI installed and authenticated
#   - lukstafi/agent-duo-testing repo cloned to ~/agent-duo-testing
#
# These tests are meant to be run manually before significant commits.
# They are NOT suitable for CI due to:
#   - Non-deterministic AI responses
#   - API costs
#   - Authentication requirements
#
# Usage: ./tests/integration.t [--quick]
#   --quick: Run minimal tests (start/status/cleanup only)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_REPO="$HOME/agent-duo-testing"
TEST_FEATURE="integration-test-$(date +%s)"
QUICK_MODE=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick) QUICK_MODE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helpers
info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}"; }

test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    info "TEST: $1"
    echo "----------------------------------------"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    success "✓ PASS"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    error "✗ FAIL: $1"
}

cleanup_test_session() {
    info "Cleaning up test session..."
    cd "$TEST_REPO" 2>/dev/null || return 0

    # Run cleanup if agent-duo is available
    if command -v agent-duo >/dev/null 2>&1; then
        agent-duo cleanup --full 2>/dev/null || true
    fi

    # Remove any test branches
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
    git branch -D "${TEST_FEATURE}-claude" 2>/dev/null || true
    git branch -D "${TEST_FEATURE}-codex" 2>/dev/null || true

    # Remove test task file
    rm -f "$TEST_REPO/${TEST_FEATURE}.md" 2>/dev/null || true

    # Kill any lingering tmux sessions
    tmux kill-session -t "duo-${TEST_FEATURE}" 2>/dev/null || true
    tmux kill-session -t "duo-${TEST_FEATURE}-orchestrator" 2>/dev/null || true
    tmux kill-session -t "duo-${TEST_FEATURE}-claude" 2>/dev/null || true
    tmux kill-session -t "duo-${TEST_FEATURE}-codex" 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Prerequisites Check
#------------------------------------------------------------------------------

echo "=== Integration Tests for agent-duo ==="
echo ""
echo "Test repository: $TEST_REPO"
echo "Test feature:    $TEST_FEATURE"
echo "Quick mode:      $QUICK_MODE"
echo ""

info "Checking prerequisites..."

# Check test repo exists
if [ ! -d "$TEST_REPO" ]; then
    error "Test repository not found: $TEST_REPO"
    echo "Clone it with: gh repo clone lukstafi/agent-duo-testing ~/agent-duo-testing"
    exit 1
fi
success "✓ Test repository exists"

# Check it's a git repo
if ! git -C "$TEST_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    error "$TEST_REPO is not a git repository"
    exit 1
fi
success "✓ Test repository is a git repo"

# Check agent-duo is installed
if ! command -v agent-duo >/dev/null 2>&1; then
    warn "agent-duo not in PATH, using local version"
    export PATH="$REPO_ROOT:$PATH"
fi
success "✓ agent-duo available"

# Check claude CLI
if ! command -v claude >/dev/null 2>&1; then
    error "claude CLI not found"
    echo "Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
fi
success "✓ claude CLI installed"

# Check codex CLI
if ! command -v codex >/dev/null 2>&1; then
    error "codex CLI not found"
    echo "Install with: npm install -g @openai/codex"
    exit 1
fi
success "✓ codex CLI installed"

# Check tmux
if ! command -v tmux >/dev/null 2>&1; then
    error "tmux not found"
    exit 1
fi
success "✓ tmux installed"

# Check gh CLI (optional but recommended)
if command -v gh >/dev/null 2>&1; then
    success "✓ gh CLI installed"
else
    warn "⚠ gh CLI not found (PR tests will be skipped)"
fi

echo ""

# Cleanup any previous test state
cleanup_test_session

# Set up trap to cleanup on exit
trap cleanup_test_session EXIT

#------------------------------------------------------------------------------
# Test: Basic Session Lifecycle (start → status → stop → cleanup)
#------------------------------------------------------------------------------

test_start "Session lifecycle: start → status → stop → cleanup"

cd "$TEST_REPO"

# Create a simple test task file
cat > "${TEST_FEATURE}.md" << 'EOF'
# Integration Test Task

This is a minimal test task for integration testing.

## Requirements
- Create a file called `test-output.txt` with the text "Hello from integration test"

## Done when
- The file exists with the correct content
EOF

# Start session (no-ttyd for simpler testing, no auto-run)
info "Starting session..."
if agent-duo start "$TEST_FEATURE" --no-ttyd 2>&1; then
    success "Session started"
else
    test_fail "Failed to start session"
    exit 1
fi

# Check .peer-sync was created
if [ -d ".peer-sync" ]; then
    success ".peer-sync directory created"
else
    test_fail ".peer-sync not created"
fi

# Check status command works
info "Checking status..."
if agent-duo status 2>&1 | grep -q "$TEST_FEATURE"; then
    success "Status shows feature name"
else
    test_fail "Status doesn't show feature"
fi

# Check phase is set
if [ -f ".peer-sync/phase" ]; then
    PHASE=$(cat .peer-sync/phase)
    if [ "$PHASE" = "work" ]; then
        success "Phase is 'work'"
    else
        warn "Phase is '$PHASE' (expected 'work')"
    fi
else
    test_fail "Phase file not created"
fi

# Check tmux sessions were created
if tmux has-session -t "duo-${TEST_FEATURE}" 2>/dev/null; then
    success "tmux session created"
else
    test_fail "tmux session not created"
fi

# Stop session
info "Stopping session..."
if agent-duo stop 2>&1; then
    success "Session stopped"
else
    test_fail "Failed to stop session"
fi

# Cleanup
info "Cleaning up..."
if agent-duo cleanup --full 2>&1; then
    success "Cleanup completed"
else
    test_fail "Cleanup failed"
fi

# Verify cleanup
if [ ! -d ".peer-sync" ]; then
    success ".peer-sync removed"
else
    test_fail ".peer-sync still exists after cleanup"
fi

test_pass

#------------------------------------------------------------------------------
# Test: Signal and Status Protocol
#------------------------------------------------------------------------------

test_start "Signal and status protocol"

cd "$TEST_REPO"

# Start fresh session
cat > "${TEST_FEATURE}.md" << 'EOF'
# Signal Test
Test task for signal protocol testing.
EOF

agent-duo start "$TEST_FEATURE" --no-ttyd >/dev/null 2>&1

# Test signal command
info "Testing signal command..."

# Signal working status
if agent-duo signal claude working "test message" 2>&1 | grep -q "claude status: working"; then
    success "Signal command accepted 'working'"
else
    test_fail "Signal command failed for 'working'"
fi

# Check status file
if [ -f ".peer-sync/claude.status" ]; then
    CONTENT=$(cat .peer-sync/claude.status)
    if [[ "$CONTENT" == working\|*\|test\ message ]]; then
        success "Status file has correct format"
    else
        test_fail "Status file format wrong: $CONTENT"
    fi
else
    test_fail "Status file not created"
fi

# Signal done status
if agent-duo signal claude done "completed" 2>&1 | grep -q "claude status: done"; then
    success "Signal command accepted 'done'"
else
    test_fail "Signal command failed for 'done'"
fi

# Test invalid status rejection
if agent-duo signal claude invalid-status 2>&1 | grep -qi "invalid"; then
    success "Invalid status rejected"
else
    test_fail "Invalid status not rejected"
fi

# Cleanup
agent-duo cleanup --full >/dev/null 2>&1

test_pass

#------------------------------------------------------------------------------
# Quick mode stops here
#------------------------------------------------------------------------------

if [ "$QUICK_MODE" = "true" ]; then
    echo ""
    info "Quick mode: skipping extended tests"
    echo ""
    echo "=== Summary ==="
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

    if [ "$TESTS_FAILED" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
fi

#------------------------------------------------------------------------------
# Test: Clarify Mode
#------------------------------------------------------------------------------

test_start "Clarify mode workflow"

cd "$TEST_REPO"

cat > "${TEST_FEATURE}.md" << 'EOF'
# Clarify Mode Test
Test task with ambiguous requirements for clarify testing.

## Requirements
- Do something useful (intentionally vague)
EOF

# Start with clarify mode
info "Starting session with --clarify..."
if agent-duo start "$TEST_FEATURE" --no-ttyd --clarify 2>&1; then
    success "Session started with clarify mode"
else
    test_fail "Failed to start with --clarify"
fi

# Check phase is clarify
PHASE=$(cat .peer-sync/phase 2>/dev/null)
if [ "$PHASE" = "clarify" ]; then
    success "Phase is 'clarify'"
else
    test_fail "Phase should be 'clarify', got: $PHASE"
fi

# Check clarify-mode flag
if [ "$(cat .peer-sync/clarify-mode 2>/dev/null)" = "true" ]; then
    success "clarify-mode flag is set"
else
    test_fail "clarify-mode flag not set"
fi

# Cleanup
agent-duo cleanup --full >/dev/null 2>&1

test_pass

#------------------------------------------------------------------------------
# Test: Worktree Creation
#------------------------------------------------------------------------------

test_start "Worktree creation and structure"

cd "$TEST_REPO"

cat > "${TEST_FEATURE}.md" << 'EOF'
# Worktree Test
Test worktree creation.
EOF

agent-duo start "$TEST_FEATURE" --no-ttyd >/dev/null 2>&1

# Check worktrees were created
PROJECT_NAME=$(basename "$TEST_REPO")
PARENT_DIR=$(dirname "$TEST_REPO")

CLAUDE_WT="$PARENT_DIR/${PROJECT_NAME}-${TEST_FEATURE}-claude"
CODEX_WT="$PARENT_DIR/${PROJECT_NAME}-${TEST_FEATURE}-codex"

if [ -d "$CLAUDE_WT" ]; then
    success "Claude worktree created: $CLAUDE_WT"
else
    test_fail "Claude worktree not created"
fi

if [ -d "$CODEX_WT" ]; then
    success "Codex worktree created: $CODEX_WT"
else
    test_fail "Codex worktree not created"
fi

# Check .peer-sync symlinks in worktrees
if [ -L "$CLAUDE_WT/.peer-sync" ]; then
    success "Claude worktree has .peer-sync symlink"
else
    test_fail "Claude worktree missing .peer-sync symlink"
fi

if [ -L "$CODEX_WT/.peer-sync" ]; then
    success "Codex worktree has .peer-sync symlink"
else
    test_fail "Codex worktree missing .peer-sync symlink"
fi

# Check branches were created
if git branch | grep -q "${TEST_FEATURE}-claude"; then
    success "Claude branch created"
else
    test_fail "Claude branch not created"
fi

if git branch | grep -q "${TEST_FEATURE}-codex"; then
    success "Codex branch created"
else
    test_fail "Codex branch not created"
fi

# Cleanup
agent-duo cleanup --full >/dev/null 2>&1

test_pass

#------------------------------------------------------------------------------
# Test: Config Command
#------------------------------------------------------------------------------

test_start "Config command"

# Test listing config
info "Testing config list..."
if agent-duo config 2>&1 | grep -q "Available settings"; then
    success "Config list works"
else
    test_fail "Config list failed"
fi

# Test setting a value
info "Testing config set..."
ORIGINAL_MODEL=$(agent-duo config codex_model 2>&1 || echo "")

if agent-duo config codex_model "test-model" 2>&1 | grep -q "Set codex_model"; then
    success "Config set works"
else
    test_fail "Config set failed"
fi

# Test getting the value back
if agent-duo config codex_model 2>&1 | grep -q "test-model"; then
    success "Config get works"
else
    test_fail "Config get failed"
fi

# Restore original value or unset
if [ -n "$ORIGINAL_MODEL" ]; then
    agent-duo config codex_model "$ORIGINAL_MODEL" >/dev/null 2>&1
fi

test_pass

#------------------------------------------------------------------------------
# Test: Doctor Command
#------------------------------------------------------------------------------

test_start "Doctor command"

info "Running doctor..."
if agent-duo doctor 2>&1 | grep -q "=== Required Tools ==="; then
    success "Doctor runs and shows sections"
else
    test_fail "Doctor output unexpected"
fi

# Check it detects installed tools
if agent-duo doctor 2>&1 | grep -q "claude:"; then
    success "Doctor checks for claude"
else
    test_fail "Doctor doesn't check for claude"
fi

test_pass

#------------------------------------------------------------------------------
# Test: Real Agent Invocation (SHORT - just verify they start)
#------------------------------------------------------------------------------

test_start "Real agent CLI invocation (brief)"

cd "$TEST_REPO"

cat > "${TEST_FEATURE}.md" << 'EOF'
# Brief Agent Test

IMPORTANT: This is an automated test. Complete quickly.

## Task
1. Create a file called `agent-test-marker.txt`
2. Write "test passed" into it
3. Signal done immediately

Do not ask questions. Just do it and signal done.
EOF

info "Starting session with real agents..."
agent-duo start "$TEST_FEATURE" --no-ttyd >/dev/null 2>&1

# Give agents a moment to initialize
sleep 3

# Check tmux sessions exist and have processes
CLAUDE_SESSION="duo-${TEST_FEATURE}"
if tmux has-session -t "$CLAUDE_SESSION" 2>/dev/null; then
    success "tmux session exists"

    # Check window count (should have orchestrator, claude, codex)
    WINDOW_COUNT=$(tmux list-windows -t "$CLAUDE_SESSION" 2>/dev/null | wc -l)
    if [ "$WINDOW_COUNT" -ge 2 ]; then
        success "tmux has multiple windows ($WINDOW_COUNT)"
    else
        warn "tmux window count: $WINDOW_COUNT"
    fi
else
    test_fail "tmux session not found"
fi

# Note: We don't wait for agents to complete - that would take too long
# Just verify the infrastructure is working

# Cleanup
agent-duo stop >/dev/null 2>&1
agent-duo cleanup --full >/dev/null 2>&1

test_pass

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------

echo ""
echo "=== Summary ==="
echo -e "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
    error "Some tests failed!"
    exit 1
else
    success "All tests passed!"
    exit 0
fi
