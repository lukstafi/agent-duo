#!/bin/bash
# Unit tests for agent-duo library functions
# These tests do NOT require real agent CLIs - they test pure bash functions

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the library
source "$REPO_ROOT/agent-lib.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test helpers
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  $1... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}: $1"
}

assert_eq() {
    if [ "$1" = "$2" ]; then
        return 0
    else
        echo "expected '$2', got '$1'" >&2
        return 1
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        echo "file '$1' does not exist" >&2
        return 1
    fi
}

assert_dir_exists() {
    if [ -d "$1" ]; then
        return 0
    else
        echo "directory '$1' does not exist" >&2
        return 1
    fi
}

#------------------------------------------------------------------------------
# Setup test environment
#------------------------------------------------------------------------------

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "=== Unit Tests ==="
echo "Test directory: $TEST_DIR"
echo ""

#------------------------------------------------------------------------------
# Test: Port availability checking
#------------------------------------------------------------------------------

echo "--- Port Functions ---"

test_start "is_port_available returns true for unused port"
if is_port_available 59999; then
    test_pass
else
    test_fail "port 59999 should be available"
fi

test_start "find_available_port finds a port"
PORT=$(find_available_port 7680)
if [ -n "$PORT" ] && [ "$PORT" -ge 7680 ]; then
    test_pass
else
    test_fail "should return port >= 7680, got: $PORT"
fi

test_start "find_consecutive_ports finds 3 consecutive ports"
PORT=$(find_consecutive_ports 7680 3)
if [ -n "$PORT" ] && [ "$PORT" -ge 7680 ]; then
    test_pass
else
    test_fail "should return port >= 7680, got: $PORT"
fi

#------------------------------------------------------------------------------
# Test: Atomic write
#------------------------------------------------------------------------------

echo ""
echo "--- Atomic Write ---"

test_start "atomic_write creates file"
atomic_write "$TEST_DIR/test.txt" "hello world"
if assert_file_exists "$TEST_DIR/test.txt" && [ "$(cat "$TEST_DIR/test.txt")" = "hello world" ]; then
    test_pass
else
    test_fail "file content mismatch"
fi

test_start "atomic_write overwrites file"
atomic_write "$TEST_DIR/test.txt" "new content"
if [ "$(cat "$TEST_DIR/test.txt")" = "new content" ]; then
    test_pass
else
    test_fail "file not overwritten"
fi

test_start "atomic_write cleans up lock"
if [ ! -d "$TEST_DIR/.lock" ]; then
    test_pass
else
    test_fail "lock directory not removed"
fi

#------------------------------------------------------------------------------
# Test: Status parsing
#------------------------------------------------------------------------------

echo ""
echo "--- Status Protocol ---"

# Set up a mock .peer-sync
MOCK_PEER_SYNC="$TEST_DIR/mock-project/.peer-sync"
mkdir -p "$MOCK_PEER_SYNC"
echo "test-feature" > "$MOCK_PEER_SYNC/feature"
echo "work" > "$MOCK_PEER_SYNC/phase"
echo "duo" > "$MOCK_PEER_SYNC/mode"
echo "1" > "$MOCK_PEER_SYNC/round"

test_start "get_agent_status parses status correctly"
echo "working|1234567890|test message" > "$MOCK_PEER_SYNC/claude.status"
STATUS=$(get_agent_status "claude" "$MOCK_PEER_SYNC")
if assert_eq "$STATUS" "working"; then
    test_pass
else
    test_fail "got: $STATUS"
fi

test_start "get_agent_status returns unknown for missing file"
STATUS=$(get_agent_status "nonexistent" "$MOCK_PEER_SYNC")
if assert_eq "$STATUS" "unknown"; then
    test_pass
else
    test_fail "got: $STATUS"
fi

#------------------------------------------------------------------------------
# Test: Agent command generation
#------------------------------------------------------------------------------

echo ""
echo "--- Agent Commands ---"

