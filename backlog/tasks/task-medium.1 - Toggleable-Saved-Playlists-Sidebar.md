---
id: task-medium.1
title: Toggleable Saved Playlists Sidebar
status: To Do
assignee: []
created_date: '2025-12-10 23:44'
updated_date: '2025-12-11 00:10'
labels:
  - ui
  - feature
dependencies: []
parent_task_id: task-medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement YouTube Music-style toggleable sidebar for quick access to saved playlists. Uses modal overlay pattern (like QueueModal). Toggle with 'g' key. Design documented in docs/ADR-interactive-layout-system.md Part 5.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create SavedPlaylistsModal in ui/modals/
- [ ] #2 Add ToggleSidebar to GlobalAction enum
- [ ] #3 Add left_anchored() helper to RectExt trait
- [ ] #4 Implement PlaylistItemOps trait (depends on task-medium.2)
- [ ] #5 Runtime test: g key opens sidebar modal
- [ ] #6 Update docs/ADR-interactive-layout-system.md
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Design documented in docs/ADR-interactive-layout-system.md Part 5. Uses same modal pattern as QueueModal. Reuses InteractiveListView component.
<!-- SECTION:NOTES:END -->
