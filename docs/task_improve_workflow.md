# Improve Workflow: Feedback-Driven Improvements

*Proposal extracted from agent workflow feedback across 3 sessions (2026-02-03 to 2026-02-10).*

## 1. Streamline the Docs-Update / PR Creation Flow

**Sources:** codex (02-03), claude (02-04 alpha), codex (02-04 alpha), claude (02-10)

**Problem:** The current `agent-duo pr` command fails if docs haven't been updated, forcing a 3-step dance: `agent-duo pr` (fail) -> `/duo-update-docs` -> `agent-duo pr` (retry). When run outside tmux, the skill can't even auto-trigger. The requirement only surfaces at PR time, surprising agents late in the workflow.

**Proposals:**

- **Integrate docs-update into PR creation.** Make `agent-duo pr` automatically trigger the update-docs phase as a sub-step when needed, rather than requiring a separate signal cycle. The agent would update docs, then the PR is created in one flow.
- **Earlier heads-up.** During the work phase skill prompt, mention that a docs update will be required before PR creation. This gives agents time to prepare notes incrementally.
- **Better error messages.** When `agent-duo pr` blocks on missing docs update, print the exact command to run (e.g., `Run: /duo-update-docs` or `agent-duo signal <agent> updating-docs`).

## 2. Phase Awareness and Context Drift

**Sources:** codex (02-04 alpha), claude (02-04 beta), claude (02-04 alpha)

**Problem:** Agents lose track of which phase they're in during long sessions. The phase file and the skill being executed can diverge (e.g., phase says `review` but a `work` skill was issued). Agents also lack visibility into their own environment variables.

**Proposals:**

- **Phase header in skill prompts.** Prepend every skill invocation with a standard header block showing: current phase, round number, agent name, peer name, feature name, and key paths (MY_WORKTREE, PEER_WORKTREE). This is low-cost and eliminates orientation time.
- **Phase-skill mismatch guard.** Before the orchestrator issues a skill, verify the phase file matches the skill being sent. Log a warning or refuse to send if they diverge.
- **Phase indicator in agent status line.** If agents support a persistent status display (e.g., Claude Code's status line), set it to show the current phase.

## 3. Review Deduplication

**Sources:** claude (02-10), codex (02-10)

**Problem:** Peer reviews repeat the same feedback across rounds when nothing has changed. Round 3 reviews echo round 2 questions verbatim. Multiple review/work cycles fire even when no diff exists between rounds.

**Proposals:**

- **Diff-gated reviews.** Before entering the review phase, the orchestrator checks if the peer's worktree has changed since the last review (e.g., compare `git diff` output hash). If unchanged, skip the review and carry forward the previous review file.
- **Prior-review context in review skill.** The review skill prompt should include (or reference) the previous round's review, with instructions to focus only on *new or unaddressed* issues. Add a section: "Previously raised issues — only re-raise if still present."
- **Addressed-feedback tracking.** Agents mark addressed feedback items in their review files (e.g., strikethrough or `[RESOLVED]`), giving the next reviewer a clear delta.

## 4. Context Compaction Resilience

**Source:** claude (02-10)

**Problem:** When the conversation context is compacted mid-work-phase, agents lose track of which files they've modified and must re-read everything. This adds significant overhead and risks missing changes.

**Proposals:**

- **File-state summary in skill prompts.** The work-phase skill could instruct agents to maintain a running list of modified files and their purpose in a scratchpad file (e.g., `.peer-sync/<agent>-worklog.md`). After compaction, the agent reads this file to re-orient.
- **Compaction-friendly instructions.** Add a note to work/review skills: "If you notice your context has been compacted, read `<agent>-worklog.md` and `git diff --stat` before continuing."

## 5. Environment and Path Accuracy

**Sources:** codex (02-10), claude (02-04 alpha)

**Problem:** The review skill sometimes references incorrect peer worktree paths. Environment variables may not be visible or may show stale values.

**Proposals:**

- **Echo paths at skill start.** Each skill prompt should instruct the agent to verify paths by running `echo $PEER_WORKTREE` (or reading the env) as the first step, rather than relying on hardcoded values in the prompt template.
- **Path validation in orchestrator.** Before sending a skill, the orchestrator verifies that PEER_WORKTREE and MY_WORKTREE directories exist. If not, log an error and attempt recovery (e.g., re-resolve from `.peer-sync`).

## 6. Skill Instruction Robustness

**Sources:** codex (02-04 beta), claude (02-04 beta)

**Problem:** Minor foot-guns in skill instructions: `rg` patterns starting with `-` are parsed as options; observation logs lack a standard template.

**Proposals:**

- **`rg` safety note.** In any skill that uses `rg` examples, add `--` before patterns (e.g., `rg -- "-pattern"`). This is a one-line fix in affected templates.
- **Standard observation template.** Provide a short template in the work skill for recording observations/decisions (e.g., a markdown section with timestamp, decision, and rationale). This makes phase logs consistent and easier for reviewers to parse.

## Summary: Priority and Effort

| # | Improvement | Impact | Effort |
|---|------------|--------|--------|
| 1 | Streamline docs-update/PR flow | High | Medium |
| 2 | Phase awareness headers | High | Low |
| 3 | Review deduplication | Medium | Medium |
| 4 | Context compaction resilience | Medium | Low |
| 5 | Path validation | Low | Low |
| 6 | Skill instruction fixes | Low | Low |

Recommended implementation order: 2, 6, 5, 1, 4, 3 (quick wins first, then the larger refactors).
