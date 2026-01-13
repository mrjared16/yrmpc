# Playback Flow: First Song with Cache Miss

## Purpose

Documents the complete flow when a user plays a song for the first time, including URL resolution, AudioCache prefix handling, and the concat+subfile streaming architecture.

**Authoritative Reference**: [ADR-001](../adr/ADR-001-audio-streaming-architecture.md)

## When to Read

- **Symptoms**: Song won't start, long delay before playback, "URL expired" errors, audio gaps
- **Tasks**: Understanding playback pipeline, debugging cache issues, integrating audio caching

---

## High-Level Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER PLAYS A SONG                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. UI LAYER                                                                │
│     SearchPaneV2 / Navigator / QueuePane                                    │
│     └─► play_song() or add_and_play()                                       │
│         └─► queue_store.replace_and_play(songs)                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. QUEUE SERVICE                                                           │
│     rmpc/src/backends/youtube/services/queue_service.rs                     │
│     └─► Sends AddSong command to YouTube server                             │
│     └─► Sends PlayPos(0) to start playback                                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. PLAYBACK SERVICE (handle_add_song)                                      │
│     rmpc/src/backends/youtube/services/playback_service.rs                  │
│     └─► MpvAudioSource::build_mpv_input(video_id)                           │
│         └─► ConcatSource (default implementation)                           │
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
                         │         ┌─────────────────────┐
                         │         │  4. AUDIO CACHE     │
                         │         │  audio/cache.rs     │
                         │         ├─────────────────────┤
                         │         │ 1. Resolve URL      │
                         │         │    (UrlResolver)    │
                         │         │ 2. HTTP Range: 0-   │
                         │         │    200KB            │
                         │         │ 3. Store prefix +   │
                         │         │    content_length   │
                         │         │ 4. LRU evict if     │
                         │         │    needed           │
                         │         └─────────┬───────────┘
                         │                   │
                         └───────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. CONCAT SOURCE (build concat URL)                                        │
│     rmpc/src/backends/youtube/audio/sources/concat.rs                       │
│     └─► concat:/cache/{id}.m4a|subfile,,start,{OFFSET},end,0,,:${URL}       │
│         └── Cached prefix ──┘  └── Stream remainder from YouTube ──┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  6. MPV INTEGRATION                                                         │
│     rmpc/src/backends/youtube/mpv/                                          │
│     └─► loadfile(concat_url) via IPC socket                                 │
│     └─► MPV args: --demuxer-lavf-o=protocol_whitelist=...                   │
│     └─► MPV plays: cached prefix instantly, streams rest from YouTube       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  7. AUDIO OUTPUT                                                            │
│     MPV → Audio device                                                      │
│     └─► Byte-perfect playback (no gap between prefix and stream)            │
│     └─► Prefix ensures instant start                                        │
└─────────────────────────────────────────────────────────────────────────────┘
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

## Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| **SearchPaneV2** | `ui/panes/search.rs` | User interaction, triggers play_song() |
| **QueueService** | `services/queue_service.rs` | Manages queue state, sends AddSong commands |
| **PlaybackService** | `services/playback_service.rs` | Handles playback commands, calls MpvAudioSource |
| **MpvAudioSource** | `audio/mpv_source.rs` | Trait for pluggable audio sources |
| **ConcatSource** | `audio/sources/concat.rs` | DEFAULT: Builds concat URLs for byte-perfect playback |
| **AudioCache** | `audio/cache.rs` | Manages prefix files (~200KB each), LRU eviction |
| **UrlResolver** | `url_resolver.rs` | Resolves video_id → stream URL, caches results |
| **Orchestrator** | `orchestrator.rs` | Coordinates prefetch window, manages priorities |
| **MpvClient** | `mpv/client.rs` | IPC communication with MPV process |

---

## AudioCache + ConcatSource Architecture (Current)

The streaming architecture uses **byte-perfect concat+subfile** protocol.

### Current State
```
User → PlaybackService → MpvAudioSource → AudioCache → ConcatSource → MPV
                              ↓                              ↓
                         Prefix files              concat:/cache|subfile:URL
                         (~200KB each)
```

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
- [ADR-001](../adr/ADR-001-audio-streaming-architecture.md) - Architecture decision record
