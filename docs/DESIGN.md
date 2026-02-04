# Agent Duo - Architecture Document

## Overview

Agent Duo coordinates two AI coding agents working in parallel on the same task, each in their own git worktree, producing two alternative solutions as separate PRs. Multiple features can run in parallel, each with isolated session state.

```
┌─────────────────────────────────────────────────────────────────┐
│                      Agent Duo Session (Multi-Feature)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ~/myapp/                    (main branch, task specs here)     │
│      ├── auth.md, payments.md (task descriptions)               │
│      └── .agent-sessions/    (registry of active sessions)      │
│                                                                 │
│  ~/myapp-auth/               (root worktree, orchestrator here) │
│      └── .peer-sync/         (session state for "auth")         │
│                                                                 │
│  ~/myapp-auth-claude/        (branch: auth-claude)              │
│      └── .peer-sync -> ../myapp-auth/.peer-sync                 │
│                                                                 │
│  ~/myapp-auth-codex/         (branch: auth-codex)               │
│      └── .peer-sync -> ../myapp-auth/.peer-sync                 │
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
agent-duo start <f1> <f2> ...   # Start multiple features in parallel (each needs its own .md file)
agent-duo start <f> --clarify   # Start with clarify phase before work
agent-duo start <f> --pushback  # Start with pushback phase (task improvement)
agent-duo start <f> --auto-run  # Start and run orchestrator immediately
agent-duo run [options]         # Run orchestrator loop (from orchestrator worktree)
agent-duo stop                  # Stop ttyd servers, keep worktrees
agent-duo stop --feature <f>    # Stop specific session only
agent-duo restart [--auto-run] [--no-ttyd] [--feature <name>]  # Recover session(s)
agent-duo status                # Show all active sessions
agent-duo status --feature <f>  # Show specific session
agent-duo confirm               # Confirm clarify/pushback phase, proceed
agent-duo pr <agent>            # Create PR for agent's solution
agent-duo merge [--auto-restart]# Start merge phase (fresh sessions)
agent-duo run-merge             # Run merge with existing sessions
agent-duo cleanup [--full]      # Remove worktrees (--full: also state)
agent-duo cleanup --feature <f> # Cleanup specific session only
agent-duo setup                 # Install agent-duo to PATH and skills
agent-duo doctor                # Check system configuration
agent-duo config [key] [value]  # Get/set configuration (ntfy_topic, etc.)
agent-duo nudge <agent> [msg]   # Send message to agent terminal
agent-duo interrupt <agent>     # Interrupt agent (Esc)
agent-duo escalate-resolve      # Review and resolve pending escalations
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
agent-duo escalate <reason> [message]         # Escalate issue to user
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
| **Phase** | Orchestrator | `gather`, `clarify`, `pushback`, `work`, `review`, `update-docs`, `pr-comments`, `merge` | Current stage of the round |
| **Agent Status** | Agent | `gathering`, `gather-done`, `clarifying`, `clarify-done`, `pushing-back`, `pushback-done`, `working`, `done`, `reviewing`, `review-done`, `updating-docs`, `docs-update-done`, `interrupted`, `error`, `escalated`, `pr-created`, `voting`, `vote-done`, `debating`, `debate-done`, `merging`, `merge-done`, `merge-reviewing`, `merge-review-done` | What agent is doing |
| **Session State** | Orchestrator | `active`, `complete` | Overall progress |

### State Files (in `.peer-sync/`)

```
.peer-sync/
├── session           # "active" or "complete"
├── phase             # "gather", "clarify", "pushback", "work", "review", "update-docs", "pr-comments", or "merge"
├── round             # Current round number (1, 2, 3...)
├── feature           # Feature name for this session
├── ports             # Port allocations (ORCHESTRATOR_PORT, CLAUDE_PORT, CODEX_PORT)
├── gather-mode       # "true" or "false" - whether gather phase is enabled (solo mode)
├── clarify-mode      # "true" or "false" - whether clarify phase is enabled
├── pushback-mode     # "true" or "false" - whether pushback phase is enabled
├── docs-update-mode  # "true" or "false" - whether update-docs phase is enabled
├── gather-confirmed  # Present when gather phase is complete (solo mode)
├── clarify-confirmed # Present when user confirms clarify phase
├── pushback-confirmed # Present when user confirms pushback phase
├── task-context.md   # Reviewer's gathered context for the coder (solo mode gather phase)
├── clarify-claude.md # Claude's approach and questions (clarify phase)
├── clarify-codex.md  # Codex's approach and questions (clarify phase)
├── codex-thinking    # Codex reasoning effort level
├── claude.status     # Agent status: "working|1705847123|implementing API"
├── codex.status      # Format: status|epoch|message
├── escalation-claude.md  # Escalation from claude (if any)
├── escalation-codex.md   # Escalation from codex (if any)
├── escalation-resolved   # Present when escalations have been resolved
├── claude.pr         # Claude's PR URL (when created)
├── codex.pr          # Codex's PR URL (when created)
├── docs-update-claude.done # Present when Claude completes update-docs phase
├── docs-update-codex.done  # Present when Codex completes update-docs phase
├── workflow-feedback-claude.md # Claude's workflow feedback
├── workflow-feedback-codex.md  # Codex's workflow feedback
├── workflow-feedback-copied    # Present when feedback has been persisted locally
├── claude.pr-hash    # Hash of claude PR comments (for change detection)
├── codex.pr-hash     # Hash of codex PR comments (for change detection)
├── merge-round       # Current merge debate round (0=initial, 1-2=debate)
├── merge-decision    # Final decision: "claude" or "codex"
├── merge-review-claude.md  # Claude's merge review (if reviewer)
├── merge-review-codex.md   # Codex's merge review (if reviewer)
├── pids/             # Process IDs for ttyd servers
├── reviews/          # Review files from each round
│   └── round-1-claude-reviews-codex.md
└── merge-votes/      # Versioned merge votes
    ├── round-0-claude-vote.md   # Claude's initial vote
    ├── round-0-codex-vote.md    # Codex's initial vote
    ├── round-1-claude-vote.md   # Claude's debate response (if needed)
    └── round-1-codex-vote.md    # Codex's debate response (if needed)
