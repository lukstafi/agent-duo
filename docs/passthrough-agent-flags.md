# Passthrough Agent Flags (--claude-flags, --codex-flags)

## Motivation

`agent-duo` and `agent-pair` hard-code which upstream CLI options they expose. Adding
`--codex-thinking` required a repo change. Adding `--codex-model` required another. Every
time the `claude` or `codex` CLI gains a useful option (`--allowedTools`, `--max-turns`,
`--provider`, etc.), agent-duo needs its own matching flag.

A generic passthrough eliminates this cycle: users pass arbitrary flags as a single quoted
string, and agent-duo forwards them verbatim to the agent launch command.

See: https://github.com/lukstafi/agent-duo/issues/25

## Current State

`get_agent_cmd()` in `agent-lib.sh` (line 694) constructs agent launch commands:

```
claude --dangerously-skip-permissions [--model M] [extra_args]
codex --yolo -c model_reasoning_effort=... [-m M] [extra_args]
```

The `extra_args` parameter exists but is only used internally (e.g., by `restart_agent_tui`).
No CLI path exposes it to users.

Model overrides (`--codex-model`, `--claude-model`) are exported as environment variables
during `cmd_start` but **not persisted to `.peer-sync/`**, so they're lost on restart.

## Proposed Change

### New CLI options

Both `agent-duo start` and `agent-pair start` accept:

```bash
agent-duo start feature-x \
  --claude-flags "--allowedTools Bash,Read,Write" \
  --codex-flags "--some-new-flag value"
```

Each flag takes a single quoted string. The string is stored as-is and appended to the
agent's launch command after all built-in flags.

### Persistence

Flags are written to `.peer-sync/claude-flags` and `.peer-sync/codex-flags` alongside
existing state files (`codex-thinking`, `ttyd-mode`, etc.). This means:

- `cmd_restart` automatically picks them up — no re-typing needed
- Command-line overrides at restart time replace the persisted values (same pattern as
  `--codex-thinking`)

### Precedence

Built-in flags (e.g., `--model` from `--claude-model`) appear earlier in the command.
Passthrough flags are appended last. If a passthrough flag conflicts with a built-in one,
the CLI's last-wins behavior determines the outcome. This is documented but not guarded —
users who pass both `--claude-model X` and `--claude-flags "--model Y"` get `Y`.

### Where `get_agent_cmd` reads the flags

When `$PEER_SYNC` is set (i.e., inside an active session), `get_agent_cmd` reads
`$PEER_SYNC/{agent}-flags` if the file exists and appends its contents. This keeps all
callers unchanged — no new parameters needed at call sites.

## Scope

**In scope:**
- `--claude-flags` and `--codex-flags` in both `agent-duo` and `agent-pair` (`start` + `restart`)
- Persistence to `.peer-sync/`
- `get_agent_cmd` reads from state files
- Help text with example

**Out of scope:**
- Validation of passthrough flag syntax (user's responsibility)
- Migrating `--codex-model` / `--claude-model` to use the same mechanism (nice-to-have follow-up)
- Per-round or per-phase flag changes (flags are session-wide)

## Edge Cases

- **Quoting**: Flags with spaces (`"--model foo --verbose"`) must survive shell parsing
  and state file round-trip. The value is stored verbatim in the state file and read back
  as a single line.
- **Empty / absent**: When not provided, the state file is absent or empty. `get_agent_cmd`
  handles this gracefully (no extra args appended).
- **Custom agents**: The `*) cmd="$agent"` fallback in `get_agent_cmd` would also benefit
  from flag passthrough for future agent types.
