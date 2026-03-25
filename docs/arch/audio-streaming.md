# Audio Streaming Architecture

## Purpose
Documents the pluggable audio source architecture for concat and relay playback paths. The concat path provides byte-perfect playback using ffmpeg's concat+subfile protocol, while the relay path serves the same staged-prefix artifacts over localhost HTTP.

**Authoritative Reference**: [ADR-001](../adr/ADR-001-audio-streaming-architecture.md)

## When to Read
- **Symptoms**: Audio gaps at track start, cache issues, "protocol_whitelist" errors
- **Tasks**: Modify audio source strategy, tune cache parameters, add new source type

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Audio Streaming System                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────┐    ┌───────────────────────────────────────────────┐  │
│  │ PlaybackService  │───►│ Runtime Transport Boundary                    │  │
│  └──────────────────┘    │                                               │  │
│                          │  ┌─────────────────────────────────────────┐  │  │
│                          │  │ FfmpegConcatSource                      │  │  │
│                          │  │ - Uses ffmpeg concat+subfile protocol   │  │  │
│                          │  │ - Byte-perfect playback                 │  │  │
│                          │  │ - Stateless, ~50 lines                  │  │  │
│                          │  └─────────────────────────────────────────┘  │  │
│                          │                                               │  │
│                          │  ┌─────────────────────────────────────────┐  │  │
│                          │  │ RelayRuntime (LocalRelay)               │  │  │
│                          │  │ - Local HTTP daemon over TCP            │  │  │
│                          │  │ - Streams staged prefix + upstream      │  │  │
│                          │  └─────────────────────────────────────────┘  │  │
│                          └───────────────────────────────────────────────┘  │
│                                           │                                  │
│                                           ▼                                  │
│                          ┌───────────────────────────────────────────────┐  │
│                          │ AudioCache (Shared)                           │  │
│                          │ - Prefix files (~200KB per song)              │  │
│                          │ - Budget: <200MB for ~100 songs               │  │
│                          │ - LRU eviction when budget exceeded           │  │
│                          │ - Path: ~/.cache/rmpc/audio/{video_id}.m4a    │  │
│                          └───────────────────────────────────────────────┘  │
│                                           │                                  │
│                                           ▼                                  │
│                                    ┌──────────────┐                         │
│                                    │     MPV      │                         │
│                                    │ concat URL   │                         │
│                                    └──────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Runtime Transport Boundary

**Location**: `rmpc/src/backends/youtube/services/playback_service.rs`

The `build_runtime_input` method forms the boundary to create an `MpvInput` representation that is compatible with MPV. Based on the selected `AudioTransportTarget`, this delegates to the appropriate transport.

**Key Points**:
- `LocalRelay` attempts to register a local HTTP session with `RelayRuntime` and falls back if staging failed.
- On immediate cache miss, relay returns `StreamAndCache` — streams the URL to MPV while a tee-prefix download caches bytes in the background.
- `Combined` and `DirectUrl` construct a direct or `FfmpegConcatSource` URL.

### ConcatSource (DEFAULT)

**Location**: `rmpc/src/backends/youtube/audio/sources/concat.rs`

Uses ffmpeg's concat+subfile protocol for byte-perfect playback. This is the default and recommended implementation.

**How It Works**:
```
1. AudioCache::ensure_prefix(video_id) 
   └─► Downloads first ~200KB if not cached

2. Build concat URL:
   concat:/cache/{video_id}.m4a|subfile,,start,{BYTE_OFFSET},end,0,,:${YOUTUBE_URL}
         └── Cached prefix ──┘  └── Remainder from YouTube starting at byte offset ──┘

3. Return MpvInput with protocol_whitelist args
```

**Concat URL Syntax**:
```
concat:<source1>|<source2>

Where source2 uses subfile protocol:
subfile,,start,<BYTE>,end,0,,:URL
        │      └─ Start byte offset
        └─ Empty filename (uses URL directly)
```

**Required MPV Args**:
```
--demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat
```

**Why concat+subfile over EDL**:
- EDL uses TIME offsets: `edl://cache.opus,0,10;{url},10,` → 5-50ms audible gap
- concat+subfile uses BYTE offsets → byte-perfect junction
- Verified via PCM MD5 comparison (identical hashes)

### Relay-first with StreamAndCache

The current default path for immediate playback is **relay-first with StreamAndCache**:

1. **Relay setup**: `RelayRuntime::register_session()` creates a localhost HTTP session.
2. **Cache hit**: if prefix is cached, relay serves it immediately via `StagedPrefix`.
3. **Cache miss**: relay returns `StreamAndCache` — streams the upstream URL to MPV while a tee-prefix download writes the first ~200KB to disk in the background.
4. **Tee-prefix promotion**: after the tee-prefix download completes, the cached bytes are promoted into `AudioCache` for reuse by future gapless/eager preparation.
5. **URL reuse**: gapless/eager prefix downloads reuse the original resolved stream URL rather than invalidating and re-extracting after the prefix write.

**Direct fallback** only occurs when relay setup fails entirely (not just prefix timeout). The coordinator swaps ownership to `TrackOwner::DirectFallback` and hands MPV a plain URL.

