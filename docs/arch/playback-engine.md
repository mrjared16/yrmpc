# Playback Engine Architecture

## Purpose
Defines the internal components of the playback system: MPV integration, URL extraction, audio caching, and gapless playback.

## When to Read
- **Symptoms**: MPV not responding, URL extraction fails, audio gaps between tracks, cache misses
- **Tasks**: Modify MPV settings, add new extractor, tune cache parameters

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PlaybackService                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Orchestrates: extraction → caching → MPV control                 │   │
│  │                                                                   │
│  │  play(song)     → resolve URL → cache → MPV loadfile             │   │
│  │  pause/resume() → MPV set_property                               │   │
│  │  seek(pos)      → MPV seek                                       │   │
│  │  next/prev()    → QueueStore navigate → play()                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┬─┘
        │                           │                                    │
        ▼                           ▼                                    ▼
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────────┐
│  CachedExtractor  │   │   AudioCache      │   │      MpvClient        │
│                   │   │                   │   │                       │
│  ytx (primary)    │   │  Rolling window   │   │  JSON IPC over socket │
│  yt-dlp (fallback)│   │  Pre-fetch N next │   │  /tmp/rmpc.sock       │
│  URL TTL: ~4hrs   │   │  Evict old tracks │   │  Event Loop (Thread)  │
└───────────────────┘   └───────────────────┘   └───────────────────────┘
```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PlaybackService                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Orchestrates: extraction → caching → MPV control                 │   │
│  │                                                                   │   │
│  │  play(song)     → resolve URL → cache → MPV loadfile             │   │
│  │  pause/resume() → MPV set_property                               │   │
│  │  seek(pos)      → MPV seek                                       │   │
│  │  next/prev()    → QueueStore navigate → play()                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┬─┘
        │                           │                                    │
        ▼                           ▼                                    ▼
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────────┐
│  CachedExtractor  │   │   AudioCache      │   │      MpvClient        │
│                   │   │                   │   │                       │
│  ytx (primary)    │   │  Rolling window   │   │  JSON IPC over socket │
│  yt-dlp (fallback)│   │  Pre-fetch N next │   │  /tmp/rmpc.sock       │
│  URL TTL: ~4hrs   │   │  Evict old tracks │   │                       │
└───────────────────┘   └───────────────────┘   └───────────────────────┘
```

## Component Details

### CachedExtractor
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
└─────────────────────────────────────────────────────────────────────────┘

Extractor Selection:
┌──────────┬─────────┬───────────────────────────────────────┐
│ Extractor│ Speed   │ Notes                                 │
├──────────┼─────────┼───────────────────────────────────────┤
│ ytx      │ ~200ms  │ Default. Lightweight Rust binary.     │
│ yt-dlp   │ ~2-3s   │ Fallback. Spawns Python. Avoid tests. │
└──────────┴─────────┴───────────────────────────────────────┘
```

### Background Extraction (Planned)
To reduce latency, background URL pre-extraction is planned:
- Pre-extract URLs via `url_resolver.prefetch()` as tracks enter the queue.
- Operates on a "best-effort" basis (errors logged, do not block).

> **Note**: This is a planned optimization, not yet implemented.

### AudioCache (Rolling Window)
```
Queue State:
  [Song1] [Song2] [Song3] [Song4] [Song5] [Song6]
              ▲
         Now Playing

Cache Window (N=2 lookahead):
  ┌─────────────────────────────────────────┐
  │ Cached: Song2 (current), Song3, Song4   │
  │ Pre-fetching: Song3, Song4 in background│
  │ Evicted: Song1 (already played)         │
  │ Not cached: Song5, Song6 (too far)      │
  └─────────────────────────────────────────┘

On track change:
  1. Shift window forward
  2. Evict tracks outside window
  3. Pre-fetch new tracks entering window
```

### MpvClient (IPC)
```
┌─────────────────────────────────────────────────────────────────────────┐
│  Communication: JSON over Unix socket (/tmp/rmpc.sock)                  │
│                                                                          │
│  Commands:                                                               │
│    loadfile <url> [replace|append]   → Start/queue playback            │
│    set_property pause true/false     → Pause/resume                     │
│    seek <seconds> [absolute|relative]→ Seek position                    │
│    get_property time-pos/duration    → Query playback state             │
│                                                                          │
│  Events (observed):                                                      │
│    end-file           → Track finished, trigger next()                  │
│    property-change    → Position/duration updates                       │
│    idle               → Nothing playing                                  │
└─────────────────────────────────────────────────────────────────────────┘

