# Agent Learnings (Staging)

This file collects agent-discovered learnings for later curation into CLAUDE.md / AGENTS.md.

<!-- Entry: gh-agent-duo-25-coder | 2026-03-01T22:55:54+0100 -->
### Session-scoped agent flags convention

When adding new agent launch options, persist them in .peer-sync and have get_agent_cmd read from session state via PEER_SYNC. This keeps behavior consistent across start, restart, tmux/ttyd modes, and merge-phase relaunches.

<!-- End entry -->
<!-- Entry: post-merge-sync-main-coder | 2026-03-06T14:03:45+0100 -->
### Final-merge behavior is template-driven

Post-merge automation is split between `agent-lib.sh` helpers and the markdown templates under `skills/templates/`. When changing merge behavior, update both the shared helper and the relevant final-merge template, then add a unit test that asserts the template still invokes the helper so the workflow does not silently drift.

<!-- End entry -->
