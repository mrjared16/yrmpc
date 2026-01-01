---
id: task-35
title: Pre-computed Shuffle Order Fix
status: In Progress
assignee: []
created_date: '2025-12-28 07:54'
updated_date: '2025-12-31 05:43'
labels:
  - bugfix
  - playback
dependencies: []
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix shuffle bug: sequential bias in prefetch window.

Problem:
- play_position loads [pos, pos+1, pos+2] into MPV
- MPV auto-advances sequentially within buffer
- Only when buffer exhausted does handle_end_of_window call next_index() (random)

Solution: Pre-compute shuffled order upfront.

ShuffleState:
- original: Vec<usize> (original order)
- shuffled: Vec<usize> (computed shuffle)
- position: usize (current index in shuffled)

Files:
- src/backends/youtube/server/orchestrator.rs - Use ShuffleState for prefetch
- src/domain/queue.rs or similar - Add ShuffleState
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ShuffleState struct implemented
- [ ] #2 Shuffle order computed on enable, not per-track
- [ ] #3 Prefetch window uses shuffled order
- [ ] #4 Previous/Next work correctly in shuffle mode
- [ ] #5 All tests pass
<!-- AC:END -->
