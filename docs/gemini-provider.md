# Gemini CLI Provider

## Motivation

Agent-duo currently supports two providers: Claude Code (`claude`) and Codex CLI (`codex`).
Gemini CLI (`gemini`, from `@google/gemini-cli`) is an open-source AI coding agent from Google
that uses a compatible interactive-terminal model. Adding it as a third provider enables users
to pair any combination of the three agents in duo or pair mode.

GitHub issue: https://github.com/lukstafi/agent-duo/issues/40

## Current State

### Provider abstraction in `agent-lib.sh`

The shared library already has a partial abstraction for providers:

- `get_agent_cmd <agent>` (line ~728): builds the CLI command for `claude` or `codex`; unknown
  agent names fall through to `*) cmd="$agent"` — a bare passthrough with no auto-approve flag
  or model selection.
- `get_agent_passthrough_flags <agent>` (line ~699): reads `claude-flags` / `codex-flags` from
  `.peer-sync/`; unknown agent returns empty.
- `get_agent_resume_key <agent>` (line ~912): extracts UUID resume keys from tmux buffer for
  `claude` / `codex`; returns failure for unknown agents.
- `attempt_agent_resume` / `resume_agent_tui` (lines ~958, ~1047): explicit `claude` / `codex`
  cases only.
- `trigger_skill <agent>` (line ~1436): sends `/skill` for claude, `$skill` for codex; no case
  for other agents.
- `install_duo_skills_to_worktree` / `install_pair_skills_to_worktree` (lines ~2517, ~2574):
  install skills into `.claude/commands/` (Markdown) and `.agents/skills/*/SKILL.md` (Codex
  directory layout). No Gemini layout.

Model config follows the pattern `DEFAULT_<AGENT>_MODEL` / `get_<agent>_model()` / env var
`AGENT_DUO_<AGENT>_MODEL` / config key `<agent>_model=` in `~/.config/agent-duo/config`.

### Entry points

- **`agent-launch`**: symlink-dispatched launcher. `agent-claude` → `AGENT_TYPE=claude`,
  `agent-codex` → `AGENT_TYPE=codex`. The `recover_agent_tui` function has explicit
  `claude` / `codex` cases for resume commands.
- **`agent-duo`**: `start_single_session` (line ~842) hardcodes two worktrees named
  `${feature}-claude` and `${feature}-codex`, hardcodes `claude.status` / `codex.status`
  files, hardcodes `CLAUDE_PORT` / `CODEX_PORT` in `allocate_ports`, and hardcodes
  `MY_NAME=claude` / `PEER_NAME=codex` environment variables. The `start_tmux_mode` and
  `start_ttyd_mode` functions likewise use hardcoded session names like `${session}-claude`
  and `${session}-codex`.
- **`agent-pair`**: already uses role-based abstraction (`coder` / `reviewer`) with the
  underlying provider stored in `.peer-sync/coder-agent` and `.peer-sync/reviewer-agent`.
  The `--claude` and `--codex` shorthand flags set the roles. No `--gemini` shorthand yet,
  and `--gemini-model` / `--gemini-flags` options are missing.
- **`cmd_doctor`** (agent-duo line ~213): checks for `claude` and `codex` binaries only.
- **`cmd_setup`** (agent-duo line ~114): installs `agent-claude` and `agent-codex` symlinks
  only.

### Notification functions

`send_clarify_ntfy` and `send_clarify_email` (lines ~1969, ~2027) read `clarify-claude.md`
and `clarify-codex.md` from `.peer-sync/` using hardcoded names when mode is `duo`.

### Skill format differences

Gemini CLI uses TOML custom commands stored in `.gemini/commands/<name>.toml`. The required
format is:

```toml
prompt = """
<skill content here>
"""
```

An optional `description` field may be included. The file base name (without `.toml`)
becomes the slash command: `duo-work.toml` → `/duo-work`.

Currently skills are stored as plain Markdown and installed to
`.claude/commands/` (Claude) and `.agents/skills/<name>/SKILL.md` (Codex). The Gemini
installation path is `.gemini/commands/` and requires TOML wrapping.

### Git exclude

`start_single_session` excludes `.claude` and `.agents` from git (line ~1000). `.gemini`
is not yet excluded.

## Proposed Change

### 1. Core provider additions in `agent-lib.sh`

