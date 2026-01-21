#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./start.sh [--base <ref>] [--tmux] [--ttyd]

Options:
  --ttyd          Launch two ttyd servers (localhost).
  --claude-port   ttyd port for Claude (default 7681)
  --codex-port    ttyd port for Codex  (default 7682)

Creates worktrees and optionally opens a tmux session.
USAGE
}

die() { echo "start: $*" >&2; exit 1; }

base=""
use_tmux="0"
use_ttyd="0"
claude_port=7681
codex_port=7682

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2;;
    --tmux) use_tmux="1"; shift;;
    --ttyd) use_ttyd="1"; shift;;
    --claude-port) claude_port="$2"; shift 2;;
    --codex-port) codex_port="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

if [[ -n "$base" ]]; then
  ./agent-duo init --base "$base"
else
  ./agent-duo init
fi

cat <<'EOF'

To orchestrate rounds:
  ./orchestrate.sh

Agent terminals:
  cd .worktrees/claude   # or codex
  # work, then signal:
  ./agent-duo signal claude work done "finished work"
EOF

if [[ "$use_tmux" != "1" && "$use_ttyd" != "1" ]]; then
  exit 0
fi

if [[ "$use_tmux" == "1" ]]; then
  command -v tmux >/dev/null 2>&1 || die "tmux not installed (omit --tmux)"

session="agent-duo"

tmux has-session -t "$session" 2>/dev/null && die "tmux session already exists: $session"

tmux new-session -d -s "$session" -n orchestrator "./orchestrate.sh"
tmux new-window -t "$session" -n claude "cd .worktrees/claude && bash"
tmux new-window -t "$session" -n codex "cd .worktrees/codex && bash"

tmux select-window -t "$session":0
tmux attach -t "$session"
fi

if [[ "$use_ttyd" == "1" ]]; then
  command -v ttyd >/dev/null 2>&1 || die "ttyd not installed (omit --ttyd)"

  sync_dir="$(pwd)/.peer-sync"
  mkdir -p "$sync_dir/pids"

  echo "start: launching ttyd on ports $claude_port and $codex_port" >&2

  ttyd -p "$claude_port" -i 127.0.0.1 bash -lc "cd .worktrees/claude && exec bash" \
    >/dev/null 2>&1 &
  echo $! >"$sync_dir/pids/ttyd-claude.pid"

  ttyd -p "$codex_port" -i 127.0.0.1 bash -lc "cd .worktrees/codex && exec bash" \
    >/dev/null 2>&1 &
  echo $! >"$sync_dir/pids/ttyd-codex.pid"

  cat <<EOF

ttyd running:
- Claude: http://127.0.0.1:${claude_port}
- Codex:  http://127.0.0.1:${codex_port}

Stop with:
  ./stop.sh
EOF
fi
