#!/usr/bin/env bash
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

test_start "get_agent_status_epoch parses epoch correctly"
EPOCH=$(get_agent_status_epoch "claude" "$MOCK_PEER_SYNC")
if assert_eq "$EPOCH" "1234567890"; then
    test_pass
else
    test_fail "got: $EPOCH"
fi

test_start "get_agent_status_epoch returns 0 for missing file"
EPOCH=$(get_agent_status_epoch "nonexistent" "$MOCK_PEER_SYNC")
if assert_eq "$EPOCH" "0"; then
    test_pass
else
    test_fail "got: $EPOCH"
fi

#------------------------------------------------------------------------------
# Test: Phase token/state helper
#------------------------------------------------------------------------------

echo ""
echo "--- Phase State ---"

PHASE_SYNC="$TEST_DIR/phase-sync"
mkdir -p "$PHASE_SYNC"

test_start "set_phase_state writes phase and round-aware token"
echo "3" > "$PHASE_SYNC/round"
set_phase_state "$PHASE_SYNC" "review"
PHASE="$(cat "$PHASE_SYNC/phase")"
TOKEN="$(cat "$PHASE_SYNC/phase-token")"
SEQ="$(cat "$PHASE_SYNC/phase-seq")"
if [ "$PHASE" = "review" ] && [ "$TOKEN" = "review|r3|s1" ] && [ "$SEQ" = "1" ]; then
    test_pass
else
    test_fail "phase=$PHASE token=$TOKEN seq=$SEQ"
fi

test_start "set_phase_state increments sequence for next phase"
set_phase_state "$PHASE_SYNC" "work"
TOKEN="$(cat "$PHASE_SYNC/phase-token")"
SEQ="$(cat "$PHASE_SYNC/phase-seq")"
if [ "$TOKEN" = "work|r3|s2" ] && [ "$SEQ" = "2" ]; then
    test_pass
else
    test_fail "token=$TOKEN seq=$SEQ"
fi

test_start "set_phase_state supports explicit round override"
set_phase_state "$PHASE_SYNC" "plan" "9"
TOKEN="$(cat "$PHASE_SYNC/phase-token")"
SEQ="$(cat "$PHASE_SYNC/phase-seq")"
if [ "$TOKEN" = "plan|r9|s3" ] && [ "$SEQ" = "3" ]; then
    test_pass
else
    test_fail "token=$TOKEN seq=$SEQ"
fi

test_start "set_phase_state falls back to round 0 for invalid round"
echo "not-a-number" > "$PHASE_SYNC/round"
set_phase_state "$PHASE_SYNC" "clarify"
TOKEN="$(cat "$PHASE_SYNC/phase-token")"
SEQ="$(cat "$PHASE_SYNC/phase-seq")"
if [ "$TOKEN" = "clarify|r0|s4" ] && [ "$SEQ" = "4" ]; then
    test_pass
else
    test_fail "token=$TOKEN seq=$SEQ"
fi

test_start "append_event writes structured JSON line"
append_event "$PHASE_SYNC" "unit_test_event" "unit-test" "claude" "working" "hello event log"
if assert_file_exists "$PHASE_SYNC/events.jsonl"; then
    if command -v jq >/dev/null 2>&1; then
        if jq -e '(.event_type == "unit_test_event") and (.source == "unit-test") and (.agent == "claude") and (.status == "working")' "$PHASE_SYNC/events.jsonl" >/dev/null 2>&1; then
            test_pass
        else
            test_fail "events.jsonl does not contain expected structured payload"
        fi
    elif grep -q "unit_test_event" "$PHASE_SYNC/events.jsonl"; then
        test_pass
    else
        test_fail "events.jsonl missing expected event content"
    fi
else
    test_fail "events.jsonl not created"
fi

test_start "set_phase_state appends phase_transition event"
set_phase_state "$PHASE_SYNC" "work"
if command -v jq >/dev/null 2>&1; then
    if tail -n 5 "$PHASE_SYNC/events.jsonl" | jq -e 'select(.event_type == "phase_transition" and .status == "work")' >/dev/null 2>&1; then
        test_pass
    else
        test_fail "phase_transition event not found"
    fi
elif grep -q "phase_transition" "$PHASE_SYNC/events.jsonl"; then
    test_pass
else
    test_fail "phase_transition event missing"
