# Playback Flow Architecture

## Overview

This document covers all playback scenarios from user action to first audio output.

## Cache Layers

| Layer | Location | TTL | Key | Purpose |
|-------|----------|-----|-----|---------|
| **URL Cache** | Memory (LRU) | 1 hour | video_id | Avoid re-extracting stream URLs |
| **Prefix Cache** | Disk (`~/.cache/rmpc/audio/`) | LRU eviction at 200MB | video_id.webm | Instant playback start |

## Preload Tiers

| Tier | Concurrency | Deadline | Fallback | Use Case |
|------|-------------|----------|----------|----------|
| **Immediate** | 100 | 200ms | Passthrough | User clicked play NOW |
| **Gapless** | 2 | None | Wait | Next track in queue |
| **Eager** | 1 | None | Wait | Tracks 2-4 in queue |
| **Background** | 1 | None | Wait | Rest of queue |

---

## Flowchart: All Playback Scenarios

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER PRESSES PLAY                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DETERMINE PLAY SOURCE                                │
├───────────────────┬─────────────────────────┬───────────────────────────────┤
│ SEARCH RESULT     │ QUEUE (already added)   │ QUEUE (partially preloaded)   │
│ - No URL cached   │ - URL likely cached     │ - URL may be cached           │
│ - No prefix       │ - Prefix likely cached  │ - Prefix may be downloading   │
│ - Cold start      │ - Hot path              │ - Race condition              │
└───────────────────┴─────────────────────────┴───────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      STEP 1: RESOLVE STREAM URL                              │
│                      (CachedExtractor.extract_one)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────┐
            │  URL CACHE    │               │  URL CACHE    │
            │     HIT       │               │     MISS      │
            │   (< 1ms)     │               │               │
            └───────┬───────┘               └───────┬───────┘
                    │                               │
                    │                       ┌───────┴───────┐
                    │                       ▼               ▼
                    │               ┌───────────────┐ ┌───────────────┐
                    │               │ IN-FLIGHT     │ │ EXTRACT URL   │
                    │               │ (coalesce)    │ │ (ytx/yt-dlp)  │
                    │               │ Wait for      │ │ ~200-500ms    │
                    │               │ existing req  │ │               │
                    │               └───────┬───────┘ └───────┬───────┘
                    │                       │                 │
                    │                       └────────┬────────┘
                    │                                │
                    └────────────────┬───────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      STEP 2: PREPARE PLAYBACK                                │
│                      (Preparer.prepare)                                      │
│                      Tier determines strategy                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
        ┌───────────────────────┐         ┌───────────────────────┐
        │  TIER: IMMEDIATE      │         │  TIER: GAPLESS/EAGER  │
        │  (user clicked play)  │         │  (prefetch for queue) │
        │                       │         │                       │
        │  200ms deadline       │         │  Wait indefinitely    │
        └───────────┬───────────┘         └───────────┬───────────┘
                    │                                 │
                    ▼                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      STEP 3: ENSURE PREFIX                                   │
│                      (AudioCache.ensure_prefix)                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
            ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
            │ PREFIX CACHE  │ │ DOWNLOADING   │ │ PREFIX CACHE  │
            │     HIT       │ │ (in-progress) │ │     MISS      │
            │   (< 1ms)     │ │               │ │               │
            └───────┬───────┘ └───────┬───────┘ └───────┬───────┘
                    │                 │                 │
                    │                 │                 ▼
                    │                 │         ┌───────────────┐
                    │                 │         │ DOWNLOAD      │
                    │                 │         │ 200KB prefix  │
                    │                 │         │ ~100-500ms    │
                    │                 │         └───────┬───────┘
                    │                 │                 │
                    └────────┬────────┴─────────────────┘
                             │
                             ▼
            ┌────────────────────────────────────┐
            │         DEADLINE CHECK             │
            │    (Immediate tier only)           │
            └────────────────┬───────────────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
        ┌───────────────┐         ┌───────────────┐
        │ PREFIX READY  │         │ DEADLINE      │
        │ within 200ms  │         │ EXCEEDED      │
        └───────┬───────┘         └───────┬───────┘
                │                         │
                ▼                         ▼
        ┌───────────────┐         ┌───────────────┐
        │ MODE: CONCAT  │         │ MODE:         │
        │               │         │ PASSTHROUGH   │
        │ lavf://concat │         │               │
        │ prefix+stream │         │ Direct stream │
        └───────┬───────┘         └───────┬───────┘
                │                         │
                └────────────┬────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      STEP 4: MPV LOADFILE                                    │
