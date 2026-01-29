# agent-duo

Coordinate two AI coding agents (Claude, Codex, etc.) working in parallel on the same task, producing **two alternative solutions** as separate PRs.

Also includes **agent-solo**: a single-worktree mode where one agent codes and another reviews.

## Why?

When solving complex problems, different approaches have different tradeoffs. Instead of getting one solution and hoping it's the best, agent-duo lets two AI agents work independently on the same task. You get:

- **Two distinct implementations** to compare
- **Peer review** between agents each round
- **Divergent thinking** - agents are encouraged to take different approaches
- **Better coverage** of the solution space

Or with **agent-solo**, a single agent implements while another reviews, giving you:

- **Focused implementation** by a dedicated coder agent
- **Independent code review** by a separate reviewer agent
- **Single worktree** - simpler setup, no branch conflicts

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
git clone https://github.com/lukstafi/agent-duo
cd agent-duo
./agent-duo setup    # For duo mode (two parallel agents)
./agent-solo setup   # For solo mode (coder + reviewer)
```

This installs:
- `agent-duo` and/or `agent-solo` CLI to `~/.local/bin/`
- Skills to `~/.claude/commands/` and `~/.codex/skills/`
- Completion hooks for automatic phase signaling

Add `~/.local/bin` to your PATH if needed.

After installation, run `agent-duo doctor` to verify your setup.

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

# 2. Start the duo session with orchestration (recommended)
agent-duo start add-auth --auto-run
# Opens 3 web terminals (orchestrator, claude, codex) and starts immediately

# With optional clarify/pushback stages:
agent-duo start add-auth --auto-run --clarify    # Agents propose approaches first
agent-duo start add-auth --auto-run --pushback   # Agents suggest task improvements first

# Alternative: manual control
agent-duo start add-auth           # Start ttyd web terminals only
agent-duo run --auto-start         # Then run orchestrator separately

# Or use tmux directly (no web terminals)
agent-duo start add-auth --no-ttyd
tmux attach -t duo-add-auth
```

### Solo Mode Quick Start

```bash
# Solo mode: one agent codes, another reviews
agent-solo start add-auth --auto-run

# Swap roles (codex codes, claude reviews)
agent-solo start add-auth --auto-run --coder codex --reviewer claude
```

## Example Session

Here's what a typical session looks like:

```
$ agent-duo start add-auth --auto-run
Starting Agent Duo session: add-auth
Project: myproject
Creating worktree for claude...
Creating worktree for codex...
Started ttyd servers

Web terminals:
  Orchestrator: http://localhost:7680
  Claude:       http://localhost:7681
  Codex:        http://localhost:7682

Starting orchestrator with --auto-start...
Stop with: agent-duo stop
```

The orchestrator terminal shows:

```
=== Agent Duo Orchestrator ===
Feature:        add-auth
Work timeout:   1200s
Review timeout: 600s
Max rounds:     10

=== Round 1: Work Phase ===
  Waiting... claude=working codex=working (120s/1200s)
  Waiting... claude=working codex=done (180s/1200s)
  Waiting... claude=done codex=done (240s/1200s)

=== Round 1: Review Phase ===
  Waiting... claude=reviewing codex=reviewing (30s/600s)
  Waiting... claude=review-done codex=review-done (90s/600s)

=== Round 2: Work Phase ===
  ...

Both PRs created - session complete!
Claude PR: https://github.com/user/myproject/pull/42
Codex PR:  https://github.com/user/myproject/pull/43
```

## Commands

### Session Management

```bash
agent-duo start <feature>              # Start with ttyd web terminals (auto-allocates 3 consecutive ports)
agent-duo start <feature> --port 8000  # Use fixed ports 8000, 8001, 8002 (fails if occupied)
agent-duo start <feature> --auto-run   # Start and run orchestrator immediately
agent-duo start <feature> --clarify    # Enable clarify stage (agents propose approaches)
agent-duo start <feature> --pushback   # Enable pushback stage (agents improve task)
agent-duo start <feature> --no-ttyd    # Start with single tmux session (no web terminals)
agent-duo run [options]                # Run orchestrator loop (if not using --auto-run)
agent-duo status                       # Show current state
agent-duo stop                         # Stop servers, keep worktrees
agent-duo restart [--auto-run]         # Recover session after system restart/crash
agent-duo cleanup [--full]             # Remove session state (--full: also worktrees/branches)
agent-duo doctor                       # Check system configuration and diagnose issues
agent-duo config [key] [value]         # Get/set configuration (e.g., ntfy_topic)
```

