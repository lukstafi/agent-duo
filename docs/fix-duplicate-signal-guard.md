# Proposal: Duplicate Signal Guard (gh-agent-duo-44)

## Summary

Follow-up prompts (orchestrator nudges, user heartbeats, skill re-invocations) can cause agents to call `signal done` multiple times in the same round. This proposal adds a lightweight guard to both signal entry points (`lib_cmd_signal()` in `agent-lib.sh` and the standalone `cmd_signal()` in `agent-duo`) that reads the current status file before writing and skips the re-signal when the status already matches. It also updates the two work-phase skill templates with pre-signal guidance.

## Current Behavior

### Signal entry points

There are two separate signal implementations:

1. **`lib_cmd_signal()`** (`agent-lib.sh:1756-1781`) -- used by `agent-pair` (via `agent-pair:3169-3171` where `cmd_signal()` delegates to `lib_cmd_signal`). This function validates the status, writes the status file with `atomic_write`, appends an `agent_signal` event to `events.jsonl`, and prints a success message.

2. **`cmd_signal()`** (`agent-duo:3334-3359`) -- a standalone copy used by `agent-duo`. It performs the same validation and `atomic_write`, but does **not** call `append_event`. This is a pre-existing divergence.

Both functions unconditionally overwrite the status file on every call, regardless of whether the current value already matches.

### Status file format

The status file at `.peer-sync/<agent>.status` contains a pipe-delimited string:

```
status|epoch|message
```

For example: `done|1709400123|implemented feature X`.

### Round lifecycle

At the start of each work round, the orchestrator explicitly resets each agent's status to `working`:

- **duo mode**: `agent-duo:4668,4675,4685,4697` -- writes `working|<epoch>|round N work phase`
- **pair mode**: `agent-pair:2523` -- writes `working|<epoch>|round N work phase`

This means a stale `done` from a previous round is always cleared before the agent begins work, so a simple same-value check is sufficient for deduplication.

### Notification hook (advisory layer)

The notification hook at `agent-lib.sh:2862-2865` already guards against re-nudging once the agent has reached `done`:

```bash
case "$current_status" in
    done|review-done|pr-created) log_debug "skipping (already $current_status)"; exit 0 ;;
esac
```

However, this only prevents the *hook* from issuing duplicate advice. It does not prevent an agent from calling `signal done` again on its own.

### Impact of duplicate signals

- **Event log pollution**: `append_event` (in `lib_cmd_signal`) writes a redundant `agent_signal` entry to `events.jsonl`
- **Timestamp corruption**: The epoch in the status file gets reset to the second signal's time, making round-timing analysis inaccurate
- **Peer confusion**: Other agents reading peer status see a "fresh" done signal and may misinterpret recency

## Proposed Changes

### 1. Add duplicate-signal guard to `lib_cmd_signal()` (agent-lib.sh)

Insert after the `case` validation (after line 1771) and before the `atomic_write` (line 1773):

```bash
    # Guard: skip re-signaling terminal statuses that are already set
    local current_status_val=""
    if [ -f "$peer_sync/${agent}.status" ]; then
        current_status_val="$(cut -d'|' -f1 < "$peer_sync/${agent}.status" 2>/dev/null)" || current_status_val=""
    fi
    case "$status" in
        done|review-done|docs-update-done|integrate-done|final-merge-done|suggest-refactor-done|pr-created|clarify-done|pushback-done|plan-done|plan-review-done|vote-done|debate-done|merge-done|merge-review-done)
            if [ "$current_status_val" = "$status" ]; then
                warn "Already signaled $status for $agent. Skipping re-signal."
                return 0
            fi
            ;;
    esac
```

**Design rationale:**
- The guard covers all `*-done` terminal statuses plus `pr-created`, not just `done`. This protects every phase transition against duplicate signals.
- It only blocks exact same-value re-signals. Legitimate forward transitions (e.g., `done` -> `review-done` -> `pr-created`) are unaffected.
- No epoch comparison is needed because the orchestrator always resets to `working` at round start.
- The early `return 0` skips both `atomic_write` and `append_event`, preventing both file corruption and event log pollution.

### 2. Add same guard to `cmd_signal()` (agent-duo:3334)

Insert the identical guard block after the validation `case` (after line 3349) and before `atomic_write` (line 3352-3353):

