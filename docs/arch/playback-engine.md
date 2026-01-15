# Playback Engine Architecture

## Purpose
Defines the internal components of the playback system: MPV integration, URL extraction, audio caching, and gapless playback.

## When to Read
- **Symptoms**: MPV not responding, URL extraction fails, audio gaps between tracks, cache misses
- **Tasks**: Modify MPV settings, add new extractor, tune cache parameters

## Architecture Overview

The playback engine follows a **Two-Layer Architecture** (see [PlayQueue Architecture](play-queue.md) for details).

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 1: PlayQueue (State)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Pure State Machine                                              │   │
│  │  Items, Order, Shuffle/Repeat Modes                              │   │
│  │  Emits: QueueEvents                                              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │ Events
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 2: Playback Bridge                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Orchestrator (Event Loop)                                       │   │
│  │    │                                                             │   │
│  │    ├──► URL Resolver (ytx/yt-dlp)                                │   │
│  │    ├──► Audio Prefetcher (Disk Cache)                            │   │
│  │    ├──► MPV Controller (IPC)                                     │   │
│  │    └──► PendingAdvance FSM (Transitions)                         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## PreloadScheduler (replaces AudioPrefetcher)

Priority-based preload scheduling for streaming audio:

### Priority Lanes
| Lane | Concurrency | Use Case |
|------|-------------|----------|
| Immediate | ∞ | Currently playing track |
| Gapless | 2 | Next track for seamless transition |
| Eager | 1 | Upcoming tracks in queue |
| Background | 1 | Speculative preloading |

### Preparer Pipeline
1. **StreamUrl**: Resolve playback URL (cached extractor)
2. **AudioPrefix**: Download first ~200KB (HTTP Range request)
3. **MpvInput**: Build Concat (with prefix) or Passthrough URL

### Tier-Based Wait Policy
- Immediate: Wait up to 200ms, then passthrough if prefix not ready
- Gapless/Eager/Background: Wait for full prefix completion

### Audio Source & Caching
- **Goal**: Instant playback start with byte-perfect audio via cached prefixes.
- **Architecture**: Pluggable `MpvAudioSource` trait (Strategy Pattern)
  - `ConcatSource` (DEFAULT): Uses ffmpeg concat+subfile protocol
  - `ProxySource` (FUTURE): HTTP server for offline mode, metrics
- **AudioCache**: Manages prefix files (~200KB per song)
  - Path: `~/.cache/rmpc/audio/{video_id}.m4a`
  - Budget: <200MB with LRU eviction
  - API: `ensure_prefix(video_id)` guarantees instant start
- **Concat URL**: `concat:/cache/{id}.m4a|subfile,,start,{OFFSET},end,0,,:${URL}`
- See: [audio-streaming.md](audio-streaming.md) for detailed architecture (ADR-001).

### MPV Controller & Sync
The Bridge maintains "What you see is what you hear" via atomic playlist management.

- **On Track Change**: MPV plays file -> Bridge detects `end-file` -> FSM advances state.
- **On Shuffle Toggle**:
  - Layer 1 reshuffles `play_order`.
  - Layer 2 receives `OrderChanged`.
  - Bridge calculates diff and sends `loadfile ... append` commands to MPV to match new order.
  - **Invariant**: Current playing track is NEVER stopped during shuffle.

## State Management & Reliability

### PendingAdvance FSM
We do NOT rely on MPV's internal state for critical logic due to race conditions.

- **States**:
  - `Idle`
  - `Playing`
  - `PendingAdvance` (Wait for confirmation)
- **Flow**:
  1. MPV sends `end-file`.
  2. FSM checks `PlayQueue` repeat mode.
  3. FSM determines intent (e.g., `RepeatOne` -> Seek 0, `Next` -> Load next).
  4. FSM executes intent and waits for `TrackChanged`.

### Epoch-Based Event Processing
To handle async races (e.g., user mashes "Next" while prefetch is running):
- `PlayQueue` maintains a `state_epoch`.
- All `QueueEvent`s carry this epoch.
- Bridge handlers discard events with stale epochs (`event.epoch < current_epoch`).

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/shared/play_queue.rs` | **Layer 1**: Pure state machine |
| `rmpc/src/backends/youtube/bridge/` | **Layer 2**: Event handlers |
| `rmpc/src/backends/youtube/audio/mod.rs` | Audio module exports |
| `rmpc/src/backends/youtube/audio/cache.rs` | AudioCache (prefix files, LRU) |
| `rmpc/src/backends/youtube/audio/mpv_source.rs` | MpvAudioSource trait |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | ConcatSource (DEFAULT) |
| `rmpc/src/player/mpv.rs` | Low-level MPV IPC |

## Configuration

```ron
// config/rmpc.ron
playback: (
    extractor: "ytx",           // or "yt-dlp"
    cache_lookahead: 2,         // Pre-fetch N next tracks
    url_ttl_seconds: 14400,     // 4 hours
    mpv_socket: "/tmp/rmpc.sock",
),
```

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Queue order in TUI != Audio | Bridge failed to handle `OrderChanged` | `bridge/handlers.rs` |
| "No cookies found" | Auth issue affecting `ytx` | `~/.config/rmpc/cookie.txt` |
| Audio gap at track start | Prefix not cached | `audio/cache.rs` |
| "protocol_whitelist" error | Missing MPV args | `audio/sources/concat.rs` |
| Single mode skips track | PendingAdvance FSM logic error | `bridge/fsm.rs` |

## See Also

- [docs/arch/play-queue.md](play-queue.md) - Detailed queue architecture
- [docs/arch/audio-streaming.md](audio-streaming.md) - Progressive streaming architecture (ADR-001)
- [docs/features/playback.md](../features/playback.md) - End-to-end playback flow
