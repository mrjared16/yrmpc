# Decisions Log: Unified Streaming Audio File

## Requirements Clarified

| Original | Clarified |
|----------|-----------|
| "Gapless streaming" | Zero audible artifact at any point during playback, including cache-to-stream boundary |
| "Instant playback" | Any queued song plays immediately (<100ms latency) when selected |
| "Limited disk space" | Max ~100MB for audio cache, LRU eviction required |
| "Future crossfade" | Architecture must support having two tracks decoded simultaneously |

## Key Decisions

### Decision 1: Unified Temp File vs EDL Splice

**Context**: Current EDL approach causes 20ms glitch at cache-to-stream boundary.

**Options**:
1. EDL splice (current) - Two sources, decoder reinit
2. HTTP proxy - Serve cache+stream as one response
3. Unified temp file - Single file, progressive download

**Decision**: Option 3 - Unified temp file

**Rationale**:
- ONE decoder session = zero reinit glitch
- File-based = seekable (unlike pipe/FIFO)
- Less complexity than HTTP proxy
- Proven pattern (librespot uses this)

**Trade-offs**:
- (+) Zero audio artifacts
- (+) Seekable
- (-) More complex than EDL
- (-) Need RangeSet for byte tracking

### Decision 2: Prefetch Strategy

**Context**: Queue can have 10-100 songs, can't download all.

**Options**:
1. Download ALL queued songs (~800MB for 100 songs)
2. Download only current song
3. Sliding window: Current(full) + Next(full) + Next+2,3(30s)

**Decision**: Option 3 - Sliding window

**Rationale**:
- Balances instant start with disk usage
- 30s prefetch = enough buffer to complete download before playback
- ~19MB typical usage, ~50MB max

**Trade-offs**:
- (+) Low disk usage
- (+) Instant start for next track
- (-) Slight delay if skipping many tracks ahead

### Decision 3: Why 30s Prefetch (not shorter)

**Context**: User asked why 30s instead of shorter chunks.

**Calculation**:
- Song: 4 min = 8.3MB at 288kbps
- Network: 3Mbps typical = 0.375 MB/s
- Download time: 8.3MB / 0.375 = 22s
- Buffer margin: 30s - 22s = 8s for network variance

**Decision**: 30s prefetch for next+2, next+3 tracks

**Rationale**: Matches librespot's `PRELOAD_NEXT_TRACK_BEFORE_END = 30s`

### Decision 4: Resume Download (Not Restart)

**Context**: When track C is promoted from "30s prefetch" to "next", what happens?

**Decision**: RESUME download from byte 1.2MB, not restart

**Implementation**:
```
HTTP Range: bytes=1228800-
RangeSet already knows: [(0, 1228800)]
Continue from where we left off
```

### Decision 5: Temp File Location

**Context**: User specified .cache dir.

**Decision**: `~/.cache/rmpc/audio/{video_id}.webm.part`

**Eviction policy**: LRU when total > 100MB

## Assumptions

| Assumption | Impact if Wrong | Mitigation |
|------------|-----------------|------------|
| WebM clusters are self-contained | Decoder errors mid-cluster | Only expose complete clusters |
| YouTube supports HTTP Range | Download fails | Fall back to full download |
| MPV can read growing file | Playback stutters | Pre-buffer minimum bytes |
| 30s is enough buffer | Playback catches up to download | Show buffer indicator, increase prefetch |

## Scope Boundaries

### In Scope
- StreamingAudioFile implementation
- RangeSet byte tracking
- AudioFileManager with prefetch window
- LRU eviction
- Seek to undownloaded region
- URL expiration handling
- Remove legacy AudioCache/EDL

### Explicitly Out of Scope
- Crossfade implementation (future work)
- Gapless track-to-track (separate concern, uses --gapless-audio)
- Offline mode (no persistent cache)
- Quality selection (always 288kbps opus)

---

## ADR-002: Demand-Based Audio Source Priority System

**Date**: 2026-01-13
**Status**: Proposed
**Epic**: yrmpc-bgn

### Context

The current playback path blocks on cache download:
1. `orchestrator::play_position()` loops prefetch window synchronously
2. `FfmpegConcatSource::build_mpv_input()` calls `handle.block_on(cache.ensure_prefix())`
3. Result: User presses play → waits 1-3 seconds per track in prefetch window

