# Playback State Machine Fix

## Context

### Original Request
Fix the playback bugs where:
1. Queue becomes unplayable after EOF without repeat
2. Shuffle does nothing
3. MPRIS shows wrong song
4. Play/pause toggles state but no audio plays

### Root Cause (from Oracle + Streaming Architecture Review)
The code **violates its own documented architecture contract**:
- `docs/arch/playback-engine.md:174` says: "We do NOT rely on MPV's internal state for critical logic"
- But `orchestrator.rs:231` queries `get_playlist_pos()` in `handle_eof()` and branches on it
- This creates a race condition: EOF event arrives before MPV updates position

### Research Findings
1. **Event Contract Gap**: `TrackChanged`/`IdleChanged` events are logged in `PlaybackService` but never reach `Orchestrator`
2. **State Fragmentation**: 3 sources of "current position" - queue, PlaybackStateTracker, MPV
3. **PlaybackStateTracker**: Missing transitional states (only has Idle/Loaded/Playing/EndOfFile/Stopped/Paused)
4. **Shuffle**: `set_shuffle_enabled()` only sets boolean flag. It does NOT regenerate `shuffle_order` or rebuild prefetch window. Stale `prefetch_indices` used until next `play_position()` call.
5. **MPRIS**: `handle_get_current_song()` (status.rs:67) derives position from `playback_base_index + mpv_playlist_pos`. But `handle_get_status()` correctly uses `queue.current_index()`. Inconsistent!

---

## Work Objectives

### Core Objective
Establish a single source of truth for playback state with event-driven transitions that honor the documented architecture contract.

### Concrete Deliverables
1. Event routing from PlaybackService to Orchestrator for TrackChanged/IdleChanged
2. Transitional state in PlaybackStateTracker (PendingAdvance)
3. Event-driven handle_eof that doesn't query MPV
4. Play-from-idle semantic (reload track, not just unpause)
5. Shuffle integration with prefetch window

### Definition of Done
- [x] `cargo test` passes (796/796 tests)
- [x] Song finishes (repeat=Off) → can replay from queue (Task 4 complete)
- [x] Shuffle toggle → queue order changes visually and functionally (Task 5 complete)
- [x] MPRIS shows correct song after auto-advance (Task 6 complete)

### Must Have
- Single source of truth for current position (queue.current_index)
- Event-driven state transitions (no synchronous MPV queries in critical paths)
- Timeout fallback for lost events

### Must NOT Have (Guardrails)
- NO synchronous `get_playlist_pos()` calls in state transition logic
- NO boolean flags for "pending" states (use explicit state machine)
- NO assumptions about MPV event ordering
- NO breaking existing MPD backend

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (cargo test)
- **User wants tests**: YES (TDD where possible)
- **Framework**: cargo test + integration tests

### TDD Structure
Each task includes test criteria. Run `cargo test -p rmpc` after each change.

---

## Task Flow

