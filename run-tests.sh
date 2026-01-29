#!/bin/bash
# Test runner for agent-duo
#
# Usage:
#   ./run-tests.sh          # Run unit tests only (fast, no external deps)
#   ./run-tests.sh --all    # Run unit + integration tests (requires CLIs)
#   ./run-tests.sh --quick  # Run unit + quick integration tests
#   ./run-tests.sh unit     # Run only unit tests
#   ./run-tests.sh integration [--quick]  # Run only integration tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}"; }

usage() {
    cat << EOF
agent-duo test runner

Usage: ./run-tests.sh [command] [options]

Commands:
  (none)        Run unit tests only (default, fast)
  unit          Run unit tests only
  integration   Run integration tests (requires real CLIs)
  --all         Run both unit and integration tests
  --quick       Run unit tests + quick integration tests

Options for integration tests:
  --quick       Run minimal integration tests only

Examples:
  ./run-tests.sh              # Fast: unit tests only
  ./run-tests.sh --all        # Full: unit + integration
  ./run-tests.sh --quick      # Medium: unit + quick integration
  ./run-tests.sh integration  # Integration tests only
  ./run-tests.sh integration --quick  # Quick integration only

Prerequisites for integration tests:
  - claude CLI installed and authenticated
  - codex CLI installed and authenticated
  - gh CLI installed and authenticated
  - ~/agent-duo-testing repository cloned
EOF
}

run_unit_tests() {
    info "═══════════════════════════════════════════════════════════════"
    info " Running Unit Tests"
    info "═══════════════════════════════════════════════════════════════"
    echo ""

    if [ -x "$TESTS_DIR/unit.t" ]; then
        if "$TESTS_DIR/unit.t"; then
            success "Unit tests passed!"
            return 0
        else
            error "Unit tests failed!"
            return 1
        fi
    else
        error "Unit test file not found or not executable: $TESTS_DIR/unit.t"
        return 1
    fi
}

run_integration_tests() {
    local quick_flag=""
    if [ "$1" = "--quick" ]; then
        quick_flag="--quick"
    fi

    info "═══════════════════════════════════════════════════════════════"
    info " Running Integration Tests ${quick_flag:+(quick mode)}"
    info "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check prerequisites
    if [ ! -d "$HOME/agent-duo-testing" ]; then
        error "Integration tests require ~/agent-duo-testing repository"
        echo "Clone it with: gh repo clone lukstafi/agent-duo-testing ~/agent-duo-testing"
        return 1
    fi

    if ! command -v claude >/dev/null 2>&1; then
        error "Integration tests require claude CLI"
        return 1
    fi

    if ! command -v codex >/dev/null 2>&1; then
        error "Integration tests require codex CLI"
        return 1
    fi

    if [ -x "$TESTS_DIR/integration.t" ]; then
        if "$TESTS_DIR/integration.t" $quick_flag; then
            success "Integration tests passed!"
            return 0
        else
            error "Integration tests failed!"
            return 1
        fi
    else
        error "Integration test file not found or not executable: $TESTS_DIR/integration.t"
        return 1
    fi
}

# Parse arguments
RUN_UNIT=false
RUN_INTEGRATION=false
INTEGRATION_QUICK=false

case "${1:-}" in
    ""|unit)
        RUN_UNIT=true
        ;;
    integration)
        RUN_INTEGRATION=true
        [ "$2" = "--quick" ] && INTEGRATION_QUICK=true
        ;;
    --all)
        RUN_UNIT=true
        RUN_INTEGRATION=true
        ;;
    --quick)
        RUN_UNIT=true
        RUN_INTEGRATION=true
        INTEGRATION_QUICK=true
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        error "Unknown command: $1"
        usage
        exit 1
        ;;
esac

# Run tests
UNIT_RESULT=0
INTEGRATION_RESULT=0

echo ""
info "agent-duo test suite"
info "===================="
echo ""

if [ "$RUN_UNIT" = true ]; then
    run_unit_tests || UNIT_RESULT=1
    echo ""
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$INTEGRATION_QUICK" = true ]; then
        run_integration_tests --quick || INTEGRATION_RESULT=1
    else
        run_integration_tests || INTEGRATION_RESULT=1
    fi
    echo ""
fi

# Summary
info "═══════════════════════════════════════════════════════════════"
info " Test Summary"
info "═══════════════════════════════════════════════════════════════"
echo ""

if [ "$RUN_UNIT" = true ]; then
    if [ "$UNIT_RESULT" -eq 0 ]; then
        success "  Unit tests:        PASSED"
    else
        error "  Unit tests:        FAILED"
    fi
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$INTEGRATION_RESULT" -eq 0 ]; then
        success "  Integration tests: PASSED"
    else
        error "  Integration tests: FAILED"
    fi
fi

echo ""

# Exit with failure if any tests failed
if [ "$UNIT_RESULT" -ne 0 ] || [ "$INTEGRATION_RESULT" -ne 0 ]; then
    exit 1
fi

success "All tests passed!"
exit 0
