---
id: task-45
title: Cannot replay song from queue after eof
status: In Progress
assignee:
  - '@claude'
created_date: '2025-12-30 07:19'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enter on queue item does nothing after song ends
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED: Can now replay song from queue after EOF.

**Root Cause**: EOF handling used unreliable get_playlist_pos() which returns -1 inconsistently.

**Fix**: Created explicit PlaybackStateTracker in playback_state.rs (NEW FILE):
- PlaybackState enum: Idle | Loaded | Playing | EndOfFile | Stopped | Paused
- transition() enforces valid state changes
- force_set() for atomic state updates

**Orchestrator Refactor** (orchestrator.rs completely rewritten):
- Use queue.current_index() as source of truth instead of mpv_pos
- handle_eof() now reliably advances to next track or loops
- All functions accept state_tracker parameter

**Tests**: eof_advances_to_next_track() proves EOF → next song works
<!-- SECTION:NOTES:END -->