│                      (PlaybackService.play_with_input)                       │
│                                                                              │
│  CONCAT:       lavf://concat:/path/to/prefix|subfile,...|https://stream     │
│  PASSTHROUGH:  https://rr1---sn-xxx.googlevideo.com/videoplayback?...       │
└─────────────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AUDIO PLAYS                                             │
│                                                                              │
│  CONCAT:       Instant start from local prefix, seamless transition         │
│  PASSTHROUGH:  Network latency before first audio (~500ms-2s)               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Scenario Details

### Scenario A: Search Result Play (Cold Start)

```
User clicks play on search result
    │
    ├─► URL Cache: MISS
    │   └─► ytx extract: ~200-500ms
    │
    ├─► Prefix Cache: MISS
    │   └─► Download 200KB: ~100-500ms (parallel with URL if possible)
    │
    ├─► Deadline: 200ms
    │   ├─► Prefix ready? → CONCAT mode
    │   └─► Prefix not ready? → PASSTHROUGH mode
    │
    └─► Total latency: 200ms (passthrough) to 800ms (concat)
```

**Optimization**: URL extraction starts immediately. Prefix download starts as soon as URL is available.

### Scenario B: Queue Song (Preloaded)

```
Song was added to queue 30+ seconds ago
    │
    ├─► URL Cache: HIT (cached when added)
    │   └─► Lookup: < 1ms
    │
    ├─► Prefix Cache: HIT (preloaded in background)
    │   └─► Lookup: < 1ms
    │
    └─► Total latency: < 10ms (concat mode guaranteed)
```

**This is the ideal path for gapless playback.**

### Scenario C: Album/Playlist Play (Parallel Flows)

This is the most complex scenario with TWO parallel flows triggered simultaneously.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    USER PLAYS ALBUM/PLAYLIST                                 │
│                    (e.g., clicks "Play" on album with 12 tracks)             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
┌───────────────────────────────────┐ ┌───────────────────────────────────────┐
│     FLOW A: IMMEDIATE PLAY        │ │     FLOW B: QUEUE PRELOAD             │
│     (First track - user waiting)  │ │     (Background - async)              │
└───────────────────────────────────┘ └───────────────────────────────────────┘
                    │                               │
                    ▼                               ▼
┌───────────────────────────────────┐ ┌───────────────────────────────────────┐
│ 1. PlayIntent::Context received   │ │ 1. handle_items_added() triggered     │
│    - Track 1 needs IMMEDIATE play │ │    - 12 tracks added to queue         │
│    - Tier: IMMEDIATE (200ms)      │ │    - Tier: BACKGROUND                 │
└───────────────────────────────────┘ └───────────────────────────────────────┘
                    │                               │
                    ▼                               ▼
┌───────────────────────────────────┐ ┌───────────────────────────────────────┐
│ 2. extract_one(track_1_id)        │ │ 2. Schedule preload for tracks 2-12   │
│    - Fast path, no throttle       │ │    - Filter uncached IDs              │
│    - ~200-500ms                   │ │    - Submit to PreloadScheduler       │
└───────────────────────────────────┘ └───────────────────────────────────────┘
                    │                               │
                    ▼                               ▼
