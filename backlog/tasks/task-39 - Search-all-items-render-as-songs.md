---
id: task-39
title: 'Search: all items render as songs'
status: Done
assignee: []
created_date: '2025-12-30 07:19'
updated_date: '2025-12-30 13:33'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Type distinction lost - artists/albums/playlists all show song icon
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED via Phase 1: Display Layer Refactor

**Root Cause**: SectionList.render() called render_simple() which hardcoded highlight callback to false, preventing type icons and playing indicators from showing.

**Solution**: Changed line 365 in section_list.rs from render_simple() to render() with proper highlight callback that checks ctx.find_current_song_in_queue().

**Files Changed**: rmpc/src/ui/widgets/section_list.rs (lines 364-381)

**Related**: Also fixed tasks 40,41,42 (same root cause)
<!-- SECTION:NOTES:END -->
