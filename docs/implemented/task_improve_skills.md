# Improve Skills: Cognitive Load Audit

*Audit of skill templates under `skills/templates/` for clarity and cognitive load, cross-referenced with agent workflow feedback from `docs/task_improve_workflow.md`.*

## 1. "Capture Learnings" Scattered Across Work and Review Phases

**Files:** `duo-work.md` (lines 53-62), `duo-review.md` (lines 111-122)

**Problem:** Both the work and review skills contain a "Capture Learnings" section asking the agent to run `agent-duo learn` and `agent-duo workflow-feedback` while they should be coding or reviewing. Meanwhile, `duo-update-docs.md` exists as a dedicated phase for exactly this purpose.

This fragments the responsibility across three places, creating confusion about when learnings actually matter. Agents appear to ignore the embedded prompts during work/review (since the task at hand is more pressing), and are then surprised when docs-update is required at PR time.

**Cross-reference with agent complaints:** Strongly corroborated by **Complaint #1** (docs-update/PR flow). Agents reported that the docs-update requirement "only surfaces at PR time, surprising agents late in the workflow." If agents were actually capturing learnings during work/review as instructed, the docs-update phase wouldn't feel surprising. The fact that it does confirms these embedded sections are dead weight — agents skip them, then get blocked later.

**Recommendation:** Remove the "Capture Learnings" sections from `duo-work.md` and `duo-review.md`. Let `duo-update-docs.md` own this responsibility exclusively. If you want an earlier heads-up (as Complaint #1 suggests), add a single line to the work skill: *"Note: You'll be asked to capture learnings before PR creation."*

## 2. Review and Work Skills Overloaded with PR-Creation Decision

**Files:** `duo-review.md` (lines 126-138), `duo-work.md` (lines 66-78)

**Problem:** Both skills end with a "Before You Stop" fork: signal done **or** create a PR now. This forces the agent to context-switch from its primary task (reviewing peer code, or coding) to evaluating "is my solution complete enough for a PR?" — an unrelated judgment that blurs phase boundaries.

In `duo-review.md` this is especially jarring: the agent has been analyzing their peer's code, and now must suddenly assess their own readiness. The skill becomes 5 responsibilities: signal reviewing, examine peer, write review, read peer's review of you, and decide whether to PR.

**Cross-reference with agent complaints:** Corroborated by **Complaint #2** (phase awareness and context drift). Agents reported losing track of which phase they're in. A review skill that can transition directly to PR creation contributes to this — the agent is "in review" but suddenly acting as "done with work." Clean phase boundaries (review always ends with `signal review-done`) would reduce drift.

Also relates to **Complaint #1**: the PR-creation path in work/review means agents may hit the docs-update blocker from within these phases, compounding the surprise.

**Recommendation:** Remove the PR-creation path from both `duo-work.md` and `duo-review.md`. These skills should always end with their respective signal (`done` or `review-done`). Let the orchestrator handle the transition to PR creation as a separate phase boundary.

## 3. Escalation Boilerplate Repeated Verbatim in 4 Skills

**Files:** `duo-work.md` (lines 42-49), `duo-review.md` (lines 101-109), `solo-coder-work.md` (lines 40-47), `solo-reviewer-work.md` (lines 94-101)

**Problem:** The "If You Discover a Blocking Issue" block — 3 `escalate` examples with descriptions — appears identically in four skills (~8 lines each, ~32 lines total). After the first encounter, subsequent copies are pure overhead.

**Cross-reference with agent complaints:** Indirectly supported by **Complaint #4** (context compaction resilience). Repeated boilerplate consumes context window space. When context gets compacted, those tokens were wasted — space that could have held actual work context. Reducing repetition improves compaction resilience.

**Recommendation:** Keep the full escalation block in the first skill the agent encounters (typically `duo-work.md` round 1 or `solo-coder-work.md`). In subsequent skills, condense to a single line:
```
If blocked by ambiguity/inconsistency, use: `agent-duo escalate <type> "<message>"`
```

## 4. `duo-merge-execute.md` Is the Longest Skill (175 Lines, 10 Steps)

**File:** `duo-merge-execute.md`

**Problem:** This skill has inherent complexity (cherry-picking across worktrees), but two sections add unnecessary weight:
- **"After Review" section** (lines 161-165): Forward-looking info about what happens after this skill completes. The agent can't act on it; it's noise during execution.
- The overall step count (10 numbered steps) is high. Steps 1-3 are all orientation (understand decision, move to worktree, read recommendations) before any actual work starts.

**Cross-reference with agent complaints:** No direct complaint maps here, but **Complaint #2** (phase awareness) is relevant — the "After Review" section describes a future phase, which is exactly the kind of forward-looking context that confuses agents about what phase they're currently in.

**Recommendation:** Remove the "After Review" section. Consider consolidating steps 1-3 into a single "Orient yourself" step with sub-bullets rather than three separate numbered headings.

## 5. Cherry-Pick Planning Embedded in Merge Vote

**File:** `duo-merge-vote.md` (lines 96-101)

**Problem:** The vote template requires "Features to Cherry-Pick from Losing PR" — asking the agent to plan post-merge integration while it should be focused on evaluating which PR is better. This is premature; cherry-pick planning belongs in `duo-merge-execute.md` where it's actually acted upon.

**Cross-reference with agent complaints:** No direct overlap, but the general theme of **Complaint #2** (phase awareness) applies — skills should focus on their phase's core responsibility without bleeding into the next phase.

**Recommendation:** Make this section optional with lighter framing: *"Optionally note any features from the other PR worth preserving."* Move detailed cherry-pick planning to `duo-merge-execute.md`.

## 6. Review Skill Lacks Prior-Review Context

**Files:** `duo-review.md`, `solo-reviewer-work.md`

**Problem (from agent complaints, confirmed in templates):** The review skills don't instruct the agent to compare against prior round reviews. `solo-reviewer-work.md` has a "Check previous rounds" step (lines 79-85) but frames it as optional and places it *after* writing the review, not before. `duo-review.md` shows peer's review of you, but not your own prior review of the peer.

**Cross-reference with agent complaints:** Directly corroborated by **Complaint #3** (review deduplication). Agents reported repeating the same feedback across rounds verbatim. The skill template doesn't guide them to focus on deltas.

**Recommendation:** In both review skills, add a step *before* writing the review: "Read your previous review of this peer's work (if any). Focus your new review on changes since then. Only re-raise prior issues if they remain unaddressed." This is a skill-level fix that addresses Complaint #3 without requiring orchestrator changes.

## 7. No Compaction Recovery Guidance in Work/Review Skills

**Files:** `duo-work.md`, `solo-coder-work.md`

**Problem (from agent complaints, confirmed absent in templates):** Work-phase skills have no guidance for recovering after context compaction. Agents reported losing track of modified files after compaction.

**Cross-reference with agent complaints:** Directly matches **Complaint #4** (context compaction resilience). The proposed solution (a running worklog file) is reasonable and low-cost.

**Recommendation:** Add to work-phase skills: *"Maintain a brief worklog at `$PEER_SYNC/<agent>-worklog.md` listing files modified and decisions made. If your context was compacted, read this file and `git diff --stat` to re-orient."* This is ~2 lines added to the skill template.

## 8. Minor: `rg` Pattern Safety

**Files:** `duo-plan.md` (line 40), `solo-coder-plan.md` (line 47)

**Problem:** Plan-phase skills show `rg -n "pattern|keyword|module"` as an example. If patterns start with `-`, they'll be parsed as options.

**Cross-reference:** Matches **Complaint #6** (skill instruction robustness).

**Recommendation:** Change to `rg -n -- "pattern|keyword|module"` in affected templates. One-line fix.

## 9. Orchestrator-Driven Commits and PR Creation

*Design change arising from findings #1 and #2: moving commit and PR creation from agent skills to the orchestrator.*

### Current State

- Agents call `agent-duo pr` themselves from work/review skills (now removed)
- `lib_create_pr()` does a single bulk commit (`"Solution from $agent for $feature"`), pushes, and creates PR
- Commit messages and PR descriptions are generic auto-generated text
- PR descriptions come from an optional `<feature>-<agent>-PR.md` file that no skill prompts agents to write

### New Design: Per-Round Commits

The orchestrator commits after each work phase, prefixing the agent's signal message with the round number:

1. Agent signals `done "implemented feature X with approach Y"`
2. Orchestrator runs `git add -A && git commit -m "Round 1: implemented feature X with approach Y"` in the agent's worktree
3. Review phase proceeds — reviewer sees committed changes
4. Agent signals `done "addressed review: fixed edge case, added tests"`
5. Orchestrator commits as `"Round 2: addressed review: fixed edge case, added tests"`

This produces natural multi-commit history with clear round progression. If the signal message is empty, the commit message defaults to `"Round N changes"`.

### Loop Stopping: Work Quiescence

The orchestrator detects convergence by checking for changes after each `done` signal:

1. Agent signals `done "summary"`
2. Orchestrator checks `git diff HEAD` in the agent's worktree
3. **If changes exist**: commit them (using signal message), proceed to review
4. **If no changes** (quiescence): the agent has converged — skip review, trigger PR creation

This replaces the current "detect both PRs exist" loop-stopping logic with a natural signal: the agent made no changes, so there's nothing more to review. Works identically for both duo and solo modes.

In solo mode, reviewer APPROVE also triggers PR creation (the coder may still have uncommitted changes from addressing final feedback — commit those, then create PR).

### PR Creation Timing (Configurable)

**Default** (`--early-pr` not set): Create PR on APPROVE (solo) or on work quiescence (duo). Cleaner PR — no intermediate states visible externally.

**`--early-pr` flag**: Create PR after the first work-round commit. Each subsequent `lib_commit_round()` that returns "committed" is followed by a `git push` to update the open PR. Enables early external feedback via GitHub reviews.

In both cases, `agent-duo pr <agent>` becomes an orchestrator-internal operation (push + `gh pr create`), not an agent-facing command.

**Race condition note:** The agent explicitly signals `done` when it considers its work saved, so the orchestrator can safely diff immediately. In the unlikely event of a file-save race, the uncommitted changes would simply be picked up in the next round's commit — no special timing guard needed.

### Interaction with Review Skills and `git diff`

Per-round commits change what reviewers see:

| Command | Shows | Use case |
|---------|-------|----------|
| `git diff main...HEAD` | Full feature diff (all rounds) | First review, or full-picture assessment |
| `git diff HEAD~1` | Just the latest round's changes | Round 2+ review — focus on what changed since feedback |
| `git log --oneline main..HEAD` | Commit history with messages | Understand progression of work |

This directly helps with **review deduplication** (Complaint #3): round 2+ reviewers can `git diff HEAD~1` to see only what the agent changed in response to their feedback, rather than re-reviewing the entire feature.

Review skills have been updated to use these commands instead of `git diff` (uncommitted changes, now usually empty) and `git status`.

### Interaction with Docs-Update

The docs-update phase (`duo-update-docs.md`) fits naturally as a step between "final commit" and "PR creation." The orchestrator can trigger it as part of the PR-creation flow, addressing Complaint #1 (docs-update surprise) without agents needing to know about it.

### Changes to Orchestrator Functions

**New `lib_commit_round()`** — called after each `done` signal:

1. Check `git diff HEAD` in agent's worktree
2. If no changes: return "quiescent" (caller decides whether to create PR or skip review)
3. If changes: `git add -A && git commit -m "Round N: <signal message>"` (or `"Round N changes"` if message is empty), return "committed"
4. If `--early-pr` and PR already exists: `git push`

**Simplified `lib_create_pr()`** — called by orchestrator on quiescence/APPROVE:

1. Trigger docs-update phase (if configured)
2. Push branch to origin
3. Create PR via `gh pr create`

The bulk commit logic moves entirely to `lib_commit_round()`.

---

## Summary: Priority and Effort

| # | Improvement | Impact | Effort | Corroborated by complaint |
|---|-----------|--------|--------|---------------------------|
| 1 | Remove "Capture Learnings" from work/review | High | Low | #1 (docs-update surprise) |
| 2 | Remove PR-creation fork from work/review | High | Low | #1, #2 (phase drift) |
| 3 | Condense escalation boilerplate (4 files) | Medium | Low | #4 (compaction) |
| 4 | Trim `duo-merge-execute.md` | Medium | Low | #2 (phase awareness) |
| 5 | Lighten cherry-pick in merge-vote | Medium | Low | #2 (phase awareness) |
| 6 | Add prior-review context to review skills | Medium | Low | #3 (review deduplication) |
| 7 | Add compaction recovery to work skills | Medium | Low | #4 (compaction resilience) |
| 8 | Fix `rg` pattern safety | Low | Low | #6 (instruction robustness) |
| 9 | Orchestrator-driven commits and PR creation | High | Medium | #1, #2, #3 |

### Applied Changes (skill templates)

Items 1-8 have been applied to skill templates. Item 9 requires orchestrator changes (see design in section 9).

Review skills updated to use `git diff main...HEAD` (full feature diff) and `git diff HEAD~1` (latest round delta) instead of `git diff` (uncommitted, now empty with per-round commits).

### Remaining Orchestrator Work

- **`lib_commit_round()`**: New function after each `done` signal — checks for changes, commits with `"Round N: <message>"` prefix, pushes if `--early-pr` and PR exists, returns quiescent/committed
- **Quiescence-based loop stopping**: Replace "detect both PRs exist" with "no diff after done signal" as convergence criterion
- **PR creation on convergence**: Orchestrator calls `lib_create_pr()` on quiescence (duo) or APPROVE (solo), with `--early-pr` flag for first-commit PR creation
- **Docs-update integration**: Trigger as part of PR-creation flow, not as agent-facing blocker
- **Complaint #2 (phase headers):** Dynamic header with resolved paths/round — orchestrator-level, not skill template
- **Complaint #5 (path validation):** Orchestrator verifies worktree paths before sending skills
