# Agent Duo: Implement the Agent Duo System

You are one of two AI agents (Claude and Codex) tasked with implementing the **agent-duo** collaborative development system. Yes, this is meta - you're implementing the system you're currently using.

## Project Goal

Build a system where two AI coding agents work **in parallel** on the same task, each in their own git worktree, periodically reviewing each other's uncommitted changes to produce **two alternative solutions** as separate PRs.

## Current State

The repo has a basic scaffold:
- `start.sh` - Launches worktrees and ttyd servers
- `orchestrate.sh` - Basic coordination loop (needs refinement)
- `skills/` - Skill files for each agent (needs refinement)
- `.peer-sync/` - Coordination directory

## Your Task

Improve and complete the agent-duo system. Consider:

### Core Functionality
1. **Worktree management**: Setup, cleanup, branch management
2. **Turn coordination**: Work phase → Review phase → Work phase loop
3. **Status signaling**: How agents communicate phase completion
4. **PR creation**: Final submission of each agent's solution

### Key Design Decisions
- How should agents signal they're done with a phase?
- How should the orchestrator detect completion?
- How should reviews be structured?
- How should agents read each other's worktrees effectively?
- Error handling: what if an agent crashes or hangs?

### Advanced Features (optional)
- Timeout handling
- Progress indicators
- Better prompts for divergent thinking
- Setup script for installing skills
- README documentation

## Constraints

- Keep it simple: shell scripts + skill markdown files
- No external dependencies beyond git, tmux, ttyd, gh CLI
- Skills must work with both Claude Code and Codex CLI conventions

## Your Approach

**IMPORTANT**: You and your peer started from the same prompt. Your goal is to develop an **alternative implementation**, not to converge on the same solution.

- If you see your peer taking approach A, consider if approach B has merit
- Different architectural choices are valuable
- The human will have two PRs to compare at the end

## Environment

- Your worktree: current directory (read/write)
- Peer's worktree: `$PEER_WORKTREE` (read-only)
- Sync directory: `$PEER_SYNC`
- Your identity: `$MY_NAME`
- Peer's identity: `$PEER_NAME`

## When Done with Work Phase

```bash
echo "done" > "$PEER_SYNC/${MY_NAME}-status"
```

Then stop and wait for the review phase.

## When Ready to Submit PR

```bash
git checkout -b ${MY_NAME}-solution
git add -A
git commit -m "Agent-duo implementation by ${MY_NAME}"
git push -u origin ${MY_NAME}-solution
gh pr create --title "${MY_NAME}'s agent-duo implementation" --body "..."
gh pr view --json url -q '.url' > "$PEER_SYNC/${MY_NAME}-pr"
```

Good luck! May the best (or most interestingly different) solution win.