fi

test_start "append_event degrades gracefully when events lock is held"
mkdir -p "$PHASE_SYNC/.events.lock"
before_lines=$(wc -l < "$PHASE_SYNC/events.jsonl" 2>/dev/null || echo 0)
EVENT_LOG_LOCK_TIMEOUT_MS=20 append_event "$PHASE_SYNC" "locked_event" "unit-test" "codex" "working" "should skip due to lock"
after_lines=$(wc -l < "$PHASE_SYNC/events.jsonl" 2>/dev/null || echo 0)
rmdir "$PHASE_SYNC/.events.lock" 2>/dev/null || true
if [ "$before_lines" = "$after_lines" ]; then
    test_pass
else
    test_fail "event appended despite held lock (before=$before_lines after=$after_lines)"
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

FLAGS_SYNC="$TEST_DIR/flags-sync"
mkdir -p "$FLAGS_SYNC"

test_start "get_agent_cmd appends claude passthrough flags from PEER_SYNC"
echo '--allowedTools Bash,Read' > "$FLAGS_SYNC/claude-flags"
CMD=$(PEER_SYNC="$FLAGS_SYNC" get_agent_cmd "claude")
if [[ "$CMD" == *"--allowedTools Bash,Read"* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "get_agent_cmd appends codex passthrough flags from PEER_SYNC"
echo '--provider openai' > "$FLAGS_SYNC/codex-flags"
CMD=$(PEER_SYNC="$FLAGS_SYNC" get_agent_cmd "codex" "medium")
if [[ "$CMD" == *"--provider openai"* ]] && [[ "$CMD" == *"model_reasoning_effort=\"medium\""* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "get_agent_cmd ignores empty passthrough file"
: > "$FLAGS_SYNC/claude-flags"
CMD=$(PEER_SYNC="$FLAGS_SYNC" get_agent_cmd "claude")
if [[ "$CMD" != *"--allowedTools Bash,Read"* ]]; then
    test_pass
else
    test_fail "got: $CMD"
fi

test_start "is_valid_codex_resume_key accepts UUID-shaped key"
if is_valid_codex_resume_key "123e4567-e89b-12d3-a456-426614174000"; then
    test_pass
else
    test_fail "valid UUID-shaped resume key rejected"
fi

test_start "is_valid_codex_resume_key rejects non-UUID key"
if is_valid_codex_resume_key "not-a-real-resume-key" >/dev/null 2>&1; then
    test_fail "non-UUID resume key accepted"
else
    test_pass
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

test_start "find_task_file prefers docs/ when both docs and root exist"
echo "# Root Preferred?" > "$MOCK_PROJECT/prefer-docs.md"
echo "# Docs Preferred" > "$MOCK_PROJECT/docs/prefer-docs.md"
FOUND=$(find_task_file "$MOCK_PROJECT" "prefer-docs")
if [ "$FOUND" = "$MOCK_PROJECT/docs/prefer-docs.md" ]; then
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
# Test: Task file commit-on-start helper
#------------------------------------------------------------------------------

echo ""
echo "--- Task File Commit Helper ---"

TASK_GIT_REPO="$TEST_DIR/task-git"
mkdir -p "$TASK_GIT_REPO"
git -C "$TASK_GIT_REPO" init -q
git -C "$TASK_GIT_REPO" config user.name "Unit Test"
git -C "$TASK_GIT_REPO" config user.email "unit@example.com"
echo "seed" > "$TASK_GIT_REPO/README.md"
git -C "$TASK_GIT_REPO" add README.md
git -C "$TASK_GIT_REPO" commit -q -m "seed"

test_start "sync_branch_with_remote no-ops when upstream is missing"
if sync_branch_with_remote "$TASK_GIT_REPO" "unit test without upstream" >/dev/null 2>&1; then
    test_pass
else
    test_fail "sync should succeed without upstream"
fi

SYNC_REMOTE="$TEST_DIR/sync-remote.git"
SYNC_MAIN="$TEST_DIR/sync-main"
SYNC_OTHER="$TEST_DIR/sync-other"
git init --bare -q "$SYNC_REMOTE"
git clone -q "$SYNC_REMOTE" "$SYNC_MAIN"
git -C "$SYNC_MAIN" config user.name "Unit Test"
git -C "$SYNC_MAIN" config user.email "unit@example.com"
echo "base" > "$SYNC_MAIN/sync.txt"
git -C "$SYNC_MAIN" add sync.txt
git -C "$SYNC_MAIN" commit -q -m "base commit"
git -C "$SYNC_MAIN" push -q -u origin HEAD

git clone -q "$SYNC_REMOTE" "$SYNC_OTHER"
git -C "$SYNC_OTHER" config user.name "Unit Test"
git -C "$SYNC_OTHER" config user.email "unit@example.com"
echo "remote update" >> "$SYNC_OTHER/sync.txt"
git -C "$SYNC_OTHER" add sync.txt
git -C "$SYNC_OTHER" commit -q -m "remote update"
git -C "$SYNC_OTHER" push -q origin HEAD

test_start "sync_branch_with_remote rebases onto latest upstream"
SYNC_BEFORE="$(git -C "$SYNC_MAIN" rev-parse HEAD)"
sync_branch_with_remote "$SYNC_MAIN" "unit test with upstream update" >/dev/null
SYNC_AFTER="$(git -C "$SYNC_MAIN" rev-parse HEAD)"
if [ "$SYNC_BEFORE" != "$SYNC_AFTER" ] && grep -Fq "remote update" "$SYNC_MAIN/sync.txt"; then
    test_pass
else
    test_fail "expected sync-main to fast-forward/rebase to include remote update"
fi

MERGE_REMOTE="$TEST_DIR/merge-remote.git"
MERGE_MAIN="$TEST_DIR/merge-main"
MERGE_WORKTREE="$TEST_DIR/merge-worktree"
MERGE_OTHER="$TEST_DIR/merge-other"
git init --bare -q "$MERGE_REMOTE"
git clone -q "$MERGE_REMOTE" "$MERGE_MAIN"
git -C "$MERGE_MAIN" config user.name "Unit Test"
git -C "$MERGE_MAIN" config user.email "unit@example.com"
echo "base" > "$MERGE_MAIN/merge.txt"
git -C "$MERGE_MAIN" add merge.txt
git -C "$MERGE_MAIN" commit -q -m "base commit"
git -C "$MERGE_MAIN" push -q -u origin HEAD
git -C "$MERGE_MAIN" worktree add -q -b feature "$MERGE_WORKTREE"

git clone -q "$MERGE_REMOTE" "$MERGE_OTHER"
git -C "$MERGE_OTHER" config user.name "Unit Test"
git -C "$MERGE_OTHER" config user.email "unit@example.com"
echo "remote update" >> "$MERGE_OTHER/merge.txt"
git -C "$MERGE_OTHER" add merge.txt
git -C "$MERGE_OTHER" commit -q -m "remote update"
git -C "$MERGE_OTHER" push -q origin HEAD

test_start "sync_main_after_merge updates the main checkout from a worktree"
MERGE_BEFORE="$(git -C "$MERGE_MAIN" rev-parse HEAD)"
(
    cd "$MERGE_WORKTREE" || exit 1
    sync_main_after_merge main
) >/dev/null 2>&1
MERGE_AFTER="$(git -C "$MERGE_MAIN" rev-parse HEAD)"
REMOTE_HEAD="$(git -C "$MERGE_MAIN" rev-parse origin/main)"
if [ "$MERGE_BEFORE" != "$MERGE_AFTER" ] && [ "$MERGE_AFTER" = "$REMOTE_HEAD" ] && grep -Fq "remote update" "$MERGE_MAIN/merge.txt"; then
    test_pass
else
    test_fail "expected merge-main to fast-forward to origin/main"
fi

echo "local only" > "$MERGE_MAIN/local-only.txt"
git -C "$MERGE_MAIN" add local-only.txt
git -C "$MERGE_MAIN" commit -q -m "local only"
echo "remote second update" > "$MERGE_OTHER/remote-second.txt"
git -C "$MERGE_OTHER" add remote-second.txt
git -C "$MERGE_OTHER" commit -q -m "remote second update"
git -C "$MERGE_OTHER" push -q origin HEAD

test_start "sync_main_after_merge falls back to merge when fast-forward fails"
(
    cd "$MERGE_WORKTREE" || exit 1
    sync_main_after_merge main
) >/dev/null 2>&1
PARENT_COUNT="$(git -C "$MERGE_MAIN" rev-list --parents -n 1 HEAD | awk '{print NF-1}')"
if [ "$PARENT_COUNT" = "2" ] && [ -f "$MERGE_MAIN/local-only.txt" ] && [ -f "$MERGE_MAIN/remote-second.txt" ]; then
    test_pass
else
    test_fail "expected merge-main to create a merge commit containing local and remote changes"
fi

test_start "ensure_task_file_committed commits untracked root task file"
echo "# Root Task" > "$TASK_GIT_REPO/root-task.md"
ensure_task_file_committed "$TASK_GIT_REPO" "root-task" "duo" >/dev/null
LAST_MSG="$(git -C "$TASK_GIT_REPO" log -1 --pretty=%s)"
if [ "$LAST_MSG" = "root-task.md: agent-duo" ] && \
   git -C "$TASK_GIT_REPO" ls-files --error-unmatch root-task.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "task file was not committed with expected message"
fi

test_start "ensure_task_file_committed keeps docs task file location and commits for pair"
mkdir -p "$TASK_GIT_REPO/docs"
echo "# Docs Task" > "$TASK_GIT_REPO/docs/docs-task.md"
ensure_task_file_committed "$TASK_GIT_REPO" "docs-task" "pair" >/dev/null
LAST_MSG="$(git -C "$TASK_GIT_REPO" log -1 --pretty=%s)"
if [ "$LAST_MSG" = "docs-task.md: agent-pair" ] && \
   [ ! -f "$TASK_GIT_REPO/docs-task.md" ] && \
   git -C "$TASK_GIT_REPO" ls-files --error-unmatch docs/docs-task.md >/dev/null 2>&1 && \
   ! git -C "$TASK_GIT_REPO" ls-files --error-unmatch docs-task.md >/dev/null 2>&1; then
    test_pass
else
    test_fail "docs task location/commit behavior was not preserved as expected"
fi

#------------------------------------------------------------------------------
# Test: Follow-up task generation
#------------------------------------------------------------------------------

echo ""
echo "--- Follow-up Task Generation ---"

MOCK_BIN_DIR="$TEST_DIR/mock-bin"
mkdir -p "$MOCK_BIN_DIR"
cat > "$MOCK_BIN_DIR/gh" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = "pr" ] && [ "$2" = "view" ] && [ "$3" = "42" ]; then
    cat << 'JSON'
{
  "title": "Improve auth flow",
  "body": "Original PR description.",
  "url": "https://github.com/example/repo/pull/42",
  "headRefName": "auth-codex",
  "comments": [
    {
      "author": {"login": "reviewer1"},
      "createdAt": "2026-02-20T10:00:00Z",
      "body": "Please fix login validation."
    }
  ],
  "reviews": [
    {
      "author": {"login": "reviewer2"},
      "state": "CHANGES_REQUESTED",
      "createdAt": "2026-02-20T11:00:00Z",
      "body": "Add tests for the new behavior."
    }
  ]
}
JSON
else
    echo "unexpected gh invocation: $*" >&2
    exit 1
fi
EOF
chmod +x "$MOCK_BIN_DIR/gh"

ORIG_PATH="$PATH"
export PATH="$MOCK_BIN_DIR:$PATH"

test_start "generate_followup_task creates task file from PR data"
if FOLLOWUP_FEATURE="$(generate_followup_task "$MOCK_PROJECT" "42")" && \
   assert_eq "$FOLLOWUP_FEATURE" "auth-followup" && \
   assert_file_exists "$MOCK_PROJECT/docs/auth-followup.md" && \
   grep -Fq "# Follow-up: Improve auth flow" "$MOCK_PROJECT/docs/auth-followup.md" && \
   grep -Fq "Please fix login validation." "$MOCK_PROJECT/docs/auth-followup.md" && \
   grep -Fq "Add tests for the new behavior." "$MOCK_PROJECT/docs/auth-followup.md"; then
    test_pass
else
    test_fail "generated follow-up task content mismatch"
fi

test_start "generate_followup_task prepends followup message as first line"
if FOLLOWUP_FEATURE="$(generate_followup_task "$MOCK_PROJECT" "42" "PRIORITY: fix blocker comments first")" && \
   FIRST_LINE="$(head -n 1 "$MOCK_PROJECT/docs/${FOLLOWUP_FEATURE}.md")" && \
   assert_eq "$FIRST_LINE" "PRIORITY: fix blocker comments first"; then
    test_pass
else
    test_fail "follow-up message was not prepended"
fi

MOCK_PROJECT_NO_DOCS="$TEST_DIR/mock-project-no-docs"
mkdir -p "$MOCK_PROJECT_NO_DOCS"

test_start "generate_followup_task writes to project root when docs/ is absent"
if FOLLOWUP_FEATURE="$(generate_followup_task "$MOCK_PROJECT_NO_DOCS" "42")" && \
   assert_file_exists "$MOCK_PROJECT_NO_DOCS/${FOLLOWUP_FEATURE}.md"; then
    test_pass
else
    test_fail "follow-up task was not written to project root when docs/ was absent"
fi

export PATH="$ORIG_PATH"

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
# Test: Workflow feedback relevance normalization
#------------------------------------------------------------------------------

echo ""
echo "--- Workflow Feedback Relevance ---"

TEMPLATE_FEEDBACK="$TEST_DIR/workflow-template.md"
cat > "$TEMPLATE_FEEDBACK" << 'EOF'
# Workflow feedback (claude) - feature - 2026-02-21

- [Actionable feedback about agent-duo workflow/skills/tooling]
- [Another specific, actionable point]
EOF

ACTIONABLE_A="$TEST_DIR/workflow-actionable-a.md"
cat > "$ACTIONABLE_A" << 'EOF'
# Workflow feedback (codex) - feature - 2026-02-21

- Improve phase handoff instructions for clarify -> work.
- Add exact command examples for follow-up task generation.
EOF

ACTIONABLE_B="$TEST_DIR/workflow-actionable-b.md"
cat > "$ACTIONABLE_B" << 'EOF'
# Workflow feedback (coder) - other-feature - 2026-02-22

* Improve phase handoff instructions for clarify -> work.
* Add exact command examples for follow-up task generation.
EOF

test_start "normalize_workflow_feedback strips template placeholders"
NORMALIZED="$(normalize_workflow_feedback "$TEMPLATE_FEEDBACK" || true)"
if [ -z "$NORMALIZED" ]; then
    test_pass
else
    test_fail "expected empty normalized template feedback, got: $NORMALIZED"
fi

test_start "workflow_feedback_hash rejects placeholder-only feedback"
if workflow_feedback_hash "$TEMPLATE_FEEDBACK" >/dev/null 2>&1; then
    test_fail "placeholder-only feedback should not produce a relevance hash"
else
    test_pass
fi

test_start "workflow_feedback_hash normalizes equivalent actionable content"
HASH_A="$(workflow_feedback_hash "$ACTIONABLE_A" 2>/dev/null || true)"
HASH_B="$(workflow_feedback_hash "$ACTIONABLE_B" 2>/dev/null || true)"
if [ -n "$HASH_A" ] && [ "$HASH_A" = "$HASH_B" ]; then
    test_pass
else
    test_fail "expected matching hashes, got A='$HASH_A' B='$HASH_B'"
fi

#------------------------------------------------------------------------------
# Test: Final merge templates
#------------------------------------------------------------------------------

echo ""
echo "--- Final Merge Templates ---"

DUO_FINAL_TEMPLATE="$REPO_ROOT/skills/templates/duo-final-merge.md"
PAIR_FINAL_TEMPLATE="$REPO_ROOT/skills/templates/pair-final-merge.md"

test_start "duo final-merge template syncs the main checkout after merge"
if grep -Fq 'sync_main_after_merge "$(get_main_branch "$PEER_SYNC")"' "$DUO_FINAL_TEMPLATE" && \
   grep -Fq "refresh the main checkout explicitly after the remote merge" "$DUO_FINAL_TEMPLATE"; then
    test_pass
else
    test_fail "duo final-merge template is missing the post-merge main sync step"
fi

test_start "pair final-merge template syncs the main checkout after merge"
if grep -Fq 'sync_main_after_merge "$(get_main_branch "$PEER_SYNC")"' "$PAIR_FINAL_TEMPLATE" && \
   grep -Fq "refresh the main checkout explicitly after the remote merge" "$PAIR_FINAL_TEMPLATE"; then
    test_pass
else
    test_fail "pair final-merge template is missing the post-merge main sync step"
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
