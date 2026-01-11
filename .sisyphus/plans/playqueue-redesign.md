# PlayQueue Architecture Redesign

## Context

### Original Request
Fix queue/playback desync issues in YouTube music TUI. Problems include shuffle not syncing between UI/MPRIS/audio, cache never being hit, single mode auto-disabling, and state toggle reverting immediately.

### Interview Summary
**Key Discussions**:
- Root cause: Dual source of truth (QueueService vs MPV), index-based references go stale
- Solution: Two-layer architecture with pure state machine (L1) and effects bridge (L2)
- User wants: Optimistic UI, docs first, prefetcher owns rate limiting strategy

**Research Findings**:
- MPD backend delegates to server, doesn't need local queue state
- Current EDL format is correct (`cache,0,10;stream,10,`)
- `prefetch_audio_batch()` exists but never called (root cause of yyb)
- PendingAdvance timeout ignores repeat mode intent (root cause of e91)

### Oracle Reviews
- Approved two-layer design with event-driven sync
- Recommended epoch-based stale event detection
- Recommended intent-based PendingAdvance FSM
- Confirmed hybrid EDL (cache + stream) approach works with MPV

---

## Work Objectives

### Core Objective
Redesign YouTube backend queue architecture with clean separation between pure state management (PlayQueue) and backend-specific effects (YouTubePlayback Bridge), ensuring "what you see is what you hear" invariant.

### Concrete Deliverables
- Updated architecture documentation in `docs/`
- `PlayQueue` pure state machine in `rmpc/src/shared/play_queue.rs`
- Refactored `YouTubePlayback` bridge in `rmpc/src/backends/youtube/`
- Integration tests for queue operations
- Fixed bugs: yyb, e91, wjq, shuffle desync

### Definition of Done
- [ ] `cargo test` passes with new queue tests
- [ ] `cargo clippy` has no new warnings
- [ ] Shuffle toggle preserves current song and updates UI/MPRIS/audio atomically
- [ ] Adding songs triggers URL resolution and audio prefetch
- [ ] Single/repeat modes work correctly across track boundaries
- [ ] Architecture docs reflect new design

### Must Have
- ID-based references (no indices)
- Event-driven sync between layers
- Pure state machine testable without MPV
- Atomic MPV playlist rebuild on order change
- Intent-based PendingAdvance FSM

### Must NOT Have (Guardrails)
- NO changes to TUI layer (only consumes PlayQueue.snapshot())
- NO changes to MPD backend (YouTube-specific refactor)
- NO consume mode implementation (deferred)
- NO new external dependencies
- NO changes to config format
- NO feature flags or gradual rollout (clean replacement)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (cargo test)
- **User wants tests**: YES (TDD for L1, integration tests for L2)
- **Framework**: Rust built-in #[test]

### Test Approach
- L1 (PlayQueue): Pure unit tests, no mocks needed
- L2 (Bridge): Integration tests with FakeMpv trait
- E2E: Manual verification with daemon + TUI

---

## Task Flow

