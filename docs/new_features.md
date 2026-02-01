# Agent-Duo: Proposed New Features

*Design proposals for workflow enhancements — not yet implemented.*

These features extend agent-duo's workflow with additional phases and triggers inspired by Claude Code team practices.

## 1. Plan-Review Phase

**Problem**: Complex tasks benefit from upfront planning, but a single agent's plan may have blind spots.

**Solution**: A two-agent plan review where one agent writes the plan and another reviews it as a "staff engineer."

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PLAN-REVIEW PHASE (optional, --plan-review flag)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Orchestrator sets phase=plan-review                         │
│  2. First agent (coder) writes detailed implementation plan     │
│     - Writes to .peer-sync/plan-{agent}.md                      │
│     - Includes: approach, file changes, risks, test strategy    │
│  3. First agent signals completion (status: plan-done)          │
│                                                                 │
│  4. Second agent (reviewer) reviews plan as "staff engineer"    │
│     - Reads .peer-sync/plan-{peer}.md                           │
│     - Writes review to .peer-sync/plan-review-{agent}.md        │
│     - Looks for: edge cases, simpler alternatives, risks        │
│  5. Second agent signals completion (status: plan-review-done)  │
│                                                                 │
│  6. Orchestrator notifies user                                  │
│  7. User reviews both plan and review in terminals              │
│  8. User runs 'agent-duo confirm' to proceed to work phase      │
│                                                                 │
│  Alternative: Both agents write plans in parallel, then         │
│  cross-review each other's plans before work begins.            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### New Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `planning` | Writing implementation plan | Agent (start of plan phase) |
| `plan-done` | Finished writing plan | Agent |
| `plan-reviewing` | Reviewing peer's plan | Agent |
| `plan-review-done` | Finished plan review | Agent |

### New State Files

```
.peer-sync/
├── plan-review-mode     # "true" or "false"
├── plan-claude.md       # Claude's implementation plan
├── plan-codex.md        # Codex's implementation plan
├── plan-review-claude.md # Claude's review of Codex's plan
└── plan-review-codex.md  # Codex's review of Claude's plan
```

### Skill: `duo-plan.md`

```markdown
# Plan Phase Instructions

You are writing an implementation plan for the task. Be thorough and specific.

## Plan Structure

1. **Summary**: One-paragraph overview of the approach
2. **Key Decisions**: Architectural choices and rationale
3. **File Changes**: List of files to create/modify with brief descriptions
4. **Risks**: What could go wrong, edge cases to handle
5. **Test Strategy**: How you'll verify the implementation works
6. **Open Questions**: Anything you're uncertain about

## Guidelines

- Be specific about file paths and function names
- Consider error handling and edge cases
- Think about backwards compatibility
- Identify dependencies between changes

When done, signal: `agent-duo signal $MY_NAME plan-done "plan complete"`
```

### Skill: `duo-plan-review.md`

```markdown
# Plan Review Instructions

You are reviewing your peer's implementation plan as a staff engineer. Be constructively critical.

## Review Criteria

1. **Completeness**: Does the plan cover all requirements?
2. **Simplicity**: Is there a simpler approach?
3. **Edge Cases**: What scenarios might break?
4. **Risks**: Are the identified risks complete?
5. **Testability**: Is the test strategy adequate?

## Review Format

Write your review to `.peer-sync/plan-review-{your-name}.md`:

```markdown
# Plan Review

## Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION

## Strengths
- ...

## Concerns
- ...

## Suggestions
- ...

## Questions for the Author
- ...
```

When done, signal: `agent-duo signal $MY_NAME plan-review-done "review complete"`
```

### CLI Changes

```bash
agent-duo start <feature> --plan-review   # Enable plan-review phase
agent-duo start <feature> --clarify --plan-review  # Both phases
```

---

## 2. Re-Plan Trigger

**Problem**: When implementation hits repeated failures, agents often push through with patches rather than stepping back to reconsider the approach.