┌───────────────────────────────────┐ ┌───────────────────────────────────────┐
│ 3. Check deadline (200ms)         │ │ 3. CachedExtractor processes          │
│    ├─► Prefix ready? CONCAT       │ │    - Coalesces concurrent requests    │
│    └─► Timeout? PASSTHROUGH       │ │    - Each extract_one: ~200-500ms     │
└───────────────────────────────────┘ │    - Rate limited if many requests    │
                    │                 └───────────────────────────────────────┘
                    ▼                               │
┌───────────────────────────────────┐               ▼
│ 4. MPV loadfile (track 1 plays)   │ ┌───────────────────────────────────────┐
│    - Audio starts immediately     │ │ 4. ensure_prefix() for each track     │
│    - User hears music             │ │    - Download 200KB prefix            │
└───────────────────────────────────┘ │    - Store in ~/.cache/rmpc/audio/    │
                                      └───────────────────────────────────────┘
                                                    │
                                                    ▼
                                      ┌───────────────────────────────────────┐
                                      │ 5. Tracks 2-12 now preloaded          │
                                      │    - URLs cached (1hr TTL)            │
                                      │    - Prefixes on disk                 │
                                      │    - Ready for gapless playback       │
                                      └───────────────────────────────────────┘
```

#### Timeline View (12-track album)

```
Time    Track 1 (IMMEDIATE)              Tracks 2-12 (BACKGROUND)
────────────────────────────────────────────────────────────────────────────
0ms     ► extract_one(T1) starts         ► handle_items_added() schedules all
        │                                │
200ms   │ URL extracted                  ► extract_one(T2) starts
        ► ensure_prefix(T1) starts       │
        │                                │
400ms   │ Deadline check                 ► T2 URL ready, prefix starts
        ├─► Prefix ready? CONCAT         ► extract_one(T3) starts
        └─► Not ready? PASSTHROUGH       │
        │                                │
500ms   ► MPV loadfile                   ► T2 prefix downloading...
        ► AUDIO PLAYS ♪                  ► T3 URL ready, prefix starts
        │                                │
1s      │ User listening to T1           ► T2, T3, T4 prefixes ready
        │                                ► T5-T8 extracting...
        │                                │
5s      │                                ► T5-T8 prefixes ready
        │                                ► T9-T12 extracting...
        │                                │
10s     │                                ► All tracks preloaded ✓
        │                                │
3min    ► T1 ends, gapless to T2         │
        ► T2 plays instantly (cached)    │
```

#### Race Conditions

**Case 1: User skips to track 5 while prefetch in progress**
```
Tracks 2-4: Already preloaded → instant play
Track 5: In-flight (URL extracted, prefix downloading)
         → Wait for prefix OR passthrough if deadline exceeded
Track 6-12: Still pending in Background tier
            → Promote track 6 to Gapless tier
```

**Case 2: extract_one for T1 wins before batch completes**
```
T1 extract_one returns at 200ms
    └─► Cache updated with T1 URL
Batch extract still running for T2-T12
    └─► When batch returns, T1 result ignored (already cached)
    └─► T2-T12 results added to cache
```

**Case 3: Same track requested by both flows**
```
T2 requested by:
  1. Background preload (queued)
  2. User skips to T2 (Immediate)

CachedExtractor coalesces via OnceLock:
  └─► Only ONE extraction runs
  └─► Both callers get same result
  └─► Higher priority (Immediate) doesn't preempt, just waits
```

### Scenario D: Queue Song (Partial Preload)

```
Song added to queue recently, preload still running
    │
    ├─► URL Cache: HIT or IN-FLIGHT
    │   ├─► HIT: < 1ms
    │   └─► IN-FLIGHT: Wait for existing extraction (coalesced)
    │
    ├─► Prefix Cache: DOWNLOADING
    │   ├─► Tier=Immediate: Wait up to 200ms, then passthrough
    │   └─► Tier=Gapless: Wait for completion
    │
    └─► Total latency: Variable (depends on download progress)
