# Plan: Universal Demand-Based Work Infrastructure

**Epic**: yrmpc-bgn
**Date**: 2026-01-14
**Status**: Ready for Implementation

---

## Problem Statement

The current playback path blocks on cache download (1-3 seconds). Additionally, `CachedExtractor` contains a brilliant pattern for priority-based work (in-flight dedup, coalescing, immediate > batch priority) but it's **hardcoded** for URL extraction. Every new optimization requires copy-pasting this complex infrastructure.

**Goal**: Create a generic `DemandScheduler<W: Work>` that can be reused for any demand-based async work.

---

## The Universal Pattern

### Work Trait (Contributors Implement This)

```rust
pub enum Priority {
    Background = 0,  // Can be delayed, batch-friendly
    Eager = 1,       // User might need soon (neighbors)
    Immediate = 2,   // User needs NOW (clicked play)
}

pub trait Work: Send + Sync + 'static {
    type Key: Clone + Eq + Hash + Send + Sync;
    type Output: Clone + Send + Sync;
    type Error: Clone + Send + Sync;
    
    fn name(&self) -> &'static str;
    fn work_one(&self, key: &Self::Key) -> Result<Self::Output, Self::Error>;
    fn work_batch(&self, keys: &[Self::Key]) -> HashMap<Self::Key, Result<Self::Output, Self::Error>>;
    fn supports_batch(&self) -> bool { false }
    fn rate_limit(&self) -> Option<Duration> { None }
}
```

### DemandScheduler (Infrastructure Provides This)

```rust
pub struct DemandScheduler<W: Work> {
    worker: Arc<W>,
    cache: LruCache<W::Key, CacheEntry<W::Output>>,
    in_flight: HashMap<W::Key, Arc<OnceLock<Result<W::Output, W::Error>>>>,
    // ... priority, version, epoch tracking
}

impl<W: Work> DemandScheduler<W> {
    /// Fast path: immediate priority, registers in in_flight
    pub fn request_one(&self, key: &W::Key, priority: Priority) -> Result<W::Output, W::Error>;
    
    /// Slow path: background, skips keys in in_flight
    pub fn request_batch(&self, keys: &[W::Key], priority: Priority);
    
    /// Non-blocking cache check
    pub fn get_cached(&self, key: &W::Key) -> Option<W::Output>;
}
```

### What Infrastructure Handles

| Feature | Description |
|---------|-------------|
| In-flight deduplication | Don't start work if already running |
| Request coalescing | Multiple waiters share one OnceLock |
| Priority resolution | Immediate > Eager > Background |
| LRU + TTL caching | Configurable max_entries and ttl |
| Batch skips in-flight | Background batch won't redo fast path work |
| Epoch-based cancellation | Stale work dropped when context changes |

---

## Parallel Fast+Batch Flow

```
Scenario: "Play Album" (50 songs)

T=0: User clicks play
     │
     ▼
AudioPreparationService receives Demand::PlayItems { ids: [50], start: 0 }
     │
     ├──▶ PARALLEL: url_scheduler.request_one(ids[0], Immediate)  ← FAST
     │         │
     │         └──▶ Registers ids[0] in in_flight
     │              Spawns: ytx music ids[0]
     │              Completes in ~200ms
     │              → PLAY IMMEDIATELY
     │
     └──▶ PARALLEL: url_scheduler.request_batch(ids, Background)  ← SLOW
               │
               └──▶ Checks in_flight: ids[0] present → SKIP
                    Remaining: ids[1..49]
                    Spawns: ytx music --bulk ids[1..49]
                    Streams NDJSON results to cache

Result: First song plays in 200ms, rest prepared in background
```

---

## Module Structure

```
rmpc/src/
├── core/
│   └── demand/                    ← NEW: Universal infrastructure
│       ├── mod.rs                 # Re-exports
│       ├── work.rs                # Work trait + Priority enum
│       ├── scheduler.rs           # DemandScheduler<W>
│       └── cache.rs               # CacheEntry, LRU logic
│
├── backends/youtube/
│   ├── extractor/
│   │   └── url_work.rs            ← Implements Work (refactored from CachedExtractor)
│   ├── audio/
│   │   ├── prefix_work.rs         ← NEW: Implements Work
│   │   └── chunk_work.rs          ← FUTURE: Implements Work
│   └── services/
│       └── audio_preparation.rs   ← Coordinates schedulers
```

---

## Decision Matrix

