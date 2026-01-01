---
id: task-44
title: Enter always clears queue instead of toggle
status: Done
assignee: []
created_date: '2025-12-30 07:19'
updated_date: '2025-12-30 13:49'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Should toggle pause on playing song, not re-queue
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED: Enter now toggles pause for currently playing song instead of always clearing queue.

**Root Cause**: resolve_action() didn't check if song is currently playing before returning action.

**Fix**: Added state-aware check in queue_pane_v2.rs:167-172:
- Check ctx.find_current_song_in_queue() 
- If URIs match and state is Play, return PaneAction::TogglePause
- Otherwise return Play action for batch playback

**Added PaneAction::TogglePause** variant in navigator_types.rs with handler in navigator.rs

**Tests**: resolve_action_toggles_pause_for_playing_song() proves fix
<!-- SECTION:NOTES:END -->
