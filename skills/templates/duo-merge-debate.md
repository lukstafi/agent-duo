---
name: duo-merge-debate
description: Agent-duo merge phase - debate when votes disagree
metadata:
  short-description: Review peer's vote and revise or defend position
---

# Agent Duo - Merge Debate Phase

**PHASE: MERGE DEBATE** - Your vote differs from your peer's. Review their reasoning and respond.

## Your Environment

- **Working directory**: Main branch
- **Sync directory**: `$PEER_SYNC`
- **Your name**: `$MY_NAME`
- **Peer's name**: `$PEER_NAME`
- **Debate round**: Check `$PEER_SYNC/merge-round`

## Context

You and your peer voted for different PRs. This debate phase allows you to:
1. Understand your peer's reasoning
2. Reconsider your position given new arguments
3. Either change your vote or defend your original choice

## Your Task

### 1. Read Your Peer's Vote

```bash
cat "$PEER_SYNC/merge-vote-${PEER_NAME}.md"
```

### 2. Read Your Previous Vote

```bash
cat "$PEER_SYNC/merge-vote-${MY_NAME}.md"
```

### 3. Consider the Arguments

Think carefully:
- Did your peer identify strengths you missed?
- Did they raise valid concerns about your choice?
- Are their cherry-pick suggestions valuable regardless of which PR wins?

### 4. Write Your Debate Response

Overwrite your vote file with your updated position:

```bash
cat > "$PEER_SYNC/merge-vote-${MY_NAME}.md" << 'EOF'
# Merge Vote from [MY_NAME] (Debate Round [N])

## Response to [PEER_NAME]'s Arguments

[Address their key points. What do you agree with? What do you disagree with and why?]

## My Vote: [claude / codex]

### Position: [CHANGED / UNCHANGED]

### Rationale

[If changed: Explain what convinced you to switch]
[If unchanged: Explain why peer's arguments don't outweigh your original reasoning]

### Features to Cherry-Pick from Losing PR

[Updated list based on both analyses - include valuable features mentioned by either side]

EOF
```

Edit the file with actual content.

### 5. Signal Completion

```bash
agent-duo signal "$MY_NAME" debate-done "debate response submitted"
```

Then **STOP and wait**. The orchestrator will check for consensus or continue to the next debate round (max 2 rounds).

## Guidelines

- **Be open-minded**: The goal is to find the best solution, not to "win"
- **Engage with arguments**: Don't just repeat yourself - respond to peer's points
- **Synthesize**: Sometimes the answer is "merge A, but definitely cherry-pick X and Y from B"
- **Agree to disagree**: After 2 rounds, if you still disagree, the user will decide
