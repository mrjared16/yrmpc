---
id: task-43
title: Add-to-queue (a key) not working
status: In Progress
assignee: []
created_date: '2025-12-30 07:19'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Pressing a in search does not add to queue
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED via TDD approach:

**Root Cause**: Missing action variant for enqueue operation in the layered action bubbling architecture.

**Solution**: Added `Enqueue` variant to action enums at all layers:
- `ListAction::Enqueue(Vec<usize>)` in navigator_types.rs
- `SectionAction::Enqueue(Vec<DetailItem>)` in navigator_types.rs
- `ContentAction::Enqueue(Vec<DetailItem>)` in navigator_types.rs

**Implementation**:
1. SelectableList: Added 'a' key handler → returns ListAction::Enqueue
2. SectionList: translate_list_action handles Enqueue → SectionAction::Enqueue
3. ContentView: Bubbles SectionAction::Enqueue → ContentAction::Enqueue
4. Panes: All panes handle ContentAction::Enqueue → PaneAction::Enqueue(Vec<Song>)
   - SearchPaneV2 (both Pane and NavigatorPane traits)
   - QueuePaneV2 (Enqueue is no-op in queue)
   - AlbumDetailPane, ArtistDetailPane, PlaylistDetailPane

**Test**: `handle_key_a_returns_enqueue_action` in selectable_list.rs PASSES ✅

**Files Changed**:
- rmpc/src/ui/panes/navigator_types.rs (added 3 Enqueue variants)
- rmpc/src/ui/widgets/selectable_list.rs (added 'a' key handler + test)
- rmpc/src/ui/widgets/section_list.rs (added translate case)
- rmpc/src/ui/widgets/content_view.rs (added bubble case)
- rmpc/src/ui/panes/search_pane_v2.rs (added 2 handlers)
- rmpc/src/ui/panes/queue_pane_v2.rs (added 2 handlers)
- rmpc/src/ui/panes/{album,artist,playlist}_detail.rs (added handlers)
<!-- SECTION:NOTES:END -->
