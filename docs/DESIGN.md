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
./agent-duo setup    # For duo mode
./agent-solo setup   # For solo mode (optional)

# Installs to ~/.local/bin/ (add to PATH if needed)
# Also installs skills to ~/.claude/commands/ and ~/.codex/skills/
# Configures completion hooks for automatic phase signaling

# Verify installation
agent-duo doctor
```

## CLI Reference

### User Commands

```bash
agent-duo start <feature>       # Start session, creates worktrees
agent-duo start <f> --clarify   # Start with clarify phase before work
agent-duo start <f> --pushback  # Start with pushback phase (task improvement)
agent-duo start <f> --auto-run  # Start and run orchestrator immediately
agent-duo run [options]         # Run orchestrator loop
agent-duo stop                  # Stop ttyd servers, keep worktrees
agent-duo restart [--auto-run]  # Recover session after crash/restart
agent-duo status                # Show session state
agent-duo confirm               # Confirm clarify/pushback phase, proceed
agent-duo pr <agent>            # Create PR for agent's solution
agent-duo cleanup [--full]      # Remove worktrees (--full: also state)
agent-duo setup                 # Install agent-duo to PATH and skills
agent-duo doctor                # Check system configuration
agent-duo config [key] [value]  # Get/set configuration (ntfy_topic, etc.)
agent-duo nudge <agent> [msg]   # Send message to agent terminal
agent-duo interrupt <agent>     # Interrupt agent (Esc + Ctrl-C)
```

### Model Selection Options

```bash
agent-duo start <feature> --auto-run \
  --claude-model opus \        # Claude model (opus, sonnet)
  --codex-model o3 \           # Codex/GPT model (o3, gpt-4.1)
  --codex-thinking high        # Codex reasoning effort (low, medium, high)
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
| **Phase** | Orchestrator | `clarify`, `pushback`, `work`, `review` | Current stage of the round |
| **Agent Status** | Agent | `clarifying`, `clarify-done`, `pushing-back`, `pushback-done`, `working`, `done`, `reviewing`, `review-done`, `interrupted`, `error` | What agent is doing |
| **Session State** | Orchestrator | `active`, `complete` | Overall progress |

### State Files (in `.peer-sync/`)