**Solution**: Automatic detection of "thrashing" that triggers a return to planning phase.

### Trigger Conditions

The orchestrator tracks failure signals and triggers re-planning when:

1. **Error accumulation**: Agent signals `error` status 3+ times in one work phase
2. **Repeated rollbacks**: Agent reverts changes 2+ times (detected via git)
3. **Explicit request**: Agent signals `needs-replan` status
4. **Time without progress**: Work phase exceeds timeout with no commits

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ RE-PLAN TRIGGER                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  During work phase, orchestrator monitors for thrashing:        │
│                                                                 │
│  1. Error count >= 3, OR                                        │
│  2. Rollback count >= 2, OR                                     │
│  3. Agent signals needs-replan, OR                              │
│  4. Timeout with no commits                                     │
│                                                                 │
│  When triggered:                                                │
│  1. Orchestrator interrupts agent                               │
│  2. Agent saves current state (partial work, learnings)         │
│  3. Orchestrator sets phase=re-plan                             │
│  4. Agent writes re-plan document:                              │
│     - What was attempted                                        │
│     - Why it failed                                             │
│     - Proposed new approach                                     │
│  5. Orchestrator notifies user                                  │
│  6. User reviews and confirms new approach                      │
│  7. Work phase resumes with fresh approach                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### New Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `needs-replan` | Agent requests re-planning | Agent |
| `re-planning` | Writing re-plan analysis | Agent |
| `re-plan-done` | Finished re-plan document | Agent |

### New State Files

```
.peer-sync/
├── error-count-claude    # Error counter for claude
├── error-count-codex     # Error counter for codex
├── replan-claude.md      # Claude's re-plan analysis
└── replan-codex.md       # Codex's re-plan analysis
```

### Skill Addition to `duo-work.md`

Add to existing work skill:

```markdown
## When to Request Re-Planning

If you find yourself:
- Repeatedly reverting changes
- Hitting the same error multiple times
- Realizing the approach is fundamentally wrong

Signal for re-planning rather than pushing through:
`agent-duo signal $MY_NAME needs-replan "reason: approach X doesn't work because Y"`

This is better than accumulating technical debt or wasting time on a dead end.
```

### Skill: `duo-replan.md`

```markdown
# Re-Plan Phase Instructions

Your previous approach hit significant obstacles. Step back and reconsider.

## Re-Plan Document Structure

Write to `.peer-sync/replan-{your-name}.md`:

```markdown
# Re-Plan Analysis

## What Was Attempted
- Approach taken
- Key implementation decisions

## Why It Failed
- Specific obstacles encountered
- Root cause analysis

## Learnings
- What we now know that we didn't before
- Constraints discovered

## Proposed New Approach
- Different strategy
- Why this should work
- How it avoids previous pitfalls

## Salvageable Work
- Code that can be reused
- Tests that remain valid
```

When done, signal: `agent-duo signal $MY_NAME re-plan-done "re-plan complete"`
```

### Configuration

```yaml
# In .peer-sync/config or agent-duo config
replan:
  error_threshold: 3        # Errors before triggering
  rollback_threshold: 2     # Rollbacks before triggering
  timeout_minutes: 60       # Time without commits
  auto_trigger: true        # false = only manual/agent-requested
```

---

## 3. Elegant-Retry Phase

**Problem**: After a mediocre implementation, incremental fixes often make code worse. Starting fresh with accumulated knowledge would be better.

**Solution**: A "scrap and redo" phase that preserves learnings while discarding implementation.

### Trigger

Manual only — user or agent explicitly requests elegant retry:

```bash
agent-duo elegant-retry <agent>   # Trigger for specific agent
agent-duo elegant-retry --both    # Both agents restart
```