```

### Scenario E: Shuffle During Prefetch

```
User shuffles queue while tracks are prefetching
    │
    ├─► PreloadScheduler.cancel_request() called
    │   └─► Pending jobs removed from lanes
    │   └─► In-progress jobs: NOT cancelled ⚠️
    │
    ├─► New shuffle order triggers new preload requests
    │   └─► Priority escalation if track already in cache
    │
    └─► ⚠️ BUG: In-progress downloads continue wasting bandwidth
```

### Scenario E: Queue Clear During Prefetch

```
User clears queue while tracks are prefetching
    │
    ├─► Queue cleared via handle_queue_clear()
    │   └─► ⚠️ NO cancellation of prefetch jobs
    │
    └─► ⚠️ BUG: Downloads continue for songs no longer needed
```

### Scenario F: ytx Bulk Mode (Rate Limited)

```
ytx bulk extraction (multiple tracks at once)
    │
    ├─► ytx intentionally throttles to avoid YouTube ban
    │   └─► Single track: ~200-500ms
    │   └─► Bulk mode: ~2-5s per track (throttled)
    │
    ├─► Impact on playback:
    │   ├─► First track: uses fast path (extract_one)
    │   └─► Queue tracks: may wait for bulk extraction
    │
    └─► Mitigation: extract_one always used for immediate play
```

**Note**: When preloading queue, `extract_one` is called per-track with request coalescing. Bulk extraction (`extract_batch`) is only used when loading entire albums/playlists, and its results are cached for individual track lookups.

### Scenario G: Gapless Playback (Adjacent Songs)

```
Track N playing, approaching end
    │
    ├─► Track N+1 already preloaded (Gapless tier)
    │   └─► MPV playlist has next track queued
    │
    ├─► MPV EOF event triggers
    │   └─► Orchestrator advances queue position
    │   └─► MPV auto-plays next from playlist
    │
    └─► Gap: 0ms (if preload successful)
```

---

## Known Issues

### Issue 1: Prefix Size Too Small

| Bitrate | 200KB Duration | Required for 10s |
|---------|----------------|------------------|
| 128kbps | ~12.5s | 160KB ✓ |
| 256kbps | ~6.25s | 320KB |
| 320kbps | ~5s | 400KB |

**Current**: 200KB fixed
**Problem**: With 256kbps streams, only ~6s of audio cached
**Fix needed**: Calculate prefix size based on bitrate, or increase to 500KB

### Issue 2: No Prefetch Cancellation on Queue Clear

When queue is cleared, in-progress prefetch jobs continue.

**Fix needed**: Add `cancel_all_jobs()` to PreloadScheduler, call on queue clear.

### Issue 3: No Structured Tracing

Current logging is scattered `log::debug!` calls. No timing metrics.

**Fix needed**: Add tracing spans with timestamps for latency measurement.

### Issue 4: Second Play Faster Than First

When user clears queue and plays same song again:
- First play: URL extraction + prefix download
- Second play: URL from cache (TTL 1hr) + prefix from disk

**Not a bug** - this is cache working correctly. But feels inconsistent.

---

## Timing Targets

| Scenario | Target Latency | Current Estimate |
|----------|----------------|------------------|
| Queue song (preloaded) | < 50ms | < 10ms ✓ |
| Queue song (partial) | < 500ms | 200-800ms |
| Search result (cold) | < 500ms | 500-1500ms ✗ |
| Search result (URL cached) | < 300ms | 200-500ms |

---

## Implementation Gaps

1. **Tracing**: Add structured logs with timestamps
2. **MPV command logging**: Log exact command sent to MPV
3. **Prefix size**: Make configurable or calculate from bitrate
4. **Queue clear cancellation**: Implement `cancel_all_jobs()`
5. **Timing metrics**: Measure and expose "request → first audio" latency
