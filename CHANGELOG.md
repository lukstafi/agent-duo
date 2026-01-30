# Changelog

All notable changes to agent-duo will be documented in this file.

## [Unreleased]

## [v0.2] - 2026-01-30

### Added
- `agent-duo merge` command for consolidating duo PRs into main branch
  - Vote-based workflow with debate mechanism when agents disagree
  - Three trigger modes: auto-restart, interactive review, and manual execute
  - Versioned vote files for complete audit trail
  - `--auto-restart` flag for automatic session continuation
  - Explicit APPROVED keyword requirement for merge review approval
- PR comment monitoring phase after PRs are created
  - Auto-trigger pr-comment skill on first entry if PR has reviews
  - Fetch inline code review comments via `gh api`
  - Shared `fetch-pr-feedback.sh` script for both duo and solo modes
  - Require PR comment when declining to make changes from feedback
  - Preserve PR comment hash baseline across session restarts
- `agent-solo restart` command for session recovery after system restart
- `--port` flag for configurable consecutive port allocation
- Test infrastructure with unit and integration tests
- `duo-amend` skill and require review before session completion
- `escalate` command for agents to flag blocking issues

### Changed
- Require Bash 4+ and use `#!/usr/bin/env bash` for macOS compatibility
- Use only Escape to interrupt agents, not Ctrl-C
- Cleanup command now removes session state only by default
- Refactored `restart_agent_tui` in agent-lib.sh to be generic (works for both duo and solo modes)
- Doubled default timeouts for agent operations

### Fixed
- macOS compatibility issues
- Add missing `--yolo` flag to Codex resume command
- Fix undefined CLAUDE_CMD variable in agent-duo
- Fix session restart and resume behavior
- Fail early if session exists when starting new session
- Remove duplicate env var exports in restart_agent_tui

## [v0.1] - 2025-01-24

Initial release with core functionality:

### Added
- Unified `agent-duo` CLI with commands: `start`, `stop`, `status`, `pr`, `cleanup`, `setup`
- Template-based skills system for Claude and Codex agents
- Orchestrator with automatic timeout-based interrupts
- Web terminal support via ttyd (default for `agent-duo start`)
- `--auto-run` flag for one-step session launch
- Completion hooks for reliable agent status signaling
- Optional `--clarify` phase for agent approach proposals
- Optional `--pushback` stage for task improvement proposals
- `restart` command for session recovery after system restart
- `doctor` command for system health checks
- `escalate` command for agents to flag blocking issues
- `agent-solo` mode for coder/reviewer workflow
- ntfy.sh push notification support with token authentication
- Configurable model selection via `--codex-model` and `--claude-model` flags
- Configurable Codex thinking effort (default: high)
- Dynamic port allocation for overlapping executions
- Auto-detect PRs created via `gh pr create`
- Auto-delete unmodified feature files in `pr` command
- TUI exit detection in orchestrator polling loops
- Codex auto-resume and pre-trigger TUI health check

### Architecture
- Feature-based naming: `<project>-<feature>-<agent>` for worktrees
- Coordination via `.peer-sync/` state files with mkdir-based locking
- Status format: `status|epoch|message`
- Phase workflow: `work` → `review` → `work` (repeat until PRs created)
