---
id: task-7
title: Now Playing View
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-27 10:36'
labels:
  - ui
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-NOW-1/2/3: Large album art, progress bar, controls.

**Context:**
- Now Playing view for focused listening
- Spec: docs/ui-ux-provised.md section 2.3
- Album art pane exists: ui/panes/album_art.rs

**Implementation hints:**
- Reuse album_art.rs widget (already renders large images)
- Add progress bar widget showing elapsed/total time
- Keyboard controls: Space (play/pause), </> (prev/next)
- Get status from player/youtube/server.rs::get_status()
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Large album art displayed (uses existing album_art.rs)
- [ ] #2 Progress bar with elapsed/total time
- [ ] #3 Playback controls accessible via keyboard
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: QueuePaneV2 has integrated Player mode with album art. Not a standalone pane but a view mode toggle. May be sufficient - consider closing.
<!-- SECTION:NOTES:END -->
