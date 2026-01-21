# agent-duo

Coordinate two AI agents (Claude and Codex) on providing **alternative solutions** to the same task.

## Overview

Agent Duo enables **parallel development** where two AI coding agents work simultaneously on the same problem, each in their own git worktree. The agents periodically review each other's work via snapshots, providing feedback while maintaining distinct implementation approaches. The result is **two alternative PRs**.

```
┌─────────────────────────────────────────────────────────────┐
│                    Agent Duo Session                         │
├─────────────────────────────────────────────────────────────┤
│   ┌─────────────┐              ┌─────────────┐              │
│   │   Claude    │   snapshots  │    Codex    │              │
│   │  Worktree   │◄────────────►│  Worktree   │              │
│   └─────────────┘   & reviews  └─────────────┘              │
│          │                            │                      │
│          └──────────┬─────────────────┘                      │
│              ┌──────▼──────┐                                 │
│              │ .peer-sync/ │                                 │
│              │ rounds/1/   │                                 │
│              │ rounds/2/   │                                 │
│              └─────────────┘                                 │
│                     │                                        │
│              ┌──────▼──────┐                                 │
│              │ Orchestrator│                                 │
│              └─────────────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **git** - Version control
- **tmux** - Terminal multiplexer
- **ttyd** - Terminal web server (optional, for `--ttyd` mode)
- **gh** - GitHub CLI (optional, for PR creation)

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/lukstafi/agent-duo.git
cd agent-duo

# 2. Create a task file
cat > task.md << 'EOF'
# Build a TODO API

Create a REST API for managing TODO items.
- CRUD operations
- In-memory storage
- JSON responses
EOF

# 3. Start the session
./agent-duo start task.md

# 4. In each agent's tmux window, run the AI agent
#    Window 1 (claude): claude
#    Window 2 (codex):  codex
```

## CLI Reference

```
agent-duo - Coordinate two AI agents on parallel implementations

COMMANDS:
    start [task.md] [--ttyd]   Start a new session
    setup                      Create worktrees without launching
    cleanup [--full]           Remove worktrees and processes

    signal <agent> <state> [msg]   Signal agent state change
    snapshot <agent>               Generate snapshot for review

    orchestrate                Run the coordination loop
    status                     Show current session state
    pr <agent>                 Create PR for agent's work

AGENTS: claude, codex
STATES: INITIALIZING, WORKING, READY, REVIEWING, DONE, ERROR
```

### Examples

```bash
# Start a session
./agent-duo start task.md

# Start with web terminals (ttyd)
./agent-duo start task.md --ttyd

# Check status
./agent-duo status

# Agent signals work complete
./agent-duo signal claude READY "implemented the API"

# Create PRs when done
./agent-duo pr claude
./agent-duo pr codex

# Clean up
./agent-duo cleanup
./agent-duo cleanup --full  # also removes state files
```

## Session Flow

Each session runs for 3 rounds (configurable):

```
Round 1:  [WORK] → snapshot → [REVIEW] →
Round 2:  [WORK] → snapshot → [REVIEW] →
Round 3:  [WORK] → snapshot → [REVIEW] → [PR]
```

### States

| State | Description |
|-------|-------------|
| `WORKING` | Actively implementing |
| `READY` | Finished phase, waiting for peer |
| `REVIEWING` | Reading peer's snapshot |
| `DONE` | Session complete |

### Timeouts

- Work phase: 10 minutes
- Review phase: 5 minutes
- Orchestrator advances automatically on timeout

## File Structure

```
agent-duo/
├── agent-duo              # Unified CLI
├── skills/
│   ├── peer-work.md       # Main coordination skill
│   └── peer-review.md     # Review phase skill
└── .peer-sync/            # Coordination (created at runtime)
    ├── phase              # Current phase
    ├── round              # Current round number
    ├── claude.status      # STATE|EPOCH|MESSAGE
    ├── codex.status
    ├── claude.path        # Worktree paths
    ├── codex.path
    ├── task.md            # Task description
    └── rounds/
        ├── 1/
        │   ├── claude-snapshot.txt
        │   ├── claude.patch
        │   ├── codex-snapshot.txt
        │   ├── codex.patch
        │   └── *-review.md
        ├── 2/
        └── 3/
```

## How Agents Coordinate

1. **Orchestrator** sets phase to "work" and agent states to "WORKING"
2. **Agents** implement their solutions independently
3. **Agents** signal completion: `./agent-duo signal <name> READY`
4. **Orchestrator** generates snapshots and sets phase to "review"
5. **Agents** read peer snapshots, write reviews, signal READY
6. Repeat for configured number of rounds
7. **Orchestrator** marks session DONE

### Status Format

Status files use the format: `STATE|EPOCH|MESSAGE`

```
WORKING|1705847123|implementing feature X
READY|1705847456|finished round 1
```

### Atomic Locking

The CLI uses mkdir-based locking to prevent race conditions when multiple agents write status simultaneously.

## Agent Skills

Copy skills to your AI agent's skills directory, or reference them directly:

```bash
# For Claude Code
cp skills/*.md ~/.claude/skills/

# Then agents can use the peer-work skill
claude  # in claude's worktree
```

The skills teach agents to:
- Check their identity and current phase
- Signal state transitions properly
- Review peer snapshots constructively
- Maintain divergent approaches

## Configuration

Edit variables at the top of `agent-duo`:

```bash
MAX_TURNS=3           # Number of work/review cycles
WORK_TIMEOUT=600      # Work phase timeout (seconds)
REVIEW_TIMEOUT=300    # Review phase timeout (seconds)
POLL_INTERVAL=5       # State polling interval
```

## Tips

### For Divergent Solutions
- Different architectures (MVC vs functional)
- Different libraries (Express vs Fastify)
- Different patterns (classes vs closures)

### For Effective Reviews
- Be constructive, not just critical
- Don't push peer toward your approach
- Reference specific files and lines

### For Smooth Sessions
- Commit frequently (makes snapshots useful)
- Signal promptly when done
- Read and consider peer feedback

## Troubleshooting

**Agents not coordinating?**
- Check `./agent-duo status`
- Verify `.peer-sync/*.status` files

**Session stuck?**
- Orchestrator advances on timeout
- Check tmux orchestrator window for logs

**PRs not created?**
- Ensure `gh` CLI is installed and authenticated
- Check for uncommitted changes

## License

MIT
