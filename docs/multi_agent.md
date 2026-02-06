# Multi-Agent Enhancements for agent-duo

How agent-duo can leverage provider-native multi-agent capabilities (Claude Code sub-agents and agent teams) while preserving the cross-provider (Claude + Codex) architecture that is our core value proposition.

## Guiding Principle

Agent-duo's value is the **cross-provider divide**: Claude Code paired with GPT Codex produces genuinely divergent solutions because the models think differently. Provider-native multi-agent features (sub-agents, teams) should strengthen each agent's side of the duo, not replace the dual structure.

```
┌─────────────────────────────────────────────────┐
│                  agent-duo                      │
│                                                 │
│  ┌─────────────────-─┐   ┌─────────────────-┐   │
│  │  Claude's Side    │   │  Codex's Side    │   │
│  │                   │   │                  │   │
│  │  ┌─Sub-agents──┐  │   │  (future: Codex  │   │
│  │  │ Reviewer    │  │   │   multi-agent    │   │
│  │  │ Researcher  │  │   │   features)      │   │
│  │  │ Test Runner │  │   │                  │   │
│  │  └─────────────┘  │   │                  │   │
│  │                   │   │                  │   │
│  │  ┌─Team─────────┐ │   │                  │   │
│  │  │ Lead + mates │ │   │                  │   │
│  │  └──────────────┘ │   │                  │   │
│  └─────────────────-─┘   └─────────────────-┘   │
│                                                 │
│          .peer-sync/ coordination               │
└─────────────────────────────────────────────────┘
```

---

## 1. Claude Code Sub-Agents

### What They Are

Sub-agents are specialized AI assistants running within a single Claude Code session. Each has its own context window, custom system prompt, specific tool access, and independent permissions. The main Claude agent delegates tasks to them automatically based on their descriptions.

