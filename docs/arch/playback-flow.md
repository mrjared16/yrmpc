# Playback Flow: First Song with Cache Miss

## Purpose

Documents the complete flow when a user plays a song for the first time, including URL resolution, AudioCache prefix handling, and the concat+subfile streaming architecture.

**Authoritative Reference**: [ADR-002](../adr/ADR-002-playintent-architecture-2026-01-15.md) (Rev 2 - Unified CacheExecutor)

## When to Read

- **Symptoms**: Song won't start, long delay before playback, "URL expired" errors, audio gaps
- **Tasks**: Understanding playback pipeline, debugging cache issues, integrating audio caching

---

## High-Level Flow Diagram (Unified CacheExecutor)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER PLAYS A SONG                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. UI LAYER                                                                │
│     SearchPaneV2 / Navigator / QueuePane                                    │
│     └─► play(PlayIntent::Context { tracks, offset, shuffle })               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. DAEMON: handle_play_intent()                                            │
│     rmpc/src/backends/youtube/server/handlers/play_intent.rs                │
│     └─► Mutate queue (instant)                                              │
│     └─► Submit preload hints (fire-and-forget)                              │
│     └─► Send Prepare(track[0], Immediate, deadline=200ms)                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. CACHE EXECUTOR (UNIFIED)                                                │
│     rmpc/src/backends/youtube/services/cache_executor.rs                    │
│     └─► Check in_flight map (coalesce if duplicate)                         │
│     └─► Stage 1: Resolve URL via UrlResolver                                │
│     └─► Stage 2: Check prefix cache                                         │
│     └─► Stage 3: Apply tier logic (deadline for Immediate)                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                          ┌─────────┴─────────┐
                          ▼                   ▼
                    ┌──────────┐        ┌──────────┐
                    │  PREFIX  │        │  PREFIX  │
                    │CACHE HIT │        │CACHE MISS│
                    └────┬─────┘        └────┬─────┘
                         │                   │
                         │                   ▼
                         │         ┌─────────────────────────────────┐
                         │         │  DEADLINE LOGIC (Immediate)     │
                         │         ├─────────────────────────────────┤
                         │         │ timeout(200ms, download_prefix) │
                         │         │                                 │
                         │         │ ├─► Success: Concat             │
                         │         │ └─► Timeout: Passthrough        │
                         │         │     (continue download bg)      │
                         │         └─────────────┬───────────────────┘
                         │                       │
                         └───────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. PREPARE RESULT                                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  Concat { prefix_path, stream_url, content_length }                         │
│    └─► Best case: gapless, seekable                                         │
│                                                                             │
│  Passthrough { stream_url }                                                 │
│    └─► Fallback: instant audio, no seek until prefix ready                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. MPV INTEGRATION                                                         │
│     rmpc/src/backends/youtube/mpv/                                          │
│                                                                             │
│     Concat mode:                                                            │
│     └─► loadfile(concat:{prefix}|subfile,,...,:{url})                       │
│     └─► MPV plays: cached prefix instantly, streams rest from YouTube       │
│                                                                             │
│     Passthrough mode:                                                       │
│     └─► loadfile({url})                                                     │
│     └─► MPV streams directly from YouTube (no seek until cached)            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  6. AUDIO OUTPUT                                                            │
│     MPV → Audio device                                                      │
│     └─► Byte-perfect playback (no gap between prefix and stream)            │
│     └─► Target: <500ms from click to audio                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Intent-Based Playback Flow (Unified CacheExecutor)

```
User Action: "Play Album" (50 songs)
      │
      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TUI: QueueStore.play(PlayIntent::Context { tracks, offset=0, shuffle })    │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ Optimistic update
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  IPC: PlayWithIntent { intent, request_id }                                 │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Daemon: handle_play_intent()                                               │
│                                                                             │
│  1. Cancel previous request_id                                              │
│  2. queue.replace(tracks)   ─────────────────────── INSTANT (no network)    │
│  3. Submit preload hints:                                                   │
│     ├─► track[0]: Immediate (user waiting)                                  │
│     ├─► track[1]: Gapless (next track)                                      │
│     └─► track[2..]: Background (opportunistic)                              │
│                                                                             │
│  4. Prepare(track[0], Immediate, deadline=200ms)                            │
│                                                                             │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CacheExecutor (UNIFIED)                                                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │ in_flight: { "track[0]": InFlightJob }                          │        │
│  │                                                                 │        │
│  │ Stage 1: url_resolver.extract_one(track[0])  ~200ms             │        │
│  │ Stage 2: audio_cache.has_prefix(track[0])?   ~0ms               │        │
│  │ Stage 3: timeout(200ms, download_prefix())                      │        │
│  │          ├─► Ready in time: Concat                              │        │
│  │          └─► Timeout: Passthrough + continue bg download        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                             │
│  Meanwhile (parallel):                                                      │
│  ├─► Background processes track[1] (Gapless) - no deadline                  │
│  └─► Background queues track[2..50] (Background)                            │
│                                                                             │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  MPV: loadfile(...)                                                         │
│                                                                             │
│  Concat mode:   concat:{prefix}|subfile,,start,{offset},...,:{url}          │
│  Passthrough:   {url}                                                       │
│                                                                             │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │
                                   ▼
                         ┌─────────────────┐
                         │  AUDIO PLAYS    │
                         │  Target: <500ms │
                         └─────────────────┘
```

