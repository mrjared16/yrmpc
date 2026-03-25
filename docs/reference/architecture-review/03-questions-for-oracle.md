# Questions for Architecture Critique

## Primary Question
Between Design A (Pipeline Stages) and Design B (Resource Pool + Orchestrator), which better fits:
1. Streaming music app requirements
2. The stated design philosophy (loosely coupled, community extensible, configurable)

## Specific Concerns

### 1. Future Change Scenarios
How well does each design handle:
- Adding a new extraction backend (e.g., proxy server)
- Adding a new audio storage backend (e.g., S3, memory-only)
- Changing rate limiting strategy
- Adding new cross-cutting concerns (e.g., metrics, tracing)
- Supporting a completely different music backend (e.g., Spotify, local files)

### 2. Loose Coupling
- Does the design naturally enforce loose coupling, or require discipline?
- Can community members extend without understanding internals?
- Are the extension points obvious and well-defined?

### 3. Reusability Across Backends
- Could this pattern work for a Spotify backend? Local file backend?
- What would need to change vs stay the same?
- Is there unnecessary coupling to YouTube specifics?

### 4. Complexity Budget
- Is either design over-engineered for a TUI music client?
- What's the minimum viable architecture that still meets the philosophy?
- Where is complexity justified vs accidental?

### 5. The "One More Time" Test
- If requirements change significantly, would we need to redo architecture?
- Which design is more resilient to unforeseen changes?

## Anti-Patterns to Watch For
- God objects (does Orchestrator become one?)
- Leaky abstractions (do internal details leak?)
- Premature generalization (are we solving problems we don't have?)
- Framework syndrome (are we building a framework instead of an app?)