Key properties:
- Run **within** a single Claude Code session (not separate processes)
- Preserve the main agent's context by isolating verbose operations
- Can run in foreground (blocking) or background (concurrent)
- Cannot nest (sub-agents can't spawn sub-agents)
- Defined as markdown files with YAML frontmatter in `.claude/agents/`

### Custom Sub-Agents vs Built-in Task Tool Types

Claude Code has two sub-agent mechanisms. Understanding the difference matters for agent-duo's design.

**Built-in Task tool types** (Explore, Plan, General-purpose, Bash) are invoked programmatically via the `Task` tool's `subagent_type` parameter. They have fixed tool access, fixed model defaults (Explore uses haiku, others inherit), no persistent memory, no hooks, and no custom system prompts. They're good general-purpose tools but not customizable.

**Custom sub-agents** (defined in `.claude/agents/` as markdown with YAML frontmatter) are routed to automatically based on their `description` field, or via explicit natural language ("use the duo-reviewer agent"). They offer:

| Capability | Custom sub-agents | Built-in Task types |
|------------|-------------------|---------------------|
| Tool restrictions | Configurable (`tools`, `disallowedTools`) | Fixed per type |
| Model selection | `haiku`, `sonnet`, `opus`, `inherit` | Fixed (Explore=haiku, others inherit) |
| Persistent memory | Yes (`user`, `project`, `local` scopes) | No |
| Lifecycle hooks | Full (PreToolUse, PostToolUse, Stop) | Limited |
| Custom system prompt | Yes (markdown body) | No |
| Skills preloading | Yes (`skills` field) | No |
| Permission modes | Configurable (`plan`, `dontAsk`, `bypassPermissions`) | Inherit only |
| Programmatic dispatch | No (description-based routing only) | Yes (`subagent_type` param) |

**Key limitation**: custom sub-agents **cannot** be invoked via the Task tool's `subagent_type` parameter. They're only triggered by Claude's automatic description-matching or explicit natural language requests.

**Conclusion for agent-duo**: Phase-specific sub-agents (reviewer, researcher, test-runner) should be **custom sub-agents** to get memory, hooks, and tool restrictions. The built-in Explore/Plan types remain useful as general-purpose tools within the main agent session and within skills.

### How agent-duo Can Use Sub-Agents

#### A. Phase-Specific Sub-Agents

Instead of relying solely on skills (markdown instructions), we can create sub-agents that are purpose-built for each phase. Sub-agents bring tool restrictions and model selection that skills alone cannot provide.

```
.claude/agents/
├── duo-reviewer.md        # Read-only, reviews peer's code
├── duo-researcher.md      # Read-only, explores codebase before work
├── duo-test-runner.md     # Bash-only, runs tests and reports failures
├── duo-doc-updater.md     # Write-only to docs, captures learnings
└── duo-plan-analyst.md    # Read-only, analyzes peer's plan
```

**Example: Review Phase Sub-Agent**

```yaml
---
name: duo-reviewer
description: Reviews peer agent's code changes. Use during review phases.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: inherit
memory: project
---

You are a code reviewer for a dual-agent development system. Your peer
(the other agent) has been working on the same feature with a different
approach.

Read the peer's changes via:
  git -C "$PEER_WORKTREE" diff
  git -C "$PEER_WORKTREE" log --oneline -10

Write your review to:
  $PEER_SYNC/reviews/round-${ROUND}-${MY_NAME}-reviews-${PEER_NAME}.md

Focus on: different tradeoffs, strengths, ideas worth noting.
Do NOT try to converge approaches -- divergence is the goal.
```

Benefits over pure skills:
- **Tool restrictions enforced**: reviewer literally cannot edit peer's code
- **Model selection**: use haiku for quick reviews, opus for deep analysis
- **Persistent memory**: reviewer builds knowledge about recurring patterns
- **Context isolation**: review output doesn't bloat the main work context

#### B. Background Research Sub-Agent

During the work phase, the main Claude agent could delegate research to a background sub-agent while continuing to write code.

```yaml
---
name: duo-researcher
description: Research codebase patterns and conventions before implementing. Use proactively at the start of work phases.
tools: Read, Grep, Glob
model: haiku
---

Quickly explore the codebase to find:
1. Relevant existing patterns for the current task
2. Test conventions and frameworks in use
3. Similar implementations to reference
4. Dependencies and API contracts

Return a concise summary (not the full code) of what you found.
```

This is valuable because agent-duo's work phases have timeouts -- a background researcher saves the main agent's time.

#### C. Test Runner Sub-Agent

```yaml
---
name: duo-test-runner
description: Run tests and report results. Use after making code changes.
tools: Bash
model: haiku
---

Run the project's test suite. Report ONLY:
1. How many tests passed/failed
2. Failing test names and error messages
3. Whether the failure is likely related to current changes

Do not attempt to fix anything. Just report.
```

This keeps verbose test output out of the main context window, which is critical when working under agent-duo's time-boxed work phases.

#### D. Persistent Memory Across Rounds

Sub-agent memory is particularly useful in agent-duo because work happens in multiple rounds. A sub-agent with `memory: project` can remember:

- What review feedback it gave in previous rounds
- Which patterns the codebase uses
- What the peer agent tends to do well or poorly
- Common test failures and their causes

```yaml
memory: project  # Stored in .claude/agent-memory/<name>/
```

This creates a `.claude/agent-memory/duo-reviewer/MEMORY.md` that persists across sessions, giving the review sub-agent "institutional knowledge" about the project and the collaboration.

### When Sub-Agents Help vs Hinder

Sub-agents are **not universally beneficial**. They impose structure that helps on some tasks and hurts on others.

**Help:**
- Review phase: enforced read-only is genuinely safer; persistent memory across rounds is valuable; context isolation keeps the main agent's window clean
- Test running: isolating verbose output is almost always beneficial
- Complex features: background research while coding saves time under timeouts

**Hinder:**
- Small/simple tasks: delegation overhead (routing decision, sub-agent spin-up, context re-gathering) costs more time than doing the work inline
- Tightly coupled work: if review insights should immediately inform the next implementation step, forcing them through a separate context window adds friction
- Description-based routing is imprecise: Claude might route when it shouldn't or miss when it should, unlike skills which give explicit phase instructions
- Context loss: sub-agents don't inherit the parent conversation, so a reviewer sub-agent starts cold and must re-discover what the main agent already knows

### The `--subagents` Flag

Sub-agents are enabled via a binary `--subagents` flag on `agent-duo start` or `agent-duo run`. This creates exactly **two skill variants** to maintain:

```
skills/
├── duo-work.md              # Default: agent does everything inline
├── duo-work-subagents.md    # --subagents: delegates to researcher, test-runner
├── duo-review.md            # Default: agent reviews inline
├── duo-review-subagents.md  # --subagents: delegates to duo-reviewer sub-agent
├── ...                      # Same pattern for other phases
```

**Why binary, not per-sub-agent granularity**: With granular toggles (`--subagent-reviewer`, `--subagent-tester`, etc.), each skill would need conditional logic ("if sub-agent X is available, use it, otherwise do it yourself"). Two clean skill sets are easier to write, test, and reason about than one skill set with branching paths.

**When `--subagents` is off** (default): current behavior. Skills instruct the agent to do all work inline. No `.claude/agents/` files are installed.

**When `--subagents` is on**: `agent-duo setup`/`start` installs sub-agent definitions to `.claude/agents/` in the worktree, and uses the `-subagents` skill variants that explicitly reference them.

### Implementation Path for Sub-Agents

1. **Create sub-agent definitions** in the agent-duo repo (source of truth)
2. **Create `-subagents` skill variants** for each phase (duo-work-subagents.md, etc.)
3. **Update `agent-duo setup`/`start`** to conditionally install sub-agent definitions and select the right skill variant based on `--subagents`
4. **Store the flag** in `.peer-sync/subagents` so the orchestrator uses the right skills throughout the session
5. **Test both paths** to ensure default (no sub-agents) behavior is unaffected

---

## 2. Claude Code Agent Teams

### What They Are

Agent Teams coordinate multiple **separate** Claude Code instances working together. One session is the **team lead** (coordinator), others are **teammates** (independent workers). Each teammate has its own full context window and can communicate with others via direct messaging.

Key properties:
- **Experimental feature** -- must be enabled with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Each teammate is a full Claude Code process
- Teammates can message each other directly (not just report to lead)
- Shared task list with self-coordination
- Display modes: in-process (single terminal) or split panes (tmux/iTerm2)
- Higher token cost than sub-agents (each teammate is a separate session)
- Cannot nest teams or promote teammates

### Teammate-Centric Design

Teams should be organized around **persistent teammate roles** (competency-based), not around phases (lifecycle-based). A teammate persists across agent-duo phases and contributes differently in each one.

Why teammate-centric beats phase-centric:
- **Continuity**: A QA teammate who wrote tests in round 1 remembers them in round 2. A phase-centric test team would dissolve after the work phase and lose that context.
- **Fewer teammates needed**: 2-3 persistent roles vs. 3+ ephemeral roles per phase.
- **Natural fit**: Agent teams are long-lived sessions. Spawning and dissolving teams per phase fights the model.
- **Simpler configuration**: `--team-qa` means "add a QA teammate" rather than "enable teams for the work phase and review phase and merge phase with different configurations each time."

#### Candidate Teammate Roles

**QA Teammate** (`--team-qa`):
```
Across all phases of Claude's session:
  │
  ├─ Work phase: writes and runs tests for the lead's implementation
  ├─ Review phase: runs peer's test suite, checks coverage gaps
  ├─ Plan phase: identifies testability concerns in the plan
  └─ Merge phase: runs combined test suites, flags regressions
```
The QA teammate owns test files (e.g., `tests/`, `*_test.*`, `*.spec.*`). The lead implements; the QA teammate tests. They message each other: QA reports failures, lead fixes, QA re-runs. This division is natural and avoids worktree contention because they own different files.

**Research & Review Teammate** (`--team-research`):
```
Across all phases of Claude's session:
  │
  ├─ Work phase: reads codebase for patterns, conventions, dependencies;
  │              feeds insights to lead as they implement
  ├─ Review phase: deep-reads peer's changes, analyzes architectural
  │                implications, drafts review notes for lead to synthesize
  ├─ Plan phase: maps existing code, identifies risks, researches
  │              libraries or approaches
  └─ Merge phase: analyzes both PRs in depth, feeds analysis to lead
```
The research teammate is **read-only** -- it never edits files, only reads and messages. This eliminates worktree contention entirely and provides a continuous stream of context that the lead would otherwise have to gather itself.

#### How Teammates Participate Across Phases

```
agent-duo phase:   plan  →  work  →  review  →  work  →  review  →  merge
                    │         │         │         │         │         │
Lead:              writes    codes     writes    codes     writes    votes &
                   plan                review              review    merges
                    │         │         │         │         │         │
QA teammate:       flags     writes    runs      updates   runs      runs
                   testability tests   peer's    tests     peer's    combined
                   issues             tests               tests     suites
                    │         │         │         │         │         │
Research mate:     maps      feeds     drafts    feeds     drafts    analyzes
                   codebase  insights  review    insights  review    both PRs
                                       notes               notes
```

The lead remains the only one who writes to `.peer-sync/` and signals to the orchestrator. Teammates communicate only with the lead (and each other) via the team messaging system.

### Teammate-Centric Configuration

```bash
# Add a QA teammate
agent-duo start auth --team-qa

# Add a research teammate
agent-duo start auth --team-research

# Add both
agent-duo start auth --team-qa --team-research

# Combine with sub-agents
agent-duo start auth --subagents --team-qa
```

Each `--team-<role>` flag:
- Enables `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in Claude's environment
- Installs the teammate role definition
- Is stored in `.peer-sync/team-qa`, `.peer-sync/team-research`, etc.

Skills need a `-team` variant that instructs the lead to coordinate with its teammates during each phase. Unlike the per-phase approach (which would need a different team skill per phase), a single set of team-aware skills works because the teammates are persistent -- the skill just says "coordinate with your QA teammate on testing" rather than "spawn a 3-person test team."

When `--subagents` and `--team-*` are both set, they complement each other: the lead (and its teammates) can use sub-agents for isolated tasks like verbose test output. Sub-agents are intra-session tools; teammates are inter-session collaborators.

### Integration Challenges with Teams

1. **Worktree contention**: Mitigated by the teammate-centric design. QA owns test files; research teammate is read-only; lead owns implementation files. File ownership is defined by role, not negotiated per phase.

2. **Status signaling**: Only the lead writes to `.peer-sync/claude.status`. Teammates communicate via team messaging, never via `.peer-sync/`.

3. **Terminal management**: agent-duo uses ttyd for agent terminals. Teams add their own display (in-process or tmux panes). The team runs within Claude's existing ttyd terminal, so no conflict -- the team's display mode is internal to Claude's session.

4. **Token cost**: Each teammate is a separate Claude Code process. The teammate-centric model is more cost-efficient than phase-centric because 2-3 persistent teammates < N ephemeral teammates spawned per phase. Still, teams should be opt-in.

5. **Experimental status**: Agent teams are experimental with known limitations (no session resumption with in-process teammates, task status can lag).

### Implementation Path for Teams

1. **Start with `--team-qa`** as the first teammate role (clearest file ownership, highest standalone value)
2. **Create team-aware skill variants** (`duo-work-team.md`, `duo-review-team.md`) that instruct the lead to coordinate with available teammates
3. **Define file ownership rules** per role (QA owns `tests/`, `*_test.*`, `*.spec.*`; lead owns everything else; research is read-only)
4. **Modify status signaling** so only the lead writes to `.peer-sync/claude.status`
5. **Add `--team-research`** once `--team-qa` is proven
6. **Measure token cost vs. quality** per teammate role to guide recommendations

---

## 3. Comparison: When to Use What

| Scenario | Mechanism | Why |
|----------|-----------|-----|
| Quick codebase research | Sub-agent (Explore) | Low cost, fast, built-in |
| Isolating verbose test output | Sub-agent (background) | Keeps main context clean |
| Continuous test writing alongside implementation | Team (QA teammate) | Persistent context, owns test files |
| Deep codebase analysis feeding into all phases | Team (Research teammate) | Read-only, continuous insights across phases |
| Persistent cross-round knowledge | Sub-agent with memory | Builds institutional knowledge cheaply |
| Complex multi-layer feature | Team (QA + Research) | Parallel work with clear file ownership |
| Simple single-file changes | Neither | Main agent handles directly |

---

## 4. Concrete Next Steps

### Phase 1: Sub-Agents (Low Risk, High Value)

- [ ] Create sub-agent definitions in agent-duo repo: reviewer, researcher, test-runner
- [ ] Create `-subagents` skill variants for key phases (duo-work, duo-review, duo-plan)
- [ ] Add `memory: project` to reviewer sub-agent for cross-round learning
- [ ] Add `--subagents` flag to `agent-duo start`/`run`, stored in `.peer-sync/subagents`
- [ ] Update `agent-duo setup` to conditionally install sub-agent definitions + select skill variant
- [ ] Test both paths: default (inline) and `--subagents` (delegating)

### Phase 2: Teams (Higher Risk, Higher Ceiling)

- [ ] Prototype `--team-qa`: QA teammate that writes/runs tests while lead implements
- [ ] Define file ownership rules (QA owns test files, lead owns implementation)
- [ ] Create team-aware skill variants (`duo-work-team.md`, `duo-review-team.md`)
- [ ] Ensure only lead writes to `.peer-sync/claude.status`
- [ ] Measure token cost vs. quality for the QA teammate role
- [ ] Add `--team-research` once `--team-qa` is proven

### Phase 3: Codex Parity

- [ ] Monitor OpenAI's multi-agent roadmap for Codex
- [ ] When Codex gains sub-agent capabilities, create equivalent configurations
- [ ] Maintain the dual structure: each provider's multi-agent features strengthen its own side

---

## 5. Codex Side: Future Considerations

OpenAI's Codex currently has no equivalent to sub-agents or teams. When it does, the same patterns apply: use provider-native multi-agent features to strengthen Codex's side of the duo.

In the meantime, Codex benefits indirectly:
- Claude's richer reviews (via sub-agents/teams) give Codex better feedback
- Claude's more thorough plans help Codex understand the feature better
- The competitive pressure of Claude's team-enhanced output may push Codex to produce better standalone work

---

## 6. Architectural Constraints

These constraints ensure multi-agent features don't break agent-duo's coordination:

1. **Only the main agent (or team lead) writes to `.peer-sync/`**. Sub-agents and teammates must not directly modify status files.
2. **The orchestrator doesn't know about sub-agents/teams**. From the orchestrator's perspective, "Claude" is one agent. Internal delegation is invisible.
3. **Skills remain the primary interface**. Sub-agents and teams are enhancements that skills can reference, not replacements for the skill system.
4. **Cross-provider communication stays file-based**. Sub-agents and teams are intra-provider only. The `.peer-sync/` protocol remains the bridge between Claude and Codex.
5. **Multi-agent features are opt-in**. Default behavior should work without sub-agents or teams for simplicity and cost control.
