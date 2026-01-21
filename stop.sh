#!/usr/bin/env bash
set -euo pipefail

die() { echo "stop: $*" >&2; exit 1; }

sync_dir="$(pwd)/.peer-sync"
pids_dir="$sync_dir/pids"

[[ -d "$pids_dir" ]] || die "no pid dir at $pids_dir"

stopped=0
for pidfile in "$pids_dir"/*.pid; do
  [[ -f "$pidfile" ]] || continue
  pid="$(cat "$pidfile" || true)"
  [[ -n "$pid" ]] || continue

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "stop: killing $pid ($(basename "$pidfile"))" >&2
    kill "$pid" >/dev/null 2>&1 || true
    stopped=$((stopped + 1))
  fi
  rm -f "$pidfile" || true
done

echo "stop: done (stopped $stopped processes)" >&2

