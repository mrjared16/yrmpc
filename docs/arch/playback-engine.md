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

## Component Details

### URL Resolver & CachedExtractor
```
┌─────────────────────────────────────────────────────────────────────────┐
│  extract(video_id) → Result<StreamUrl>                                  │
│                                                                         │
│  1. Check cache: HashMap<VideoId, (URL, Expiry)>                        │
│     └─► If valid (not expired): return cached URL                       │
│                                                                         │
│  2. Extract fresh URL:                                                  │
│     └─► Primary: ytx (Rust, ~200ms)                                     │
│     └─► Fallback: yt-dlp (Python, ~2-3s)                                │
│                                                                         │
│  3. Cache result with TTL (~4 hours, YouTube URL expiry)                │
│                                                                         │
│  4. Return URL                                                          │
│     └─► Progressive file path (ProgressiveAudioFile)                    │
│         MPV reads directly from local progressive download file         │
│         See: [audio-streaming.md](audio-streaming.md) for details       │
└─────────────────────────────────────────────────────────────────────────┘
```

### Audio Prefetcher & ProgressiveAudioFile
- **Goal**: Minimize latency and prevent buffering via progressive download.
- **Trigger**: `ItemsAdded` event or `ItemsRemoved` (cancellation).
- **Strategy**:
  - `AudioFileManager` coordinates file lifecycle with LRU eviction.
  - `ProgressiveAudioFile` handles concurrent read/write with blocking semantics.
  - Priority-based prefetch: Current (full), Next (full), Next+2/3 (30s partial).
  - Stores progressive files in `~/.cache/rmpc/streaming/`.
  - See: [audio-streaming.md](audio-streaming.md) for architecture details.

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
| `rmpc/src/backends/youtube/services/audio_prefetcher.rs` | Audio downloader |
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
| Gaps between tracks | Prefetcher lag or cache miss | `audio_prefetcher.rs` |
| Single mode skips track | PendingAdvance FSM logic error | `bridge/fsm.rs` |

## See Also

- [docs/arch/play-queue.md](play-queue.md) - Detailed queue architecture
- [docs/arch/audio-streaming.md](audio-streaming.md) - Progressive streaming architecture (ADR-001)
- [docs/features/playback.md](../features/playback.md) - End-to-end playback flow
