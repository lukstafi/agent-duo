# Changelog

All notable changes to agent-duo will be documented in this file.

## [Unreleased]

## [v0.7] - 2026-02-21

### Added
- **`--followup-msg` support in follow-up starts**: `agent-duo start --followup <PR#> --followup-msg "<message>"` and `agent-pair` equivalent now prepend a custom line to generated follow-up tasks
- **Shared phase preflight context helper**: work/review/amend skills now run a common preflight step that surfaces latest peer review context, peer status, and `git diff --stat main...HEAD`

### Changed
- **Keep feature spec docs committed on start**: `agent-duo`/`agent-pair` now normalize and commit `<feature>.md` before spawning worktrees, and no longer delete the spec copy during session startup
- **Phase transitions now emit coordination tokens**: orchestrator writes `phase`, `phase-seq`, and `phase-token` so hooks can deduplicate stale transitions
- **Notify hook is now advisory and race-safe**: unified duo/pair notify flow records transition advice and nudges agents with the recommended `agent-* signal` command instead of mutating status directly
- **Round transitions are restart-safe**: orchestrator persists next-round state immediately after a completed cycle so restart resumes cleanly at the next round

### Fixed
- **Non-clarify timeout paths now interrupt explicitly**: pushback/plan/plan-review/work/review/docs-update/pr-comments/merge/final-merge timeout paths issue interrupts instead of drifting
- **Phase completion logs final wait status before exit**: round loops now print final wait state before breaking, improving timeout/debug visibility
- **Codex resume-key persistence is validated**: launcher stores Codex resume keys only when they match expected UUID format
- **Agent restart path reuses launch defaults**: restarted sessions now preserve the same launch defaults used by fresh sessions

## [v0.6] - 2026-02-19

### Added
- **`--claude` / `--codex` shorthand flags** for `agent-pair start`: `--claude` sets coder=claude/reviewer=codex, `--codex` sets the reverse
- **Task file auto-send** in `agent-claude`/`agent-codex`: launchers find `<task>.md` and send its contents as the initial prompt (large files >3KB send a path reference instead)
- **Extra CLI argument forwarding** in `agent-claude`/`agent-codex`: use `-- <args>` to pass additional flags (e.g. `--chrome`) to the underlying CLI; args persist across restarts

