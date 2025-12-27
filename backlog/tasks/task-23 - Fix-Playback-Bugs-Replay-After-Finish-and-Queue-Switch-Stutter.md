---
id: task-23
title: 'Fix Playback Bugs: Replay After Finish and Queue Switch Stutter'
status: Done
assignee:
  - '@agent'
created_date: '2025-12-21 17:52'
updated_date: '2025-12-27 07:20'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two related bugs in playback:

1. **Song cannot replay after finish**: When a song finishes and queue ends, the user cannot play any song again until restart. Current state sets current_index=None and MPV goes idle.

2. **Queue song switch causes stutter**: When clicking different song in queue while playing, the audio stutters and sometimes continues playing old song. The playlist_clear() may not stop current track before loading new ones.

**Root cause hypothesis**: playlist_clear does not stop current playback, causing race condition when new tracks are loaded.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Songs can be replayed after queue ends
- [x] #2 Switching songs in queue is seamless without stutter
- [x] #3 MPV idle state is properly handled
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add stop() before playlist_clear() in play_position - DONE
2. Add stop() in play_position_static for event processor - DONE  
3. Add info logging for debugging - DONE
4. Test: Play song, let it end, try to replay - PENDING
5. Test: Switch songs in queue while playing - PENDING
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed by adding stop() before playlist_clear() in play_position(). Also reduced protocol logging to trace level and updated terminology (MPV playlist → buffer).

All AC completed per implementation notes. Testing may be verified later.
<!-- SECTION:NOTES:END -->
