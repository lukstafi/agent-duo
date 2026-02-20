# Lighter Plan Confirmation for Well-Scoped Tasks

## Motivation

When a task description already contains a complete, detailed plan (e.g., a textbook chapter
with section-by-section outline), the plan-review round-trip adds latency without adding value.
The coder writes a plan that essentially restates the task description, then the reviewer must
spin up, read it, and approve — a formality that costs time and API tokens.

This was observed during task_chapter12 (a full textbook chapter with 8 sections, ~940 lines).
The plan phase was useful for the coder to organize their approach, but sending it to the
reviewer for approval was unnecessary.

See: https://github.com/lukstafi/agent-duo/issues/11

## Current State

### Pair mode (`agent-pair`)

The plan phase (lines 2136-2291) runs a loop of up to 3 rounds:

1. Coder receives `pair-coder-plan` skill, writes plan to `.peer-sync/plan-coder.md`,
   signals `plan-done`
2. Orchestrator enters plan-review phase (line 2200): sends `pair-reviewer-plan` to reviewer
3. Reviewer writes verdict (`APPROVE` or `REQUEST_CHANGES`) to `.peer-sync/plan-review.md`
4. If `APPROVE` or max rounds: creates `plan-confirmed` marker, proceeds to work

The reviewer round-trip (lines 2200-2291) is the overhead: the reviewer session must activate,
read the plan, evaluate, write a verdict, and signal. For a well-scoped task, this is ~60-120s
of latency with no information gain.

### Duo mode (`agent-duo`)

The plan phase (lines 4135-4316) runs in parallel:

1. Both agents (claude + codex) write plans simultaneously (`plan-claude.md`, `plan-codex.md`)
2. After both finish, enter plan-review: each agent reviews the other's plan
   (`plan-review-claude.md`, `plan-review-codex.md`)
3. After both reviews complete: creates `plan-confirmed`, proceeds to work

The cross-review phase (lines 4227-4316) is the overhead in duo mode.

### CLI flags

Current planning flag: `--plan` (line 712 in agent-duo, enables full plan-review flow).
No option to plan without review.

## Proposed Change

Add a `--plan-confirm` CLI flag that enables the plan phase but **skips the review phase**.
Agents still write their plans (useful as self-documentation and approach organization), but
the orchestrator creates `plan-confirmed` immediately after plans are written, without
triggering the reviewer.

**In pair mode**: Coder writes plan to `plan-coder.md`, signals `plan-done`, orchestrator
skips lines 2200-2291 and writes `plan-confirmed` directly.

**In duo mode**: Both agents write plans in parallel, orchestrator skips lines 4227-4316
(the cross-review phase) and writes `plan-confirmed` directly after both plans complete.

### Acceptance criteria

- `--plan-confirm` enables plan phase but skips review
- `--plan-confirm` without `--plan` implies `--plan` (plan-only doesn't make sense without planning)
- The plan files are still written for reference
- The existing `--plan` flag continues to work as before (full plan-review)
- Works in both pair mode and duo mode
- Combines correctly with `--clarify` and `--pushback` (only affects plan→plan-review transition)

### Edge cases

- **Duo mode asymmetry**: In confirm mode, both agents still plan independently but neither
  reviews the other. Plans serve as self-documentation, not coordination. This is intended.
- **Future: task-level override**: A `plan_mode: confirm` field in task descriptions could
  enable lighter planning per-task without changing CLI invocation. Not required initially.

## Scope

**In scope**: `--plan-confirm` flag in both `agent-pair` and `agent-duo`, config file
(`.peer-sync/plan-confirm-only`), conditional skip logic in orchestrator plan handlers.

**Out of scope**: Task-level plan mode override, changes to plan skill templates,
modifications to the plan file format.

**Related**: gh-agent-duo-12 documents the workflow patterns that motivated this change.