test_start "get_agent_cmd for claude"
CMD=$(get_agent_cmd "claude")
if [[ "$CMD" == *"claude"* ]] && [[ "$CMD" == *"--dangerously-skip-permissions"* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "get_agent_cmd for codex with default thinking"
CMD=$(get_agent_cmd "codex")
if [[ "$CMD" == *"codex"* ]] && [[ "$CMD" == *"--yolo"* ]] && [[ "$CMD" == *"high"* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "get_agent_cmd for codex with low thinking"
CMD=$(get_agent_cmd "codex" "low")
if [[ "$CMD" == *"low"* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "get_agent_cmd for custom agent passes through"
CMD=$(get_agent_cmd "my-custom-agent")
if assert_eq "$CMD" "my-custom-agent"; then
    test_pass
else
    test_fail "got: $CMD"
fi

#------------------------------------------------------------------------------
# Test: Task file discovery
#------------------------------------------------------------------------------

echo ""
echo "--- Task File Discovery ---"

# Set up mock project structure
MOCK_PROJECT="$TEST_DIR/mock-project"
mkdir -p "$MOCK_PROJECT/docs"

test_start "find_task_file finds file in root"
echo "# Test Task" > "$MOCK_PROJECT/my-feature.md"
FOUND=$(find_task_file "$MOCK_PROJECT" "my-feature")
if [ "$FOUND" = "$MOCK_PROJECT/my-feature.md" ]; then
    test_pass
else
    test_fail "got: $FOUND"
fi

test_start "find_task_file finds file in docs/"
echo "# Docs Task" > "$MOCK_PROJECT/docs/docs-feature.md"
FOUND=$(find_task_file "$MOCK_PROJECT" "docs-feature")
if [ "$FOUND" = "$MOCK_PROJECT/docs/docs-feature.md" ]; then
    test_pass
else
    test_fail "got: $FOUND"
fi

test_start "find_task_file returns error for missing file"
if find_task_file "$MOCK_PROJECT" "nonexistent-feature" 2>/dev/null; then
    test_fail "should have failed"
else
    test_pass
fi

#------------------------------------------------------------------------------
# Test: Project root discovery
#------------------------------------------------------------------------------

echo ""
echo "--- Project Root Discovery ---"

test_start "get_project_root finds .peer-sync in current dir"
cd "$MOCK_PROJECT"
ROOT=$(PEER_SYNC="" get_project_root)
if [ "$ROOT" = "$MOCK_PROJECT" ]; then
    test_pass
else
    test_fail "got: $ROOT"
fi

test_start "get_project_root uses PEER_SYNC env var"
export PEER_SYNC="$MOCK_PEER_SYNC"
ROOT=$(get_project_root)
if [ "$ROOT" = "$TEST_DIR/mock-project" ]; then
    test_pass
else
    test_fail "got: $ROOT"
fi
unset PEER_SYNC

#------------------------------------------------------------------------------
# Test: Signal command
#------------------------------------------------------------------------------

echo ""
echo "--- Signal Command ---"

cd "$MOCK_PROJECT"

test_start "lib_cmd_signal writes status file"
lib_cmd_signal "claude" "done" "test complete" >/dev/null 2>&1
if [ -f "$MOCK_PEER_SYNC/claude.status" ]; then
    CONTENT=$(cat "$MOCK_PEER_SYNC/claude.status")
    if [[ "$CONTENT" == done\|*\|test\ complete ]]; then
        test_pass
    else
        test_fail "wrong content: $CONTENT"
    fi
else
    test_fail "status file not created"
fi

test_start "lib_cmd_signal rejects invalid status"
# Run in subshell because die() exits the process
if (lib_cmd_signal "claude" "invalid-status" 2>/dev/null); then
    test_fail "should have rejected invalid status"
else
    test_pass
fi

#------------------------------------------------------------------------------
# Test: Phase command
#------------------------------------------------------------------------------

echo ""
echo "--- Phase Command ---"

test_start "lib_cmd_phase reads phase file"
echo "review" > "$MOCK_PEER_SYNC/phase"
PHASE=$(lib_cmd_phase)
if assert_eq "$PHASE" "review"; then
    test_pass
else
    test_fail "got: $PHASE"
fi

#------------------------------------------------------------------------------
# Test: Feature command
#------------------------------------------------------------------------------

echo ""
echo "--- Feature/Mode Commands ---"

test_start "get_feature reads feature file"
FEATURE=$(get_feature)
if assert_eq "$FEATURE" "test-feature"; then
    test_pass
else
    test_fail "got: $FEATURE"
fi

test_start "get_mode reads mode file"
MODE=$(get_mode)
if assert_eq "$MODE" "duo"; then
    test_pass
else
    test_fail "got: $MODE"
fi

test_start "get_mode defaults to duo when file missing"
rm -f "$MOCK_PEER_SYNC/mode"
MODE=$(get_mode)
if assert_eq "$MODE" "duo"; then
    test_pass
else
    test_fail "got: $MODE"
fi

#------------------------------------------------------------------------------
# Test: Escalation helpers
#------------------------------------------------------------------------------

echo ""
echo "--- Escalation Helpers ---"

test_start "has_pending_escalations returns false when none"
rm -f "$MOCK_PEER_SYNC"/escalation-*.md
if has_pending_escalations "$MOCK_PEER_SYNC" >/dev/null; then
    test_fail "should return false"
else
    test_pass
fi

test_start "has_pending_escalations returns true when present"
echo "# Test escalation" > "$MOCK_PEER_SYNC/escalation-claude.md"
if has_pending_escalations "$MOCK_PEER_SYNC" >/dev/null; then
    test_pass
else
    test_fail "should return true"
fi
rm -f "$MOCK_PEER_SYNC/escalation-claude.md"

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
    exit 1
else
    exit 0
fi
