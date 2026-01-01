---
id: task-29
title: UI Architecture Fix - ContentView Bubbling
status: Done
assignee:
  - '@agent'
created_date: '2025-12-27 15:23'
updated_date: '2025-12-27 15:49'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix ContentView to bubble actions instead of interpreting them. Panes now decide what Activate means. Per ADR-unified-view-architecture.md requirements.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ContentView bubbles all actions (Activate, MoveUp, MoveDown, Delete, Mark, Back)
- [x] #2 Panes interpret Activate based on their context
- [x] #3 All 708 tests pass
- [x] #4 Issue 3: QueuePane uses ContentView layers
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Remove local ContentAction from content_view.rs, re-export from navigator_types.rs
2. Update content_view.rs handle_key to bubble all actions
3. Update detail panes (artist, album, playlist) to interpret ContentAction::Activate
4. Update search_pane_v2.rs to interpret ContentAction::Activate
5. Update input_content_view.rs to use ContentAction::Back
6. Run tests to verify
7. Issue 3: Refactor QueuePane to use ContentView layers (pending)
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Issue 3 Complete: QueuePaneV2 refactored to use ContentView<QueueContent>. Added current_index to QueueContent for Now Playing section. build_sections creates Now Playing + Up Next sections. All 708 tests pass.
<!-- SECTION:NOTES:END -->
