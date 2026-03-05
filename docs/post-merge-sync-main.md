# Post-Merge Sync: Pull Local Main After Remote PR Merge

## Motivation

When an agent merges a PR remotely via `gh pr merge`, the merge succeeds on GitHub
but the local main checkout (the actual repository root, not the worktree where the
PR was created) is never updated. Downstream verification steps that run against the
local checkout then see stale state and report criteria as unmet, even though the
work is complete on the remote.

The issue was first observed with gh-ludics-21: a Codex session created and merged
PR #29 in the ludics repository, but the local `~/ludics` checkout remained at the
pre-merge commit. Verification reported 7/10 criteria as unmet; a manual
`git pull --ff-only` in the local checkout resolved it.

GitHub issue: https://github.com/lukstafi/agent-duo/issues/49

## Current State

Agent sessions run in worktrees (git worktrees, separate checkouts with a `.git`
file rather than a `.git` directory). The final-merge phase operates from such a
worktree:

- Worktree: `/Users/lukstafi/agent-duo-<feature-name>/` (contains `.git` file)
- Main repo: `/Users/lukstafi/agent-duo/` (contains `.git` directory)

The existing skill templates (`duo-final-merge.md` and `pair-final-merge.md`) already
note the worktree problem for `--delete-branch` (step 6 in each template), but they
make no attempt to refresh the main checkout after the merge.

**Key files:**
- `skills/templates/duo-final-merge.md` — Step 6 (lines 80–104): PR merge step,
  ends with remote branch deletion; no post-merge pull follows
- `skills/templates/pair-final-merge.md` — Identical structure (lines 80–104)
- `agent-lib.sh` — Contains the building blocks:
  - `get_main_project_root()` (~line 94): walks `.git` vs `.git` file distinction
    to find the actual repository root from any worktree path
  - `get_main_branch()` (~line 3180): reads cached `main-branch` from `.peer-sync`
    or detects it from `origin/HEAD`; falls back to `main`
  - `get_main_head()` (~line 3210): already does `git fetch origin <main_branch>`
    but only from the current worktree, not from the main checkout

There is no `sync_main_after_merge` function or equivalent anywhere in the codebase.

## Proposed Change

### New helper: `sync_main_after_merge` in `agent-lib.sh`

Add a reusable shell function that:

1. Resolves the main project root via `get_main_project_root` (not `PWD`, which is
   inside a worktree)
2. Fetches from `origin` to refresh remote refs in the main checkout
3. Attempts `git pull --ff-only` to fast-forward the local main branch
4. Falls back to `git merge origin/<main_branch>` if fast-forward fails (for cases
   where local main has diverged, which should be rare but possible)
5. Logs a warning and returns success if both pull strategies fail — the remote
   merge is already complete; a stale local checkout is suboptimal but recoverable
   and must not block the completion signal

The function must accept the main branch name as a parameter (not hardcode `main`)
because `get_main_branch` requires a `peer_sync` path. The caller reads the branch
name before calling the helper, so the helper's signature is:

```bash
sync_main_after_merge <main_branch>
```

The `git -C <main_root>` form must be used throughout so git operations target the
main checkout regardless of `PWD`.

### Template updates

Both `duo-final-merge.md` and `pair-final-merge.md` should call
`sync_main_after_merge` immediately after the `gh pr merge` command succeeds (before
deleting the remote branch, since branch deletion is a best-effort cleanup). The
call should be preceded by a comment explaining why this is necessary — agents
operate from worktrees, so the main checkout is never updated automatically.

The `PEER_SYNC` variable is already available in both templates (it is the session's
sync directory, used to read the PR URL). `get_main_branch "$PEER_SYNC"` therefore
works without changes to the template environment.

### Acceptance criteria

- After `gh pr merge` succeeds in both `duo-final-merge.md` and
  `pair-final-merge.md`, the main project root's local `main` branch is pulled to
  match `origin/main`
- `sync_main_after_merge` is added to `agent-lib.sh` and handles the fetch +
  fast-forward + fallback merge + non-blocking warning path
- The function uses `get_main_project_root` to locate the correct checkout (not
  `PWD`)
- Sync failure (network issue, diverged history) logs a warning but does not cause
  the final-merge skill to fail or block the completion signal
- A comment in the template explains the worktree vs. main repo separation as
  rationale for the explicit pull

### Edge cases

- **Main branch name is not `main`**: `get_main_branch "$PEER_SYNC"` detects the
  correct name; the helper must use the passed-in value, not a hardcoded constant
- **Fast-forward impossible**: Local main has local commits (unusual but possible
  if someone pushed directly). Fallback merge handles this; if that also fails, log
  and continue
- **`git -C` not available**: `git -C` has been stable since git 1.8.5 (2013) and
  is safe to depend on
- **No network**: `git fetch` failure is non-fatal; log and continue

## Scope

**In scope:**
- `sync_main_after_merge` function in `agent-lib.sh`
- Post-merge pull step in `duo-final-merge.md`
- Post-merge pull step in `pair-final-merge.md`
- Explanatory comment in both templates

**Out of scope:**
- Updating other phases (work, integrate, review) — they do not merge PRs
- Syncing worktrees other than the main checkout
- Refactoring `cmd_signal()` in `agent-duo` (separate concern, tracked elsewhere)
- TypeScript rewrite (gh-agent-duo-50) — this change must land first to unblock
  the rewrite with a clean bash baseline

**Dependencies:**
- Must land before gh-agent-duo-50 (TypeScript rewrite) begins
- No dependencies on other open tasks