| Demand      | Cache State  | Action                              |
|-------------|--------------|-------------------------------------|
| PlayNow     | Prefix Ready | → Concat URL (instant)              |
| PlayNow     | URL Only     | → Passthrough URL (200ms)           |
| PlayNow     | Nothing      | → Extract + Passthrough (200ms-4s)  |
| Neighbor    | Prefix Ready | → Concat URL                        |
| Neighbor    | Not Ready    | → Schedule prefix, return pending   |
| Background  | Any          | → Queue work, no immediate return   |

---

## TODOs

### Phase 1: Core Infrastructure (P1)

- [ ] 1. Create Work trait and Priority enum

  **What to do**:
  - Create `rmpc/src/core/demand/mod.rs` with re-exports
  - Create `rmpc/src/core/demand/work.rs` with:
    - `Priority` enum (Background, Eager, Immediate)
    - `Work` trait with associated types (Key, Output, Error)
    - `work_one()`, `work_batch()`, `supports_batch()`, `rate_limit()`
  - Create `rmpc/src/core/demand/cache.rs` with:
    - `CacheEntry<O>` struct (output, priority, version, inserted_at)
    - `SchedulerConfig` struct (max_entries, ttl, batch_rate_limit)

  **References**:
  - `rmpc/src/backends/youtube/extractor/cached.rs:1-50` - CacheEntry pattern
  - `rmpc/src/backends/youtube/extractor/mod.rs` - Extractor trait pattern

  **Acceptance Criteria**:
  - [ ] `cargo build` passes with new module
  - [ ] `cargo test` passes
  - [ ] Trait is generic over Key, Output, Error types

  **Commit**: YES
  - Message: `feat(core): add Work trait and Priority enum for demand scheduling`

---

- [ ] 2. Implement DemandScheduler<W: Work>

  **What to do**:
  - Create `rmpc/src/core/demand/scheduler.rs` with:
    - `DemandScheduler<W>` struct (worker, cache, in_flight, next_version, current_epoch)
    - `request_one()` - fast path with OnceLock coalescing
    - `request_batch()` - slow path that skips in_flight keys
    - `get_cached()` - non-blocking cache lookup with TTL
    - `try_cache()` - priority-aware cache update (immediate wins)
    - `advance_epoch()` - for cancellation

  **References**:
  - `rmpc/src/backends/youtube/extractor/cached.rs:50-200` - Core scheduling logic
  - `rmpc/src/backends/youtube/extractor/cached.rs:200-300` - Batch skipping logic
  - `rmpc/src/backends/youtube/extractor/cached.rs:430-530` - Tests for coalescing

  **Acceptance Criteria**:
  - [ ] `cargo build` passes
  - [ ] Unit test: concurrent request_one coalesces (one work, multiple waiters)
  - [ ] Unit test: request_batch skips keys in in_flight
  - [ ] Unit test: immediate priority wins over background in cache

  **Commit**: YES
  - Message: `feat(core): implement DemandScheduler with coalescing and priority`

---

### Phase 2: Apply to URL Extraction (P2)

- [ ] 3. Refactor CachedExtractor to use DemandScheduler

  **What to do**:
  - Create `rmpc/src/backends/youtube/extractor/url_work.rs`:
    - `UrlExtractionWork` struct implementing `Work` trait
    - `work_one()` - spawns `ytx music VIDEO_ID`
    - `work_batch()` - spawns `ytx music --bulk` with NDJSON streaming
  - Update `CachedExtractor` to wrap `DemandScheduler<UrlExtractionWork>`
  - Keep same public API (`extract_one`, `extract_batch`)

  **References**:
  - `rmpc/src/backends/youtube/extractor/cached.rs` - Current implementation
  - `rmpc/src/backends/youtube/extractor/ytx.rs` - ytx command execution

  **Acceptance Criteria**:
  - [ ] All existing CachedExtractor tests pass
  - [ ] `test_extract_one_does_not_wait_for_prefetch` still passes
  - [ ] `test_concurrent_extract_one_coalesces_requests` still passes

  **Commit**: YES
  - Message: `refactor(extractor): use DemandScheduler for URL extraction`

---