### Legacy Passthrough vs Concat Decision

> **Note**: The section below describes the older Combined/Direct transport paths. The default immediate path is now relay-first (see above).

The Preparer chooses between:

1. **Concat URL** (preferred for staged/combined): 
   - Uses pre-downloaded audio prefix
   - Zero startup latency for MPV
   - Required for gapless transitions

2. **Passthrough URL**:
   - Direct stream URL, no prefix
   - Used when prefix not ready within deadline
   - Ensures Immediate tier plays within 200ms target

Decision tree:
```
if tier == Immediate && prefix_not_ready_in_200ms:
    return Passthrough
else:
    wait_for_prefix()
    return Concat
```

### AudioCache

**Location**: `rmpc/src/backends/youtube/audio/cache.rs`

Manages prefix files that enable instant playback start. Shared by all MpvAudioSource implementations.

```
┌─────────────────────────────────────────────────────────────────┐
│                        AudioCache                                │
├─────────────────────────────────────────────────────────────────┤
│  config:                                                         │
│  ├── cache_dir: PathBuf      # ~/.cache/rmpc/audio/              │
│  ├── prefix_size: u64        # 204800 (200KB)                    │
│  └── max_cache_size: u64     # 209715200 (200MB)                 │
│                                                                  │
│  entries: RwLock<HashMap<String, CacheEntry>>                    │
│                                                                  │
│  CacheEntry:                                                     │
│  ├── path: PathBuf           # Full path to .m4a file            │
│  ├── size: u64               # Actual size on disk               │
│  ├── content_length: u64     # Total file size (for byte offset) │
│  └── last_accessed: Instant  # For LRU eviction                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key Operations**:

| Method | Description |
|--------|-------------|
| `ensure_prefix(video_id)` | Returns path if cached, else downloads first ~200KB |
| `get_content_length(video_id)` | Returns total file size for byte offset calculation |
| `evict_lru()` | Removes oldest entries when budget exceeded |
| `total_size()` | Sum of all cached prefix files |

**Prefix Download Flow**:
```
ensure_prefix(video_id)
    │
    ▼
┌─────────────────────────────────┐
│ Check if exists in cache_dir    │
│         │                       │
│         ▼                       │
│ ┌─────────────────────────────┐ │
│ │ If exists: update LRU,      │ │
│ │            return path      │ │
│ └─────────────────────────────┘ │
│         │                       │
│         ▼                       │
│ ┌─────────────────────────────┐ │
│ │ If not exists:              │ │
│ │   1. Resolve YouTube URL    │ │
│ │   2. HTTP Range: 0-200KB    │ │
│ │   3. Write to cache_dir     │ │
│ │   4. Store content_length   │ │
│ │   5. Evict LRU if needed    │ │
│ │   6. Return path            │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### RelayRuntime

**Location**: `rmpc/src/backends/youtube/media/relay_runtime.rs`

A fully functional localhost HTTP daemon bridging the `AudioCache` and upstream. Replaces earlier design ideas around offline proxy streaming.
- Manages a local `TCPListener` to serve stream chunks for `LocalRelay` modes.
- Enforces an uninterrupted playback session via MPV playing from `localhost`.
- Current behavior streams downstream immediately but still forwards one upstream range per player request.
- Planned throttling-bypass hardening keeps the same localhost relay contract while splitting large relay -> YouTube requests into smaller chunks.

## Legacy Components (REMOVED)

Legacy components such as `RangeSet`, `ProgressiveAudioFile`, and `AudioFileManager` have been superseded by `RelayRuntime` and a simpler `AudioCache`.

## Data Flow

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────────────┐
│ PlaybackSvc │────►│ Transport Router │────►│ build_runtime_input() │
│             │     │ (Relay/Concat)   │     │                       │
└─────────────┘     └──────────────────┘     └───────────┬───────────┘
                                                          │
                           ┌──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AudioCache                                   │
│                                                                      │
│   ensure_prefix(video_id)                                            │
│   ─────────────────────                                              │
│   1. Check ~/.cache/rmpc/audio/{video_id}.m4a                        │
│   2. If miss: HTTP Range request for first 200KB                     │
│   3. Store content_length for byte offset                            │
│   4. Return path + content_length                                    │
└─────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       ConcatSource                                   │
│                                                                      │
│   Build concat URL:                                                  │
│   concat:{cache_path}|subfile,,start,{prefix_size},end,0,,:${URL}   │
│          └─ Cached prefix ─┘  └─ Stream remainder from YouTube ─┘   │
│                                                                      │
│   Return MpvInput:                                                   │
│   - url: concat:...                                                  │
│   - args: [--demuxer-lavf-o=protocol_whitelist=...]                  │
└─────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │     MPV      │
                    │              │
                    │ Plays cached │
                    │ prefix then  │
                    │ streams rest │
                    └──────────────┘
```

The diagram above shows the concat path. Relay uses the same preparation core and staged prefix, but hands MPV a localhost relay URL instead of a `lavf://concat` URL. After the planned throttling bypass is implemented, Relay will still stream bytes to MPV immediately; only the relay -> YouTube leg changes by chunking large upstream ranges.

