# Task Learning Feature

*Implementation handoff document for capturing agent learnings at session end.*

## Overview

Agents accumulate valuable knowledge during sessions: undocumented patterns, gotchas, build quirks, conventions. This knowledge is currently lost when sessions end. This feature captures it in two forms:

1. **Project learnings** → Updates to the target project's `CLAUDE.md` / `AGENTS.md`
2. **Workflow learnings** → Feedback for improving agent-duo itself

## Two Learning Streams

### Stream 1: Project Documentation Updates

When agents work on a project, they discover things that should be documented for future agents (or humans). Each agent appends learnings to `AGENTS_STAGING.md` in the project root.

**Types of learnings:**
- Undocumented conventions (error handling patterns, naming schemes)
- Missing setup requirements (services, env vars, dependencies)
- Build/test gotchas (order dependencies, required flags)
- Outdated docs that contradict code

#### Approach: Staging File with Deferred Curation

Agents append entries to `AGENTS_STAGING.md` rather than editing `CLAUDE.md`/`AGENTS.md` directly.

**Format:**
```markdown
<!-- Entry: auth-claude | 2026-02-03 -->
### Redis required for integration tests

Integration tests require Redis running on localhost:6379:
```bash
docker run -d -p 6379:6379 redis:alpine
npm run test:integration
```
<!-- End entry -->

<!-- Entry: auth-codex | 2026-02-03 -->
### Error handling pattern

All API endpoints use `ApiError` from `src/errors.ts`. Throw `new ApiError(statusCode, message)`.
<!-- End entry -->
```

**Why this approach:**
- **No merge conflicts** — Both agents append, git handles it naturally
- **Lower agent effort** — Just append, don't refactor existing docs
- **Deferred curation** — Human (or future agent session) consolidates into `CLAUDE.md` periodically
- **Clear provenance** — Each entry tagged with session/agent/date
- **Survives failed PRs** — Even if PR is abandoned, learnings reach main via the other PR

**Curation workflow:**
1. `AGENTS_STAGING.md` accumulates entries across sessions
2. Periodically, user (or agent) reviews staging file
3. Valuable entries get refactored into `CLAUDE.md`/`AGENTS.md`
4. Staging file gets cleared or trimmed

This could itself be a task for agent-duo: "Consolidate AGENTS_STAGING.md into CLAUDE.md"

### Stream 2: Agent-Duo Workflow Feedback

Agents also learn about the agent-duo workflow itself: what worked well, what was confusing, where they got stuck due to unclear instructions.

**Types of learnings:**
- Skill instructions that were ambiguous or missing
- Coordination protocol issues (timing, signaling)
- Missing tooling (commands they wished existed)
- Workflow friction points

**Output:** Feedback written to `.peer-sync/workflow-feedback-{agent}.md`.

## Workflow Feedback Mechanism

The question: how should workflow feedback reach agent-duo maintainers?

### Option A: Local Accumulation (Recommended)

Feedback accumulates locally in `~/.agent-duo/workflow-feedback/`. Users can:
- Review and submit as GitHub issues manually
- Ignore if not interested in contributing
- Delete periodically

**Pros:** No network dependencies, user controls what gets shared, simple implementation.

**Structure:**
```
~/.agent-duo/
└── workflow-feedback/
    └── 2026-02-03-auth-claude.md
    └── 2026-02-03-auth-codex.md
```

### Option B: GitHub Issues (Semi-Automated)

With user consent, feedback could be submitted as GitHub issues to the agent-duo repo. The CLI would:
1. Show accumulated feedback
2. Ask if user wants to submit
3. Create issue via `gh issue create`

**Pros:** Feedback reaches maintainers. **Cons:** Requires GitHub auth, may create noise.

### Recommendation

Start with **Option A** (local accumulation). Add an `agent-duo feedback` command that:
- Lists accumulated feedback files
- Lets users view/delete them
- Optionally creates a GitHub issue from selected feedback (requires explicit action)

## Implementation Notes

### New Phase: `update-docs`

Triggers automatically before PR creation. Agents commit doc updates to their branch, then create the PR. Non-optional but fast—agents just externalize what they already know.

### New Skill: `duo-update-docs.md`

Instructs agents to:
1. Reflect on what they learned during implementation
2. Append entries to `AGENTS_STAGING.md` (create if doesn't exist)
3. Write workflow feedback to `.peer-sync/`
4. Commit and signal done

### State Files

```
.peer-sync/
├── workflow-feedback-claude.md   # Stream 2: agent-duo feedback
└── workflow-feedback-codex.md
```

(Stream 1 learnings go to `AGENTS_STAGING.md` in project root, committed to PR branch.)

### Status Values

| Status | Meaning |
|--------|---------|
| `updating-docs` | Agent is committing doc updates |
| `docs-update-done` | Agent finished doc updates |

### CLI Extensions

```bash
agent-duo start <feature> --skip-docs-update  # Opt out of doc update phase
agent-duo feedback                            # View/manage workflow feedback
```

## What Makes Good Feedback

**Project docs (good):**
- "Integration tests require Redis running on localhost:6379"
- "The codebase uses ApiError class for all endpoint errors"

**Project docs (bad):**
- Implementation details of the specific feature
- Opinions on code style

**Workflow feedback (good):**
- "The review skill didn't explain how to handle merge conflicts in peer's worktree"
- "Wish there was a command to see peer's status without parsing files"
- "Escalate command doesn't work when peer-sync path has spaces"

**Workflow feedback (bad):**
- "The task was hard" (not actionable)
- Bug reports (use GitHub issues directly)

## Integration Points

- Runs before PR creation (part of the PR workflow)
- Workflow feedback copied to `~/.agent-duo/workflow-feedback/` on session end
- `agent-duo feedback` command for reviewing accumulated feedback
