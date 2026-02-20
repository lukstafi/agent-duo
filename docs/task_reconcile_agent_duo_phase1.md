# Task: Reconcile for agent-duo (Phase 1, Detection Only)

## Goal
Add `agent-duo reconcile --check` to detect session/state drift across `.peer-sync`, `.agent-sessions`, worktrees, and runtime artifacts, without mutating anything.

## Scope
- New CLI command: `agent-duo reconcile --check`.
- Human-readable report + `--json` output.
- Exit code semantics for automation.
- Check-only implementation (no fix actions in this phase).

## Deliverables
- `agent-duo reconcile --check` command implemented.
- `agent-duo reconcile --check --feature <name>` support.
- `agent-duo reconcile --check --all` support from project root.
- `agent-duo reconcile --check --json` machine-readable output.
- Exit codes:
  - `0` no issues
  - `1` issues found
  - `64` invalid usage
- Deterministic check keys and severities in output.

## Checks (Phase 1)

1. `session_registry.dangling_link`
   - `.agent-sessions/*.session` symlink target missing.
2. `peer_sync.missing_required_file`
   - required files missing (`phase`, `session`, `feature`, `mode`).
3. `peer_sync.status_file_missing`
   - missing `claude.status` / `codex.status` (or pair role equivalents) for active session.
4. `worktree.missing_root`
   - session exists but root worktree path missing.
5. `worktree.missing_agent`
   - expected agent worktree missing for mode.
6. `worktree.peersync_symlink_broken`
   - agent worktree `.peer-sync` missing or broken symlink.
7. `runtime.dead_pid_file`
   - PID file exists but process is not alive.
8. `runtime.lock_stale`
   - stale lock dir/file older than threshold.
9. `pr_metadata.pr_created_missing_url`
   - status indicates PR created but `.pr` URL file missing.

## Files to Touch
- `agent-duo` (add `reconcile` command wiring + help text)
- `agent-lib.sh` (check helpers + report rendering + exit handling)
- `docs/DESIGN.md` (CLI and operational docs section)

## Suggested Approach
1) Add a `cmd_reconcile()` entrypoint to `agent-duo` with `--check`, `--json`, `--feature`, `--all`.
2) Implement reusable check helpers in `agent-lib.sh` returning structured issue records.
3) Add report renderers:
   - human summary grouped by severity
   - JSON object with `issues[]`.
4) Normalize discovery logic so reconcile works from:
   - main project root
   - root worktree
   - agent worktree.
5) Add exit code enforcement and usage validation.

## Dependencies
- Existing session discovery/resolution helpers in `agent-lib.sh`.
- Existing mode detection (`duo`/`pair`) and status file conventions.

## Validation
- Shell and lint:
  - `shellcheck agent-duo agent-lib.sh`
- Manual sanity:
  - Start normal session, run `agent-duo reconcile --check` (expect clean / low-noise report).
  - Break a symlink intentionally, run reconcile (expect issue detected).
  - Kill ttyd process leaving PID file, run reconcile (expect dead PID detection).
  - Run `--json` and verify schema stability.
- Exit codes:
  - No issues: `0`
  - Injected issues: `1`
  - Invalid args: `64`

## Out of Scope
- `--fix-safe` and `--fix-aggressive`.
- Automatic mutation of session/worktree state.
- Preflight integration into `restart`/`run-merge`.

## Risks
- False positives in unconventional user-managed layouts.
- Mode-specific edge cases (`pair` vs `duo`) causing noisy checks.

## Success Criteria
- Reconcile reliably detects common drift classes without mutating state.
- Output is useful enough for human triage and scriptable automation.
