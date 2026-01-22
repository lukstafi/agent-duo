# agent-duo

Coordinate two AI coding agents (Claude, Codex, etc.) working in parallel on the same task, producing **two alternative solutions** as separate PRs.

## Why?

When solving complex problems, different approaches have different tradeoffs. Instead of getting one solution and hoping it's the best, agent-duo lets two AI agents work independently on the same task. You get:

- **Two distinct implementations** to compare
- **Peer review** between agents each round
- **Divergent thinking** - agents are encouraged to take different approaches
- **Better coverage** of the solution space

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      Agent Duo Session                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ~/myapp/                    (main branch, orchestrator)        │
│      ├── auth.md             (task description)                 │
│      └── .peer-sync/         (coordination state)               │
│                                                                 │
│  ~/myapp-auth-claude/        (branch: auth-claude)              │
│  ~/myapp-auth-codex/         (branch: auth-codex)               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Each agent works in its own git worktree. They can peek at each other's uncommitted changes via `$PEER_WORKTREE`. The orchestrator manages work/review cycles with automatic timeouts.

## Installation

```bash
git clone https://github.com/user/agent-duo
cd agent-duo
./agent-duo setup
```

This installs:
- `agent-duo` CLI to `~/.local/bin/`
- Skills to `~/.claude/commands/` and `~/.codex/skills/`

Add `~/.local/bin` to your PATH if needed.

## Quick Start

```bash
# 1. Create a task description in your project
cd ~/myproject
cat > add-auth.md << 'EOF'
# Add User Authentication

Implement user authentication with:
- Login/logout endpoints
- Session management
- Password hashing with bcrypt
- Rate limiting on login attempts

Use the existing Express app structure.
EOF

# 2. Start the duo session
agent-duo start add-auth

# 3. Attach to tmux and start agents manually in their windows
tmux attach -t duo-add-auth
# Window 1 (claude): claude --dangerously-skip-permissions
# Window 2 (codex): codex --yolo

# 4. Or run the orchestrator to manage everything
agent-duo run --auto-start
```

## Example Session

Here's what a typical session looks like:

```
$ agent-duo start add-auth
Starting Agent Duo session: add-auth
Project: myproject
Creating worktree for claude...
Creating worktree for codex...
Created tmux session: duo-add-auth

Windows:
  0: orchestrator  - Main project root
  1: claude        - /Users/me/myproject-add-auth-claude
  2: codex         - /Users/me/myproject-add-auth-codex

Attach with: tmux attach -t duo-add-auth

$ agent-duo run
=== Agent Duo Orchestrator ===
Feature:        add-auth
Work timeout:   600s
Review timeout: 300s
Max rounds:     10

=== Round 1: Work Phase ===
  Waiting... claude=working codex=working (120s/600s)
  Waiting... claude=working codex=done (180s/600s)
  Waiting... claude=done codex=done (240s/600s)

=== Round 1: Review Phase ===
  Waiting... claude=reviewing codex=reviewing (30s/300s)
  Waiting... claude=review-done codex=review-done (90s/300s)

=== Round 2: Work Phase ===
  ...

Both PRs created - session complete!
Claude PR: https://github.com/user/myproject/pull/42
Codex PR:  https://github.com/user/myproject/pull/43
```

## Commands

### Session Management

```bash
agent-duo start <feature>      # Create worktrees, tmux session
agent-duo run [options]        # Run orchestrator loop
agent-duo status               # Show current state
agent-duo stop                 # Stop servers, keep worktrees
agent-duo cleanup [--full]     # Remove worktrees (--full: everything)
```

### Orchestrator Options

```bash
agent-duo run \
  --work-timeout 600 \     # Seconds before interrupting work phase
  --review-timeout 300 \   # Seconds before interrupting review phase
  --max-rounds 10 \        # Maximum work/review cycles
  --auto-start             # Auto-launch agent CLIs
```

### Manual Control

```bash
agent-duo nudge claude "Please wrap up and signal done."
agent-duo interrupt codex
agent-duo pr claude          # Create PR for an agent
```

## The Work/Review Cycle

Each round consists of:

1. **Work Phase**: Agents implement their solution independently
   - They can peek at peer's worktree for insight (not imitation)
   - Signal `done` when ready for review
   - Orchestrator interrupts if timeout reached

2. **Review Phase**: Agents review each other's code
   - Write structured review to `.peer-sync/reviews/`
   - Note different tradeoffs, not defects
   - Signal `review-done` when finished

3. **Repeat** until both agents create PRs

## Documentation

- [DESIGN.md](DESIGN.md) - Full architecture and protocol details
- [CLAUDE.md](CLAUDE.md) - Instructions for AI agents working on this repo

## Requirements

- `git` with worktree support
- `tmux`
- `gh` CLI (for PR creation)
- Optional: `ttyd` for web terminals (`--ttyd` mode)

## License

MIT