```

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ GATHER PHASE (solo mode only, optional, --gather flag)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=gather                              │
│  2. Reviewer explores codebase (status: gathering)              │
│     - Searches for relevant source files, docs, tests           │
│     - Write context to .peer-sync/task-context.md               │
│  3. Reviewer signals completion (status: gather-done)           │
│  4. User reviews context and proceeds                           │
│  5. Coder will read task-context.md before starting work        │
│                                                                 │
│  Note: This phase is only available in solo mode. The reviewer  │
│  gathers context to help the coder understand the codebase.     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

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

┌─────────────────────────────────────────────────────────────────┐
│ PR COMMENTS PHASE (automatic after both PRs created)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=pr-comments                         │
│  2. Polls GitHub PRs for new comments/reviews                   │
│  3. When new comments detected:                                 │
│     - Send ntfy notification                                    │
│     - Trigger duo-pr-comment skill for affected agent           │
│  4. Agent fetches comments via `gh pr view --json`              │
│  5. Agent addresses feedback, pushes amendments                 │
│  6. Agent signals done                                          │
│  7. Repeat until both PRs are merged/closed                     │
│                                                                 │
│  Terminates when: both PRs merged/closed, or Ctrl-C             │
│                                                                 │
│  AUTOMATIC MERGE TRIGGER                                        │
│  ───────────────────────                                        │
│  If a comment containing "Proceed to merge" is detected on      │
│  either PR, the orchestrator automatically transitions to       │
│  the merge phase with fresh agent sessions.                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ MERGE PHASE                                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Three ways to trigger merge:                                   │
│  1. `agent-duo merge` - User command (from any terminal),       │
│     sends run-merge to orchestrator terminal                    │
│  2. `agent-duo run-merge` - Orchestrator command, starts fresh  │
│     agent sessions and runs merge flow directly                 │
│  3. Automatic - "Proceed to merge" comment on PR triggers it    │
│  All methods start fresh sessions for unbiased voting.          │
│                                                                 │
│  VOTE PHASE                                                     │
│  ──────────                                                     │
│  1. Orchestrator sets phase=merge, merge-round=0                │
│  2. Both agents analyze both PRs (status: voting)               │
│     - Fresh sessions, no bias from original implementation      │
│     - Write vote to .peer-sync/merge-votes/round-0-{agent}-vote.md │
│  3. Agents vote: "claude" or "codex" (status: vote-done)        │
│                                                                 │
│  CONSENSUS CHECK                                                │
│  ───────────────                                                │
│  4. If votes agree → proceed to execution                       │
│  5. If votes differ → debate phase (max 2 rounds)               │
│                                                                 │
│  DEBATE PHASE (if needed)                                       │
│  ────────────                                                   │
│  6. Agents read peer's vote, revise or defend (status: debating)│
│     - Each round creates new versioned vote file (round-N)      │
│  7. After 2 rounds, if still no consensus → escalate to user    │
│                                                                 │
│  EXECUTION PHASE                                                │
│  ───────────────                                                │
│  8. "Losing" agent works in WINNING worktree (status: merging)  │
│     - cd to $PEER_WORKTREE (winning agent's directory)          │
│     - Cherry-pick valuable features from losing PR              │
│     - Commit and push to winning branch                         │
│     - Close losing PR with explanation                          │
│  9. "Winning" agent reviews cherry-picks (status: merge-reviewing)│
│     - Reviews work in their own worktree ($MY_WORKTREE)         │
│     - Can reference losing worktree for comparison              │
│                                                                 │
│  AMEND LOOP (if review requests changes)                        │
│  ─────────────────────────────────────────                      │
│  10. "Losing" agent addresses feedback in winning worktree      │
│  11. "Winning" agent re-reviews                                 │
│  12. Repeat until approved (max 3 rounds)                       │
│                                                                 │
│  COMPLETION                                                     │
│  ──────────                                                     │
│  13. On approval: notify user, return to PR-comments phase      │
│  14. Orchestrator monitors winning PR for comments/merge        │
│  15. User merges winning PR to main when ready                  │
│                                                                 │
│  Key: Agents do NOT merge to main. User retains merge control.  │
│  Both worktrees remain available for reference throughout.      │
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

### Escalation

Agents can escalate issues requiring user input without interrupting their work:

```bash
agent-duo escalate ambiguity "requirements unclear: what should happen when X?"
agent-duo escalate inconsistency "docs say X but code does Y"
agent-duo escalate misguided "this feature already exists in module Z"
```

**Scope for escalation:**
- **Ambiguity** - Requirements are unclear, need clarification
- **Inconsistency** - Conflicting requirements or code/docs mismatch
- **Misguided** - Evidence the task approach is wrong

**Out of scope:** Getting stuck on implementation → wrap partial progress as a PR instead.

**Flow:**
1. Agent calls `escalate <reason> [message]`
2. Creates `.peer-sync/escalation-<agent>.md` with details
3. Sets agent status to `escalated`
4. Agent continues working (not interrupted)
5. Orchestrator checks for escalations before each phase transition
6. If escalations exist: displays them, sends ntfy notification, prompts user
7. User resolves via prompt in orchestrator terminal or `agent-duo escalate-resolve`
8. Escalation files removed, orchestrator continues

This differs from clarify/pushback phases which are enforced blocking points. Escalation is an ad-hoc mechanism for issues discovered during work or review.

## Agent Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `gathering` | Collecting task context (solo mode) | Agent (start of gather phase) |
| `gather-done` | Finished gather phase | Agent |
| `clarifying` | Proposing approach and questions | Agent (start of clarify phase) |
| `clarify-done` | Finished clarify phase | Agent |
| `pushing-back` | Proposing task improvements | Agent (start of pushback phase) |
| `pushback-done` | Finished pushback phase | Agent |
| `working` | Actively implementing | Agent (start of work phase) |
| `done` | Finished work phase | Agent |
| `reviewing` | Reading peer's changes | Agent (start of review phase) |
| `review-done` | Finished review phase | Agent |
| `updating-docs` | Capturing project/workflow learnings | Agent (start of update-docs phase) |
| `docs-update-done` | Finished update-docs phase | Agent |
| `interrupted` | Timed out, yielding to review | Orchestrator |
| `error` | Something failed | Agent or Orchestrator |
| `escalated` | Issue needs user input | Agent (after `agent-duo escalate`) |
| `pr-created` | PR submitted | Agent (after `agent-duo pr`) |
| `voting` | Analyzing PRs for merge vote | Agent (start of merge vote) |
| `vote-done` | Submitted merge vote | Agent |
| `debating` | Responding to peer's vote | Agent (merge debate round) |
| `debate-done` | Finished debate response | Agent |
| `merging` | Executing merge + cherry-pick | Agent (losing agent) |
| `merge-done` | Merge execution complete | Agent |
| `merge-reviewing` | Reviewing merge result | Agent (winning agent) |
| `merge-review-done` | Finished merge review | Agent |

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

### Session Completion

Session completes when:
1. Both agents have `pr-created` status, **AND**
2. At least one full review cycle has completed (round >= 2)

This ensures:
- Both agents see at least one peer review before the session ends
- An agent who creates a PR early continues to participate in work/review cycles
- The early-PR agent can respond to peer feedback and amend their PR if needed
- Both agents continue reviewing each other's work until the session completes

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
# Launches web terminals on 3 consecutive ports (default: first available from 7680):
#   http://localhost:<port>   - Orchestrator
#   http://localhost:<port+1> - Claude's terminal
#   http://localhost:<port+2> - Codex's terminal
# Port assignments stored in .peer-sync/ports
# PIDs tracked in .peer-sync/pids/ for clean shutdown

agent-duo start myfeature --port 8000
# Uses fixed ports 8000, 8001, 8002 (fails if any are occupied)
```

