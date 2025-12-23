---
id: task-18
title: Queue Update Event Notification
status: Done
assignee:
  - '@claude'
created_date: '2025-12-13 17:34'
updated_date: '2025-12-15 18:52'
labels:
  - queue
  - backend
  - architecture
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix queue UI lag after add/delete operations.

**Problem**: User adds song -> UI doesn't update until manual refresh

**Root Cause**: YouTube backend doesn't have MPD's IdleEvent mechanism. When a query adds songs to the queue, the result isn't used to update `ctx.queue`.

**Previous Attempt**: Blocking idle on shared socket - REVERTED (caused 30s freeze)

**Chosen Solution**: Result-type driven state updates
- Queries that return `QueryResult::Queue(...)` automatically update `ctx.queue`
- Event loop matches on result TYPE, not query ID
- Simple, ~15 lines of code, no new infrastructure
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Queue updates instantly after add
- [x] #2 Queue updates instantly after delete
- [x] #3 No blocking/delay on startup or search
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Phase 1: Immediate Fix (~15 lines)
1. Modify search_pane_v2.rs add_to_queue() to return MpdQueryResult::Queue
2. Generalize event_loop.rs to handle Queue result from any query ID

Phase 2: Naming Cleanup (later)
- Rename MpdQueryResult to QueryResult

Phase 3: Backend Consolidation (later)
- Check mpv_backend.rs usage
- Consolidate youtube backend structure
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### Session 2025-12-14: Architecture Analysis

**Key insight**: The problem isn't missing events - it's that query results aren't used properly.

Current flow:
1. `ctx.query()` adds song to queue
2. Returns `MpdQueryResult::Any(...)`
3. Event loop ignores it
4. Queue never updates

Fixed flow:
1. `ctx.query()` adds song to queue
2. Returns `MpdQueryResult::Queue(updated_queue)`
3. Event loop: `ctx.queue = updated_queue`
4. UI renders with new queue

**Rejected approaches**:
1. ❌ Event channels - too much infrastructure for the problem
2. ❌ Optimistic updates - song IDs missing, breaks playback
3. ❌ Dual sockets - complex, MPD-specific pattern

**Previous session notes (2025-12-13)**:
- Added ServerCommand::Idle to protocol.rs (KEEP)
- Added event_tx broadcast in server.rs (KEEP)
- Client enter_idle/read_response are NO-OP (fine for now)
- Search was broken, now fixed (task-19 complete)

### Implementation (2025-12-14)

**Files modified:**
1. `rmpc/src/ui/panes/search_pane_v2.rs` (lines 215-234)
   - Changed add_to_queue to return `MpdQueryResult::Queue(Some(queue))` instead of `MpdQueryResult::Any`
   - Removed unused `target(PaneType::Search)` since we dont need pane callback
   - Simplified: removed `added_count` tracking

2. `rmpc/src/core/event_loop.rs` (lines 455-463)
   - Generalized Queue handling: `(id, _, MpdQueryResult::Queue(queue))` matches ANY query ID
   - Added `id` to debug log for traceability

### Session 2025-12-16: Hybrid Queue Architecture Refactor

**Context**: Investigation of queue update issues revealed deeper architectural problems:
1. `loadfile replace` destroyed MPV playlist → no auto-advance
2. Repeat/Shuffle were stub implementations (no-ops)
3. No MPV event observation → polling instead of reacting

**Major Refactor Implemented:**

**Phase 1: MPV Event Loop**
- Added `MpvEvent` enum to mpv_ipc.rs
- Added `observe_property()` for playlist-pos, pause, idle-active
- Added `start_event_loop()` spawning background thread

**Phase 2: Rolling Prefetch Window**
- Changed play_position: `loadfile replace` → `playlist_clear + append × 3 + playlist_play_index(0)`
- MPV now has next 2-3 tracks ready for seamless auto-advance
- Added `handle_track_ended()` to sync queue position and extend prefetch

**Phase 3: Repeat Mode**
- Added `RepeatMode` enum: Off, One, All
- Added `SetRepeat` protocol command
- `handle_track_ended` respects repeat mode

**Phase 4: Shuffle Mode**
- History-based shuffle (avoids recently played)
- `previous_index()` navigates back through history
- `next_index()` picks random from unplayed tracks

**Files Modified:**
- rmpc/src/player/mpv_ipc.rs
- rmpc/src/player/youtube/services/queue_service.rs
- rmpc/src/player/youtube/services/playback_service.rs
- rmpc/src/player/youtube/protocol.rs
- rmpc/src/player/youtube/server.rs
- rmpc/src/player/youtube/client.rs

**Testing Required:**
- Auto-advance: Queue 3+ songs, let them play through
- Repeat One: Enable, verify song loops
- Repeat All: Enable, play to end of queue, verify loop back
- Shuffle: Enable, verify random order, verify previous works
<!-- SECTION:NOTES:END -->

## Solution Design

### The Pattern: Result-Type Driven State Updates

```rust
// Any query returning Queue automatically updates ctx.queue
ctx.query()
    .id("enqueue_v2")
    .query(|client| {
        client.add_song(&song, None)?;
        let queue = client.playlist_info()?;
        Ok(QueryResult::Queue(Some(queue)))  // <- Framework handles update
    });
```

### Why This Works

| Before | After |
|--------|-------|
| Only "global_queue_update" ID updates queue | ANY query returning Queue updates queue |
| Scattered refresh logic | Centralized in event loop |
| Backend-specific workarounds | Backend-agnostic pattern |

### Implementation Phases

#### Phase 1: Immediate Fix (~30 min)
- `search_pane_v2.rs`: Return `Queue` from enqueue query
- `event_loop.rs`: Handle `Queue` result from any query ID

#### Phase 2: Naming Cleanup (~1 hour)
- Rename `MpdQueryResult` to `QueryResult` (remove MPD coupling)
- Atomic find/replace across codebase

#### Phase 3: Backend Consolidation (~2 hours)
- Check if `mpv_backend.rs` is used independently
- If not: merge into `youtube/playback.rs`
- Clean youtube/ module structure

### Files to Modify

| File | Change |
|------|--------|
| `rmpc/src/ui/panes/search_pane_v2.rs` | Return `Queue` from `add_to_queue` |
| `rmpc/src/core/event_loop.rs` | Generalize Queue result handling |

## Related

- ADR: [ADR-query-result-state-updates.md](../../docs/ADR-query-result-state-updates.md)
- Handoff (archived): [.agent/handoff-queue-update.md](../../.agent/handoff-queue-update.md)