Or agent signals:
```bash
agent-duo signal $MY_NAME needs-elegant-retry "current implementation is overcomplicated"
```

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ ELEGANT-RETRY PHASE                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Agent (or user) triggers elegant-retry                      │
│  2. Orchestrator sets phase=elegant-retry for that agent        │
│                                                                 │
│  3. Agent writes learnings document:                            │
│     - What worked                                               │
│     - What was overcomplicated                                  │
│     - Key insights gained                                       │
│     - Constraints discovered                                    │
│                                                                 │
│  4. Agent archives current branch:                              │
│     git branch {feature}-{agent}-attempt-{n}                    │
│                                                                 │
│  5. Agent resets to clean state:                                │
│     git reset --hard origin/main                                │
│                                                                 │
│  6. Agent re-implements with accumulated knowledge              │
│     - Reads own learnings document                              │
│     - Reads peer's review (if available)                        │
│     - Aims for "elegant solution" not "working solution"        │
│                                                                 │
│  7. Work continues normally                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### New Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `needs-elegant-retry` | Agent requests fresh start | Agent |
| `archiving` | Saving current attempt | Agent |
| `retrying` | Re-implementing from scratch | Agent |

### New State Files

```
.peer-sync/
├── learnings-claude.md       # Claude's learnings from failed attempt
├── learnings-codex.md        # Codex's learnings from failed attempt
└── attempt-count-{agent}     # Number of retry attempts
```

### Skill: `duo-elegant-retry.md`

```markdown
# Elegant Retry Instructions

Your current implementation works but is overcomplicated. You're starting fresh with everything you've learned.

## Before Resetting

Write your learnings to `.peer-sync/learnings-{your-name}.md`:

```markdown
# Learnings from Attempt N

## What Worked Well
- Components that were clean and correct

## What Was Overcomplicated
- Unnecessary abstractions
- Premature optimizations
- Over-engineering

## Key Insights
- Things you understand now that you didn't before
- Constraints that became clear during implementation

## The Elegant Approach
- How you would do it differently
- Why this is simpler/cleaner
```

## Archive and Reset

```bash
# Archive current work
git branch {feature}-{your-name}-attempt-{n}
git push origin {feature}-{your-name}-attempt-{n}

# Reset to clean state
git reset --hard origin/main
```

## Re-Implement

Now implement the elegant solution:
- Read your learnings document
- Read peer's review (if available)
- Aim for simplicity over completeness
- "Knowing everything you know now, implement it right"

Signal when starting fresh: `agent-duo signal $MY_NAME retrying "starting elegant implementation"`
```

### Guardrails

- Maximum 2 elegant-retry attempts per agent per session (prevent infinite loops)
- Each attempt branch is preserved for reference
- User must confirm if agent requests retry (not auto-approved)

---

## Implementation Priority

| Feature | Complexity | Value | Suggested Order |
|---------|------------|-------|-----------------|
| Re-plan trigger | Medium | High | 1st — prevents wasted effort |
| Plan-review phase | Medium | Medium | 2nd — improves plan quality |
| Elegant-retry | Low | Medium | 3rd — escape hatch for mediocre code |

## Integration with Existing Phases

```
Start
  │
  ├─[--clarify]──→ Clarify Phase
  │                    │
  ├─[--pushback]─→ Pushback Phase
  │                    │
  ├─[--plan-review]→ Plan-Review Phase  ← NEW
  │                    │
  ▼                    ▼
Work Phase ◄───────────┘
  │
  ├─[thrashing detected]──→ Re-Plan Phase ← NEW
  │                              │
  │◄─────────────────────────────┘
  │
  ├─[needs-elegant-retry]──→ Elegant-Retry ← NEW
  │                              │
  │◄─────────────────────────────┘
  │
  ▼
Review Phase
  │
  ▼
(continue or PR)
```

## Open Questions

1. **Plan-review parallelism**: Should both agents plan simultaneously then cross-review, or should it be sequential (one plans, one reviews)?

2. **Re-plan scope**: Should re-planning affect both agents or just the one that's thrashing?