```bash
    # Guard: skip re-signaling terminal statuses that are already set
    local current_status_val=""
    if [ -f "$peer_sync/${agent}.status" ]; then
        current_status_val="$(cut -d'|' -f1 < "$peer_sync/${agent}.status" 2>/dev/null)" || current_status_val=""
    fi
    case "$status" in
        done|review-done|docs-update-done|integrate-done|final-merge-done|suggest-refactor-done|pr-created|clarify-done|pushback-done|plan-done|plan-review-done|vote-done|debate-done|merge-done|merge-review-done)
            if [ "$current_status_val" = "$status" ]; then
                warn "Already signaled $status for $agent. Skipping re-signal."
                return 0
            fi
            ;;
    esac
```

**Note on code duplication**: The `agent-duo` file has its own `cmd_signal()` that is a near-copy of `lib_cmd_signal()` but omits `append_event`. Ideally this would be refactored to call `lib_cmd_signal()` (as `agent-pair` already does), but that refactoring is out of scope for this issue.

### 3. Update work-phase skill templates

**`skills/templates/pair-coder-work.md`** -- add a note before the Signal section's code block (before line 50):

```markdown
> **Note:** If you have already signaled `done` in this round (e.g., from a previous prompt), the signal command will skip the duplicate automatically. You do not need to re-signal.
```

**`skills/templates/duo-work.md`** -- add a note before the Signal section's code block (before line 57):

```markdown
> **Note:** If you have already signaled `done` in this round (e.g., from a previous prompt), the signal command will skip the duplicate automatically. You do not need to re-signal.
```

This is simpler than asking agents to manually check peer status before signaling. The guard in the command itself is the true protection; the template note is informational to reduce unnecessary signal attempts.

### 4. (Deferred) `--force` flag

A `--force` flag to bypass the guard is not included in this proposal. If a future need arises for legitimate re-signaling with a different message (without changing status), it can be added as a follow-up. The current guard uses exact status match, so changing to a different terminal status (e.g., `done` -> `pr-created`) is already permitted.

## Testing Strategy

### Unit test additions (`tests/unit.t` or new test file)

1. **First signal succeeds**: Signal `done` when status is `working` -> status file updated, exit code 0, success message printed.

2. **Duplicate signal skipped**: Signal `done` when status is already `done` -> status file NOT updated (timestamp unchanged), exit code 0, warning message printed containing "Already signaled".

3. **Different terminal status allowed**: Signal `review-done` when status is `done` -> status file updated to `review-done`.

4. **Non-terminal status always writes**: Signal `working` when status is already `working` -> status file updated (non-terminal statuses are not guarded).

5. **Guard works after orchestrator reset**: Signal `done`, then reset to `working`, then signal `done` again -> second `done` signal succeeds (simulating a new round).

### Integration test additions (`tests/integration.t`)

6. **End-to-end duplicate signal**: Within an active session, signal `done` twice in sequence. Verify the second call prints the warning and the events.jsonl has only one `agent_signal` entry for `done`.

### Manual testing

7. Run a duo session, let the agent signal `done`, then send a "Continue." heartbeat. Verify the agent does not produce a second `done` signal (or if it tries, the command-level guard catches it).

### Regression checks

8. Confirm existing integration tests still pass (signal working, signal done, invalid status rejection).

9. Verify that the notification hook dedup logic (agent-lib.sh:2862-2865, 2980-2983) is untouched and still functions.

## Acceptance Criteria

- [ ] `lib_cmd_signal()` (agent-lib.sh) includes the duplicate-signal guard for all terminal statuses
- [ ] `cmd_signal()` (agent-duo) includes the same guard
- [ ] When a duplicate terminal signal is detected, a warning is printed and the write is skipped
- [ ] No `agent_signal` event is appended to `events.jsonl` for skipped signals
- [ ] The status file epoch is preserved (not reset) when a duplicate is skipped
- [ ] Work-phase skill templates (`pair-coder-work.md`, `duo-work.md`) include an informational note about automatic dedup
- [ ] No regression in first-time signaling, phase transitions, or orchestrator wait loops
- [ ] Existing notification hook dedup logic remains unchanged
- [ ] All existing tests pass; new tests validate the guard behavior

## Files Modified

| File | Change |
|------|--------|
| `agent-lib.sh` (~line 1771) | Add ~10-line guard in `lib_cmd_signal()` |
| `agent-duo` (~line 3349) | Add same ~10-line guard in `cmd_signal()` |
| `skills/templates/pair-coder-work.md` (~line 49) | Add informational note about automatic dedup |
| `skills/templates/duo-work.md` (~line 56) | Add informational note about automatic dedup |
| `tests/integration.t` or `tests/unit.t` | Add duplicate-signal test cases |