## Skills

Skills provide phase-specific instructions to agents. Installed to:
- Claude: `~/.claude/commands/duo-{work,review,clarify,pushback,amend,update-docs,pr-comment,integrate,merge-vote,merge-debate,merge-execute,merge-review,merge-amend}.md`
- Codex: `~/.codex/skills/duo-{work,review,clarify,pushback,amend,update-docs,pr-comment,integrate,merge-vote,merge-debate,merge-execute,merge-review,merge-amend}/SKILL.md`

Key skill behaviors:
- **Gather phase** (solo mode): Explore codebase, collect relevant file links and notes, write `task-context.md`, signal `gather-done`
- **Clarify phase**: Propose high-level approach, ask clarifying questions, signal `clarify-done`
- **Pushback phase**: Propose improvements to the task file, signal `pushback-done`
- **Work phase**: Implement solution, signal `done` when ready
- **Amend phase**: For agents with PRs — review peer feedback and amend PR if warranted
- **Review phase**: Read peer's worktree via git, write review, signal `review-done`; agents with PRs still participate
- **Update-Docs phase**: Capture project learnings and workflow feedback, signal `docs-update-done`
- **PR Comment phase**: Fetch GitHub PR comments via `gh pr view`, address feedback, push amendments
- **Integrate phase**: Rebase branch onto updated main after another feature was merged, signal `integrate-done`
- **Merge Vote phase**: Analyze both PRs objectively, vote on which to merge, signal `vote-done`
- **Merge Debate phase**: Read peer's vote, reconsider or defend position, signal `debate-done`
- **Merge Execute phase**: For losing agent — cd to winning worktree, cherry-pick from losing PR into winning branch, close losing PR, signal `merge-done`
- **Merge Review phase**: For winning agent — review cherry-picks in own worktree, can reference losing worktree, signal `merge-review-done`
- **Merge Amend phase**: For losing agent — address review feedback in winning worktree, signal `merge-done`
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
4. Signals appropriate status: `gather-done` (gather), `done` (work), `review-done` (review), `clarify-done` (clarify), `pushback-done` (pushback), `docs-update-done` (update-docs)
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
| `MY_WORKTREE` | Path to this agent's worktree | `/Users/me/myapp-auth-claude` |
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
# Kill ttyd processes (check .peer-sync/ports for actual port numbers)
pkill -f "ttyd.*<port>"
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
│  ~/myapp/                    (main branch, task specs here)     │
│      ├── myfeature.md        (task description)                 │
│      └── .agent-sessions/    (registry of active sessions)      │
│                                                                 │
│  ~/myapp-myfeature/          (root worktree, orchestrator here) │
│      └── .peer-sync/         (session state for "myfeature")    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow:**
1. **Gather phase** (optional, `--gather`): Reviewer explores codebase and collects task context
2. **Clarify phase** (optional, `--clarify`): Coder proposes approach, reviewer comments
3. **Pushback phase** (optional, `--pushback`): Reviewer proposes task improvements
4. **Coder** implements the solution (work phase)
5. **Reviewer** examines code and writes review with verdict (APPROVE/REQUEST_CHANGES)
6. If approved: create PR. If changes requested: loop continues.
7. After PR created: monitor for GitHub comments and address feedback

