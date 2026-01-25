# Agent Duo - Architecture Document

## Overview

Agent Duo coordinates two AI coding agents working in parallel on the same task, each in their own git worktree, producing two alternative solutions as separate PRs.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Agent Duo Session                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ~/myapp/                    (main branch, orchestrator runs)   │
│      │                                                          │
│      ├── myfeature.md        (task description)                 │
│      └── .peer-sync/         (coordination state)               │
│                                                                 │
│  ~/myapp-myfeature-claude/   (branch: myfeature-claude)         │
│      └── .peer-sync -> ~/myapp/.peer-sync                       │
│                                                                 │
│  ~/myapp-myfeature-codex/    (branch: myfeature-codex)          │
│      └── .peer-sync -> ~/myapp/.peer-sync                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Installation

```bash
# From the agent-duo repository
./agent-duo setup

# Installs to ~/.local/bin/agent-duo (add to PATH if needed)
# Also installs skills to ~/.claude/commands/ and ~/.codex/skills/
```

## CLI Reference

### User Commands

```bash
agent-duo start <feature>      # Start session, creates worktrees
agent-duo start <f> --clarify  # Start with clarify phase before work
agent-duo stop                 # Stop ttyd servers, keep worktrees
agent-duo status               # Show session state
agent-duo confirm              # Confirm clarify phase, proceed to work
agent-duo pr <agent>           # Create PR for agent's solution
agent-duo cleanup [--full]     # Remove worktrees (--full: also state)
agent-duo setup                # Install agent-duo to PATH and skills
```

### Agent Commands

```bash
agent-duo signal <agent> <status> [message]   # Signal status change
agent-duo peer-status                         # Read peer's status
agent-duo phase                               # Read current phase
```

## Naming Conventions

Given project directory `myapp` and feature `auth`:

| Item | Name |
|------|------|
| Task file | `auth.md` (in project root) |
| Claude's branch | `auth-claude` |
| Codex's branch | `auth-codex` |
| Claude's worktree | `../myapp-auth-claude/` |
| Codex's worktree | `../myapp-auth-codex/` |
| PR file (optional) | `auth-claude-PR.md` |

## Coordination Protocol

### Concepts

| Concept | Who sets | Values | Purpose |
|---------|----------|--------|---------|
| **Phase** | Orchestrator | `clarify`, `work`, `review` | Current stage of the round |
| **Agent Status** | Agent | `clarifying`, `clarify-done`, `working`, `done`, `reviewing`, `review-done`, `interrupted`, `error` | What agent is doing |
| **Session State** | Orchestrator | `active`, `complete` | Overall progress |

### State Files (in `.peer-sync/`)

```
.peer-sync/
├── session          # "active" or "complete"
├── phase            # "clarify", "work", or "review"
├── round            # Current round number (1, 2, 3...)
├── feature          # Feature name for this session
├── clarify-mode     # "true" or "false" - whether clarify phase is enabled
├── clarify-confirmed # Present when user confirms clarify phase
├── clarify-claude.md # Claude's approach and questions (clarify phase)
├── clarify-codex.md  # Codex's approach and questions (clarify phase)
├── claude.status    # Agent status: "working|1705847123|implementing API"
├── codex.status     # Format: status|epoch|message
└── reviews/         # Review files from each round
    └── round-1-claude-reviews-codex.md
```

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ CLARIFY PHASE (optional, --clarify flag)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=clarify                             │
│  2. Agents propose approach and questions (status: clarifying)  │
│     - Write to .peer-sync/clarify-{agent}.md                    │
│  3. Agents signal completion (status: clarify-done)             │
│  4. Orchestrator emails results to user                         │
│  5. User reviews approaches in terminals                        │
│  6. User responds to agents if needed (back-and-forth)          │
│  7. User runs 'agent-duo confirm' to proceed                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Round N                                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WORK PHASE                                                     │
│  ──────────                                                     │
│  1. Orchestrator sets phase=work                                │
│  2. Agents work independently (status: working)                 │
│  3. Agents signal completion (status: done)                     │
│     - Or orchestrator interrupts (status: interrupted)          │
│  4. Orchestrator waits for both done/interrupted                │
│                                                                 │
│  REVIEW PHASE                                                   │
│  ────────────                                                   │
│  5. Orchestrator sets phase=review                              │
│  6. Agents review peer's worktree (status: reviewing)           │
│     - git -C "$PEER_WORKTREE" diff                              │
│     - Write review to .peer-sync/reviews/                       │
│  7. Agents signal completion (status: review-done)              │
│  8. Orchestrator waits for both review-done                     │
│                                                                 │
│  (Repeat for next round or until PRs created)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Recoverable Interrupts

When an agent takes too long, the orchestrator can interrupt rather than fail:

1. Orchestrator sends interrupt (writes to `.peer-sync/<agent>.interrupt`)
2. Agent detects interrupt, saves state, sets status to `interrupted`
3. Review phase proceeds normally
4. Next work phase, agent continues with peer feedback
5. Skills explain: "If interrupted, review feedback and continue"

This allows graceful handling of slow agents without losing progress.

## Agent Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `clarifying` | Proposing approach and questions | Agent (start of clarify phase) |
| `clarify-done` | Finished clarify phase | Agent |
| `working` | Actively implementing | Agent (start of work phase) |
| `done` | Finished work phase | Agent |
| `reviewing` | Reading peer's changes | Agent (start of review phase) |
| `review-done` | Finished review phase | Agent |
| `interrupted` | Timed out, yielding to review | Orchestrator |
| `error` | Something failed | Agent or Orchestrator |
| `pr-created` | PR submitted | Agent (after `agent-duo pr`) |

## Reading Peer's Work

Agents read peer's uncommitted changes directly via git:

