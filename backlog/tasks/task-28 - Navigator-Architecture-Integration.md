---
id: task-28
title: Navigator Architecture Integration
status: Done
assignee:
  - '@agent'
created_date: '2025-12-27 07:28'
updated_date: '2025-12-27 07:29'
labels:
  - architecture
  - ui
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Integrate Navigator controller into ui/mod.rs to replace legacy PaneContainer routing for tab/detail panes. Enables unified view architecture per ADR-unified-view-architecture.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Navigator field added to Ui struct
- [x] #2 Navigator initialized based on legacy_panes.enabled config
- [x] #3 Key routing through Navigator.handle_key()
- [x] #4 Render routing through Navigator.render()
- [x] #5 Event routing (on_event, on_query_finished) through Navigator
- [x] #6 NavigatorPane trait extended with event methods
- [x] #7 Dead actor.rs file removed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed Session 2025-12-27:

## Key Changes

**ui/mod.rs:**
- Added navigator: Option<Navigator> field
- Initialize when legacy_panes.enabled=false (default)
- Route handle_key() through Navigator
- Route render() TabContent through Navigator
- Route on_event() through Navigator

**navigator_types.rs:**
- Added on_event() and on_query_finished() to NavigatorPane trait
- Made traits pub(crate) for visibility consistency

**navigator.rs:**
- Added on_event() routing to all panes
- Added on_query_finished() routing to active pane

**search_pane_v2.rs & queue_pane_v2.rs:**
- Added on_query_finished/on_event to NavigatorPane impls

**Bug Fixes:**
- n/N vim navigation in Normal mode after find
- execute_queue_move using position lookup instead of ID as position

**Deleted:**
- rmpc/src/actor.rs (dead code, never compiled)

Build: ✅ passes
Tests: ✅ 708 unit tests pass
<!-- SECTION:NOTES:END -->
