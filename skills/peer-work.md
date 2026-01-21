# Peer Work Skill

You are participating in an **Agent Duo** session - a collaborative development exercise where two AI agents (Claude and Codex) work **in parallel** on the same task, producing **alternative solutions**.

## Your Identity

Check which agent you are by reading `.peer-sync/your_identity` or by checking your current branch:
- If on `claude-work` branch: You are **Claude**
- If on `codex-work` branch: You are **Codex**

## Coordination Protocol

The session follows a turn-based structure coordinated via files in `.peer-sync/`:

### State Files
- `.peer-sync/claude.state` - Claude's current state
- `.peer-sync/codex.state` - Codex's current state
- `.peer-sync/turn` - Current turn number (1, 2, 3...)
- `.peer-sync/current_phase` - Either "WORK" or "REVIEW"
- `.peer-sync/task.md` - The task description (if provided)

### States You Can Be In
- `INITIALIZING` - Starting up
- `WORKING` - Actively implementing
- `READY_FOR_REVIEW` - Finished current work phase, waiting for peer
- `REVIEWING` - Reading and reviewing peer's changes
- `DONE` - Session complete

### State Transitions (Your Responsibility)
1. When you see your state is `WORKING`:
   - Work on the task
   - When done with this phase, set your state to `READY_FOR_REVIEW`

2. When you see your state is `REVIEWING`:
   - Read your peer's diff from `.peer-sync/{peer}.diff`
   - Write your review to `.peer-sync/{peer}_review_turn{N}.md`
   - When done, set your state back to `READY_FOR_REVIEW`

## Signaling State Changes

To change your state, write to your state file:
```bash
# Example for Claude:
echo "READY_FOR_REVIEW" > .peer-sync/claude.state

# Example for Codex:
echo "READY_FOR_REVIEW" > .peer-sync/codex.state
```

## Reading Peer's Work

During review phases, you can find:
- `.peer-sync/{peer}.diff` - Git diff of peer's changes
- `.peer-sync/{peer}.files` - List of files peer modified
- Peer's worktree path in `.peer-sync/{peer}_worktree_path`

You can directly read files from peer's worktree:
```bash
# Read a file from peer's worktree
cat "$(cat .peer-sync/codex_worktree_path)/path/to/file.js"
```

## Work Phase Guidelines

**Goal**: Produce a **distinct, alternative implementation** from your peer.

### First Turn
1. Read the task description from `.peer-sync/task.md`
2. Design your approach - deliberately consider alternatives
3. Start implementing your solution
4. Focus on getting a working foundation

### Subsequent Turns
1. Read peer's review of your work (if any)
2. Consider their feedback, but maintain your distinct approach
3. Continue building on your implementation
4. Improve based on valid critiques without converging

### Divergence Strategies
- If peer uses approach A, consider approach B
- Different file structures are OK
- Different libraries/patterns are encouraged
- The goal is **two viable alternatives**, not one "correct" answer

## Review Phase Guidelines

When reviewing your peer's work:

1. **Read their diff** at `.peer-sync/{peer}.diff`
2. **Understand their approach** - what pattern/structure are they using?
3. **Provide constructive feedback** including:
   - What's working well
   - Potential issues or bugs
   - Suggestions (without pushing them to your approach)
   - Questions about their design decisions

4. **Write your review** to `.peer-sync/{peer}_review_turn{N}.md`:
```markdown
# Review of {Peer}'s Work - Turn {N}

## Approach Summary
(Brief description of their approach)

## Strengths
- ...

## Concerns
- ...

## Suggestions
- ...

## Questions
- ...
```

5. **Signal completion** by setting your state to `READY_FOR_REVIEW`

## Important Rules

1. **Don't copy** your peer's implementation
2. **Don't converge** - maintain distinctness
3. **Do communicate** via reviews
4. **Do commit frequently** to make your work visible
5. **Respect timeouts** - the orchestrator will advance phases even if you're not ready

## Startup Checklist

When you first start:
1. [ ] Check your identity (which agent am I?)
2. [ ] Read the task from `.peer-sync/task.md`
3. [ ] Check current turn number from `.peer-sync/turn`
4. [ ] Check current phase from `.peer-sync/current_phase`
5. [ ] Read any existing peer reviews of your work
6. [ ] Begin working or reviewing based on phase
7. [ ] Signal state changes appropriately

## Session Flow

```
Turn 1:
  [WORK] Both agents work independently
  [REVIEW] Both agents review peer's changes

Turn 2:
  [WORK] Incorporate feedback, continue building
  [REVIEW] Review peer's progress

Turn 3:
  [WORK] Final polish
  [REVIEW] Final review

[DONE] Orchestrator creates PRs for both solutions
```

Good luck! Remember: the goal is **two quality alternatives**, not agreement.