```bash
# From agent's worktree (PEER_WORKTREE is set by orchestrator)
git -C "$PEER_WORKTREE" status
git -C "$PEER_WORKTREE" diff
git -C "$PEER_WORKTREE" diff --stat

# Or read files directly
cat "$PEER_WORKTREE/src/main.js"
```

No snapshot files needed - direct access is simpler with unrestricted permissions.

## PR Creation

```bash
agent-duo pr claude
```

This command:
1. Auto-commits any uncommitted changes
2. Pushes branch to origin
3. Creates PR via `gh pr create`
4. Uses `<feature>-<agent>-PR.md` for body if it exists
5. Sets agent status to `pr-created`
6. Records PR URL in `.peer-sync/<agent>.pr`

Session completes when both agents have `pr-created` status.

## Terminal Modes

### tmux mode (default)

```bash
agent-duo start myfeature
# Creates tmux session "duo-myfeature" with windows:
#   0: orchestrator
#   1: claude (in myapp-myfeature-claude/)
#   2: codex (in myapp-myfeature-codex/)
```

### ttyd mode (web terminals)

```bash
agent-duo start myfeature --ttyd
# Launches:
#   http://localhost:7681 - Claude's terminal
#   http://localhost:7682 - Codex's terminal
# PIDs tracked in .peer-sync/pids/ for clean shutdown
```

## Skills

Skills provide phase-specific instructions to agents. Installed to:
- Claude: `~/.claude/commands/duo-work.md`, `duo-review.md`, `duo-clarify.md`
- Codex: `~/.codex/skills/duo-work.md`, `duo-review.md`, `duo-clarify.md`

Key skill behaviors:
- **Clarify phase**: Propose high-level approach, ask clarifying questions, signal `clarify-done`
- **Work phase**: Implement solution, signal `done` when ready
- **Review phase**: Read peer's worktree via git, write review, signal `review-done`
- **Divergence**: Maintain distinct approach from peer
- **Interrupts**: If interrupted, gracefully yield and continue next round

## Completion Hooks

Agents don't reliably execute signaling commands from skill instructions. Instead, `agent-duo setup` configures completion hooks:

- **Claude**: `Stop` hook in `~/.claude/settings.json`
- **Codex**: `notify` hook in `~/.codex/config.toml`

Both hooks run `~/.local/bin/agent-duo-notify` which:
1. Reads the current phase from `$PEER_SYNC/phase`
2. Signals `done` (work phase) or `review-done` (review phase)
3. Skips if already in a terminal state

## Environment Variables

Set by orchestrator in each agent's tmux/ttyd session:

| Variable | Value | Example |
|----------|-------|---------|
| `PEER_SYNC` | Path to .peer-sync | `/Users/me/myapp/.peer-sync` |
| `MY_NAME` | This agent's name | `claude` |
| `PEER_NAME` | Other agent's name | `codex` |
| `PEER_WORKTREE` | Path to peer's worktree | `/Users/me/myapp-auth-codex` |
| `FEATURE` | Feature name | `auth` |

## Locking

Status file writes use atomic mkdir-based locking:

```bash
# Acquire lock
while ! mkdir "$PEER_SYNC/.lock" 2>/dev/null; do sleep 0.05; done
# Write status
echo "done|$(date +%s)|finished feature" > "$PEER_SYNC/$MY_NAME.status"
# Release lock
rmdir "$PEER_SYNC/.lock"
```

## Cleanup

```bash
# Stop servers, keep worktrees and state
agent-duo stop

# Remove worktrees, keep state for review
agent-duo cleanup

# Remove everything
agent-duo cleanup --full
```

Manual cleanup if needed:
```bash
git worktree remove ../myapp-auth-claude
git worktree remove ../myapp-auth-codex
tmux kill-session -t duo-auth
pkill -f "ttyd.*768[12]"
```

## Supported Agents

Currently: `claude`, `codex`

Future: `gemini`, `grok`, etc. (naming follows same pattern)

## Design Principles

1. **Simple file-based protocol** - No daemons, just files and git
2. **Direct access over snapshots** - Simpler with unrestricted permissions
3. **Recoverable interrupts** - Timeouts don't lose progress
4. **Feature-based naming** - Clear organization for multiple sessions
5. **Unified CLI** - Single `agent-duo` command for all operations
6. **Graceful degradation** - Works without ttyd, gh, etc.

---

## Historical Notes

### First Duo Run (2026-01-21)

The agent-duo system was bootstrapped by having Claude and Codex implement it collaboratively. Both created PRs with distinct approaches:

| Agent | PR | Key Differences |
|-------|-----|-----------------|
| Claude | [#1](https://github.com/lukstafi/agent-duo/pull/1) | Sibling worktrees, unified CLI, skills installer |
| Codex | [#2](https://github.com/lukstafi/agent-duo/pull/2) | Worktrees inside repo, `doctor`/`paths`/`wait` helpers, PID tracking |

### Lessons Learned

1. **tmux send-keys**: Must send text and `C-m` separately for agent CLIs
2. **Skills location**: Claude looks in `~/.claude/commands/`, not local `skills/`
3. **Cross-worktree access**: Codex needs `--yolo` (not `--full-auto`) for unrestricted access
4. **Nudging agents**: Send "Continue." rather than empty Enter to unstick agents
5. **PEER_SYNC paths**: Use absolute paths and symlinks to avoid confusion
6. **Agents don't reliably run signal commands**: Neither Claude nor Codex reliably execute bash commands from skill instructions. Use completion hooks instead (`agent-duo setup` configures both)

### Active Worktrees (from bootstrap)

```
~/agent-duo         main branch
~/project-claude    claude-work branch (Claude's PR)
~/project-codex     codex-work branch (Codex's PR)
```
