---
id: task-50
title: Enter on song should toggle pause if same song playing
status: In Progress
assignee: []
created_date: '2025-12-31 15:16'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When pressing Enter on a song in search results, it always clears queue and plays. Expected: If the selected song is already playing, toggle pause instead. Root cause: play_song() unconditionally calls client.clear() without checking if song is already current.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Enter on currently playing song toggles pause/play
- [ ] #2 Enter on different song clears queue and plays
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed: In resolve_action(), added check if selected song URI matches currently playing song - if so, calls pause_toggle() instead of clearing queue and playing.
<!-- SECTION:NOTES:END -->
