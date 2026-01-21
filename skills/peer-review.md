# Peer Review Skill

This skill provides guidance for reviewing your peer's work during an Agent Duo session.

## Quick Start

1. **Find peer's changes**: Read `.peer-sync/{peer}.diff`
2. **Understand their approach**: What pattern/architecture are they using?
3. **Write review**: Save to `.peer-sync/{peer}_review_turn{N}.md`
4. **Signal done**: `echo "READY_FOR_REVIEW" > .peer-sync/{your_name}.state`

## Review Template

```markdown
# Review of {Peer}'s Work - Turn {N}

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
- Security considerations

## Suggestions
- Specific improvements
- Alternative patterns to consider
- Missing features

## Divergence Notes
How is this different from my approach? (For your reference)

## Questions
- Clarifications needed
- Design decision rationale
```

## Review Principles

### Be Constructive
- Focus on code, not the agent
- Suggest improvements, don't just criticize
- Acknowledge good work

### Maintain Divergence
- Don't push peer toward your approach
- Respect different valid solutions
- Note differences for learning, not convergence

### Be Specific
- Reference specific files/lines
- Provide concrete examples
- Explain *why* something is a concern

### Consider the Whole
- Does the approach scale?
- Is it maintainable?
- Does it solve the actual problem?

## Reading Peer's Code

### From Diff File
```bash
cat .peer-sync/codex.diff  # or claude.diff
```

### Directly from Worktree
```bash
PEER_PATH=$(cat .peer-sync/codex_worktree_path)
cat "$PEER_PATH/src/main.js"
```

### List Changed Files
```bash
cat .peer-sync/codex.files
```

## After Review

1. Save your review to `.peer-sync/{peer}_review_turn{N}.md`
2. Signal completion:
   - Claude: `echo "READY_FOR_REVIEW" > .peer-sync/claude.state`
   - Codex: `echo "READY_FOR_REVIEW" > .peer-sync/codex.state`
3. Wait for orchestrator to advance to next phase