- [ ] 4. Implement PrefixDownloadWork

  **What to do**:
  - Create `rmpc/src/backends/youtube/audio/prefix_work.rs`:
    - `PrefixDownloadWork` struct implementing `Work` trait
    - `work_one()` - HTTP Range request for first 200KB
    - `work_batch()` - concurrent downloads with rate limiting
  - Instantiate `DemandScheduler<PrefixDownloadWork>` in server

  **References**:
  - `rmpc/src/backends/youtube/audio/cache.rs` - Current ensure_prefix logic
  - `rmpc/src/backends/youtube/audio/sources/concat.rs` - Current blocking call

  **Acceptance Criteria**:
  - [ ] `cargo build` passes
  - [ ] Unit test: prefix downloads to correct path
  - [ ] Unit test: concurrent requests coalesce

  **Commit**: YES
  - Message: `feat(audio): implement PrefixDownloadWork using DemandScheduler`

---

- [ ] 5. Create AudioPreparationService

  **What to do**:
  - Create `rmpc/src/backends/youtube/services/audio_preparation.rs`:
    - Holds `url_scheduler: DemandScheduler<UrlExtractionWork>`
    - Holds `prefix_scheduler: DemandScheduler<PrefixDownloadWork>`
    - `handle_play_now()` - fast path URL + check prefix cache
    - `handle_play_items()` - parallel fast+batch for albums
    - `handle_prepare()` - background batch for queue
  - Wire into server construction

  **References**:
  - `rmpc/src/backends/youtube/services/playback_service.rs` - Current service pattern
  - `rmpc/src/backends/youtube/server/mod.rs` - Server construction

  **Acceptance Criteria**:
  - [ ] `cargo build` passes
  - [ ] Service coordinates both schedulers
  - [ ] PlayNow returns in <500ms (passthrough if no prefix)

  **Commit**: YES
  - Message: `feat(services): add AudioPreparationService coordinating schedulers`

---

- [ ] 6. Remove block_on from FfmpegConcatSource

  **What to do**:
  - Modify `FfmpegConcatSource::build_mpv_input()`:
    - Remove `handle.block_on(cache.ensure_prefix())`
    - Check `prefix_scheduler.get_cached()` instead
    - If cached → return Concat URL
    - If not cached → return Passthrough URL

  **References**:
  - `rmpc/src/backends/youtube/audio/sources/concat.rs:40-60` - Current blocking

  **Acceptance Criteria**:
  - [ ] `cargo build` passes
  - [ ] No `block_on` in hot path
  - [ ] Manual test: play starts in <500ms on uncached song

  **Commit**: YES
  - Message: `fix(audio): remove blocking from FfmpegConcatSource`

---

- [ ] 7. Wire orchestrator to emit Demand

  **What to do**:
  - Modify `orchestrator.rs`:
    - Replace `build_playback_url()` loop with `Demand::PlayItems`
    - Replace queue event handling with `Demand::Prepare`
  - Send demands to `AudioPreparationService`

  **References**:
  - `rmpc/src/backends/youtube/server/orchestrator.rs:85-160` - play_position
  - `rmpc/src/backends/youtube/server/handlers/queue_events.rs` - ItemsAdded

  **Acceptance Criteria**:
  - [ ] `cargo build` passes
  - [ ] Play album with 50 songs: first plays in <500ms
  - [ ] Next track plays instantly (prefix cached from background)

  **Commit**: YES
  - Message: `refactor(orchestrator): emit Demand instead of direct build_playback_url`

---

### Phase 3: Future Optimizations (P3)

- [ ] 8. Add Demand::UserFocus for eager prefetch

  **What to do**:
  - Add `Demand::UserFocus { video_id }` variant
  - Wire from search_pane/navigator when user hovers/focuses item
  - Fire-and-forget: schedules URL+prefix at Background priority

  **References**:
  - `rmpc/src/ui/panes/navigator.rs` - Navigation events

  **Acceptance Criteria**:
  - [ ] Hovering search result triggers background prefetch
  - [ ] If user clicks: likely cached → instant play

  **Commit**: YES
  - Message: `feat(prefetch): add UserFocus for speculative prefetch on browse`

---

## Success Criteria

1. **First song plays in <500ms** regardless of cache state
2. **Subsequent songs play instantly** (prefix cached from background)
3. **No blocking in hot path** (removed block_on)
4. **Infrastructure is reusable** - adding ChunkDownloadWork requires only implementing Work trait
5. **All existing tests pass**

---

## Verification Commands

```bash
# Build
cd rmpc && cargo build

# Tests
cd rmpc && cargo test

# Manual verification
./restart_daemon_debug.sh
./rmpc/target/debug/rmpc --config ./config/rmpc.ron
# Add album, observe first song plays in <500ms
# Click next, observe instant playback
```