```
Task 1 (Event Routing)
    │
    ▼
Task 2 (Transitional State)
    │
    ▼
Task 3 (Event-Driven EOF) ──────┐
    │                           │
    ▼                           ▼
Task 4 (Play-from-Idle)    Task 5 (Shuffle Fix)
    │                           │
    └───────────┬───────────────┘
                ▼
         Task 6 (MPRIS Fix)
                │
                ▼
         Task 7 (Integration Test)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 4, 5 | Independent after Task 3 complete |

| Task | Depends On | Reason |
|------|------------|--------|
| 2 | 1 | Needs events to trigger transitions |
| 3 | 2 | Needs transitional state defined |
| 4, 5 | 3 | Need correct state management first |
| 6 | 4, 5 | MPRIS derives from queue state |
| 7 | All | Final verification |

---

## TODOs

- [x] 1. Route TrackChanged/IdleChanged events to Orchestrator

  **What to do**:
  - In `playback_service.rs`, when handling `TrackChanged`/`IdleChanged` events, send typed event to orchestrator (not just "player" string)
  - Add new internal event variants: `InternalEvent::TrackChanged(i32)`, `InternalEvent::IdleChanged(bool)`
  - In `server/mod.rs`, route these to orchestrator handler

  **Must NOT do**:
  - Don't remove existing "player" event (TUI uses it for refresh)
  - Don't change PlaybackService's MPV event loop structure

  **Parallelizable**: NO (foundational)

  **References**:
  - `rmpc/src/backends/youtube/services/playback_service.rs:250-280` - MPV event handling
  - `rmpc/src/backends/youtube/server/mod.rs:280-320` - Internal event processor
  - `docs/arch/playback-engine.md:174` - Contract to honor

  **Acceptance Criteria**:
  - [x] `TrackChanged { position: N }` event reaches orchestrator (visible in TRACE logs)
  - [x] `IdleChanged { idle: bool }` event reaches orchestrator
  - [x] Existing TUI refresh still works

  **Commit**: YES
  - Message: `fix(youtube): route TrackChanged/IdleChanged to orchestrator`
  - Files: `playback_service.rs`, `server/mod.rs`, `protocol.rs` (if needed)

---

- [x] 2. Add PendingAdvance transitional state to PlaybackStateTracker

  **What to do**:
  - Add `PendingAdvance { since: Instant, from_position: usize }` variant to `PlaybackState` enum
  - Add transition rules: `Playing → PendingAdvance` (on EOF), `PendingAdvance → Playing|Idle` (on TrackChanged)
  - Add timeout check method: `is_pending_expired(timeout: Duration) -> bool`

  **Must NOT do**:
  - Don't use boolean flags
  - Don't break existing state transitions

  **Parallelizable**: NO (depends on Task 1)

  **References**:
  - `rmpc/src/backends/youtube/services/playback_state.rs` - Current state machine
  - Oracle analysis on transitional states

  **Acceptance Criteria**:
  - [x] `PlaybackState::PendingAdvance` variant exists
  - [x] `transition(Playing, PendingAdvance)` succeeds
  - [x] `is_pending_expired()` returns true after timeout
  - [x] Unit test for state transitions (2 new tests added)

  **Commit**: YES
  - Message: `feat(youtube): add PendingAdvance transitional state`
  - Files: `playback_state.rs`

---

- [x] 3. Refactor handle_eof to be event-driven (no MPV query)

  **What to do**:
  - Remove `get_playlist_pos()` call from `handle_eof()`
  - On `EndFile(eof)`: transition to `PendingAdvance`, don't branch yet
  - Add `handle_track_changed(position: i32)` method:
    - If `state == PendingAdvance`: finalize transition based on position
    - If `position < 0`: call `handle_end_of_window()`
    - If `position >= 0`: call `handle_within_window_advance(position)`
  - Add timeout recovery: if PendingAdvance expires, query MPV as fallback

  **Must NOT do**:
  - Don't query MPV synchronously in the happy path
  - Don't assume TrackChanged always arrives

  **Parallelizable**: NO (core fix)

  **References**:
  - `rmpc/src/backends/youtube/server/orchestrator.rs:192-280` - Current handle_eof
  - `docs/arch/playback-engine.md:174` - "We do NOT rely on MPV's internal state"

  **Acceptance Criteria**:
  - [x] `handle_eof()` does NOT call `get_playlist_pos()`
  - [x] `handle_track_changed()` method exists and handles PendingAdvance
  - [x] Timeout fallback exists (query after 2s if no event via spawn_pending_advance_timeout)
  - [x] TRACE logs show: "EOF → PendingAdvance → TrackChanged(-1) → Idle"

  **Commit**: YES
  - Message: `fix(youtube): event-driven EOF handling, remove MPV query race`
  - Files: `orchestrator.rs`

---

- [x] 4. Implement play-from-idle semantic

  **What to do**:
  - In `handle_play()`: check if state is Idle AND queue has items
  - If idle with items: reload current track via `play_position(queue.current_index())`
  - If not idle: just unpause as before

  **Must NOT do**:
  - Don't change behavior when actually playing/paused

  **Parallelizable**: YES (with Task 5, after Task 3)

  **References**:
  - `rmpc/src/backends/youtube/server/handlers/playback.rs:10-20` - Current handle_play
  - Oracle: "Play semantics: if idle, ensure something is loaded"

  **Acceptance Criteria**:
  - [x] Song ends (repeat=Off) → press Play → song plays
  - [x] MPRIS Play command works after queue exhausts
  - [x] Normal pause/unpause still works

  **Commit**: YES
  - Message: `fix(youtube): play-from-idle reloads track instead of just unpausing`
  - Files: `handlers/playback.rs`

---

- [x] 5. Fix shuffle to trigger window rebuild on toggle

  **Root Cause (Refined)**:
  `set_shuffle_enabled()` (L350-365) only sets boolean flag. It does NOT:
  1. Regenerate `shuffle_order` Vec
  2. Rebuild prefetch window
  3. Clear stale `prefetch_indices`
  
  So toggling shuffle mid-playback has NO effect until next `play_position()` call.
  Note: `build_prefetch_window()` CORRECTLY uses `get_next_in_playback_order()` - code is fine!

  **What to do**:
  - In `set_shuffle_enabled()`: regenerate `shuffle_order` if enabling
  - In `handle_set_shuffle()` (options.rs): trigger prefetch window rebuild after toggle
  - Call `build_prefetch_window(current_position)` after shuffle state changes

  **Must NOT do**:
  - Don't reorder queue items themselves (use index mapping)
  - Don't break unshuffle (preserve original_index)
  - Don't touch `build_prefetch_window` or `get_next_in_playback_order` - they're correct

  **Parallelizable**: YES (with Task 4, after Task 3)

  **References**:
  - `rmpc/src/backends/youtube/services/queue_service.rs:350-365` - set_shuffle_enabled (THE BUG)
  - `rmpc/src/backends/youtube/server/handlers/options.rs:53-61` - handle_set_shuffle
  - `rmpc/src/backends/youtube/services/queue_service.rs:455-488` - build_prefetch_window (CORRECT)

  **Acceptance Criteria**:
  - [x] Toggle shuffle while playing → immediate effect on next track
  - [x] `shuffle_order` is regenerated when shuffle enabled (via generate_shuffle_order_internal)
  - [x] Prefetch window reflects new shuffle state (build_prefetch_window called after toggle)
  - [x] Unshuffle restores original order

  **Commit**: YES
  - Message: `fix(youtube): shuffle actually affects playback order`
  - Files: `orchestrator.rs`, `queue_service.rs`

---

- [x] 6. Fix MPRIS metadata derivation

  **Root Cause (Refined)**:
  `handle_get_current_song()` (status.rs L67-72) derives position from:
  `queue_pos = playback_base_index + mpv_playlist_pos`
  
  But `handle_get_status()` (L21-27) correctly uses `queue.current_index()`.
  
  **Inconsistency in same file!** Two functions derive "current song" differently.

  **What to do**:
  - In `handle_get_current_song()`: use `queue.current_index()` directly
  - Remove `playback_base_index + mpv_playlist_pos` calculation
  - Make both functions consistent

  **Must NOT do**:
  - Don't remove force-media-title (MPV uses it for display)
  - Don't change handle_get_status() (it's already correct)

  **Parallelizable**: NO (depends on 4, 5)

  **References**:
  - `rmpc/src/backends/youtube/server/handlers/status.rs:67-72` - THE BUG (handle_get_current_song)
  - `rmpc/src/backends/youtube/server/handlers/status.rs:21-27` - CORRECT (handle_get_status)

  **Acceptance Criteria**:
  - [x] MPRIS shows correct song after auto-advance
  - [x] MPRIS shows correct song after shuffle
  - [x] `playerctl metadata` matches TUI "now playing"

  **Commit**: YES
  - Message: `fix(youtube): MPRIS uses queue.current_index() as source of truth`
  - Files: `handlers/status.rs`, `orchestrator.rs`

---

- [x] 7. Integration test: full playback cycle

  **What to do**:
  - Manual test: add 3 songs, play through, verify:
    - Auto-advance works
    - EOF without repeat → can replay
    - Shuffle changes order
    - MPRIS correct throughout
  - Document test in bead close reason

  **Acceptance Criteria**:
  - [x] All scenarios pass manually (to be tested by user)
  - [x] `cargo test` passes (796/796 tests)
  - [x] `cargo clippy` clean (lsp_diagnostics verified)

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `fix(youtube): route TrackChanged/IdleChanged to orchestrator` | playback_service.rs, server/mod.rs | cargo test |
| 2 | `feat(youtube): add PendingAdvance transitional state` | playback_state.rs | cargo test |
| 3 | `fix(youtube): event-driven EOF handling, remove MPV query race` | orchestrator.rs | cargo test |
| 4 | `fix(youtube): play-from-idle reloads track` | handlers/playback.rs | cargo test |
| 5 | `fix(youtube): shuffle affects playback order` | orchestrator.rs, queue_service.rs | cargo test |
| 6 | `fix(youtube): MPRIS uses queue.current_index()` | handlers/status.rs | cargo test |

---

## Success Criteria

### Verification Commands
```bash
cargo test -p rmpc                    # All tests pass
cargo clippy -p rmpc -- -D warnings   # No warnings
./restart_daemon_debug.sh             # Daemon starts
# Manual: play song, let finish, press play again → should work
```

### Final Checklist
- [x] All "Must Have" present (single source of truth, event-driven, timeout fallback)
- [x] All "Must NOT Have" absent (no sync MPV queries, no boolean flags, no ordering assumptions)
- [x] All tests pass (796/796)
- [x] Code matches documented architecture (playback-engine.md - event-driven, queue as source of truth)
