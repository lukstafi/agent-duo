# Agent-Debate: Structured Decision-Making Between Two AI Agents

## Motivation

`agent-duo` and `agent-pair` are about writing code — parallel implementations, coder/reviewer
workflows, worktrees, PRs. But many important project decisions aren't code decisions: "Should
we drop multi-streaming support?", "Is it worth adding an LLVM backend before v1.0?", "Should
we use JWT or session-based auth?"

These strategic questions benefit from structured argumentation where two agents take opposing
positions and debate to a conclusion. The existing merge-debate mechanism (vote → debate → consensus)
proves this pattern works, but it's deeply embedded in the merge flow and only handles "which PR
to merge."

A standalone `agent-debate` entry point would:
- Let the user pose any thesis/question and get a structured, adversarial analysis
- Assign genuine/steelman roles so both sides get the strongest possible case
- Produce a written outcome with preserved argument chains for review
- Run unattended with `--auto-run`

See: https://github.com/lukstafi/agent-duo/issues/24

## Current State

### Merge-debate infrastructure

The merge flow already implements parallel voting and debate rounds:
- `extract_vote` / `votes_agree` / `get_agreed_vote` — vote file parsing and consensus checking
- `generate_merge_debate_message` — constructs debate prompts with previous-round context
- Round-indexed vote files in `.peer-sync/merge-votes/round-{n}-{agent}-vote.md`
- Required marker lines (`## My Vote:`) for orchestrator parsing
- Max 2 debate rounds before user escalation

### Session infrastructure

Fully reusable: tmux session management, port allocation, skill template installation,
`send_to_agent` / `trigger_skill`, `atomic_write`, status signaling protocol, `.peer-sync/`
state coordination.

### What's missing

No way to run a debate without a git worktree, a code task, and a merge context. The debate
protocol (assessment → role assignment → opening → response → hold/yield) doesn't exist.

## Proposed Change

### CLI interface

```
agent-debate start "<thesis>" [options]
agent-debate status
agent-debate stop
agent-debate cleanup
```

Options: `--auto-run`, `--max-rounds N` (default 5), `--round-timeout N` (default 600s),
`--no-ttyd`, `--codex-thinking`.

### Debate workspace (no worktree)

Debates produce text, not code. The workspace is:
```
~/.agent-duo/debates/<debate-id>/
├── thesis.md
├── assessments/{claude,codex}.md
├── statements/{claude,codex}-opening.md
├── responses/round-{n}-{agent}.md
├── decisions/round-{n}-{agent}.md
└── outcome.md
```

Both agents share this workspace via environment variables (like `$PEER_SYNC` today). A symlink
`.peer-sync/` inside the debate dir provides status coordination using the existing protocol.

### Debate protocol

1. **Assessment** — Each agent independently rates the thesis on a 5-level scale
   (strongly disagree → strongly agree). Written to `assessments/{agent}.md` with a required
   `## Level: N` marker for parsing.

2. **Role assignment** — Higher-assessment agent becomes proponent, lower becomes opponent.
   Equal assessments get random assignment.

3. **Labeling** — Each agent is labeled "genuine" (assessment aligns with assigned role) or
   "steelman" (arguing against their actual position). Labels are explicit in all subsequent
   skills so agents aren't confused when steelmanning.

4. **Opening statements** — Both agents write opening statements in parallel.

5. **Response + decision loop** — Each round:
   a. Both agents respond to the other's latest argument (parallel)
   b. Both agents decide "hold" or "yield" (parallel), written with `## Decision: hold` or
      `## Decision: yield` marker
   c. Termination: one hold + one yield → holder's position wins; both yield → draw;
      both hold → next round; max rounds → draw

6. **Outcome** — Written to `outcome.md` with thesis, result, assessments, key arguments,
   and links to all round artifacts.

### Skill templates (4 new)

| Skill | Signal | Output |
|-------|--------|--------|
| `debate-assess` | `assess-done` | `assessments/{agent}.md` |
| `debate-opening` | `opening-done` | `statements/{agent}-opening.md` |
| `debate-respond` | `respond-done` | `responses/round-{n}-{agent}.md` |
| `debate-decide` | `decide-done` | `decisions/round-{n}-{agent}.md` |

Templates follow the existing format: YAML frontmatter, phase header, purpose, steps with
bash code blocks, signal instructions. The steelman label is prominent in templates where
it applies ("You are arguing for a position you don't personally hold — present the strongest
possible case.").

### Session namespace

`SESSION_REGISTRY_PREFIX="debate"` with session files at `.agent-sessions/debate-*.session`.
Separate from duo/pair to avoid namespace collisions.

## Scope

**In scope:**
- The `agent-debate` script (entry point, orchestrator, session management)
- 4 skill templates
- Debate workspace management (create, status, cleanup)
- Hold/yield consensus mechanism
- Outcome report generation

**Out of scope:**
- Multi-agent debates (3+ agents) — start with 2
- Integration with ludics/harness task system — debates are standalone
- Web UI for debate viewing — terminal output and file artifacts are sufficient
- Debate chains (using one debate's outcome as input to another)

## Edge Cases

- **Both agents strongly agree** — Random proponent/opponent. Opponent steelmans the counter-position. Tests whether the thesis withstands adversarial scrutiny even when both agents lean toward it.
- **Both agents neutral** — Random roles, both labeled steelman. May produce less conviction; the max-rounds limit prevents aimless cycling.
- **Agent timeout** — Same timeout/retry as existing status polling. If an agent fails to signal within `round-timeout`, the round is forfeited (equivalent to yield).
- **Multi-part thesis** — Assessment is holistic. Agents may address parts individually in arguments but the hold/yield decision is on the thesis as a whole.