**Key differences from duo mode:**
- Single worktree (both agents work on same branch)
- Sequential rather than parallel work
- Clear coder/reviewer roles (swappable with `--coder` and `--reviewer`)
- Gather phase available (reviewer collects context for coder)
- Skills: `solo-coder-{work,clarify}.md`, `solo-reviewer-{work,clarify,gather,pushback}.md`, `solo-pr-comment.md`

## Multi-Session Support (Parallel Task Execution)

Both agent-duo and agent-solo support running multiple features in parallel. Each feature gets its own isolated session with a root worktree.

### Directory Structure (Multi-Session)

```
~/myapp/                          # Main project (no .peer-sync here)
├── .agent-sessions/              # Registry tracking all active sessions
│   ├── auth.session              # Symlink → ../myapp-auth/.peer-sync
│   └── payments.session          # Symlink → ../myapp-payments/.peer-sync
├── auth.md, payments.md          # Task specs in main branch

~/myapp-auth/                     # Root worktree for "auth" feature
├── .peer-sync/                   # Session state (singleton per feature)
├── auth.md                       # Task file copied here
└── (code)

~/myapp-auth-claude/              # Agent worktree (duo mode)
├── .peer-sync -> ../myapp-auth/.peer-sync
~/myapp-auth-codex/               # Agent worktree (duo mode)
├── .peer-sync -> ../myapp-auth/.peer-sync

~/myapp-payments/                 # Root worktree for "payments" feature
├── .peer-sync/                   # Separate session state
└── ...
```