### Changed
- **Breaking**: Renamed `agent-solo` → `agent-pair` and all `solo-*` skills → `pair-*` skills. "Pair" better describes the coder+reviewer collaboration mode.
- **Breaking**: `agent-pair start` no longer defaults coder/reviewer — must specify `--claude`, `--codex`, or both `--coder`/`--reviewer`
- Removed `--ide` access mode from `agent-launch` (unreliable: Codex doesn't support it, only one Claude Code terminal can connect to IDE at a time)

## [v0.5] - 2026-02-15

### Added
- **`--followup` flag**: Convert observations from an existing PR into a new task with `agent-duo start --followup <PR-number>` and `agent-pair start --followup <PR-number>`
- **Feedback-digest pipeline**: Automatically file structured GitHub issues from agent feedback via ludics
- **High-priority ntfy notification** when merge vote reaches no consensus
- **`update-docs` phase** for pair mode

### Changed
- **Orchestrator-driven commits and PR creation**: Quiescence detection triggers automatic commits and PR creation instead of relying on agents
- **Diff-gated reviews**: Skip redundant reviews when peer had no changes
- Reduced cognitive load in skill templates
- Reorganized implemented feature spec docs into task-spec living design docs
- Hardened quiescence detection for in-phase commits

### Fixed
- Fix race condition in suggest-refactor: Stop hook signals done before file is written
- Guard all file-producing hook phases against cross-phase race condition
- Replace 5-second sleep heuristic with phase-tracking guard in Stop hook
- Fix merge-phase skill discovery: install skills to root worktree
- Fix `gh pr view` calls to use `--json` and avoid deprecated `projectCards` query
- Guard tmux `send-keys` against copy-mode crash under `set -e`
- Fix merge consensus not detected after final debate round
- Fix PR comment feedback loop and feature file deletion of repo files
- Silence expected hook log noise for cross-phase race and pr-comments phase
- Fix convergence detection: decouple from PR status, let converged agents review
- Fix `lib_commit_round` stdout contamination breaking review and convergence detection
- Fix round-1 fallbacks in skill templates and unquote heredoc delimiters

## [v0.4] - 2026-02-13

### Added
- **Standalone agent launchers**: `agent-claude` and `agent-codex` commands for managed tmux sessions without orchestration
  - Shared `agent-launch` script with `--ide`/`--ttyd`/`--bare` access modes
  - Optional `--branch` flag for automatic git worktree creation
  - Prefix-isolated session state (`claude-*`/`codex-*`) in `.agent-sessions/`
- **Suggest-refactor post-merge phase**: After a PR is merged, agents reflect on what they'd do differently
  - Suggestions saved locally, posted as PR comment, and sent via ntfy
- **"Proceed to merge" PR comment trigger** in pair mode (consistent with duo mode)
- **Local skills**: Skills installed per-project instead of globally (#7)
  - `doctor` command updated to check templates instead of global skills
- **Descriptive terminal/browser titles** for all agent sessions
  - Titles show "agent: task" in VS Code terminal tabs and ttyd browser tabs
- **Multi-agent enhancement proposal** for Claude sub-agents and teams

### Changed
- Increased phase timeouts: work 20m→1h, review 10m→30m, vote 10m→3h, debate 5m→40m
- Vote/debate timeouts now gracefully interrupt agents and create synthetic votes instead of killing the session
- Namespace duo/pair registry entries (`duo-*`/`pair-*`) with unified cross-type status display
- Push current branch at start to avoid PRs with unpushed commits

### Fixed
- Fix orchestrator premature exit after reviewer approval and broken resume
  - Auto-create PR after approval instead of just exiting
  - Resume from persisted round number instead of hardcoding round=1
  - Detect already-approved reviews on restart to create PR immediately
- Fix agent-pair infinite approve loop: break after reviewer approval
- Fix glob quoting for paths with spaces and include legacy unprefixed sessions
- Fix tmux terminal titles for VS Code and standard terminals

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
  - New `duo-final-merge` and `pair-final-merge` skills for automated merging
- **Integrate phase**: Automatic rebase when main branch advances
  - Detects when parallel sessions need rebasing after a PR merges
  - New `duo-integrate` and `pair-integrate` skills
  - Orchestrator polls origin/main and triggers integration automatically
- **Plan/plan-review phase** (`--plan`): Agents write implementation plans
  - Agents write plans to `.peer-sync/plan-<agent>.md`
  - Peer review of plans before work begins
  - New skills: `duo-plan`, `duo-plan-review`, `pair-coder-plan`, `pair-reviewer-plan`
- **Gather phase** for pair mode (`--gather`): Reviewer collects task context
  - Reviewer explores codebase and writes `task-context.md` for coder
  - New `pair-reviewer-gather` skill
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
- Workflow feedback now persisted in pair mode (moved to shared lib)
- Fix final-merge phase: add missing status and worktree-safe merge
- Fix merge phase to work in winning worktree instead of main
- Fix spurious `/pair-pr-comment` triggers after rebase
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
  - Shared `fetch-pr-feedback.sh` script for both duo and pair modes
  - Require PR comment when declining to make changes from feedback
  - Preserve PR comment hash baseline across session restarts
- `agent-pair restart` command for session recovery after system restart
- `--port` flag for configurable consecutive port allocation
- Test infrastructure with unit and integration tests
- `duo-amend` skill and require review before session completion
- `escalate` command for agents to flag blocking issues

### Changed
- Require Bash 4+ and use `#!/usr/bin/env bash` for macOS compatibility
- Use only Escape to interrupt agents, not Ctrl-C
- Cleanup command now removes session state only by default
- Refactored `restart_agent_tui` in agent-lib.sh to be generic (works for both duo and pair modes)
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
- `agent-pair` mode for coder/reviewer workflow
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