Additionally, `AudioPrefetcher` only extracts URLs, never triggers cache download.
The "prefetch" name/contract mismatch creates false confidence.

### Decision

**Adopt an asset-based demand system with centralized scheduling.**

#### Core Concepts

1. **Assets are first-class** (not methods):
   - `Asset::StreamUrl` - extracted playback URL
   - `Asset::Prefix { size: u64 }` - cached audio prefix (200KB)
   - Future: `Asset::Chunk { start, len }`, `Asset::FullFile`

2. **Demand types express intent** (sender doesn't know HOW):
   ```rust
   enum Demand {
       PlayNow { video_id, deadline, epoch },      // Must respond NOW
       PrepareNeighbors { items, epoch },          // Next/prev, full cache
       PrepareTail { ids, epoch },                 // Rest of queue, chunks
       UserFocus { video_id, epoch },              // Future: speculative
   }
   ```

3. **PreparationEngine** (single brain):
   - Coalesces by `WorkKey { video_id, asset }`
   - Keeps highest urgency per key
   - Epoch-based cancellation (stale work dropped)
   - Two-lane scheduler: urgent (no rate limit) + background (rate limited)
   - Fairness budget: 80% urgent, 20% background

4. **PlaybackInputResolver** (pure, non-blocking):
   - Given demand + cache state → returns `PlaybackInput`
   - Key invariant: **PlayNow NEVER blocks on prefix download**
   - If prefix not ready → use passthrough URL immediately

#### Decision Matrix

| Demand      | Cache State  | Action                              |
|-------------|--------------|-------------------------------------|
| PlayNow     | Prefix Ready | → Concat URL (instant)              |
| PlayNow     | URL Only     | → Passthrough URL (200ms)           |
| PlayNow     | Nothing      | → Extract + Passthrough (200ms-4s)  |
| Neighbor    | Prefix Ready | → Concat URL                        |
| Neighbor    | Not Ready    | → Schedule prefix, return pending   |
| Background  | Any          | → Queue work, no immediate return   |

### Consequences

**Positive:**
- Play starts in <500ms regardless of cache state
- Neighbors get prefixes proactively
- Single place for scheduling policy (coalesce, cancel, fairness)
- Extensible: add `UserFocus` without method proliferation

**Negative:**
- More moving parts than current simple design
- Need to migrate orchestrator call sites
- AudioPrefetcher becomes redundant (deprecate)

**Trade-offs:**
- Complexity for maintainability trade-off is worth it
- Migration can be incremental (Step 1 fixes blocking immediately)

### Implementation Beads

| ID        | Priority | Title                                          | Blocks     |
|-----------|----------|------------------------------------------------|------------|
| yrmpc-bgn | P1       | Epic: Demand-Based Audio Source Priority       | -          |
| yrmpc-b7q | P1       | Step 1: Remove blocking from play path         | yrmpc-bgn  |
| yrmpc-zqk | P1       | Step 2: Create Demand + WorkKey types          | yrmpc-bgn  |
| yrmpc-1x2 | P2       | Step 3: PreparationEngine skeleton             | yrmpc-zqk  |
| yrmpc-5dr | P2       | Step 4: Wire engine to queue events            | yrmpc-1x2  |
| yrmpc-dp6 | P2       | Step 5: PlaybackInputResolver                  | yrmpc-1x2  |
| yrmpc-sed | P2       | Step 6: Orchestrator emits Demand              | yrmpc-dp6  |
| yrmpc-g0v | P3       | Step 7: Two-lane scheduler                     | yrmpc-1x2  |
| yrmpc-6i3 | P3       | Step 8: Deprecate AudioPrefetcher              | yrmpc-sed  |

### Alternatives Considered

1. **Method proliferation** (`build_playback_url_immediate()`)
   - Rejected: Doesn't scale, boolean blindness

2. **Boolean flags** (`build_playback_url(id, urgent: bool)`)
   - Rejected: Magic booleans, can't express Neighbor vs Background

3. **Just wire cache into AudioPrefetcher callback**
   - Partial solution: Fixes symptom, not root cause
   - Still no demand awareness, still has scheduling scattered
