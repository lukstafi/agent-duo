# agent-claude and agent-codex: Standalone Agent Launchers

## Summary

Add two new top-level commands `agent-claude` and `agent-codex` that launch managed tmux sessions for individual agent use, without orchestration. These are independent entry points alongside the existing `agent-duo` and `agent-solo` commands.

## Motivation

Users often want a persistent, managed Claude Code or Codex session without the full duo/solo orchestration (phases, reviews, PRs). Currently the only options are raw `claude`/`codex` in a terminal or the VS Code extension. These commands provide tmux persistence, optional web terminal access, optional VS Code IDE integration, and session tracking via `.agent-sessions/` — reusing agent-duo's existing infrastructure.

## CLI Interface

```bash
agent-claude <task> --ide [--branch]        # Launch Claude Code, connect to VS Code
agent-claude <task> --ttyd [--branch]       # Launch Claude Code with web terminal
agent-claude <task> --bare [--branch]       # Launch Claude Code, tmux only

agent-codex <task> --ide [--branch]         # Same for Codex
agent-codex <task> --ttyd [--branch]
agent-codex <task> --bare [--branch]
```

- `<task>` is required. Used for tmux session naming and branch name (if `--branch`).
- `--ide` / `--ttyd` / `--bare` is a required, mutually exclusive choice.
- `--branch` is optional. When present, creates a git worktree on a new branch named `<task>`.

### Additional Commands

```bash
agent-claude status                        # List active agent-claude sessions
agent-claude stop <task>                   # Stop ttyd, keep tmux session
agent-claude cleanup <task>                # Kill tmux session, remove worktree if any
agent-claude restart <task>                # DWIM recovery (reattach tmux, restart ttyd)
agent-claude attach <task>                 # Attach to existing tmux session
```

Same for `agent-codex`.

## Tmux Session Naming

- Format: `claude-<project>-<task>` / `codex-<project>-<task>`
- `<project>` is derived from the current directory basename (like agent-duo does).
- Example: running `agent-claude refactor` from `~/ocannl/` creates tmux session `claude-ocannl-refactor`.

## Access Modes

### `--ide`

1. Create tmux session.
2. Launch agent TUI inside it.
3. Wait for agent readiness (reuse agent-duo's existing tmux send-and-wait patterns).
4. Send `/ide` to connect to VS Code.
5. Attach to tmux session.

### `--ttyd`

1. Create tmux session.
2. Launch agent TUI inside it.
3. Start ttyd on a dynamically allocated port (reuse agent-duo's port allocation and `start_ttyd_servers` logic).
4. Record port in session state.
5. Print web terminal URL.

### `--bare`

1. Create tmux session.
2. Launch agent TUI inside it.
3. Attach directly.

## `--branch` Flag

When present:

1. Create a new branch named `<task>` from current HEAD.
2. Create a git worktree at `../<project>-<task>/` (following agent-duo's sibling worktree convention).
3. Launch the agent TUI in the worktree directory.
4. On `cleanup`, remove the worktree.

When absent:

- Launch the agent in the current working directory on whatever branch is checked out.
- Works in non-git directories too.

## Session State

### `.agent-sessions/` Registry

Namespace session files by entry point prefix to avoid conflicts with agent-duo/agent-solo:

```
.agent-sessions/
├── duo-auth.session              # existing agent-duo sessions
├── solo-payments.session         # existing agent-solo sessions
├── claude-refactor.session       # new: agent-claude sessions
├── codex-bugfix.session          # new: agent-codex sessions
```

Each command's cleanup only touches its own prefix (`claude-*`, `codex-*`, `duo-*`, `solo-*`).

**Concurrency audit required**: review existing `.agent-sessions/` read/write code in agent-duo and agent-solo to ensure concurrent writes from different entry points don't race. Use the existing mkdir-based locking if needed.

### Session State File Format

Each `claude-<task>.session` / `codex-<task>.session` is a small text file:

```
agent=claude
task=refactor
tmux=claude-ocannl-refactor
mode=ide
ttyd_port=7681
workdir=/Users/lukstafi/ocannl
worktree=/Users/lukstafi/ocannl-refactor
started=2026-02-12T13:00:00+01:00
```

- `ttyd_port`: only present when `mode=ttyd`.
- `worktree`: only present when `--branch` was used.
- `status`: one of `running`, `idle`, `finished`, `maintenance`.

## Implementation Notes

### Reuse from Agent-Duo

Factor out or directly call existing functions from agent-duo for:

- tmux session creation and management
- ttyd server start/stop and dynamic port allocation
- PID tracking in state files
- Sending commands to agent TUIs via tmux `send-keys`
- Agent readiness detection (waiting for TUI to be ready before sending `/ide`)
- DWIM restart logic

### Installation

`agent-duo setup` should also install `agent-claude` and `agent-codex` to `~/.local/bin/`. These can be separate scripts or symlinks to a shared launcher that dispatches based on `$0`.

### Unified Status View

`agent-duo status` (from a project root) should optionally show all session types — duo, solo, claude, codex — by reading all `*.session` files regardless of prefix. Each entry point's own `status` command shows only its sessions.

## Out of Scope

- No orchestration phases (clarify, pushback, plan, review, etc.).
- No `.peer-sync/` directory or coordination protocol.
- No PR creation or merge workflows.
- No skills injection — the agent runs with whatever skills/commands it already has installed.
- No completion hooks specific to these sessions.

## Testing

1. `agent-claude foo --bare` in a git repo: creates tmux session, launches claude, attaches.
2. `agent-claude foo --ide` in a git repo: same + sends `/ide`.
3. `agent-claude foo --ttyd` in a git repo: same + starts ttyd, prints URL.
4. `agent-claude foo --branch --bare`: creates worktree and branch `foo`, launches in worktree.
5. `agent-claude status`: shows the session.
6. `agent-claude cleanup foo`: kills tmux, removes worktree if present, removes `.agent-sessions/claude-foo.session`.
7. Running `agent-duo cleanup --full` does NOT remove `claude-*` session files.
8. Running `agent-claude foo --bare` in a non-git directory works (no branch/worktree features).
9. `agent-claude restart foo` after tmux survives but ttyd died: restarts ttyd only.
10. Concurrent: start `agent-duo start auth --auto-run` and `agent-claude refactor --bare` in the same project — both register in `.agent-sessions/` without conflicts.
