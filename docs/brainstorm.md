# Agent-Duo Evolution Brainstorm

Inspired by patterns from [Awesome Agentic Patterns](https://agentic-patterns.com/), this document explores ideas for evolving agent-duo beyond its current dual-agent parallel PR workflow.

---

## Current Architecture Recap

Agent-duo coordinates two AI agents working in parallel on the same task:
- Separate git worktrees per agent
- Work → Review → Work cycle with file-based coordination
- Produces two alternative PRs for human selection

---

## High-Impact Pattern Applications

### 1. Multi-Agent Debate / Opponent Processor

**Pattern**: Opponent Processor / Multi-Agent Debate Pattern

**Current state**: Agents review each other's work but don't actively debate.

**Evolution idea**: Add a structured debate phase where agents argue for their approach:

```
WORK → REVIEW → DEBATE → WORK
```

- After review, each agent writes a "defense" of their approach
- Agents read opponent's defense and write rebuttals
- Human (or third agent) judges which arguments are stronger
- Feedback informs next work round

**Implementation sketch**:
```bash
agent-duo signal claude debate-ready "My approach handles edge cases X, Y better"
# New phase: debate
# .peer-sync/debates/round-1-claude-defense.md
# .peer-sync/debates/round-1-codex-rebuttal-to-claude.md
```

---

### 2. Oracle and Worker Multi-Model Approach

**Pattern**: Oracle and Worker Multi-Model Approach

**Current state**: Both agents are peers with equal roles.

**Evolution idea**: Introduce an "architect" oracle that:
- Reads the task specification
- Decomposes into sub-tasks with clear interfaces
- Assigns different sub-tasks to each agent
- Agents work on complementary pieces rather than competing

**Use case**: Large features where parallel competition is wasteful.

```
┌─────────────────────────────────────────────┐
│  Oracle (GPT-4o / Claude Haiku)             │
│  - Analyzes task                            │
│  - Splits into: API layer / UI layer        │
└─────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
┌─────────────────┐  ┌─────────────────┐
│  Claude         │  │  Codex          │
│  (API layer)    │  │  (UI layer)     │
└─────────────────┘  └─────────────────┘
         │                    │
         └────────┬───────────┘
                  ▼
          Integration phase
```

---

### 3. Sub-Agent Spawning

**Pattern**: Sub-Agent Spawning

**Current state**: Fixed two-agent topology.

**Evolution idea**: Allow agents to spawn sub-agents for specific tasks:

- Agent hits a complex sub-problem (e.g., "optimize this algorithm")
- Spawns a temporary sub-agent specialized for that task
- Sub-agent returns result, terminates
- Parent agent integrates result

**Benefits**:
- Agents can parallelize their own work
- Specialized sub-agents for testing, docs, security review

**Coordination**: Sub-agents would write to `.peer-sync/subagents/` with their own status files.

---

### 4. Reflection Loop + Self-Critique

**Patterns**: Reflection Loop, Self-Critique Evaluator Loop

**Current state**: Agents only receive peer feedback.

**Evolution idea**: Add self-reflection checkpoints:

```
WORK (checkpoint) → SELF-CRITIQUE → WORK (continue) → PEER-REVIEW
```

- Mid-work, agent pauses to critique own approach
- Writes `.peer-sync/reflections/round-1-claude-self-critique.md`
- Addresses own concerns before peer sees work
- Produces higher-quality work for peer review

**Trigger**: Time-based (after N minutes) or milestone-based (after first commit).

---

### 5. Filesystem-Based Agent State + Memory Synthesis

**Patterns**: Filesystem-Based Agent State, Memory Synthesis from Execution Logs

**Current state**: Minimal state (status, phase, round).

**Evolution idea**: Rich persistent memory across sessions:

```
.peer-sync/
├── memory/
│   ├── claude-session-summaries.md    # Auto-generated summaries
│   ├── codex-lessons-learned.md       # Extracted insights
│   └── shared-decisions.md            # Architectural choices made
```

- After each round, synthesize key decisions into memory
- Future sessions can load relevant memories
- Agents learn from past duo sessions on same codebase

**Implementation**: Add `agent-duo summarize` command that uses LLM to distill session logs.

---

### 6. Progressive Autonomy with Model Evolution

**Pattern**: Progressive Autonomy with Model Evolution

**Current state**: Fixed autonomy level (agents work freely within phase).

**Evolution idea**: Adaptive autonomy based on confidence and past performance:

- **Low autonomy** (new task/codebase): Frequent checkpoints, human approval for major changes
- **Medium autonomy** (familiar patterns): Standard work/review cycle
- **High autonomy** (well-tested patterns): Agents can skip review for trivial changes

**Implementation**: Track success metrics in `.peer-sync/metrics/` and adjust phase lengths.

---

### 7. Spec-As-Test Feedback Loop

**Pattern**: Spec-As-Test Feedback Loop

**Current state**: Task description in `<feature>.md` is prose.

**Evolution idea**: Structured specs that become executable tests:

````markdown
# feature.md

## Requirements
- [ ] User can login with email/password
- [ ] Failed login shows error message
- [ ] Successful login redirects to dashboard

## Acceptance Tests
```gherkin
Given a registered user
When they enter valid credentials
Then they are redirected to /dashboard
```
````

- Orchestrator extracts tests from spec
- Agents must pass tests to complete work phase
- Automatic validation before review phase

---

### 8. Background Agent with CI Feedback

**Pattern**: Background Agent with CI Feedback, Coding Agent CI Feedback Loop

**Current state**: No CI integration.

**Evolution idea**: Continuous CI feedback during work:

```
┌─────────────────────────────────────────────┐
│  CI Watcher                                 │
│  - Monitors agent commits                   │
│  - Runs tests on each commit                │
│  - Writes results to .peer-sync/ci/         │
└─────────────────────────────────────────────┘
         │
         ▼ (on failure)
┌─────────────────────────────────────────────┐
│  Agent receives: "Tests failing:            │
│  src/auth.test.js:42 - expected 401"        │
└─────────────────────────────────────────────┘
```

**Implementation**: `agent-duo start --ci` launches background watcher that runs tests on file changes.

---

### 9. Swarm Migration Pattern

**Pattern**: Swarm Migration Pattern

**Current state**: Agents stay in their worktrees throughout.

**Evolution idea**: Dynamic agent reassignment:

- If one agent finishes early, can "migrate" to help the other
- Or migrate to a third worktree for integration work
- Swarm of 3+ agents that dynamically allocate to subtasks

**Use case**: One agent stuck on hard problem, other finished - can pair up.

---

### 10. Human-in-the-Loop Approval Framework

**Pattern**: Human-in-the-Loop Approval Framework

**Current state**: Human reviews final PRs.

**Evolution idea**: Configurable approval gates throughout:

```yaml
# .agent-duo.yml
approval_gates:
  - after: planning
    require: human
  - after: first_commit
    require: peer_only
  - after: review_phase
    require: human_if_major_changes
```

- Orchestrator pauses at gates for human input
- Slack/webhook notifications for approval requests
- Mobile-friendly approval interface

---

## Lower-Effort Enhancements

### 11. Verbose Reasoning Transparency

**Pattern**: Verbose Reasoning Transparency

Add `--verbose` mode that captures agent reasoning:
```bash
agent-duo start myfeature --verbose
# Creates .peer-sync/reasoning/claude-thoughts.log
```

### 12. Action Caching & Replay

**Pattern**: Action Caching & Replay Pattern

Record and replay sessions for debugging:
```bash
agent-duo replay auth-session-2024-01-15
```

### 13. Team-Shared Agent Configuration as Code

**Pattern**: Team-Shared Agent Configuration as Code

Move agent preferences to version-controlled config:
```yaml
# .agent-duo.yml
agents:
  claude:
    model: claude-sonnet-4
    skills: [duo-work, duo-review, security-check]
  codex:
    model: codex-1
    skills: [duo-work, duo-review]
```

### 14. Dual-Use Tool Design

**Pattern**: Dual-Use Tool Design

Ensure all agent commands work for humans too:
```bash
# Human can manually trigger what agents do
agent-duo signal claude done "Finished API implementation"
agent-duo peer-status  # Works in any context
```

---

## Experimental / Long-Term Ideas

### 15. Tree-of-Thought Parallel Exploration

**Pattern**: Tree-of-Thought Reasoning, Language Agent Tree Search (LATS)

Instead of two fixed agents, spawn a tree of approaches:
- Root: Initial task analysis
- Branches: Different architectural choices
- Leaves: Concrete implementations
- Prune unsuccessful branches, merge successful ones

### 16. Self-Rewriting Meta-Prompt Loop

**Pattern**: Self-Rewriting Meta-Prompt Loop

Agents improve their own skills:
- After successful session, agent proposes skill improvements
- Human approves, skills evolve
- Skills become increasingly effective over time

### 17. Iterative Multi-Agent Brainstorming

**Pattern**: Iterative Multi-Agent Brainstorming

Pre-implementation brainstorming phase:
```
BRAINSTORM (3+ agents) → SELECT (human) → IMPLEMENT (2 agents)
```

### 18. Isolated VM per Agent

**Pattern**: Isolated VM per RL Rollout

For untrusted experiments, run each agent in isolated VM:
```bash
agent-duo start myfeature --isolated
# Each agent gets fresh VM with project snapshot
```

---

## Key Improvement Areas

This section categorizes the core challenges agent-duo faces and maps relevant patterns to each.

### 1. Managing Context

**The challenge**: Agent-duo is context-hungry by design. Each agent's context must simultaneously handle:
- Building a complete solution
- Reviewing the peer's solution (reading their diffs, understanding their approach)
- Orchestration overhead (status signals, phase awareness, coordination protocol)

This triple burden strains context windows. Additionally, we don't yet know how well native compaction (auto-summarization) will perform under this workload—something to monitor.

**Unique to agent-duo: Context fragmentation**. The work/review/work cycle means context accumulates fragments from multiple concerns. An agent might have: early implementation thoughts → peer review notes → revised implementation plans → more peer feedback—all interleaved and potentially conflicting.

**Remedies**:

| Approach | How it helps | Relevant patterns |
|----------|--------------|-------------------|
| **Delegation (subagents)** | Offload specific tasks to fresh-context subagents that return only results | Sub-Agent Spawning (#3), Oracle/Worker Split (#2) |
| **Proactive context clearing** | Clear context before hitting limits, rely on file-based state (the "Ralph-Wiggum loop" approach) | Filesystem-Based Agent State (#5), Memory Synthesis (#5), Proactive Agent State Externalization |
| **Curated context injection** | Only inject relevant portions of peer's work, not full diffs | Context-Minimization Pattern, Curated Code Context Window, Dynamic Context Injection |
| **Phase isolation** | Separate work and review into distinct agent invocations | Discrete Phase Separation, Planner-Worker Separation |

**Potential implementation**:

```bash
# Proactive context clearing between phases
agent-duo start myfeature --fresh-context-per-phase

# Agent writes state to file before context clear
# .peer-sync/state/claude-round-2-checkpoint.md
# New agent instance loads checkpoint and continues
```

**Open questions**:
- When should we proactively clear vs. let auto-compaction handle it?
- How much state can be reliably externalized to files?
- Can we detect context degradation (agent confusion, repetition) and trigger clearing?

---

### 2. Human Feedback Integration

**The challenge**: Agent-duo's core value proposition is autonomy—two agents iterate toward vetted solutions without human babysitting. However, this autonomy can be wasteful when:
- Critical information is missing that only the human knows
- A situation could trigger an insight in the user ("oh, we actually want X not Y")
- Agents are heading down a dead-end path the human could redirect
- The task scope was ambiguous and agents diverged from intent

**Two sub-problems**:

1. **When to inject feedback** (feedback injection points)
2. **How to notify the human** (push notification mechanisms)

**Feedback injection points**:

| Point | When to trigger | Relevant patterns |
|-------|-----------------|-------------------|
| **After planning** | Before agents start coding, validate approach | Human-in-the-Loop Approval (#10), Plan-Then-Execute |
| **On uncertainty** | Agent explicitly flags low confidence | Chain-of-Thought Monitoring & Interruption, Spectrum of Control |
| **After first commit** | Early checkpoint before deep investment | Progressive Complexity Escalation |
| **On divergence detection** | Agents' approaches are too similar or too different | Multi-Agent Debate (#1) |
| **Time-based** | Periodic check-ins (every N minutes) | Seamless Background-to-Foreground Handoff |
| **On error/block** | Agent hits a wall, needs human input | Rich Feedback Loops > Perfect Prompts |

**Push notification mechanisms**:

| Mechanism | Pros | Cons |
|-----------|------|------|
| **Terminal bell/sound** | Immediate, no setup | Only works if terminal visible |
| **Desktop notification** | Works in background | OS-specific, may be ignored |
| **Email** | Reliable, async-friendly | Slow, interruptive |
| **Slack/Discord webhook** | Team-visible, fast | Requires setup |
| **SMS (Twilio)** | Reaches anywhere | Costly, very interruptive |
| **tmux alert** | Native to current setup | Only works in tmux mode |

**Potential implementation**:

```yaml
# .agent-duo.yml
notifications:
  channels:
    - type: terminal_bell
    - type: slack
      webhook: ${SLACK_WEBHOOK_URL}
    - type: email
      to: dev@example.com

  triggers:
    - event: needs_human_input
      channels: [slack, terminal_bell]
    - event: phase_complete
      channels: [terminal_bell]
    - event: error
      channels: [slack, email]
```

```bash
# Orchestrator triggers notification
agent-duo notify "Claude needs clarification on auth approach" --channel slack

# Or agent requests human input (pauses until response)
agent-duo ask-human "Should login support OAuth or just email/password?"
# Blocks until human responds via CLI, Slack, or web UI
```

**Balancing autonomy and feedback**:

The goal isn't to add human checkpoints everywhere—that defeats the purpose. Instead:

1. **Default to autonomy**: Agents work independently unless they hit genuine uncertainty
2. **Proactive agent signaling**: Train agents (via skills) to recognize when human input would help
3. **Configurable gates**: Let users choose their preferred autonomy level per-project
4. **Async-friendly**: Human can respond later; agents continue on other work or pause gracefully

**Relevant patterns**: Human-in-the-Loop Approval Framework (#10), Seamless Background-to-Foreground Handoff, Chain-of-Thought Monitoring & Interruption, Spectrum of Control / Blended Initiative, Rich Feedback Loops > Perfect Prompts

---

## Priority Matrix

| Idea | Impact | Effort | Priority |
|------|--------|--------|----------|
| Spec-As-Test Feedback | High | Medium | 1 |
| CI Feedback Loop | High | Medium | 2 |
| Multi-Agent Debate | High | Medium | 3 |
| Reflection Loop | Medium | Low | 4 |
| Memory Synthesis | Medium | Medium | 5 |
| Verbose Reasoning | Low | Low | 6 |
| Oracle/Worker Split | High | High | 7 |
| Sub-Agent Spawning | High | High | 8 |

---

## Next Steps

1. **Validate demand**: Which patterns address real pain points?
2. **Prototype Spec-As-Test**: Add structured spec parsing to work phase
3. **Add CI watcher**: Background process for test feedback
4. **Experiment with debate**: Manual debate phase to test value

---

*Document generated 2026-01-23. Patterns sourced from [agentic-patterns.com](https://agentic-patterns.com/).*
