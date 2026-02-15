---
name: solo-update-docs
description: Agent-solo update-docs phase instructions for capturing learnings
metadata:
  short-description: Capture project and workflow learnings before PR
---

# Agent Solo - Update Docs Phase

**PHASE CHANGE: You are now in the UPDATE-DOCS phase, not work or review.**

Stop implementation work. Your task is to capture what you learned for future agents and the agent-solo workflow.

## 1) Project learnings (AGENTS_STAGING.md)

Append a short entry to `AGENTS_STAGING.md` in the project root.

Guidelines:
- Focus on **undocumented conventions**, **setup requirements**, **build/test gotchas**, or **doc/code mismatches**
- Avoid feature-specific implementation details or subjective opinions

Suggested commands:

```bash
DATE=$(date +%F)
STAGING="AGENTS_STAGING.md"

# Create the staging file if it doesn't exist
if [ ! -f "$STAGING" ]; then
  cat > "$STAGING" << STAGING_EOF
# Agent Learnings (Staging)

This file collects agent-discovered learnings for later curation into CLAUDE.md / AGENTS.md.

STAGING_EOF
fi

cat >> "$STAGING" << ENTRY_EOF
<!-- Entry: ${FEATURE}-${MY_NAME} | ${DATE} -->
### [Short title]

[What should future agents know? Keep it concise and actionable.]

<!-- End entry -->
ENTRY_EOF
```

Edit the new entry to replace the placeholder text with your actual learnings.

## 2) Workflow feedback (agent-solo)

Write workflow feedback to the sync directory so it can be collected later:

```bash
DATE=$(date +%F)
FEEDBACK_FILE="$PEER_SYNC/workflow-feedback-${MY_NAME}.md"

cat > "$FEEDBACK_FILE" << FEEDBACK_EOF
# Workflow feedback (${MY_NAME}) - ${FEATURE} - ${DATE}

- [Actionable feedback about agent-solo workflow/skills/tooling]
- [Another specific, actionable point]
FEEDBACK_EOF
```

Keep feedback actionable (avoid generic complaints). Include missing commands, unclear instructions, or friction points.

## 3) Signal completion

```bash
agent-solo signal "$MY_NAME" docs-update-done "learnings captured"
```

The orchestrator will handle PR creation after docs are updated.
