# Rewrite agent-duo from Bash to TypeScript/Bun

## Motivation

The agent-duo codebase (~14,000 lines across four Bash files) has reached a complexity
threshold where the lack of types, module boundaries, and a clean provider abstraction
creates significant friction for extending the system. Adding a new AI provider currently
requires modifying a dozen scattered `case` statements throughout `agent-lib.sh` and
`agent-duo`. Four feature tasks — Gemini provider (gh-agent-duo-40), Cursor provider
(gh-agent-duo-48), post-merge pull (gh-agent-duo-49), and ttyd links in notifications
(gh-agent-duo-39) — are blocked on the provider interface that only exists after this
rewrite.

TypeScript/Bun is already in use by the `ludics` orchestrator in the same toolchain
environment, providing a directly applicable architectural reference. The `bun build
--compile` workflow produces zero-dependency single-file native binaries with fast startup,
matching or exceeding Bash's cold-start performance.

See: https://github.com/lukstafi/agent-duo/issues/50

## Current State

The shared library and four entry-point scripts together form the agent-duo system:

- `agent-lib.sh` (4,256 lines) — shared library covering session discovery, provider
  dispatch, port allocation, skill installation, status protocol, notifications, tmux/ttyd
  helpers, PR/git helpers, workflow feedback.
- `agent-duo` (5,836 lines) — duo-mode entry point; commands: `start`, `run`, `stop`,
  `restart`, `status`, `cleanup`, `setup`, `doctor`, `config`, `nudge`, `interrupt`,
  `signal`, `escalate-resolve`, `feedback`, `pr`, `merge`, `run-merge`, `confirm`.
- `agent-pair` (3,483 lines) — pair-mode entry point; mirrors agent-duo for
  coder/reviewer sessions.
- `agent-launch` (773 lines) — shared launcher for `agent-claude` / `agent-codex`
  standalone entry points.

Session state lives in `.peer-sync/` directories (one per active session root worktree).
The files use plain-text and `key=value` formats that are directly sourced by Bash.
Provider-specific behavior is currently implemented as inline `case $AGENT` blocks
scattered across all four files.

The `ludics` project at `~/ludics/` already demonstrates the target stack:
- `src/adapters/types.ts` — `Adapter` interface pattern
- `src/adapters/tmux.ts` — `Bun.spawnSync`-based tmux wrappers
- `src/adapters/base.ts` — atomic key=value file I/O, git helpers
- `src/adapters/peer-sync.ts` — `.peer-sync` and `.agent-sessions` reader
- `package.json` — `bun build --compile` build script
- `tsconfig.json` — ES2022, bundler module resolution

## Proposed Change

Replace the four Bash files with TypeScript/Bun modules compiled to native binaries,
preserving all external contracts (CLI interface, `.peer-sync` on-disk format, worktree
naming, skill invocation protocol, completion hooks).

**Core contract: the `.peer-sync` on-disk format must be byte-compatible.** Sessions
started under the Bash implementation must be resumable under the TypeScript
implementation without any migration step.

### Provider interface

Define a `Provider` interface in `src/lib/provider.ts` that isolates all agent-specific
behavior. Adding a new provider (Gemini, Cursor, or any future CLI agent) requires only
implementing this interface and registering the new class — no modifications to
orchestrator code.

```typescript
export interface Provider {
  readonly name: string;  // "claude" | "codex" | "gemini" | "cursor"
  getCmd(opts?: { model?: string; flags?: string; thinking?: string }): string;
  triggerSkill(session: string, skill: string): void;
  getResumeKey(session: string): string | null;
  attemptResume(session: string, peer_sync: string): boolean;
  resumeTui(session: string, opts?: { thinking?: string; displayName?: string }): void;
  installSkills(worktreePath: string, templatesDir: string, mode: "duo" | "pair"): void;
  configureHooks?(worktreePath: string, peer_sync: string, agentName: string): void;
}
```

Concrete implementations: `ClaudeProvider` in `src/providers/claude.ts`,
`CodexProvider` in `src/providers/codex.ts`. A `ProviderRegistry` maps agent-type
strings to provider instances; `cmdStart` looks up providers by the `--agent1` /
`--agent2` flags and writes chosen agent names to `.peer-sync/agents`.

