---
id: task-46
title: Repeat mode not triggering after track ends
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
eof event does not trigger repeat/next
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED: Repeat mode now triggers correctly after track ends.

**Root Cause**: Same as task-45 - unreliable playlist-pos from MPV caused race conditions.

**Fix**: Same state machine architecture as task-45.

**Repeat One**: handle_eof() checks repeat_mode, replays current track via play_position_internal()

**Repeat All**: At end of queue, loops to index 0

**Tests**:
- eof_with_repeat_one_replays_current() proves Repeat One works
- eof_at_end_with_repeat_all_loops() proves Repeat All loops

**Architecture**: All repeat logic now uses queue.current_index() + PlaybackStateTracker, eliminating MPV race conditions.
<!-- SECTION:NOTES:END -->
