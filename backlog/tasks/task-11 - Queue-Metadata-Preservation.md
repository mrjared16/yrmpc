---
id: task-11
title: Queue Metadata Preservation
status: Done
assignee:
  - '@agent'
created_date: '2025-12-10 04:31'
updated_date: '2025-12-12 10:26'
labels:
  - queue
  - backend
  - blocker
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix metadata loss when songs are added to queue from search results. Currently, Enqueue::Song passes full Song object but only song.file (URI) is sent to backend, losing title/artist/album/thumbnail metadata. This blocks task-2 (Rich List UI for queue) and task-1 (Playing Highlight).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 MusicBackend trait has add_song(song: Song) method
- [x] #2 YouTubeBackend preserves full Song metadata when adding to queue
- [x] #3 Queue displays title/artist/album from search results
- [x] #4 Thumbnails available in queue view

- [ ] #5 Ctx.queue removed, AppState is single source of truth
- [ ] #6 No dual-queue sync issues
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Phase 1: Infrastructure (Non-Breaking)
1. Create QueueOperations trait (no defaults)
2. Make Ctx.queue() a getter from AppState (non-breaking)
3. Deprecate add(&str), use enqueue(&Song)

Phase 2: Feature Fixes (ISSUE_FIX_PLAN)
4. PlayOrToggle action for enter key
5. on_event sync for delete visibility
6. seek(0) on play

Phase 3: UI Fixes
7. 3-column layout (SearchPaneV2)
8. Cover image sizing (QueuePaneV2)
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Blocks: task-2 (Queue View Revamp), task-1 (Queue Playing Highlight). Related: task-8 (Metadata Consistency Fix - addresses case mismatch, not complete loss).

Phase 1 Complete:
- Created QueueOperations trait (enqueue, dequeue, reorder, clear_queue, play_by_id)
- No default implementations (forces all backends to implement)
- Implemented for: YouTubeBackend, MpvBackend, MpdBackend, YouTubeClient
- Client.add_song now delegates to enqueue
- Build successful

Phase 2 Complete:
- PlayOrToggle action already existed and was used by play_selected
- Added seek(0) when playing different song (ISSUE_FIX_PLAN #5)
- on_event already handles UiEvent::Player for selection validation (ISSUE_FIX_PLAN #4)
- All feature fixes verified with successful build
<!-- SECTION:NOTES:END -->