### Module decomposition

`agent-lib.sh` logic splits into typed, independently testable modules:

| Source region | Target module |
|---|---|
| Session/project discovery (lines 52–498) | `src/lib/session.ts` |
| Agent commands / provider dispatch (lines 640–765) | `src/lib/provider.ts`, `src/providers/` |
| Port management (lines 766–847) | `src/lib/ports.ts` |
| tmux/ttyd helpers (lines 848–1151) | `src/lib/tmux.ts`, `src/lib/ttyd.ts` |
| Status protocol (lines 1152–1460) | `src/lib/status.ts` |
| Skill installation (lines 2484–2706) | `src/lib/skills.ts` |
| Notifications (lines 1865–2483) | `src/lib/notify.ts` |
| PR creation / workflow (lines 3461–4035) | `src/lib/pr.ts`, `src/lib/workflow.ts` |
| Resume logic | `src/providers/claude.ts`, `src/providers/codex.ts` |
| Config file reader | `src/lib/config.ts` |
| Git helpers | `src/lib/git.ts` |
| `.peer-sync` atomic reads/writes | `src/lib/peer-sync.ts` |

Entry points compile to single binaries:
- `src/duo.ts` → `dist/agent-duo`
- `src/pair.ts` → `dist/agent-pair`
- `src/launch.ts` → `dist/agent-launch` (with `agent-claude` / `agent-codex` symlinks)

Shell-based tests (`tests/unit.t`, `tests/integration.t`) are ported to the Bun test
runner (`tests/unit.test.ts`, `tests/integration.test.ts`).

### Acceptance criteria

- All CLI commands (`start`, `run`, `stop`, `restart`, `status`, `cleanup`, `setup`,
  `doctor`, `config`, `nudge`, `interrupt`, `signal`, `peer-status`, `phase`,
  `escalate-resolve`, `feedback`, `pr`, `merge`, `run-merge`, `confirm`) behave
  identically to the Bash implementation.
- `.peer-sync` on-disk format is unchanged; existing Bash-started sessions are resumable.
- Worktree naming (`${project}-${feature}`, `${project}-${feature}-${agent}`) unchanged.
- Skill installation and `{{SKILL_CMD}}` placeholder substitution work per provider.
- `agent-duo signal` completion hook mechanism unchanged.
- Port allocation, ttyd lifecycle, tmux session management all work correctly.
- Binary compilation: `bun build --compile src/duo.ts --outfile dist/agent-duo` (and
  equivalents for pair, launch).
- Full test suite passes.
- No performance regression in the orchestrator poll loop.

### Out of scope

- `skills/templates/*.md` files — remain as Markdown, copied/transformed at session start.
- Gemini provider TOML wrapping — belongs to gh-agent-duo-40.
- Cursor `.cursor/commands/` installation — belongs to gh-agent-duo-48.
- Any change to the `.peer-sync` on-disk format.

## Scope

**In scope:**
- Full replacement of `agent-lib.sh`, `agent-duo`, `agent-pair`, `agent-launch` with
  TypeScript/Bun modules and compiled binaries.
- `Provider` interface and `ClaudeProvider` / `CodexProvider` implementations.
- All library modules (`session`, `ports`, `tmux`, `ttyd`, `peer-sync`, `status`,
  `skills`, `notify`, `pr`, `workflow`, `git`, `config`).
- Test suite port to Bun test runner.
- `agent-duo setup` / `agent-duo doctor` fully functional.
- `buildTtydUrls` / `getTtydHostname` in `src/lib/notify.ts` (unblocks gh-agent-duo-39).
- `syncMainAfterMerge` in `src/lib/git.ts` (unblocks gh-agent-duo-49).

**Dependencies:**
- Blocks gh-agent-duo-40 (Gemini provider — requires `Provider` interface to exist).
- Blocks gh-agent-duo-48 (Cursor provider — same requirement).
- Blocks gh-agent-duo-49 (post-merge pull — `syncMainAfterMerge` hook site).
- Blocks gh-agent-duo-39 (ttyd links — `buildTtydUrls` hook site).

**Architectural reference:** `~/ludics/src/adapters/` for tmux wrappers, peer-sync
reader, atomic file I/O patterns, and `bun build --compile` build configuration.