Add Gemini as a first-class provider alongside Claude and Codex:

- Add `DEFAULT_GEMINI_MODEL=""` constant and `get_gemini_model()` function following the
  same `AGENT_DUO_GEMINI_MODEL` env var / `gemini_model=` config key / default pattern.
- In `get_agent_passthrough_flags`: add `gemini) flags_file="gemini-flags" ;;` case.
- In `get_agent_cmd`: add `gemini)` case building `gemini --yolo [-m $model]` with
  passthrough flags, before the `*) cmd="$agent"` fallback.
- In `trigger_skill`: add `gemini)` case using slash-command syntax (`/$skill` + Enter),
  same as Claude since Gemini uses the same `/skill` invocation format.
- In `get_agent_resume_key`: add `gemini)` case that returns empty / failure (Gemini has
  checkpointing but no documented UUID-based resume pattern; defer full support).
- In `attempt_agent_resume`: add `gemini)` case that returns 1 (skip, no-op).
- In `resume_agent_tui`: add `gemini)` case that falls through to fresh launch.

**Gemini skill installation helper:**

Add `install_gemini_skill <src_md> <dest_toml>` that wraps Markdown skill content into
the TOML format: reads the source `.md` file, emits `prompt = """<content>"""` to the
destination `.toml` file.

Extend `install_duo_skills_to_worktree` and `install_pair_skills_to_worktree` to accept
an optional agent list parameter (defaulting to `claude codex` for backward compatibility)
and, when `gemini` is in the list, also create `.gemini/commands/` and call
`install_gemini_skill` for each skill.

### 2. `agent-gemini` symlink and `agent-launch` dispatch

- Add `agent-gemini)` case to the `INVOKED_AS` switch in `agent-launch`:
  `AGENT_TYPE="gemini"; SESSION_PREFIX="gemini"`.
- Update the error messages for unknown invocations to include `agent-gemini`.
- Update `recover_agent_tui` in `agent-launch`: add `gemini)` case that performs a fresh
  launch (no UUID-based resume for now), same as the fallback path.
- Add `agent-gemini` symlink to source tree alongside existing `agent-claude` / `agent-codex`.
- Update `cmd_setup` in `agent-duo` to install the `agent-gemini` symlink.

### 3. Generalize `agent-duo` to support configurable agent pairs

This is the deepest change. Currently `start_single_session` assumes `claude` + `codex`.
The function signature should accept `agent1` and `agent2` parameters (defaulting to
`claude` and `codex`). All hardcoded strings derived from agent names must become dynamic:

- Worktree names: `${feature}-claude`, `${feature}-codex` → `${feature}-${agent1}`,
  `${feature}-${agent2}`.
- Status files: `claude.status`, `codex.status` → `${agent1}.status`, `${agent2}.status`.
- Environment variables set in tmux sessions: `MY_NAME`, `PEER_NAME` use the selected agents.
- Flags files written to `.peer-sync/`: `claude-flags`, `codex-flags` → `${agent1}-flags`,
  `${agent2}-flags`.
- Git exclude: add `.gemini` to the exclude list unconditionally (safe to exclude even when
  not used).
- Skill installation calls: pass the selected agent pair to `install_duo_skills_to_worktree`.

`allocate_ports` in `agent-duo` currently writes `CLAUDE_PORT` / `CODEX_PORT` to the ports
file. This should be generalized: the two agent-specific ports should be named
`AGENT1_PORT` / `AGENT2_PORT` (or `${AGENT1_UPPER}_PORT` / `${AGENT2_UPPER}_PORT`). All
consumers (`start_ttyd_mode`, `cmd_restart`, `cmd_status`) must be updated accordingly.

`start_tmux_mode` and `start_ttyd_mode` use hardcoded `${session_name}-claude` and
`${session_name}-codex` tmux session names. Parameterize to `${session_name}-${agent1}`
and `${session_name}-${agent2}`.

`send_clarify_ntfy` and `send_clarify_email`: the duo branch currently hardcodes
`clarify-claude.md` and `clarify-codex.md`. These functions should read the active
agent pair from `.peer-sync/` (e.g., from status file names or a new
`duo-agents` file written at session start) and use `clarify-${agent1}.md` /
`clarify-${agent2}.md` dynamically.