---

## Sequence Diagram

```
┌──────┐  ┌───────────┐  ┌─────────┐  ┌───────────┐  ┌───────────┐  ┌──────────┐  ┌─────┐
│ User │  │SearchPane │  │QueueSvc │  │PlaybackSvc│  │AudioCache │  │ConcatSrc │  │ MPV │
└──┬───┘  └─────┬─────┘  └────┬────┘  └─────┬─────┘  └─────┬─────┘  └────┬─────┘  └──┬──┘
   │            │             │             │              │             │           │
   │ Enter/Play │             │             │              │             │           │
   │───────────>│             │             │              │             │           │
   │            │             │             │              │             │           │
   │            │ replace_and_play(songs)   │              │             │           │
   │            │────────────>│             │              │             │           │
   │            │             │             │              │             │           │
   │            │             │ PlayPos(0)  │              │             │           │
   │            │             │────────────>│              │             │           │
   │            │             │             │              │             │           │
   │            │             │             │ build_mpv_input(video_id)  │           │
   │            │             │             │─────────────────────────────>│           │
   │            │             │             │              │             │           │
   │            │             │             │              │ ensure_prefix│           │
   │            │             │             │              │<─────────────│           │
   │            │             │             │              │             │           │
   │            │             │             │   ┌──────────┴──────────┐  │           │
   │            │             │             │   │ PREFIX CACHE MISS:  │  │           │
   │            │             │             │   │ 1. Resolve URL      │  │           │
   │            │             │             │   │ 2. HTTP Range 0-200K│  │           │
   │            │             │             │   │ 3. Store prefix     │  │           │
   │            │             │             │   │ 4. Store length     │  │           │
   │            │             │             │   └──────────┬──────────┘  │           │
   │            │             │             │              │             │           │
   │            │             │             │              │ path+length │           │
   │            │             │             │              │────────────>│           │
   │            │             │             │              │             │           │
   │            │             │             │              │  concat URL │           │
   │            │             │             │<─────────────────────────────│           │
   │            │             │             │              │             │           │
   │            │             │             │ loadfile(concat_url, args) │           │
   │            │             │             │────────────────────────────────────────>│
   │            │             │             │              │             │           │
   │            │             │             │              │             │  ┌────────┴────────┐
   │            │             │             │              │             │  │ 1. Read cached  │
   │            │             │             │              │             │  │    prefix       │
   │            │             │             │              │             │  │ 2. Stream rest  │
   │            │             │             │              │             │  │    from YouTube │
   │            │             │             │              │             │  │    at byte      │
   │            │             │             │              │             │  │    offset       │
   │            │             │             │              │             │  └────────┬────────┘
   │            │             │             │              │             │           │
   │<════════════════════════════════════════════════════════════════════════════════│
   │                              AUDIO PLAYS INSTANTLY                              │
```

---

## Cache Miss Scenarios

| Cache Type | Location | Miss Behavior | Latency Impact |
|------------|----------|---------------|----------------|
| **URL Cache** | In-memory HashMap | Call extractor (ytx/yt-dlp) | +200ms to +4s |
| **Audio Prefix Cache** | `~/.cache/rmpc/audio/` | HTTP Range request for first 200KB | +50-200ms |
| **Metadata Cache** | ytmapi-yrmpc | API call to YouTube Music | +100-500ms |

---

## Component Responsibilities (Updated for Unified CacheExecutor)

| Component | File | Responsibility |
|-----------|------|----------------|
| **QueueStore** | `ui/app_store.rs` | TUI state, sends PlayIntent via IPC |
| **play_intent handler** | `server/handlers/play_intent.rs` | Mutate queue, submit preload, trigger playback |
| **CacheExecutor** | `services/cache_executor.rs` | **UNIFIED**: All cache access (preload + playback) |
| **UrlResolver** | `url_resolver.rs` | Extract video_id → stream URL |
| **AudioCache** | `audio/cache.rs` | Manage prefix files (~200KB each), LRU eviction |
| **ConcatSource** | `audio/sources/concat.rs` | Build concat URLs for byte-perfect playback |
| **MpvClient** | `mpv/client.rs` | IPC communication with MPV process |

### Removed/Deprecated Components

| Component | Status | Replaced By |
|-----------|--------|-------------|
| **PreloadScheduler** | DEPRECATED | CacheExecutor |
| **Preparer** | DEPRECATED | CacheExecutor |
| **PlaybackService.play()** | Refactored | Delegates to CacheExecutor |

---