```
yrmpc-yg6 (Docs)
      │
      ▼
yrmpc-5vp (L1: PlayQueue)
      │
      ├────────────────┬────────────────┐
      ▼                ▼                │
yrmpc-46w          yrmpc-an1            │
(L1 tests)         (L2 Bridge)          │
                       │                │
      ┌────────────────┼────────────────┤
      ▼                ▼                ▼
yrmpc-o3d          yrmpc-g9i        yrmpc-1mn
(prefetch)         (FSM)            (atomic rebuild)
      │
      ▼
yrmpc-4cj (prefetcher)
      │
      ▼
yrmpc-jxx (Integration)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | yrmpc-46w, yrmpc-an1 | Both depend only on yrmpc-5vp |
| B | yrmpc-o3d, yrmpc-g9i, yrmpc-1mn | All depend only on yrmpc-an1 |

---

## TODOs

- [x] 1. Docs: Update architecture documentation (yrmpc-yg6)

  **What to do**:
  - Update `docs/arch/playback-engine.md` with new two-layer architecture
  - Update `docs/capabilities/queue.md` with new PlayQueue trait
  - Update `docs/features/queue.md` with new event flow
  - Add `docs/arch/play-queue.md` for detailed PlayQueue design
  - Update `docs/INDEX.md` to reference new docs

  **Must NOT do**:
  - Change any code files
  - Add implementation details that aren't decided

  **Parallelizable**: NO (must be first)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md` - Complete architecture design
  - `docs/INDEX.md` - Current doc structure
  - `docs/arch/playback-engine.md` - Current playback docs to update

  **Acceptance Criteria**:
  - [ ] All referenced doc files exist and are updated
  - [ ] Architecture diagrams match the agreed design
  - [ ] No code changes in this task

  **Commit**: YES
  - Message: `docs(arch): document PlayQueue two-layer architecture`
  - Files: `docs/**/*.md`

---

- [x] 2. L1: Implement PlayQueue pure state machine (yrmpc-5vp)

  **What to do**:
  - Create `rmpc/src/shared/play_queue.rs` with PlayQueue struct
  - Implement: items HashMap, original_order, play_order, current_id, history
  - Implement: shuffle, repeat modes
  - Implement: `apply(Command) -> Vec<Event>` pure function
  - Define QueueCommand and QueueEvent enums

  **Must NOT do**:
  - Any async code
  - Any I/O or MPV knowledge
  - Any prefetch logic

  **Parallelizable**: NO (depends on docs)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md:L1 section` - Design spec
  - `docs/arch/play-queue.md` - Architecture (created in task 1)
  - `rmpc/src/backends/youtube/services/queue_service.rs` - Current impl to replace

  **Acceptance Criteria**:
  - [ ] `PlayQueue::new()` creates empty queue
  - [ ] `apply(Add)` adds to both original_order and play_order
  - [ ] `apply(SetShuffle(true))` reorders play_order with current first
  - [ ] `apply(SetShuffle(false))` restores original_order
  - [ ] All operations use IDs, never indices
  - [ ] `cargo build` succeeds

  **Commit**: YES
  - Message: `feat(queue): implement PlayQueue pure state machine`
  - Files: `rmpc/src/shared/play_queue.rs`, `rmpc/src/shared/mod.rs`

---

- [x] 3. L1: PlayQueue unit tests (yrmpc-46w)

  **What to do**:
  - Add comprehensive tests for PlayQueue in `rmpc/src/shared/play_queue.rs`
  - Test shuffle preserves current
  - Test add during shuffle appends to end
  - Test remove updates both orders
  - Test history for previous navigation
  - Test repeat mode transitions

  **Must NOT do**:
  - Integration tests with MPV
  - Any mocking

  **Parallelizable**: YES (with yrmpc-an1, both depend on yrmpc-5vp)

  **References**:
  - `rmpc/src/shared/play_queue.rs` - Implementation to test
  - `.sisyphus/drafts/playback-integration-tests.md:Testing Strategy` - Test cases

  **Acceptance Criteria**:
  - [ ] `cargo test play_queue` runs all tests
  - [ ] All tests pass
  - [ ] Coverage includes: add, remove, move, shuffle on/off, repeat modes, next, previous

  **Commit**: YES
  - Message: `test(queue): add PlayQueue unit tests`
  - Files: `rmpc/src/shared/play_queue.rs`

---

- [x] 4. L2: Refactor YouTubePlayback bridge event handlers (yrmpc-an1)

  **What to do**:
  - Create event handler structure in `rmpc/src/backends/youtube/bridge/`
  - Implement handlers for: ItemsAdded, ItemsRemoved, OrderChanged, CurrentChanged, ModesChanged
  - Add epoch-based stale event detection
  - Wire PlayQueue events to bridge handlers

  **Must NOT do**:
  - Change prefetch logic yet (separate task)
  - Change PendingAdvance yet (separate task)

  **Parallelizable**: YES (with yrmpc-46w)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md:Layer 2` - Bridge design
  - `rmpc/src/backends/youtube/server/orchestrator.rs` - Current orchestrator
  - `rmpc/src/backends/youtube/server/handlers/` - Current handlers

  **Acceptance Criteria**:
  - [ ] Event handlers exist for all QueueEvent variants
  - [ ] Epoch increments on each mutation
  - [ ] Stale events (epoch < current) are ignored
  - [ ] `cargo build` succeeds

  **Commit**: YES
  - Message: `refactor(youtube): implement bridge event handlers`
  - Files: `rmpc/src/backends/youtube/bridge/*.rs`

