---
id: task-4
title: Artist Album Detail View
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-27 07:19'
labels:
  - ui
  - navigation
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-DETAIL-1: Sectioned layout for artist/album/playlist detail views.

**Context:**
- Detail views show when user clicks browsable items (artist/album/playlist)
- Spec: docs/ui-ux-provised.md section 2.4
- Grid layout design: docs/grid-layout-design.md

**Implementation hints:**
- Create detail panes in ui/panes/ (artist.rs, album.rs, playlist.rs)
- Artist: Rich List for top songs + Grid for albums
- Album/Playlist: Rich List for tracks + Play All button
- Use browse() API in player/youtube/api.rs
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Artist view shows top songs (Rich List) + albums (Grid)
- [ ] #2 Album view shows track list with Play All
- [ ] #3 Playlist view shows tracks with Play All
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Session 2025-12-27 Progress:

Navigator architecture now in place which enables detail panes:
- ArtistDetailPane, AlbumDetailPane, PlaylistDetailPane exist in navigator.rs
- NavigateTo(EntityRef) action routes to these detail panes
- ContentView<C> provides content stacking for drill-down

Infrastructure ready. Remaining:
- Wire up API calls for fetching artist/album/playlist content
- Populate detail panes with sections (Grid for albums, RichList for songs)
<!-- SECTION:NOTES:END -->