MPV Launch (daemon mode):
  mpv --idle --no-video --input-ipc-server=/tmp/rmpc.sock
```

## Gapless Playback & Queue Management

### Hybrid Queue Architecture (Rolling Prefetch)
Instead of a simple `loadfile` per track, we use MPV's internal playlist to ensure gapless playback.

1. **Rolling Window**: We maintain a sliding window of the next N tracks (default 3) in MPV's internal playlist.
2. **Transition**: When a track ends, MPV auto-advances instantly.
3. **Sync**: We observe `end-file` events to shift our application-side queue window and append the next track to MPV.

### Shuffle Architecture (Planned)
To support the rolling window prefetch while shuffling:
- **Strategy**: Pre-computed shuffle order with `shuffled: Vec<usize>` mapping sequential indices to random queue positions.
- The "rolling window" operates on the *shuffled* index list, allowing MPV to still preload `[current, next, next+1]` efficiently.

> **Note**: This is a planned design. Current shuffle implementation differs.

**Command Sequence:**
```
play(index):
  1. playlist_clear
  2. loadfile(track[index])
  3. loadfile(track[index+1]) append
  4. loadfile(track[index+2]) append
  5. playlist_play_index(0)
```

### Queue State & Metadata
- **Source of Truth**: `AppState` holds the in-memory queue with `QueueItem` metadata. `QueueStore` handles backend-synchronized `Vec<Song>`. Access via `Ctx.queue_store()` accessor.
- **Metadata Preservation**: We use `enqueue(&Song)` (passing full objects) rather than `add(url)`. This ensures title, artist, album, and thumbnail data are preserved from search results to the queue.
- **Result-Driven Updates**: Queries returning `QueryResult::Queue(...)` automatically trigger a global state update, ensuring the UI reflects queue changes (add/delete) instantly without manual refreshes.

### Queue UI & Interaction
- **Rich List Rendering**: Queue uses `ItemListWidget` (Rich List) to display thumbnails and metadata.
- **Active Track**: Highlighted with **bold** text and `▶` prefix (via `ListItemDisplay::is_playing()`).
- **Manipulation**: 
  - **Reorder**: `J`/`K` keys move tracks (modify `AppState` -> sync to Backend).
  - **Delete**: `d`/`x` keys remove tracks.

## State Management & Reliability

### PlaybackStateTracker
We do NOT rely on MPV's internal state (e.g., `playlist-pos`) for critical logic due to race conditions and inconsistent EOF reporting.
- **Source of Truth**: `PlaybackStateTracker` (Idle | Loaded | Playing | EndOfFile | Stopped | Paused).
- **Queue Index**: `queue.current_index()` is the authoritative position, not MPV.
- **EOF Handling**: `handle_eof` relies on the Tracker to decide whether to advance, repeat one, or loop (Repeat All).

### Race Condition Prevention
- **Stop-before-Clear**: When switching tracks, we explicitly call `stop()` before `playlist_clear()` to prevent the "ghost playback" stutter where MPV continues playing the old track while loading the new one.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/player/playback_service.rs` | PlaybackService orchestrator |
| `rmpc/src/player/extractor.rs` | CachedExtractor, ytx/yt-dlp |
| `rmpc/src/player/mpv.rs` | MpvClient, IPC communication |
| `rmpc/src/player/audio_cache.rs` | Rolling window cache |
| `rmpc/src/player/mod.rs` | Module exports |

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
| "No audio" | URL expired, re-extract | `extractor.rs` |
| MPV not responding | Socket not created | Check mpv --input-ipc-server |
| Gaps between tracks | Cache miss, slow extraction | `audio_cache.rs` |
| Wrong track plays | Queue/cache desync | `playback_service.rs` |
| ytx fails | Binary not found | Check PATH, fallback to yt-dlp |

## See Also

- [docs/features/playback.md](../features/playback.md) - End-to-end playback flow
- [docs/features/queue.md](../features/queue.md) - Queue management
- [docs/arch/youtube-integration.md](youtube-integration.md) - Video ID source
