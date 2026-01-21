# agent-duo

Shell scripts and skills to coordinate two AI agent peers (Claude and Codex) on providing alternative solutions to the same task.

## Overview

Agent Duo enables **parallel development** where two AI coding agents work simultaneously on the same problem, each in their own git worktree. The agents periodically review each other's uncommitted changes, providing feedback while maintaining distinct implementation approaches. The result is **two alternative PRs** for the same task.

```
┌─────────────────────────────────────────────────────────────┐
│                    Agent Duo Session                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────┐              ┌─────────────┐              │
│   │   Claude    │              │    Codex    │              │
│   │  Worktree   │◄────────────►│  Worktree   │              │
│   │ (claude-work)│   Reviews   │ (codex-work) │              │
│   └─────────────┘              └─────────────┘              │
│          │                            │                      │
│          └──────────┬─────────────────┘                      │
│                     │                                        │
│              ┌──────▼──────┐                                 │
│              │ .peer-sync/ │                                 │
│              │  - states   │                                 │
│              │  - diffs    │                                 │
│              │  - reviews  │                                 │
│              └─────────────┘                                 │
│                     │                                        │
│              ┌──────▼──────┐                                 │
│              │ Orchestrator│                                 │
│              │   (tmux)    │                                 │
│              └─────────────┘                                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **git** - Version control
- **tmux** - Terminal multiplexer
- **ttyd** - Terminal web server (`brew install ttyd`)
- **gh** - GitHub CLI (optional, for PR creation)
- **Claude Code** and/or **Codex CLI**

## Quick Start

```bash
# 1. Clone and enter the repo
git clone https://github.com/lukstafi/agent-duo.git
cd agent-duo

# 2. Install skills for your AI agents
./install-skills.sh

# 3. Create a task file
cat > task.md << 'EOF'
# Build a TODO API

Create a simple REST API for managing TODO items.
Requirements:
- CRUD operations
- In-memory storage
- JSON responses
EOF

# 4. Start the session
./start.sh task.md

# 5. In Claude's ttyd terminal (http://localhost:7681):
#    Run: claude --skill peer-work

# 6. In Codex's ttyd terminal (http://localhost:7682):
#    Run: codex --skill peer-work
```

## Session Flow

### Turn-Based Coordination

Each session runs for a configurable number of turns (default: 3):

```
Turn 1: [WORK] → [REVIEW] →
Turn 2: [WORK] → [REVIEW] →
Turn 3: [WORK] → [REVIEW] → [CREATE PRs]
```

### States

Agents transition through these states:

| State | Description |
|-------|-------------|
| `INITIALIZING` | Agent starting up |
| `WORKING` | Actively implementing |
| `READY_FOR_REVIEW` | Finished work/review phase |
| `REVIEWING` | Reading peer's changes |
| `DONE` | Session complete |

### Phase Timing

- Work phase timeout: 10 minutes
- Review phase timeout: 5 minutes
- Orchestrator advances phases on timeout

## File Structure

```
agent-duo/
├── start.sh           # Launch worktrees and agents
├── orchestrate.sh     # Coordinate turn-based workflow
├── cleanup.sh         # Tear down worktrees and processes
├── install-skills.sh  # Install skills to agent CLIs
├── skills/
│   ├── peer-work.md   # Main working skill
│   └── peer-review.md # Review phase guidance
├── .peer-sync/        # Coordination directory (created at runtime)
│   ├── claude.state   # Claude's current state
│   ├── codex.state    # Codex's current state
│   ├── turn           # Current turn number
│   ├── current_phase  # WORK or REVIEW
│   ├── task.md        # Task description
│   ├── claude.diff    # Claude's changes for review
│   ├── codex.diff     # Codex's changes for review
│   └── *_review_*.md  # Review files
└── README.md
```

## How It Works

### 1. Worktree Setup (`start.sh`)

Creates two git worktrees in sibling directories:
- `../agent-duo-claude` on branch `claude-work`
- `../agent-duo-codex` on branch `codex-work`

Both worktrees share a symlinked `.peer-sync/` for coordination.

### 2. Orchestration (`orchestrate.sh`)

The orchestrator:
1. Signals agents to start working
2. Polls for state changes
3. Generates diffs when work phases complete
4. Signals review phases
5. Advances through turns
6. Creates PRs at the end

### 3. Agent Skills

Agents use the `peer-work` skill which teaches them to:
- Check their identity and current phase
- Work on distinct implementations
- Signal state transitions
- Review peer's changes constructively
- Maintain divergent approaches

## Configuration

Edit `orchestrate.sh` to customize:

```bash
MAX_TURNS=3           # Number of work/review cycles
WORK_TIMEOUT=600      # Work phase timeout (seconds)
REVIEW_TIMEOUT=300    # Review phase timeout (seconds)
POLL_INTERVAL=5       # State polling interval (seconds)
```

## Manual State Control

Agents signal state changes by writing to their state file:

```bash
# Claude signals ready for review
echo "READY_FOR_REVIEW" > .peer-sync/claude.state

# Codex signals ready for review
echo "READY_FOR_REVIEW" > .peer-sync/codex.state
```

## Cleanup

```bash
# Remove worktrees and stop processes
./cleanup.sh

# Also remove state files
./cleanup.sh --full
```

## Tips for Good Sessions

### For Divergent Solutions

1. **Different architectures**: One agent might use MVC, another might use functional composition
2. **Different libraries**: One uses Express, another uses Fastify
3. **Different patterns**: One uses classes, another uses closures

### For Effective Reviews

1. **Be constructive**: Suggest improvements, don't just criticize
2. **Respect divergence**: Don't push peer toward your approach
3. **Be specific**: Reference files and line numbers

### For Smooth Coordination

1. **Commit frequently**: Makes changes visible in diffs
2. **Signal promptly**: Don't forget to update your state
3. **Read reviews**: Incorporate valid feedback

## Troubleshooting

### Agents not coordinating
- Check `.peer-sync/*.state` files
- Verify symlinks in worktrees
- Check orchestrator logs in tmux

### ttyd not starting
- Check if ports 7681/7682 are in use
- Try `pkill ttyd` and restart

### PRs not created
- Ensure `gh` CLI is installed and authenticated
- Check for uncommitted changes in worktrees

## License

MIT
