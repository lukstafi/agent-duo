# Agent Learnings (Staging)

This file collects agent-discovered learnings for later curation into CLAUDE.md / AGENTS.md.

<!-- Entry: gh-agent-duo-25-coder | 2026-03-01T22:55:54+0100 -->
### Session-scoped agent flags convention

When adding new agent launch options, persist them in .peer-sync and have get_agent_cmd read from session state via PEER_SYNC. This keeps behavior consistent across start, restart, tmux/ttyd modes, and merge-phase relaunches.

<!-- End entry -->