### CLI for Multi-Session

```bash
# Start multiple features at once
agent-duo start auth payments billing --auto-run

# Status shows all sessions from main project
agent-duo status                  # Shows all sessions
agent-duo status --feature auth   # Shows specific session

# From a worktree, commands auto-detect the session
cd ../myapp-auth-claude
agent-duo status                  # Shows auth session

# Stop/cleanup all or specific
agent-duo stop                    # Stops all (from main project)
agent-duo stop --feature auth     # Stops specific session
agent-duo cleanup --full          # Cleans all with worktrees
agent-duo cleanup --feature auth --full
```

### Session Discovery

Commands resolve which session to operate on:

1. **From agent/root worktree**: Auto-detect via `.peer-sync` symlink
2. **From main project with single session**: Auto-detect (uses the only active session)
3. **From main project with multiple sessions**: Operate on ALL sessions (default)
4. **`--feature` flag**: Override to target specific session

### Single vs Multiple Sessions

All sessions use the same unified architecture:
- Single session = multi-session with N=1
- No `--feature` needed when only one session exists
- Commands auto-detect the appropriate mode

### Integrate Phase (Cross-Session Rebasing)

When running multiple features in parallel, after one PR is merged to main:

1. **Detection**: Orchestrator polls `origin/main` for changes
2. **Check**: If main advanced, check if agent branches need rebasing
3. **Trigger**: If behind, trigger `duo-integrate` or `solo-integrate` skill
4. **Rebase**: Agent rebases onto main, resolves conflicts, force-pushes
5. **Resume**: Orchestrator returns to PR comment watch phase

