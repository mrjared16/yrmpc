# Audio Streaming Architecture

## Purpose
Documents the pluggable audio source architecture with byte-perfect playback using ffmpeg's concat+subfile protocol. This replaces the previous EDL approach which had timing gaps.

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
│  │ PlaybackService  │───►│ MpvAudioSource (Trait - Strategy Pattern)     │  │
│  └──────────────────┘    │                                               │  │
│                          │  ┌─────────────────────────────────────────┐  │  │
│                          │  │ ConcatSource (DEFAULT)                  │  │  │
│                          │  │ - Uses ffmpeg concat+subfile protocol   │  │  │
│                          │  │ - Byte-perfect playback                 │  │  │
│                          │  │ - Stateless, ~50 lines                  │  │  │
│                          │  └─────────────────────────────────────────┘  │  │
│                          │                                               │  │
│                          │  ┌─────────────────────────────────────────┐  │  │
│                          │  │ ProxySource (FUTURE)                    │  │  │
│                          │  │ - HTTP server for offline mode          │  │  │
│                          │  │ - Metrics, URL refresh                  │  │  │
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

### MpvAudioSource Trait

**Location**: `rmpc/src/backends/youtube/audio/mpv_source.rs`

The pluggable interface for audio source strategies. Uses the Strategy Pattern to allow swapping implementations.

```rust
pub struct MpvInput {
    pub url: String,
    pub mpv_args: Vec<String>,
}

pub trait MpvAudioSource: Send {
    fn startup(&mut self) -> anyhow::Result<()> { Ok(()) }
    fn shutdown(&mut self) {}
    fn build_mpv_input(&mut self, video_id: &str) -> anyhow::Result<MpvInput>;
}
```

**Key Points**:
- `build_mpv_input()` returns both URL and MPV arguments
- `startup()`/`shutdown()` for sources that need initialization (e.g., ProxySource HTTP server)
- All implementations share the same `AudioCache`

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

### RangeSet (Kept for Future Proxy)

**Location**: `rmpc/src/backends/youtube/audio/range_set.rs`

Tracks downloaded byte ranges as sorted, non-overlapping `(start, end)` tuples. Currently kept for the future ProxySource implementation.

```
Example progression:

Initial:     []
add(0, 50):  [(0, 50)]
add(100,150): [(0, 50), (100, 150)]
add(50, 100): [(0, 150)]  ← Merged!
```

**Key Methods**:

| Method | Description |
|--------|-------------|
| `add_range(start, end)` | Add range, auto-merge overlapping/adjacent |
| `contains(offset)` | Binary search for O(log n) lookup |
| `contiguous_from(offset)` | End of contiguous bytes from offset |

## Legacy Components (DORMANT)

### ProgressiveAudioFile (DORMANT - Future ProxySource)

**Location**: `rmpc/src/backends/youtube/streaming_audio_file.rs`

**Status**: DORMANT. Will be refactored for ProxySource implementation.

A streaming audio file supporting concurrent read/write. Originally designed for the full-file progressive download approach. When ProxySource is implemented, this will be refactored to handle the HTTP server's file serving.

### AudioFileManager (TO BE DELETED)

**Location**: `rmpc/src/backends/youtube/audio_file_manager.rs`

**Status**: TO BE DELETED. Replaced by simpler AudioCache.

The original file lifecycle manager with LRU eviction. AudioCache provides the same functionality with a simpler API focused on prefix files only.

## Data Flow

```
┌─────────────┐     ┌──────────────────┐     ┌───────────────────────┐
│ PlaybackSvc │────►│ MpvAudioSource   │────►│ build_mpv_input()     │
│             │     │ (ConcatSource)   │     │                       │
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

## Key Design Decisions

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
├── cache.rs                # AudioCache
├── mpv_source.rs           # MpvAudioSource trait + MpvInput
├── sources/
│   ├── mod.rs
│   ├── concat.rs           # ConcatSource (DEFAULT)
│   └── proxy/              # ProxySource (FUTURE)
│       ├── mod.rs
│       └── server.rs
└── range_set.rs            # Byte range tracking (for future proxy)

# Legacy (to be removed/refactored)
rmpc/src/backends/youtube/streaming_audio_file.rs   # DORMANT
rmpc/src/backends/youtube/audio_file_manager.rs     # TO BE DELETED
```

## See Also

- [ADR-001](../adr/ADR-001-audio-streaming-architecture.md) - Authoritative architecture decision
- [playback-engine.md](playback-engine.md) - Overall playback architecture
- [playback-flow.md](playback-flow.md) - End-to-end playback flow