## CacheExecutor Architecture (Current)

The streaming architecture uses **byte-perfect concat+subfile** protocol, coordinated by a **unified CacheExecutor**.

### Current State (Rev 2)
```
                    ┌──────────────────────────────────────┐
                    │          CacheExecutor               │
                    │  (Single owner of all cache access)  │
                    └──────────────────┬───────────────────┘
                                       │
             ┌─────────────────────────┼─────────────────────────┐
             │                         │                         │
             ▼                         ▼                         ▼
      ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
      │ UrlResolver  │          │ AudioCache   │          │    MPV       │
      │ (extract URL)│          │ (prefix file)│          │ (playback)   │
      └──────────────┘          └──────────────┘          └──────────────┘
```

**Key principle**: No component calls UrlResolver or AudioCache directly. All requests go through CacheExecutor, which handles:
- Request coalescing (in_flight map)
- Tier-based priority (Immediate > Gapless > Eager > Background)
- Deadline logic (Immediate: 200ms timeout → passthrough fallback)
- Concurrency limits (2/2/2/1 per tier)

### Concat URL Construction

```
AudioCache::ensure_prefix(video_id)
    │
    ├─► Returns: (path, content_length)
    │   path: ~/.cache/rmpc/audio/{video_id}.m4a
    │   content_length: Total file size from HTTP headers
    │
    ▼
ConcatSource builds:
    concat:{path}|subfile,,start,{prefix_size},end,0,,:${youtube_url}
           │                      │
           │                      └─► Byte offset where YouTube stream starts
           └─► Cached prefix file

MPV receives:
    url: concat:...
    args: --demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat
```

### Why concat+subfile (not EDL)

| Approach | Offset Type | Result |
|----------|-------------|--------|
| EDL syntax | TIME-based | 5-50ms audible gap at junction |
| concat+subfile | BYTE-based | Byte-perfect, no gap (verified via PCM MD5) |

---

## Future ProxySource Architecture (Not Yet Implemented)

The ProxySource implementation will use ProgressiveAudioFile for full offline mode and advanced features.

### Future State (with ProxySource)
```
User → PlaybackService → MpvAudioSource → ProxySource → ProgressiveAudioFile → MPV
                                               ↓
                                         HTTP Server
                                               ↓
                                          YouTube CDN
```

### ProgressiveAudioFile Flow (For Reference)

```
┌─────────────────────────────────────────────────────────────────┐
│  ProxySource starts HTTP server on localhost:PORT               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                ┌────────────────────────┐
                │ ProgressiveAudioFile   │
                │ ::new(path, length)    │
                ├────────────────────────┤
                │ • Pre-allocate file    │
                │ • Initialize RangeSet  │
                │ • Return Arc<Self>     │
                └────────────────────────┘
                              │
                   ┌──────────┼──────────┐
                   ▼          │          ▼
         ┌─────────────────┐  │  ┌─────────────────┐
         │  WRITER TASK    │  │  │  READER (MPV)   │
         │  (Background)   │  │  │  via HTTP       │
         ├─────────────────┤  │  ├─────────────────┤
         │ HTTP GET chunks │  │  │ read_at(offset) │
         │       ↓         │  │  │       ↓         │
         │ write_at(off,   │  │  │ Block on Condvar│
         │         data)   │  │  │ until data ready│
         │       ↓         │  │  │       ↓         │
         │ Update RangeSet │──┼──│ Return bytes    │
         └─────────────────┘  │  └─────────────────┘
```

### Key Design Decisions (Future)

| Decision | Implementation | Rationale |
|----------|----------------|-----------|
| **Persistent pread/pwrite** | `FileExt::read_at/write_at` | Eliminates seek syscalls, enables concurrent access |
| **Mutex pattern** | Clone data, release lock, then I/O | Prevents reader/writer contention |
| **Deadline timeout** | `Instant + Duration` in loop | Prevents infinite hang on stalled downloads |

---

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Song won't start | URL resolution failed | `RUST_LOG=debug` for extractor errors |
| Long delay before play | ytx failed, using yt-dlp | Check if ytx is installed and working |
| "URL expired" error | Cached URL too old | URL cache TTL, cookie freshness |
| Audio gap at start | Prefix not cached | Check AudioCache, ensure_prefix() |
| "protocol_whitelist" error | Missing MPV args | Verify MpvInput.mpv_args passed |
| "concat: No such file" | Cache path wrong | Check cache_dir config |
| Playback hangs | Network stall during prefix download | Check network, timeout handling |

---

## See Also

- [audio-streaming.md](audio-streaming.md) - Detailed AudioCache and ConcatSource architecture
- [playback-engine.md](playback-engine.md) - Overall engine architecture
- [ADR-001](../adr/ADR-001-audio-streaming-architecture.md) - Original streaming architecture decision
- [ADR-002](../adr/ADR-002-playintent-architecture-2026-01-15.md) - **PlayIntent + Unified CacheExecutor** (current)