```
┌──────────────────────────────────────────────────────────────┐
│                    PR Comment Watch Loop                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Poll: has origin/main advanced?                             │
│    YES → Check if branches behind main                       │
│          YES → Trigger integrate skill                       │
│                Wait for integrate-done                       │
│                Resume PR watch                               │
│                                                              │
│  Poll: PR comments changed?                                  │
│    YES → Trigger pr-comment skill                            │
│                                                              │
│  Check: PRs closed?                                          │
│    YES → Session complete (accepted/closed)                  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**State files:**
- `.peer-sync/last-main-commit` — Last known origin/main SHA (for change detection)
- `.peer-sync/main-branch` — Cached main branch name (main/master)

## Design Principles

1. **Simple file-based protocol** - No daemons, just files and git
2. **Direct access over snapshots** - Simpler with unrestricted permissions
3. **Recoverable interrupts** - Timeouts don't lose progress
4. **Feature-based naming** - Clear organization for multiple sessions
5. **Unified CLI** - Single `agent-duo` command for all operations
6. **Graceful degradation** - Works without ttyd, gh, etc.
7. **Session recovery** - `restart` command handles crashes gracefully
8. **Parallel sessions** - Multiple features can run simultaneously with isolated state

---

## ⚠️ Security Considerations

**Agent-duo runs agents without permission restrictions.** Both Claude Code (`--dangerously-skip-permissions`) and Codex (`--yolo`) operate with full filesystem and shell access. This is by design—agents need unrestricted access to implement features, run tests, and coordinate via `.peer-sync/`.

### Risks

| Risk | Description |
|------|-------------|
| **Arbitrary code execution** | Agents can run any shell command |
| **Filesystem access** | Agents can read/write any file the user can access |
| **Network access** | Agents can make network requests (APIs, package installs) |
| **Credential exposure** | `.env` files, SSH keys, API tokens are accessible |
| **Supply chain** | Agents may install packages with malicious dependencies |

### Current Mitigations

- **Git worktrees**: Agent work is isolated to separate directories
- **Branch isolation**: Each agent works on a dedicated branch
- **Human review**: PRs require human approval before merge
- **Orchestrator oversight**: Timeouts and interrupts limit runaway behavior

### Future: Sandboxed Execution

For higher-security scenarios, consider:

1. **Container isolation**: Run each agent in a Docker container with limited mounts
2. **VM isolation**: Dedicated VMs per agent (see pai-lite's architecture notes)
3. **Network restrictions**: Firewall rules limiting outbound connections
4. **Credential isolation**: Mount only necessary secrets, use short-lived tokens

**Not yet implemented.** Current agent-duo assumes a trusted environment where agents operate on your behalf. If running on sensitive codebases or with untrusted task descriptions, consider additional isolation measures.

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
| **`restart` command** | Recover sessions after system restart/crash (DWIM behavior, multi-session support) |
| **`doctor` command** | Diagnose configuration issues, test email/ntfy delivery |
| **`config` command** | Get/set configuration values |
| **ntfy.sh notifications** | Push notifications via ntfy.sh service |
| **Model selection** | `--claude-model`, `--codex-model`, `--codex-thinking` options |
| **Dynamic port allocation** | Ports stored in `.peer-sync/ports` instead of hardcoded |
| **agent-solo mode** | Single-worktree coder/reviewer workflow |
| **Escalation** | `escalate` command for agents to flag ambiguity/inconsistency/misguided tasks |

The pushback phase allows agents to propose improvements to the task file before implementation begins, enabling iterative task refinement.

The escalation mechanism allows agents to flag issues discovered during work/review without interrupting their progress. Unlike clarify/pushback which are enforced phases, escalation is ad-hoc and blocks phase transitions until the user resolves.

The `restart` command is DWIM (Do What I Mean):
- Recreates tmux sessions if they're missing
- Restarts ttyd servers if they're down (skipped for `--no-ttyd` sessions)
- Restarts agent TUIs if needed
- With `--auto-run`: also restarts the orchestrator loop
- With `--no-ttyd`: forces tmux-only mode regardless of how session was started

The session's ttyd mode is recorded in `.peer-sync/ttyd-mode` during start. When run from the main branch without `--feature`, it iterates through all active sessions and restarts each one. Use `--feature <name>` to restart a specific session.
