# Peer Work Skill

You are participating in an **Agent Duo** session - a collaborative development exercise where two AI agents (Claude and Codex) work **in parallel** on the same task, producing **alternative solutions**.

## Your Identity

Check which agent you are by looking at your current branch:
- If on `claude-work` branch: You are **Claude**
- If on `codex-work` branch: You are **Codex**

## Coordination Protocol

The session follows a round-based structure coordinated via the `agent-duo` CLI and files in `.peer-sync/`:

### Key Files
- `.peer-sync/claude.status` - Claude's status (format: `STATE|EPOCH|MESSAGE`)
- `.peer-sync/codex.status` - Codex's status
- `.peer-sync/round` - Current round number (1, 2, 3...)
- `.peer-sync/phase` - Current phase: "work", "review", or "done"
- `.peer-sync/task.md` - The task description
- `.peer-sync/rounds/N/` - Snapshots for round N

### States
- `INITIALIZING` - Starting up
- `WORKING` - Actively implementing
- `READY` - Finished current phase, waiting for peer
- `REVIEWING` - Reading and reviewing peer's changes
- `DONE` - Session complete
- `ERROR` - Something went wrong

## Signaling State Changes

Use the `agent-duo` CLI to signal state changes:

```bash
# Signal you're done with work phase (from repo root or via .peer-sync symlink)
../agent-duo signal claude READY "finished implementing feature X"

# Or from the main repo
./agent-duo signal codex READY "completed API endpoints"
```

The CLI handles atomic locking and timestamps automatically.

## Reading Peer's Work

During review phases, find peer snapshots in `.peer-sync/rounds/N/`:

```bash
# List available snapshots
ls .peer-sync/rounds/

# Read peer's snapshot for current round
cat .peer-sync/rounds/1/codex-snapshot.txt

# Or apply their patch to see changes
cat .peer-sync/rounds/1/codex.patch
```

You can also read files directly from peer's worktree:
```bash
# Get peer's worktree path
PEER_PATH=$(cat .peer-sync/codex.path)
cat "$PEER_PATH/src/main.js"
```

## Work Phase Guidelines

**Goal**: Produce a **distinct, alternative implementation** from your peer.

### First Round
1. Read the task: `cat .peer-sync/task.md`
2. Check current state: `../agent-duo status`
3. Design your approach - deliberately consider alternatives
4. Implement your solution
5. Signal completion: `../agent-duo signal <you> READY "description"`

### Subsequent Rounds
1. Read peer's review of your work (if any) in `.peer-sync/rounds/N/`
2. Consider feedback, but maintain your distinct approach
3. Continue building on your implementation
4. Signal when ready

### Divergence Strategies
- If peer uses approach A, consider approach B
- Different file structures are OK
- Different libraries/patterns are encouraged
- The goal is **two viable alternatives**, not one "correct" answer

## Review Phase Guidelines

When reviewing your peer's work:

1. **Read their snapshot**: `cat .peer-sync/rounds/N/<peer>-snapshot.txt`
2. **Understand their approach** - what pattern/structure are they using?
3. **Write your review** to `.peer-sync/rounds/N/<peer>-review.md`:

```markdown
# Review of {Peer}'s Work - Round {N}

## Approach Summary
(Brief description of their approach)

## Strengths
- ...

## Concerns
- ...

## Suggestions
- ...
```

4. **Signal completion**: `../agent-duo signal <you> READY "reviewed peer"`

## Quick Reference

```bash
# Check session status
../agent-duo status

# Signal work done
../agent-duo signal claude READY "message"
../agent-duo signal codex READY "message"

# Read task
cat .peer-sync/task.md

# Read peer snapshot
cat .peer-sync/rounds/1/codex-snapshot.txt

# Read current phase
cat .peer-sync/phase

# Read current round
cat .peer-sync/round
```

## Important Rules

1. **Don't copy** your peer's implementation
2. **Don't converge** - maintain distinctness
3. **Do communicate** via reviews
4. **Do commit frequently** to make your work visible in snapshots
5. **Respect timeouts** - the orchestrator advances phases even if you're not ready

## Session Flow

```
Round 1:
  [WORK] Both agents work independently → signal READY
  [REVIEW] Review peer's snapshot → signal READY

Round 2:
  [WORK] Incorporate feedback, continue building → signal READY
  [REVIEW] Review peer's progress → signal READY

Round 3:
  [WORK] Final polish → signal READY
  [REVIEW] Final review → signal READY

[DONE] Create PRs with: ../agent-duo pr claude
```

Good luck! Remember: the goal is **two quality alternatives**, not agreement.