## Key Design Decisions

### Dedup<K,V>: Request Coalescing

**Location**: `rmpc/src/shared/dedup.rs`

All concurrent requests for the same resource are coalesced — only one actual download runs; all callers share its result.

```
Thread 1: ensure_prefix("abc123") ──┐
Thread 2: ensure_prefix("abc123") ──┼──► Dedup<K,V> ──► ONE HTTP request
Thread 3: ensure_prefix("abc123") ──┘         │
                                      All 3 await same result
```

Uses `tokio::sync::OnceCell` (NOT `std::sync::OnceLock`) to avoid blocking the async runtime. Slots are cleaned up after all callers complete, preventing memory leaks.

This is applied in:
- `AudioCache::ensure_prefix` — prevents duplicate prefix downloads
- `YouTubeMediaPreparer` — prevents duplicate prepare calls per track
- `CachedExtractor` — prevents duplicate URL extractions

---

### ADR-001: concat+subfile over EDL

**Decision**: Use ffmpeg concat+subfile protocol instead of EDL syntax.

**Problem with EDL**:
```
edl://cache.opus,0,10;{youtube_url},10,
                 ↑              ↑
            TIME offset    TIME offset
```
- TIME-based offsets don't match encoded audio boundaries
- Results in 5-50ms audible gap at junction

**Solution with concat+subfile**:
```
concat:/cache/{id}.m4a|subfile,,start,200000,end,0,,:${URL}
                              ↑
                         BYTE offset
```
- BYTE-based offset = byte-perfect junction
- PCM MD5 verified identical to original file

### Prefix Size: 200KB

**Decision**: Cache first 200KB of each song.

**Rationale**:
- 200KB ≈ 1-2 seconds of M4A audio at 128kbps
- Enough to start playback instantly
- 100 songs = ~20MB (well under 200MB budget)
- Trade-off: Larger prefix = more instant playback but higher storage

### Budget: 200MB with LRU Eviction

**Decision**: Maximum 200MB for prefix cache with LRU eviction.

**Rationale**:
- 200MB holds ~1000 song prefixes
- LRU ensures recently played songs stay cached
- Reasonable disk footprint for music player

## Configuration

```ron
// config/rmpc.ron
audio: (
    cache_dir: "~/.cache/rmpc/audio/",
    prefix_size: 204800,       // 200KB
    max_cache_size: 209715200, // 200MB
),
```

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Audio gap at track start | Prefix not cached | Check AudioCache, network |
| "protocol_whitelist" error | Missing MPV args | Verify MpvInput.mpv_args passed |
| "concat: No such file" | Cache path wrong | Check cache_dir config |
| Byte offset wrong | content_length mismatch | Check stored vs actual size |
| Cache filling disk | LRU not triggering | Check max_cache_size, eviction |
| Slow first play | Prefix download slow | Check network, URL resolver |

## Code Structure

```
rmpc/src/backends/youtube/audio/
├── mod.rs                  # Module exports
├── cache.rs                # AudioCache (prefix download + LRU)
├── mpv_source.rs           # MpvAudioSource trait + MpvInput
├── planner.rs              # AudioSourcePlanner (mode → transport)
├── range_set.rs            # Byte range set (used by streaming_audio_file)
├── sources/
│   ├── mod.rs
│   ├── concat.rs           # FfmpegConcatSource (DEFAULT)
│   └── direct.rs           # DirectSource

rmpc/src/backends/youtube/media/
├── mod.rs                  # MediaPreparer trait + PreparedMedia
├── preparer.rs             # YouTubeMediaPreparer (coalescing, tier, cancel)
├── relay_runtime.rs        # RelayRuntime HTTP daemon

rmpc/src/shared/
├── dedup.rs                # Dedup<K,V> (tokio::OnceCell coalescing)
└── play_queue/             # PlayQueue state machine (L1)
```

## Relay Upstream Chunk Splitting

The relay serves localhost correctly, but the upstream fetch strategy matters for YouTube large-range throttling.

**Current behavior:**
```text
MPV requests bytes=0-50000000
    -> relay serves staged prefix immediately if available
    -> relay fetches upstream in smaller throttle-safe chunks
    -> relay streams each chunk downstream as soon as it arrives
    -> MPV still sees one normal localhost response
```

This keeps the existing localhost session runtime and changes only the upstream fetch strategy. Chunk splitting stays inside `RelayRuntime` rather than forcing a transport rewrite.

### Queue Warm vs Playback Preparation

These two behaviors are separate:

- **Queue warm**: when a song is merely added to the queue, resolve the stream URL only. Do not stage prefix bytes. This gives later playback a head start without paying prefix download cost for every queued item.
- **Playback preparation**: when a song is in the active playback window, use staged-prefix-capable preparation. This reduces silence for immediate play and auto-advance.

## See Also

- [ADR-001](../adr/ADR-001-audio-streaming-architecture.md) - Authoritative architecture decision
- [playback-flow.md](playback-flow.md) - **Canonical current playback behavior**
- [playback-engine.md](playback-engine.md) - Overall playback architecture
