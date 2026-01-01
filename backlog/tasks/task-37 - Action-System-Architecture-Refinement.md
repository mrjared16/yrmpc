---
id: task-37
title: Action System Architecture Refinement
status: Done
assignee:
  - '@agent'
created_date: '2025-12-29 05:14'
updated_date: '2025-12-29 12:27'
labels:
  - SOLID
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deep architectural refinement of the action system based on code review session.

Critical Issues:
1. Two ActionKind enums (domain vs actions)
2. Panes bypass Intent system (dead code)
3. PlayHandler conflates Play + TogglePlayback
4. Header in domain layer (layer violation)
5. Inconsistent resolve_action signatures
6. Navigate/ToggleMark in wrong layer
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single IntentKind definition (no duplicate ActionKind)
- [ ] #2 Header only exists in UI layer (ListItem enum)
- [ ] #3 All panes use create_intent() with consistent signature
- [ ] #4 PlayHandler only handles play new content
- [ ] #5 Intent system actually executes actions (not bypassed)
- [ ] #6 User sees feedback when action fails
- [ ] #7 HashMap dispatcher with priority chains
- [ ] #8 Pass &Intent instead of owned
- [ ] #9 All 711+ tests pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Phase 1: Fix Layer Violations
1.1 Rename ActionKind → IntentKind (actions/intent.rs)
1.2 Remove Navigate/ToggleMark from IntentKind
1.3 Create UI-only ListItem enum, clean Header from DetailItem

### Phase 2: Unify Responsibility
2.1 Standardize create_intent() signature across all panes
2.2 Move validation to handlers only
2.3 Split PlayHandler → PlayHandler + TogglePlaybackHandler
2.4 Delete duplicated marked-item logic (4+ copies → 1)

### Phase 3: Wire Intent System
3.1 Panes return PaneAction::Execute(Intent)
3.2 Handlers query ctx for backend-specific IDs
3.3 Add user feedback on Outcome::Rejected

### Phase 4: Optimize Dispatcher
4.1 HashMap<IntentKind, Vec<Handler>> with priority
4.2 Pass &Intent instead of owned
4.3 Structure for future pre/post phases

## Key Decisions
- Q1: Option A - Create UI-only ListItem enum
- Q2: Rename ActionKind → IntentKind
- Q3: Remove Navigate/ToggleMark from IntentKind
- Q3.2: Option B - Handler queries ctx for backend IDs
- Q4: Hybrid - HashMap + priority, future pre/post phases
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed all phases of the action system architecture refinement. Key changes:
- Renamed ActionKind → IntentKind
- Removed Navigate/ToggleMark from IntentKind (UI-only concerns)
- Created ListItem UI wrapper (layer separation)
- Added Selection to ContentView/SectionList (unified marked item handling)
- Created TogglePlaybackHandler for SRP compliance
- Changed Handler trait to take &Intent (zero-copy)
- Wired Navigator to route all actions through ActionDispatcher
- Updated ARCHITECTURE.md documentation
<!-- SECTION:NOTES:END -->