**Flag additions to `cmd_start`:**

- `--gemini-model <model>` sets the Gemini model (exports `AGENT_DUO_GEMINI_MODEL`).
- `--gemini-flags "<args>"` stores Gemini passthrough flags.
- Agent pair selection flags:
  - `--claude --gemini` sets `agent1=claude`, `agent2=gemini`.
  - `--gemini --codex` sets `agent1=gemini`, `agent2=codex`.
  - `--claude --codex` (or no agent flags) remains default behavior.

### 4. `agent-pair` additions

- Add `--gemini` shorthand: sets `coder="gemini"; reviewer="claude"` (or a similar
  sensible default; exact default TBD).
- Add `--gemini-model <model>` and `--gemini-flags "<args>"` option parsing, following
  the `--codex-model` / `--claude-model` / `--codex-flags` / `--claude-flags` pattern.
- Export `AGENT_DUO_GEMINI_MODEL` when `--gemini-model` is specified.
- Skill installation in `start_single_session_pair`: detect when `coder` or `reviewer` is
  `gemini` and include Gemini skill installation for the shared worktree.

### 5. `cmd_doctor`

Add Gemini CLI detection after the existing `claude` / `codex` checks:

```bash
if command -v gemini >/dev/null 2>&1; then
    success "gemini: found at $(command -v gemini)"
else
    warn "gemini: NOT FOUND (optional - install: npm install -g @google/gemini-cli)"
fi
```

Gemini is optional (not required for default claude+codex sessions), so a missing binary
should not set `all_ok=false`.

### 6. Tests

Extend `tests/unit.t`:
- `get_agent_cmd gemini` with and without model.
- `get_agent_passthrough_flags gemini` reads `gemini-flags` from `.peer-sync/`.
- `trigger_skill gemini` uses slash-command syntax.

Extend `tests/integration.t`:
- `agent-gemini` launch and status check (mocked binary).
- Duo start with `--claude --gemini` creates correct worktree names and status files.

### 7. Documentation

- `README.md`: document `agent-gemini` entry point, `--gemini` / `--gemini-model` /
  `--gemini-flags` flags, installation command, and note on deferred resume/notify support.
- `docs/DESIGN.md`: update provider list, naming conventions table (add Gemini row), and
  architecture diagram.
- Help text in `agent-duo`, `agent-pair`, and `agent-launch`.

## Scope

### In scope

- All acceptance criteria from the GitHub issue (see task file).
- `agent-lib.sh` provider functions: `get_agent_cmd`, `get_agent_passthrough_flags`,
  `trigger_skill`, `get_agent_resume_key`, `attempt_agent_resume`, `resume_agent_tui`.
- Gemini skill installation in TOML format via `install_gemini_skill` helper.
- `agent-gemini` symlink and `agent-launch` dispatch.
- `agent-duo` generalization: parameterized agent pair, worktree names, status files,
  port names, session names, flags files, clarify notification filenames.
- `agent-pair` `--gemini` shorthand and `--gemini-model` / `--gemini-flags` options.
- `cmd_doctor` and `cmd_setup` updates.
- Unit and integration tests for Gemini-specific code paths.
- README and DESIGN.md documentation updates.

### Out of scope (deferred)

- Gemini resume/checkpoint integration: Gemini's checkpoint mechanism differs from
  UUID-based resume. Initial implementation returns empty / skips resume logic.
  Document as known limitation.
- Gemini completion/notify hook: Claude uses Stop hooks; Codex uses notify config.
  Gemini may lack an equivalent. Defer until mechanism is documented upstream.
- `--gemini-thinking` flag: Gemini has no documented reasoning-effort flag equivalent
  to Codex's `model_reasoning_effort`. Defer.

### Dependencies

- Sibling task **gh-agent-duo-48** (Cursor CLI provider) is structurally parallel: the
  same generalization work for duo mode agent pair selection will also enable Cursor as
  a provider. Implement gh-agent-duo-40 first; gh-agent-duo-48 can reuse the patterns
  established here.
- References:
  - **gh-agent-duo-25** (completed): passthrough agent flags — the `--gemini-flags`
    option follows identical patterns.
  - **gh-agent-duo-24** (in-progress): agent-debate entry point — avoid conflicts in
    `agent-lib.sh` and entry point files; coordinate on merge ordering.
