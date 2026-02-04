# Changelog

All notable changes to agent-duo will be documented in this file.

## [Unreleased]

## [v0.3] - 2026-02-04

### Added
- **Parallel task execution**: Run multiple features simultaneously
  - `agent-duo start feat1 feat2 feat3` creates isolated sessions for each
  - Central `.agent-sessions/` registry tracks active sessions
  - `--feature` flag to target specific session in multi-session context
- **Auto-finish mode** (`--auto-finish`): Fully unattended session completion
  - Auto-triggers merge phase after inactivity timeout (default 30 min)
  - With 2 open PRs: triggers merge voting phase
  - With 1 open PR: triggers final rebase and merge
  - New `duo-final-merge` and `solo-final-merge` skills for automated merging
- **Integrate phase**: Automatic rebase when main branch advances
  - Detects when parallel sessions need rebasing after a PR merges
  - New `duo-integrate` and `solo-integrate` skills
  - Orchestrator polls origin/main and triggers integration automatically
- **Plan/plan-review phase** (`--plan`): Agents write implementation plans
  - Agents write plans to `.peer-sync/plan-<agent>.md`
  - Peer review of plans before work begins
  - New skills: `duo-plan`, `duo-plan-review`, `solo-coder-plan`, `solo-reviewer-plan`
- **Gather phase** for solo mode (`--gather`): Reviewer collects task context
  - Reviewer explores codebase and writes `task-context.md` for coder
  - New `solo-reviewer-gather` skill
- **Unified agent communication** with API error retry
  - Automatic retry on 500/429 errors with exponential backoff
  - New `send_to_agent`, `retry_last_send` helper functions

### Changed
- Stale PR detection: `has_pr()` verifies commit ancestry to handle recycled branch names
- `cleanup --full` now also deletes remote branches
- **Breaking**: Unified session architecture - all sessions now use root worktree model
  - Legacy sessions with `.peer-sync/` in main project root no longer supported
  - Users must cleanup and re-start existing sessions
- Refactored `cmd_pr` to use shared `lib_create_pr` in agent-lib.sh

### Fixed
- Fix `has_pr` to work from any directory and after rebases
- Workflow feedback now persisted in solo mode (moved to shared lib)
- Fix final-merge phase: add missing status and worktree-safe merge
- Fix merge phase to work in winning worktree instead of main
- Fix spurious `/solo-pr-comment` triggers after rebase
- Fix duplicate TUI startup command in restart flow
- Fix undefined `DEFAULT_TIMEOUT` in integration loop
- Fix cleanup `--full` for legacy sessions with missing worktrees
- Fix non-existent `send_notification` calls in merge phase
- Disable Codex update prompts in automated sessions (`check_for_update_on_startup=false`)

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
