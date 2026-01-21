#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./orchestrate.sh [--rounds N] [--work-timeout S] [--review-timeout S]

Protocol:
  - Sets phase to work/review.
  - Expects each agent to call: ./agent-duo signal <agent> <phase> done "..."
  - Generates snapshots for peer review in .peer-sync/rounds/<round>/.
USAGE
}

die() { echo "orchestrate: $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

need_cmd git

rounds=3
work_timeout=1800
review_timeout=900

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rounds) rounds="$2"; shift 2;;
    --work-timeout) work_timeout="$2"; shift 2;;
    --review-timeout) review_timeout="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

./agent-duo status >/dev/null 2>&1 || die "run ./agent-duo init first"

sync_dir="$(./agent-duo paths | awk -F': ' '/^sync:/{print $2}' | head -n1)"
[[ -d "$sync_dir" ]] || die "missing sync dir: $sync_dir"

log_file="$sync_dir/orchestrate.log"
log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$log_file" >&2
}

now() { date +%s; }

set_phase() { printf '%s\n' "$1" >"$sync_dir/phase"; }
set_round() { printf '%s\n' "$1" >"$sync_dir/round"; }

write_pending() {
  local phase="$1"
  ./agent-duo signal claude "$phase" pending "waiting"
  ./agent-duo signal codex "$phase" pending "waiting"
}

read_state() {
  local agent="$1" line
  line="$(cat "$sync_dir/${agent}.status" 2>/dev/null || true)"
  [[ -n "$line" ]] || { echo "missing"; return; }
  echo "$line" | awk -F'|' '{print $1 "|" $2}'
}

is_done_for_phase() {
  local agent="$1" want_phase="$2" cur
  cur="$(read_state "$agent")"
  [[ "$cur" == "${want_phase}|done" ]]
}

wait_phase() {
  local phase="$1" timeout="$2" start
  start="$(now)"
  while true; do
    local c s
    c="$(read_state claude)"
    s="$(read_state codex)"
    if is_done_for_phase claude "$phase" && is_done_for_phase codex "$phase"; then
      return 0
    fi
    if (( $(now) - start > timeout )); then
      echo "orchestrate: timeout waiting for $phase" >&2
      is_done_for_phase claude "$phase" || ./agent-duo signal claude "$phase" timeout "timed out"
      is_done_for_phase codex "$phase" || ./agent-duo signal codex "$phase" timeout "timed out"
      return 0
    fi
    sleep 2
  done
}

log "starting ($rounds rounds)"

for ((r=1; r<=rounds; r++)); do
  log "round $r work"
  set_round "$r"
  set_phase work
  write_pending work
  wait_phase work "$work_timeout"

  log "round $r snapshot"
  ./agent-duo snapshot claude --round "$r" || true
  ./agent-duo snapshot codex --round "$r" || true

  log "round $r review"
  set_phase review
  write_pending review
  wait_phase review "$review_timeout"
done

log "complete"
