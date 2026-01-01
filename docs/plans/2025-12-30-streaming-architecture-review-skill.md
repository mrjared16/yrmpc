# Streaming Architecture Review Skill Design

**Date**: 2025-12-30
**Status**: Implemented
**Location**: `.claude/skills/streaming-architecture-review/SKILL.md`

---

## Overview

Created a specialized Claude skill for architectural review of the yrmpc streaming music TUI application. The skill provides expert-level analysis of design patterns, SOLID principles, and music-streaming-specific concerns.

---

## Design Decisions

### Trigger Strategy
- **Reactive**: Auto-triggers when keywords like "architecture", "refactor", "SOLID", "design pattern" are detected
- **On-demand**: Explicit invocation via `/streaming-architecture-review`

### Analysis Approach
- **Mode**: Analysis + Recommendations (not auto-fix)
- **Scope**: Cross-cutting concern analysis (traces features across layers)
- **Output**: Interactive conversation with ASCII diagrams

### Domain Expertise
Comprehensive streaming music knowledge:
- Queue/playback state machines
- Content hierarchy modeling
- Caching strategies
- Real-time sync patterns (MPRIS, daemon)
- Search and discovery UX
- Performance characteristics (low-latency, memory management)

### Communication Style
- **Direct code reviewer**: Points out issues with evidence and concrete suggestions
- **ASCII diagrams**: Every architectural concept visualized
- **Feature scenarios**: Uses real yrmpc features (current and planned) to demonstrate problems
- **Interactive**: One finding at a time, waits for user feedback

---

## Key Features

### 1. Cross-Cutting Analysis
Doesn't analyze files in isolation. Instead:
- Traces data flow across layers (UI → Domain → Backend)
- Identifies coupling points between components
- Maps dependencies using symbolic tools
- Thinks in terms of features, not files

### 2. SOLID & Pattern Focus
Identifies violations of:
- **S**ingle Responsibility Principle
- **O**pen/Closed Principle
- **L**iskov Substitution Principle
- **I**nterface Segregation Principle
- **D**ependency Inversion Principle

Plus design patterns:
- Strategy, Observer, Factory, Adapter, Facade, etc.
- Domain-Driven Design principles
- Clean Architecture layering

### 3. Feature-Based Examples
For each issue, provides:
```
📊 Current Design (ASCII diagram)
❌ The Problem (SOLID/pattern violation)
🎵 Feature Scenario (concrete yrmpc feature that breaks)
✅ Better Design (ASCII diagram)
💡 Why This Helps (principle satisfaction)
📋 Trade-offs (pros/cons)
```

### 4. Efficient Code Exploration
Uses Serena's symbolic tools:
- `find_symbol` - locate components
- `find_referencing_symbols` - trace dependencies
- `get_symbols_overview` - understand structure
- Avoids reading entire files unnecessarily

---

## Example Use Cases

### Scenario 1: Adding Radio Mode
```
User: "I want to add a radio mode feature, but I'm not sure how it fits
       into the current architecture."

Skill:
1. Analyzes Navigator, ActionDispatcher, ContentView
2. Identifies tight coupling in action handling
3. Shows ASCII diagram of current vs proposed design
4. Explains how Strategy pattern would help
5. Demonstrates that radio mode would require 50+ line changes
   to Navigator with current design
6. Proposes ActionRouter pattern to make it 10 lines
```

### Scenario 2: Search Results Rendering Bug
```
User: "Search results are losing their section headers. The architecture
       feels wrong but I can't pinpoint it."

Skill:
1. Traces search flow: Backend → Domain → UI
2. Identifies layer violation in build_sections
3. Shows ASCII diagram of data transformation pipeline
4. Explains missing Adapter pattern between domain and UI
5. Provides feature scenario: "Adding playlist search breaks because..."
6. Recommends introducing SectionBuilder abstraction
```

### Scenario 3: Queue State Management
```
User: "Queue state seems to leak across components. Is this an
       architecture smell?"

Skill:
1. Maps queue state references across codebase
2. Identifies shared mutable state anti-pattern
3. Shows current coupling with ASCII diagram
4. Explains how Observer pattern would decouple
5. Demonstrates music-app-specific concern: multi-client sync
6. Proposes event-driven architecture with trade-offs
```

---

## Constraints & Guidelines

### What It Does:
✓ Deep architectural analysis across components
✓ ASCII diagrams for every concept
✓ Concrete yrmpc feature examples
✓ SOLID/pattern violation identification
✓ Interactive one-issue-at-a-time presentation
✓ Music-streaming domain expertise

### What It Doesn't Do:
✗ Write implementation code (unless explicitly requested)
✗ Analyze single files in isolation
✗ Present all findings at once
✗ Use generic examples
✗ Ignore performance implications

---

## Technical Implementation

### File Structure
```
.claude/skills/
└── streaming-architecture-review/
    └── SKILL.md
        ├── YAML Frontmatter (name, description, allowed-tools)
        ├── Core Expertise
        ├── Analysis Process
        ├── Output Format
        ├── Example Findings
        ├── Key Behaviors
        └── Success Criteria
```

### Integration
- **Trigger**: Configured in `.claude/skills/skill-rules.json` with:
  - Keywords: architecture, refactor, SOLID, design pattern, code smell, etc.
  - Intent patterns: "review.*architecture", "violat.*principle", etc.
  - Context triggers: Auto-suggest when editing Navigator, actions, or domain files
- **Tools**: Serena symbolic tools for code exploration (allowed without prompts)
- **Output**: Markdown with ASCII diagrams in conversation
- **Follow-up**: Can create refactoring plans if requested

---

## Success Metrics

The skill succeeds when:
1. User understands root architectural issue (not symptoms)
2. User sees impact on future features (concrete scenarios)
3. User has clear options with trade-offs (informed decisions)
4. User knows next steps (prioritized action plan)

---

## Future Enhancements

Potential improvements:
- [ ] Integration with backlog CLI (create architecture debt tasks)
- [ ] Architecture decision record (ADR) generation
- [ ] Performance profiling integration
- [ ] Dependency graph visualization
- [ ] Pattern library for common music-app architectures

---

## Related Documentation

- [ARCHITECTURE.md](../ARCHITECTURE.md) - Current system architecture
- [VISION.md](../VISION.md) - Project vision and goals
- [ADR-backend-refactor.md](../ADR-backend-refactor.md) - Backend architecture decisions
- [ADR-rich-list-ui.md](../ADR-rich-list-ui.md) - UI architecture decisions

---

## Notes

This skill embodies the principle: **"Think harder. Critique before responding."**

It's designed to be a **consultant**, not a code generator. The value is in:
- Deep architectural analysis
- Clear explanation with diagrams
- Music-streaming domain expertise
- Helping users make informed decisions

The user writes the code. The skill provides the architectural vision.