### Orchestrator Options

```bash
agent-duo run \
  --work-timeout 1200 \     # Seconds before interrupting work phase
  --review-timeout 600 \    # Seconds before interrupting review phase
  --clarify-timeout 600 \   # Seconds for clarify stage
  --pushback-timeout 600 \  # Seconds for pushback stage
  --max-rounds 10 \         # Maximum work/review cycles
  --auto-start              # Auto-launch agent CLIs
```

### Model Selection

```bash
agent-duo start <feature> --auto-run \
  --claude-model opus \     # Claude model (opus, sonnet)
  --codex-model o3 \        # Codex/GPT model (o3, gpt-4.1)
  --codex-thinking high     # Codex reasoning effort (low, medium, high)
```

### Manual Control

```bash
agent-duo nudge claude "Please wrap up and signal done."
agent-duo interrupt codex
agent-duo pr claude          # Create PR for an agent
agent-duo confirm            # Confirm clarify phase, proceed to work
```

## The Work/Review Cycle

Each round consists of:

1. **Clarify Phase** (optional, `--clarify`): Agents propose approaches
   - Write approach and questions to `.peer-sync/clarify-<agent>.md`
   - User receives notification (email/ntfy) and can respond
   - Run `agent-duo confirm` to proceed

2. **Pushback Phase** (optional, `--pushback`): Agents improve the task
   - Agents propose edits to the task file
   - User can accept, reject, or modify suggestions
   - Run `agent-duo confirm` to proceed

3. **Work Phase**: Agents implement their solution independently
   - They can peek at peer's worktree for insight (not imitation)
   - Signal `done` when ready for review
   - Orchestrator interrupts if timeout reached

4. **Review Phase**: Agents review each other's code
   - Write structured review to `.peer-sync/reviews/`
   - Note different tradeoffs, not defects
   - Signal `review-done` when finished

5. **Repeat** until both agents create PRs

## Notifications

Configure push notifications to know when agents need attention:

```bash
# ntfy.sh - free push notifications (recommended)
agent-duo config ntfy_topic my-agent-duo-topic
# Subscribe at: https://ntfy.sh/my-agent-duo-topic

# Email notifications use git config user.email
# Requires working mail setup (see: agent-duo doctor)
```

## Agent Solo Mode

Agent-solo is a simpler alternative where one agent codes and another reviews:

```bash
agent-solo start <feature> --auto-run
```

**Workflow:**
1. **Coder** implements the solution
2. **Reviewer** examines code and writes review with verdict (APPROVE/REQUEST_CHANGES)
3. If approved: create PR. If changes requested: coder addresses feedback, loop continues.

**Key differences from duo mode:**
- Single worktree (both agents work on same branch)
- Sequential rather than parallel work
- Clear coder/reviewer roles (swappable with `--coder` and `--reviewer`)

See `agent-solo help` for full command reference.

## Documentation

- [docs/DESIGN.md](docs/DESIGN.md) - Full architecture and protocol details
- [CLAUDE.md](CLAUDE.md) - Instructions for AI agents working on this repo

## Requirements

- **Bash 4.0+** (macOS ships with Bash 3.2; install via `brew install bash`)
- `git` with worktree support
- `tmux`
- `gh` CLI (for PR creation)
- `ttyd` for web terminals (use `--no-ttyd` to disable)
- `claude` CLI (Claude Code)
- `codex` CLI (OpenAI Codex)

### macOS Bash Setup

macOS includes Bash 3.2 for licensing reasons. Install a modern version:

```bash
brew install bash
# Add to PATH (for Apple Silicon Macs):
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
# Verify:
bash --version  # Should show 5.x
```

## Troubleshooting

Run `agent-duo doctor` to diagnose common issues:

```bash
agent-duo doctor              # Check all configuration
agent-duo doctor --send-email # Test email delivery
agent-duo doctor --send-ntfy  # Test ntfy notifications
```

The doctor command checks: required tools, AI CLIs, git config, email/ntfy setup, skills installation, hook configuration, and PATH.

## License

MIT