```
.peer-sync/
├── session           # "active" or "complete"
├── phase             # "clarify", "pushback", "work", or "review"
├── round             # Current round number (1, 2, 3...)
├── feature           # Feature name for this session
├── ports             # Port allocations (ORCHESTRATOR_PORT, CLAUDE_PORT, CODEX_PORT)
├── clarify-mode      # "true" or "false" - whether clarify phase is enabled
├── pushback-mode     # "true" or "false" - whether pushback phase is enabled
├── clarify-confirmed # Present when user confirms clarify phase
├── pushback-confirmed # Present when user confirms pushback phase
├── clarify-claude.md # Claude's approach and questions (clarify phase)
├── clarify-codex.md  # Codex's approach and questions (clarify phase)
├── codex-thinking    # Codex reasoning effort level
├── claude.status     # Agent status: "working|1705847123|implementing API"
├── codex.status      # Format: status|epoch|message
├── pids/             # Process IDs for ttyd servers
└── reviews/          # Review files from each round
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
│  4. Orchestrator sends notification (email/ntfy) to user        │
│  5. User reviews approaches in terminals                        │
│  6. User responds to agents if needed (back-and-forth)          │
│  7. User runs 'agent-duo confirm' to proceed                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PUSHBACK PHASE (optional, --pushback flag)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=pushback                            │
│  2. Agents propose task improvements (status: pushing-back)     │
│     - Edit the task file directly with suggested changes        │
│  3. Agents signal completion (status: pushback-done)            │
│  4. Orchestrator backs up original task, notifies user          │
│  5. User reviews changes in terminals (can accept/reject/modify)│
│  6. User runs 'agent-duo confirm' to proceed                    │
│     - Original task restored from backup before work begins     │
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
| `pushing-back` | Proposing task improvements | Agent (start of pushback phase) |
| `pushback-done` | Finished pushback phase | Agent |
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

### ttyd mode (web terminals, default)

```bash
agent-duo start myfeature
# Launches web terminals with dynamically allocated ports:
#   http://localhost:<port>   - Orchestrator
#   http://localhost:<port+1> - Claude's terminal
#   http://localhost:<port+2> - Codex's terminal
# Port assignments stored in .peer-sync/ports
# PIDs tracked in .peer-sync/pids/ for clean shutdown
```

## Skills

Skills provide phase-specific instructions to agents. Installed to:
- Claude: `~/.claude/commands/duo-{work,review,clarify,pushback}.md`
- Codex: `~/.codex/skills/duo-{work,review,clarify,pushback}/SKILL.md`

Key skill behaviors:
- **Clarify phase**: Propose high-level approach, ask clarifying questions, signal `clarify-done`
- **Pushback phase**: Propose improvements to the task file, signal `pushback-done`
- **Work phase**: Implement solution, signal `done` when ready
- **Review phase**: Read peer's worktree via git, write review, signal `review-done`
- **Divergence**: Maintain distinct approach from peer
- **Interrupts**: If interrupted, gracefully yield and continue next round

## Completion Hooks

Agents don't reliably execute signaling commands from skill instructions. Instead, `agent-duo setup` configures completion hooks:

- **Claude**: `Stop` hook in `~/.claude/settings.json` with command `agent-duo-notify claude`
- **Codex**: `notify` hook in `~/.codex/config.toml` with args `["agent-duo-notify", "codex"]`

Both hooks run `~/.local/bin/agent-duo-notify <agent-name>` which:
1. Receives agent name as `$1` (required - hooks don't inherit shell environment variables)
2. Discovers `PEER_SYNC` from `$PWD/.peer-sync` symlink (present in worktrees)
3. Reads the current phase from `$PEER_SYNC/phase`
4. Signals appropriate status: `done` (work), `review-done` (review), `clarify-done` (clarify), `pushback-done` (pushback)
5. Skips if already in a terminal state

## Notifications

The orchestrator can notify users when attention is needed:

### ntfy.sh (Push Notifications)

```bash
agent-duo config ntfy_topic my-topic      # Set topic name
agent-duo config ntfy_token tk_xxx        # Optional: access token for private topics
agent-duo config ntfy_server https://ntfy.sh  # Optional: custom server
```

### Email

Uses `git config user.email` as the recipient. Requires a working mail setup (postfix, msmtp, etc.).

Run `agent-duo doctor` to verify notification configuration.

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

## Agent Solo Mode

Agent-solo is an alternative mode where one agent codes and another reviews in a single worktree:

```
┌─────────────────────────────────────────────────────────────────┐
│                      Agent Solo Session                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ~/myapp/                    (main branch, orchestrator)        │
│      ├── myfeature.md        (task description)                 │
│      └── .peer-sync/         (coordination state)               │
│                                                                 │
│  ~/myapp-myfeature/          (branch: myfeature, shared)        │
│      └── .peer-sync -> ~/myapp/.peer-sync                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow:**
1. **Coder** implements the solution (work phase)
2. **Reviewer** examines code and writes review with verdict (APPROVE/REQUEST_CHANGES)
3. If approved: create PR. If changes requested: loop continues.

**Key differences from duo mode:**
- Single worktree (both agents work on same branch)
- Sequential rather than parallel work
- Clear coder/reviewer roles (swappable with `--coder` and `--reviewer`)
- Skills: `solo-coder-{work,clarify}.md`, `solo-reviewer-{work,clarify,pushback}.md`

## Design Principles

1. **Simple file-based protocol** - No daemons, just files and git
2. **Direct access over snapshots** - Simpler with unrestricted permissions
3. **Recoverable interrupts** - Timeouts don't lose progress
4. **Feature-based naming** - Clear organization for multiple sessions
5. **Unified CLI** - Single `agent-duo` command for all operations
6. **Graceful degradation** - Works without ttyd, gh, etc.
7. **Session recovery** - `restart` command handles crashes gracefully

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
7. **Hook environment isolation**: Agent hooks (Claude Stop, Codex notify) run as separate processes and don't inherit shell environment variables set via `export`. Pass context via command arguments and discover paths from `$PWD`

### Active Worktrees (from bootstrap)

```
~/agent-duo         main branch
~/project-claude    claude-work branch (Claude's PR)
~/project-codex     codex-work branch (Codex's PR)
```

### January 2026 Iteration

Major feature additions since the initial bootstrap:

| Feature | Description |
|---------|-------------|
| **Pushback phase** | New `--pushback` flag, `pushing-back`/`pushback-done` statuses, `duo-pushback` skill |
| **`restart` command** | Recover sessions after system restart/crash (DWIM behavior) |
| **`doctor` command** | Diagnose configuration issues, test email/ntfy delivery |
| **`config` command** | Get/set configuration values |
| **ntfy.sh notifications** | Push notifications via ntfy.sh service |
| **Model selection** | `--claude-model`, `--codex-model`, `--codex-thinking` options |
| **Dynamic port allocation** | Ports stored in `.peer-sync/ports` instead of hardcoded |
| **agent-solo mode** | Single-worktree coder/reviewer workflow |

The pushback phase allows agents to propose improvements to the task file before implementation begins, enabling iterative task refinement.