3. **Elegant-retry branch cleanup**: How long to keep archived attempt branches?

4. **Integration with solo mode**: Do these features apply to agent-solo, and if so, how?

---

## 4. Spec-As-Test Feedback Loop

**Problem**: Task descriptions in `<feature>.md` are prose. Agents may implement something that "works" but doesn't match the user's intent. Validation happens late (at PR review).

**Solution**: Structured specs that become executable acceptance tests, validated automatically before review phase.

### Spec Format

````markdown
# feature.md

## Requirements

- [ ] User can login with email/password
- [ ] Failed login shows error message after 3 attempts
- [ ] Successful login redirects to dashboard
- [ ] Session expires after 30 minutes of inactivity

## Acceptance Tests

```gherkin
Feature: User Authentication

Scenario: Successful login
  Given a registered user with email "test@example.com"
  When they enter valid credentials
  Then they are redirected to /dashboard
  And a session cookie is set

Scenario: Failed login lockout
  Given a registered user
  When they enter wrong password 3 times
  Then login is blocked for 5 minutes
  And an error message is displayed
```
````

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ SPEC-AS-TEST INTEGRATION                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User writes feature.md with Requirements + Acceptance Tests │
│                                                                 │
│  2. Orchestrator extracts tests at session start                │
│     - Parses gherkin/structured test blocks                     │
│     - Generates test stubs in .peer-sync/acceptance-tests/      │
│                                                                 │
│  3. Work phase: Agents implement feature                        │
│     - Can run acceptance tests anytime: `agent-duo test`        │
│     - Tests provide concrete feedback on progress               │
│                                                                 │
│  4. Before review phase transition                              │
│     - Orchestrator runs acceptance tests automatically          │
│     - If tests fail: agent stays in work phase, gets feedback   │
│     - If tests pass: proceed to review phase                    │
│                                                                 │
│  5. Review phase: Peer reviews code knowing tests pass          │
│     - Can focus on design/approach rather than correctness      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### New Commands

```bash
agent-duo test              # Run acceptance tests for current feature
agent-duo test --watch      # Run tests on file changes
agent-duo test --generate   # Generate test stubs from spec
```

### New State Files

```
.peer-sync/
├── acceptance-tests/
│   ├── generated/          # Auto-generated from spec
│   │   └── auth.test.js
│   └── results/
│       ├── claude-round-1.json
│       └── codex-round-1.json
└── spec-validated          # Present when tests pass
```

### Skill Addition to `duo-work.md`

```markdown
## Acceptance Tests

Your task file includes acceptance tests. Use them to validate your implementation:

1. Run tests periodically: `agent-duo test`
2. Tests must pass before you can signal `done`
3. If tests fail, fix the implementation before proceeding

The orchestrator will block review phase transition until tests pass.
```

### Test Framework Integration

The orchestrator detects the project's test framework and generates appropriate test files:

| Framework | Detection | Generated Format |
|-----------|-----------|------------------|
| Jest | `package.json` has jest | `.test.js` with describe/it |
| pytest | `pyproject.toml` or `pytest.ini` | `test_*.py` with pytest fixtures |
| Go testing | `go.mod` present | `*_test.go` with table-driven tests |
| Generic | fallback | Shell script with assertions |

### Benefits

- **Early validation**: Catch misunderstandings before code review
- **Concrete progress**: "3/5 tests passing" is clearer than "mostly done"
- **Reduced review burden**: Reviewers know functionality works, can focus on design
- **Documentation**: Specs serve as living documentation

### Open Questions

1. **Test generation quality**: How much can be auto-generated vs. requiring human refinement?
2. **Gherkin vs. simpler format**: Is gherkin too heavyweight? Consider simpler checkbox-based specs.
3. **Partial test passage**: Should agents proceed to review if 80% of tests pass?

---

## 5. Update Project Documentation Phase

