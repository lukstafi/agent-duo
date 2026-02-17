# Plan-Review Phase

*Feature spec for optional planning phases enabled by `--plan` flag.*

## Overview

Complex tasks benefit from explicit upfront planning before implementation begins. The `--plan` flag introduces planning phases after pushback, where agents write implementation plans and review each other's plans before starting work.

## Enabling

```bash
agent-duo start <feature> --plan              # Enable plan phase
agent-duo start <feature> --clarify --plan    # Combine with clarify
agent-pair start <feature> --plan             # Also works in pair mode
```

## Duo Mode Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PLAN PHASE (duo mode, --plan flag)                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=plan                                │
│  2. Both agents write implementation plans (status: planning)   │
│     - Write to .peer-sync/plan-{agent}.md                       │
│  3. Both agents signal completion (status: plan-done)           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PLAN-REVIEW PHASE (duo mode)                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=plan-review                         │
│  2. Both agents review peer's plan (status: plan-reviewing)     │
│     - Read .peer-sync/plan-{peer}.md                            │
│     - Write review to .peer-sync/plan-review-{agent}.md         │
│  3. Both agents signal completion (status: plan-review-done)    │
│  4. Agents read peer's review before starting work              │
│  5. Orchestrator proceeds to work phase automatically           │
│  (No explicit plan-amend phase—agents incorporate feedback      │
│  directly into their implementation)                            │
│                                                                 │
│  AGENT-TRIGGERED CLARIFY (optional, during plan or plan-review) │
│  ─────────────────────────────────────────────────────────────  │
│  If an agent needs user clarification while planning:           │
│  - Agent signals status: needs-clarify                          │
│  - Orchestrator pauses, notifies user                           │
│  - User responds in agent's terminal                            │
│  - Agent signals plan-done or plan-review-done when ready       │
│  Reuses the clarify skill mechanics without a separate phase.   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Pair Mode Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PLAN PHASE (pair mode, --plan flag)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=plan                                │
│  2. Coder writes implementation plan (status: planning)         │
│     - Writes to .peer-sync/plan-coder.md                        │
│  3. Coder signals completion (status: plan-done)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PLAN-REVIEW PHASE (pair mode)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=plan-review                         │
│  2. Reviewer examines coder's plan (status: plan-reviewing)     │
│     - Reads .peer-sync/plan-coder.md                            │
│     - Writes verdict + feedback to .peer-sync/plan-review.md    │
│     - Verdict: APPROVE or REQUEST_CHANGES                       │
│  3. Reviewer signals completion (status: plan-review-done)      │
│                                                                 │
│  If APPROVE:                                                    │
│     - Orchestrator notifies user, proceeds to work phase        │
│                                                                 │
│  If REQUEST_CHANGES:                                            │
│     - Phase returns to plan (coder updates plan based on        │
│       feedback, loop repeats)                                   │
│     - Max 3 plan iterations before auto-proceeding to work      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Motivation for a different approach in pair mode relative to duo mode: pair mode is consensus driven while duo mode is divergence driven.

## Phase Ordering

```
Start
  │
  ├─[--clarify]──→ Clarify Phase
  │                    │
  ├─[--pushback]─→ Pushback Phase
  │                    │
  ├─[--plan]─────→ Plan Phase ←─────────┐
  │                    │                │
  │               Plan-Review Phase     │
  │                    │                │
  │                    ├─(pair, REQUEST_CHANGES)
  │                    │
  ▼                    ▼
Work Phase ◄───────────┘
```

## Status Values

| Status | Meaning | Mode |
|--------|---------|------|
| `planning` | Writing implementation plan | Both |
| `plan-done` | Finished writing plan | Both |
| `plan-reviewing` | Reviewing plan(s) | Both |
| `plan-review-done` | Finished plan review | Both |
| `needs-clarify` | Agent needs user input during planning | Both |

## State Files

```
.peer-sync/
├── plan-mode             # "true" or "false"
├── plan-round            # Current plan iteration (pair mode, 1-2)
├── plan-claude.md        # Claude's implementation plan (duo)
├── plan-codex.md         # Codex's implementation plan (duo)
├── plan-coder.md         # Coder's implementation plan (pair)
├── plan-review-claude.md # Claude's review of Codex's plan (duo)
├── plan-review-codex.md  # Codex's review of Claude's plan (duo)
├── plan-review.md        # Reviewer's verdict on coder's plan (pair)
└── plan-confirmed        # Present when plan phase is complete
```

## Skills

Shared templates in `skills/templates/`:

### `duo-plan.md`

Instructs agent to write an implementation plan covering:
- **Approach**: High-level strategy
- **Key decisions**: Architectural choices and rationale
- **File changes**: Files to create/modify
- **Risks**: Edge cases, potential issues
- **Test strategy**: How to verify correctness

### `duo-plan-review.md`

Instructs agent to review peer's plan:
- **Completeness**: Does it cover all requirements?
- **Simplicity**: Is there a simpler approach?
- **Risks**: Missing edge cases or failure modes?
- **Feasibility**: Will this approach work?

### `pair-coder-plan.md`

Same structure as `duo-plan.md`, adapted for pair mode (single plan, no peer).

### `pair-reviewer-plan.md`

Same structure as `duo-plan-review.md`, plus writes a verdict (APPROVE/REQUEST_CHANGES).

## Key Differences: Duo vs Pair

| Aspect | Duo Mode | Pair Mode |
|--------|----------|-----------|
| Who plans | Both agents in parallel | Coder only |
| Who reviews | Cross-review (each reviews peer) | Reviewer reviews coder |
| Iteration | None (feedback incorporated in work) | Loop if REQUEST_CHANGES |
| Proceed | Automatic after review | Auto if APPROVE, loop if not |

## Design Rationale

**Why no explicit plan-amend phase in duo mode?**
- Agents maintain distinct approaches; forcing plan amendments could cause convergence
- Peer feedback is available during work phase
- Keeps the workflow simpler

**Why loop in pair mode?**
- Single implementation path—plan quality matters more
- Reviewer acts as staff engineer gate
- Capped at 3 iterations (initial + 2 revisions) to prevent infinite loops

**Why no user confirm in duo mode?**
- Keeps workflow autonomous—no blocking on human
- Plans and reviews are available in `.peer-sync/` if user wants to inspect
- User can still nudge agents during work phase if needed

**Why agent-triggered clarify instead of mandatory checkpoint?**
- Most tasks don't need clarification—automatic flow is faster
- When clarification is needed, agent knows best when to ask
- Reuses existing clarify skill mechanics (no new skill needed)
- User only gets pulled in when genuinely necessary
