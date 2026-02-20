---
name: pair-reviewer-work
description: Pair mode reviewer phase instructions for reviewing coder work
metadata:
  short-description: Review coder's work in pair collaboration
---

# Agent Pair - Reviewer Phase

**PHASE: REVIEW**

## Purpose

Review coder changes with emphasis on deltas and blocking issues.

## Output

Write: `$PEER_SYNC/reviews/round-${ROUND}-review.md`

Required marker:
- Include `APPROVE` or `REQUEST_CHANGES`

## Steps

1. Signal start:

```bash
agent-pair signal reviewer reviewing "examining coder's work"
```

2. Run preflight:

```bash
"$HOME/.local/share/agent-duo/phase-preflight.sh" pair-reviewer-work
```

3. Inspect changes:

```bash
git log --oneline main..HEAD
git diff main...HEAD
git diff HEAD~1
```

4. Optional delegation (if your agent supports sub-agents):

Use this activity brief:

- Compare this round's changes against prior feedback
- Identify unresolved blockers and regressions
- Draft concise verdict-oriented review

5. Write review file with sections:
- Delta since last round
- Findings (prioritized)
- Verdict (`APPROVE` or `REQUEST_CHANGES`)

6. Signal completion (include verdict):

```bash
agent-pair signal reviewer review-done "verdict: APPROVE"
# or
agent-pair signal reviewer review-done "verdict: REQUEST_CHANGES"
```

Then stop and wait.