**Problem**: Agents learn project-specific patterns during implementation but this knowledge is lost when the session ends. The project's `CLAUDE.md` or `AGENTS.md` files become stale.

**Solution**: A non-optional phase at session end where agents propose updates to project documentation based on what they learned.

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ UPDATE-DOCS PHASE (automatic, after PR creation)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Triggers when: Both PRs created OR session completing          │
│                                                                 │
│  1. Each agent reviews what they learned during implementation: │
│     - New patterns discovered in the codebase                   │
│     - Gotchas or pitfalls encountered                           │
│     - Conventions that weren't documented                       │
│     - Tool-specific knowledge (build commands, test patterns)   │
│                                                                 │
│  2. Agent reads current CLAUDE.md / AGENTS.md                   │
│                                                                 │
│  3. Agent proposes updates (or "no changes needed"):            │
│     - Writes to .peer-sync/docs-update-{agent}.md               │
│     - Includes: section, proposed text, rationale               │
│                                                                 │
│  4. Orchestrator notifies user of proposed updates              │
│                                                                 │
│  5. User reviews and applies (or discards) suggestions          │
│     - Can cherry-pick from both agents' proposals               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Proposal Format

```markdown
# Documentation Update Proposal

**Agent:** claude
**Session:** auth-feature
**Date:** 2026-02-01

## Proposed Updates

### 1. Add to "Testing" section

**Rationale:** Discovered that integration tests require a running Redis instance, not documented.

**Proposed text:**
```
## Testing

Integration tests require Redis running on localhost:6379:
\`\`\`bash
docker run -d -p 6379:6379 redis:alpine
npm run test:integration
\`\`\`
```

### 2. Add to "Conventions" section

**Rationale:** The codebase uses a specific error handling pattern I had to discover.

**Proposed text:**
```
## Error Handling

All API endpoints use the `ApiError` class from `src/errors.ts`:
- Throw `new ApiError(400, "message")` for client errors
- Throw `new ApiError(500, "message")` for server errors
- The global error handler formats these consistently
```

### 3. No changes needed

**Section:** Build commands
**Rationale:** Current documentation is accurate and complete.
```

### New Status Values

| Status | Meaning | Set by |
|--------|---------|--------|
| `updating-docs` | Reviewing and proposing doc updates | Agent |
| `docs-update-done` | Finished doc update proposal | Agent |

### Skill: `duo-update-docs.md`

```markdown
# Update Documentation Phase

Your implementation work is complete. Before the session ends, review what you learned and propose updates to the project's documentation.

## What to Look For

1. **Undocumented patterns**: Conventions you discovered by reading code
2. **Gotchas**: Things that tripped you up or took time to figure out
3. **Missing setup steps**: Dependencies, environment variables, services
4. **Outdated information**: Docs that contradict current code
5. **Useful commands**: Build, test, or debug commands you found helpful

## What NOT to Include

- Implementation details of your specific feature (that goes in the PR)
- Opinions on how code "should" be written
- Temporary workarounds or hacks

## Output

Write your proposals to `.peer-sync/docs-update-{your-name}.md` using the format specified.

If you have no meaningful updates to propose, write "No changes needed" with a brief rationale.

Signal completion: `agent-duo signal $MY_NAME docs-update-done "proposal ready"`
```

### CLI Changes

```bash
agent-duo start <feature> --skip-docs-update  # Opt out of docs phase
```

### Benefits

- **Institutional knowledge capture**: Learnings don't disappear with the session
- **Continuous documentation improvement**: Docs evolve with the codebase
- **Two perspectives**: Both agents may notice different things
- **Low overhead**: Agents already have context; just need to externalize it

### Integration with pai-lite

If pai-lite is configured, proposed doc updates can be:
- Routed to the Mayor for consolidation with other learnings
- Tracked as low-priority tasks if not immediately applied
- Used to update Mayor's project-specific memory files
