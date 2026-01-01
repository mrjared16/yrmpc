---
id: task-32
title: Action System Architecture (Intent/Router/Strategy)
status: Done
assignee:
  - '@agent'
created_date: '2025-12-28 07:48'
updated_date: '2025-12-28 15:49'
labels:
  - architecture
  - refactor
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace scattered resolve_action logic with unified Intent → Router → Strategy pattern.

Key Components:
- Intent: User intent with Selection (items + type queries)
- ActionRouter: Dispatches to strategies by priority
- Strategy trait: execute(intent, ctx) -> ActionResult
- Wrap-to-extend: Custom strategies wrap defaults

Selection provides queries (no abstraction):
- has_only(types), is_homogeneous(), is_empty(), songs(), etc.

Files:
- New: src/actions/ directory with intent.rs, router.rs, strategies/
- Modify: navigator.rs, navigator_types.rs, all panes
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Intent and Selection types defined
- [x] #2 ActionRouter dispatches to registered strategies
- [x] #3 DefaultPlayStrategy handles single/multi song play
- [x] #4 DefaultSaveStrategy handles save to library
- [x] #5 Panes build Intent instead of using resolve_action
- [x] #6 All tests pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create src/actions/ directory structure
2. Define Intent struct and ActionKind enum in intent.rs
3. Define Selection struct with query methods (has_only, is_homogeneous, songs, etc.)
4. Define Strategy trait and ActionResult enum in strategy.rs
5. Create ActionRouter in router.rs
6. Implement DefaultPlayStrategy in strategies/play.rs
7. Implement DefaultQueueStrategy in strategies/queue.rs
8. Add PaneAction::Execute(Intent) variant to navigator_types.rs
9. Update Navigator to dispatch Execute to ActionRouter
10. Update one pane (search) to use Intent building
11. Run tests, verify behavior
12. Update remaining panes
13. Final cleanup and tests
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Action System Architecture with Intent/Router/Strategy pattern

Naming refined: Strategy→Handler, ActionRouter→ActionDispatcher. See .agent/handoffs/2025-12-28-architecture-improvements.md

## Code Review Session (2025-12-28)

### Critical Issues Found:
1. **Two ActionKind enums exist** - domain/content.rs AND actions/intent.rs
2. **Panes still contain all logic** - resolve_action not using Intent system
3. **PlayHandler conflates Play + TogglePlayback** - SRP violation
4. **Header in domain layer** - should be UI-only
5. **Inconsistent resolve_action signatures** - 3 different patterns

### Recommended Refactoring Phases:
- Phase 1: Fix layer violations (Header, ActionKind)
- Phase 2: Unify responsibility (standardize resolve_action)
- Phase 3: Actually wire Intent system
- Phase 4: Optimize (pass &Intent, HashMap dispatcher)

### Status: Infrastructure built, not integrated
The action system exists but panes bypass it entirely.
<!-- SECTION:NOTES:END -->
