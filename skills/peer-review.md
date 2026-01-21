# Peer Review Skill

Quick guide for reviewing your peer's work during an Agent Duo session.

## Quick Start

1. **Find peer's snapshot**: `cat .peer-sync/rounds/N/<peer>-snapshot.txt`
2. **Understand their approach**: What pattern/architecture are they using?
3. **Write review**: Save to `.peer-sync/rounds/N/<peer>-review.md`
4. **Signal done**: `../agent-duo signal <you> READY "reviewed peer"`

## Review Template

```markdown
# Review of {Peer}'s Work - Round {N}

## Approach Summary
Brief description of peer's implementation approach.

## Strengths
- What's working well
- Good design decisions
- Clean code patterns

## Concerns
- Potential bugs
- Edge cases not handled
- Performance issues

## Suggestions
- Specific improvements
- Alternative patterns to consider

## Divergence Notes
How is this different from my approach?
```

## Reading Peer's Code

```bash
# Read snapshot (includes git status, diffs, untracked files)
cat .peer-sync/rounds/1/codex-snapshot.txt

# Read just the patch
cat .peer-sync/rounds/1/codex.patch

# Read directly from peer's worktree
PEER=$(cat .peer-sync/codex.path)
cat "$PEER/src/main.js"
```

## Review Principles

- **Be constructive** - suggest improvements, don't just criticize
- **Maintain divergence** - don't push peer toward your approach
- **Be specific** - reference files and line numbers
- **Acknowledge good work** - note what's working well

## After Review

```bash
# Save your review
# (write to .peer-sync/rounds/N/<peer>-review.md)

# Signal completion
../agent-duo signal claude READY "reviewed codex"
# or
../agent-duo signal codex READY "reviewed claude"
```