---

- [x] 5. L2: Wire prefetch_audio_batch to ItemsAdded (yrmpc-o3d)

  **What to do**:
  - In ItemsAdded handler, call URL resolver for all new IDs
  - Queue audio chunk downloads in prefetcher
  - Ensure prefetch_audio_batch() is actually called

  **Must NOT do**:
  - Change rate limiting strategy (separate task)
  - Change EDL format

  **Parallelizable**: YES (with yrmpc-g9i, yrmpc-1mn)

  **References**:
  - `rmpc/src/backends/youtube/services/playback_service.rs:prefetch_audio_batch` - Dead code to wire
  - `.sisyphus/drafts/playback-integration-tests.md:Prefetch Triggers` - When to trigger

  **Acceptance Criteria**:
  - [ ] Adding songs triggers URL resolution
  - [ ] Adding songs queues audio chunk download
  - [ ] Cache files appear in `~/.cache/rmpc/audio/`
  - [ ] Fixes bead yyb

  **Commit**: YES
  - Message: `fix(youtube): wire prefetch_audio_batch to ItemsAdded event`
  - Files: `rmpc/src/backends/youtube/bridge/*.rs`

---

- [x] 6. L2: Intent-based PendingAdvance FSM (yrmpc-g9i)

  **What to do**:
  - Replace current PendingAdvance with intent-based enum
  - Implement: Advance(to_id), Repeat(id), Stop
  - On EOF, determine intent from repeat mode BEFORE setting pending
  - Execute intent on confirmation or timeout

  **Must NOT do**:
  - Change prefetch logic
  - Change MPV playlist management

  **Parallelizable**: YES (with yrmpc-o3d, yrmpc-1mn)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md:PendingAdvance FSM` - Design
  - `rmpc/src/backends/youtube/server/orchestrator.rs:handle_eof` - Current impl

  **Acceptance Criteria**:
  - [ ] RepeatOne mode loops current track (seek to 0)
  - [ ] RepeatAll mode loops queue at end
  - [ ] Single mode stops after current track
  - [ ] Intent preserved across timeout fallback
  - [ ] Fixes bead e91

  **Commit**: YES
  - Message: `fix(youtube): implement intent-based PendingAdvance FSM`
  - Files: `rmpc/src/backends/youtube/bridge/*.rs`

---

- [x] 7. L2: Atomic MPV playlist rebuild on OrderChanged (yrmpc-1mn)

  **What to do**:
  - On OrderChanged event, compute new prefetch window
  - Remove MPV playlist[1..n] (keep current playing)
  - Append new tracks in new order
  - Update prefetch_ids to match

  **Must NOT do**:
  - Touch current playing track (no audio gap)
  - Change URL resolution logic

  **Parallelizable**: YES (with yrmpc-o3d, yrmpc-g9i)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md:Shuffle Toggle flow` - Algorithm
  - `rmpc/src/backends/youtube/mpv_client.rs` - MPV IPC commands

  **Acceptance Criteria**:
  - [ ] Shuffle toggle updates MPV playlist atomically
  - [ ] Current song continues playing (no gap)
  - [ ] Next track after shuffle is from new order
  - [ ] MPRIS shows correct metadata

  **Commit**: YES
  - Message: `fix(youtube): atomic MPV playlist rebuild on order change`
  - Files: `rmpc/src/backends/youtube/bridge/*.rs`

---

- [x] 8. L2: Audio prefetcher with rate limiting (yrmpc-4cj)

  **What to do**:
  - Implement AudioPrefetcher with priority queue
  - Single worker thread with token bucket (1 req/sec)
  - Priority by distance from current track
  - Cancellation on queue remove/clear

  **Must NOT do**:
  - Change EDL composition
  - Change URL resolution

  **Parallelizable**: NO (depends on yrmpc-o3d)

  **References**:
  - `.sisyphus/drafts/playback-integration-tests.md:Audio Prefetcher` - Design
  - `rmpc/src/backends/youtube/services/audio_cache.rs` - Current cache

  **Acceptance Criteria**:
  - [ ] Downloads are sequential (1 at a time by default)
  - [ ] Rate limiting prevents YouTube bans
  - [ ] Nearest tracks downloaded first
  - [ ] Removed tracks cancel pending downloads

  **Commit**: YES
  - Message: `feat(youtube): implement rate-limited audio prefetcher`
  - Files: `rmpc/src/backends/youtube/services/audio_prefetcher.rs`

---

- [x] 9. Integration: Connect PlayQueue to YouTubeClient (yrmpc-jxx)

  **What to do**:
  - Replace QueueService usage with PlayQueue
  - Wire PlayQueue events to Bridge
  - Update YouTubeClient to use new architecture
  - Ensure TUI reads from PlayQueue.snapshot()

  **Must NOT do**:
  - Change TUI code (only change what it reads from)
  - Change MPD backend

  **Parallelizable**: NO (depends on all L2 tasks)

  **References**:
  - `rmpc/src/backends/youtube/client.rs` - Main client to update
  - `rmpc/src/backends/youtube/services/queue_service.rs` - To be replaced

  **Acceptance Criteria**:
  - [ ] All queue operations go through PlayQueue
  - [ ] TUI displays correct play order
  - [ ] MPRIS shows correct current track
  - [ ] Audio plays in displayed order
  - [ ] All existing tests pass
  - [ ] Fixes bead wjq

  **Commit**: YES
  - Message: `refactor(youtube): integrate PlayQueue with YouTubeClient`
  - Files: `rmpc/src/backends/youtube/*.rs`

---

## Commit Strategy

| After Task | Message | Verification |
|------------|---------|--------------|
| 1 | `docs(arch): document PlayQueue two-layer architecture` | Docs render correctly |
| 2 | `feat(queue): implement PlayQueue pure state machine` | `cargo build` |
| 3 | `test(queue): add PlayQueue unit tests` | `cargo test play_queue` |
| 4 | `refactor(youtube): implement bridge event handlers` | `cargo build` |
| 5 | `fix(youtube): wire prefetch_audio_batch` | Cache files appear |
| 6 | `fix(youtube): implement intent-based PendingAdvance` | Single mode works |
| 7 | `fix(youtube): atomic MPV playlist rebuild` | Shuffle works |
| 8 | `feat(youtube): rate-limited audio prefetcher` | Sequential downloads |
| 9 | `refactor(youtube): integrate PlayQueue` | Full E2E works |

---

## Success Criteria

### Verification Commands
```bash
cargo fmt --check          # Formatting OK
cargo clippy               # No warnings
cargo test                 # All tests pass
./restart_daemon_debug.sh  # Start daemon
./rmpc/target/debug/rmpc --config ./config/rmpc.ron  # Test manually
```

### Manual Verification
1. Add 5 songs to queue
2. Play first song
3. Toggle shuffle → queue order changes, current song continues
4. Toggle shuffle off → queue returns to original order
5. Enable repeat one → song loops
6. Enable repeat all → queue loops at end
7. Check MPRIS shows correct metadata throughout

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All linked beads (yyb, e91, wjq) can be closed
- [ ] Architecture docs match implementation
