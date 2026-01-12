# Audio Streaming Architecture

## Purpose
Documents the progressive streaming audio system: `ProgressiveAudioFile` (currently named `StreamingAudioFile`), `AudioFileManager`, and `RangeSet`. This architecture replaces the previous EDL+cache approach with a unified progressive download model.

## When to Read
- **Symptoms**: Audio cuts out mid-track, buffering issues, cache disk usage, download stalls
- **Tasks**: Modify streaming behavior, tune cache parameters, debug download issues

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Audio Streaming System                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌───────────────────┐    ┌──────────────────────────┐  │
│  │ URL Resolver │───▶│ Download Task     │───▶│ StreamingAudioFile       │  │
│  │ (ytx/yt-dlp) │    │ (HTTP range req)  │    │ - Pre-allocated file     │  │
│  └──────────────┘    └───────────────────┘    │ - RangeSet tracking      │  │
│                              │                 │ - Condvar signaling      │  │
│                              │ write_at()      └───────────┬──────────────┘  │
│                              ▼                             │                 │
│                      ┌───────────────────┐                 │ read_at()       │
│                      │ AudioFileManager  │                 │ (blocks if      │
│                      │ - File lifecycle  │                 │  not available) │
│                      │ - LRU eviction    │                 ▼                 │
│                      │ - Prefetch window │         ┌──────────────┐         │
│                      └───────────────────┘         │     MPV      │         │
│                                                    │ (reads file) │         │
│                                                    └──────────────┘         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### StreamingAudioFile (→ ProgressiveAudioFile)

**Location**: `rmpc/src/backends/youtube/streaming_audio_file.rs`

A streaming audio file that supports concurrent reading and writing. Design inspired by librespot's `AudioFile`.

```
┌─────────────────────────────────────────────────────────────────┐
│                    StreamingAudioFile                            │
├─────────────────────────────────────────────────────────────────┤
│  Inner (Mutex-protected):                                        │
│  ├── path: PathBuf           # File location on disk             │
│  ├── content_length: u64     # Total expected file size          │
│  ├── downloaded: RangeSet    # Tracks which bytes are ready      │
│  ├── write_file: Option<File> # Write handle (None when done)   │
│  ├── error: Option<String>   # Download error if any             │
│  └── requested_offset: Option<u64>  # Seek target for priority  │
│                                                                  │
│  Condvar: Arc<Condvar>       # Signals new bytes available       │
└─────────────────────────────────────────────────────────────────┘
```

**Key Operations**:

| Method | Description |
|--------|-------------|
| `new(path, content_length)` | Pre-allocates file to `content_length` |
| `write_at(offset, data)` | Called by downloader, notifies waiters |
| `read_at(offset, buf)` | **Blocks** until bytes available |
| `bytes_available_from(offset)` | Non-blocking availability check |
| `request_range(offset)` | Signals priority download from offset |
| `set_error(msg)` | Propagates download failure to readers |

**Blocking Read Flow**:
```
read_at(offset, buf)
    │
    ▼
┌─────────────────────────────────┐
│ Lock mutex, check error         │
│         │                       │
│         ▼                       │
│ ┌─────────────────────────────┐ │
│ │ Loop until bytes available: │ │
│ │   contiguous_from(offset)   │ │
│ │   if available: break       │ │
│ │   else: condvar.wait()      │ │◀─── Blocked here
│ └─────────────────────────────┘ │
│         │                       │
│         ▼                       │
│ Release lock, do file I/O       │
│         │                       │
│         ▼                       │
│ Return bytes read               │
└─────────────────────────────────┘
```

### AudioFileManager

**Location**: `rmpc/src/backends/youtube/audio_file_manager.rs`

Manages multiple `StreamingAudioFile` instances with lifecycle control and cache eviction.

```
┌─────────────────────────────────────────────────────────────────┐
│                     AudioFileManager                             │
├─────────────────────────────────────────────────────────────────┤
│  config:                                                         │
│  ├── cache_dir: PathBuf      # ~/.cache/rmpc/streaming/          │
│  └── max_size_bytes: u64     # 100 MB default                    │
│                                                                  │
│  files: RwLock<HashMap<String, ManagedFile>>                     │
│                                                                  │
│  ManagedFile:                                                    │
│  ├── file: Arc<StreamingAudioFile>                               │
│  ├── video_id: String                                            │
│  ├── content_length: u64                                         │
│  ├── last_accessed: Instant  # For LRU                           │
│  └── priority: PrefetchPriority                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Prefetch Priorities**:

| Priority | Description | Evictable? |
|----------|-------------|------------|
| `Current` | Currently playing track | No |
| `Next` | Next track in queue | No |
| `Partial { duration_secs: 30 }` | Next+2, Next+3 | Yes |
| `None` | Not in prefetch window | Yes |

**LRU Eviction**: When cache exceeds `max_size_bytes`, evicts least-recently-used files that aren't `Current` or `Next` priority.

### RangeSet

**Location**: `rmpc/src/backends/youtube/range_set.rs`

Tracks downloaded byte ranges as sorted, non-overlapping `(start, end)` tuples. Adjacent ranges are automatically merged.

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
| `total_bytes()` | Sum of all range sizes |
| `is_complete(content_length)` | True if single range `[0, content_length)` |
| `first_gap_after(offset, file_size)` | Find next undownloaded region |

## Data Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────────┐
│ PlaybackSvc │────▶│ AudioFile   │────▶│ get_or_create(video_id) │
│             │     │ Manager     │     │                         │
└─────────────┘     └─────────────┘     └───────────┬─────────────┘
                                                     │
                          ┌──────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    StreamingAudioFile                            │
│                                                                  │
│   Download Task          │           MPV Reader                  │
│   ─────────────          │           ──────────                  │
│   1. HTTP GET range      │           1. Open file path           │
│   2. Receive chunk       │           2. Seek to position         │
│   3. write_at(off, data) │           3. read_at(offset, buf)     │
│   4. Notify condvar ─────┼──────────▶4. Wait if not available    │
│   5. Repeat until done   │           5. Read when ready          │
└─────────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### ADR-001: Unified Progressive File over EDL

**Decision**: Use a single progressive file instead of EDL syntax combining cache + stream URLs.

**Rationale**:
- EDL required MPV to manage two sources, causing seek complexity
- Progressive file gives full control over buffering behavior
- Simpler error handling (one source, one error path)
- Better seek support via `request_range()` priority mechanism

### Pre-allocation Strategy

**Decision**: Pre-allocate file to `content_length` at creation.

**Rationale**:
- Allows random-access writes without sparse file handling
- Provides atomic `is_complete()` check (single range `[0, len)`)
- Avoids filesystem fragmentation

### Condvar-based Blocking

**Decision**: `read_at()` blocks via `Condvar::wait()` until bytes available.

**Rationale**:
- Simpler than polling or async notification
- Natural backpressure when download is slower than playback
- MPV's read pattern is synchronous, matches well

### Mutex Pattern (CRITICAL Issue - To Be Fixed)

**Current**: Mutex held during disk I/O in `read_at()`.

**Problem**: Reader/writer contention, potential jitter.

**Fix (yrmpc-8f9)**: Clone needed data, release lock, then do I/O.

### Read Handle (CRITICAL Issue - To Be Fixed)

**Current**: `read_at()` opens new `File` handle every call.

**Problem**: Syscall overhead, file descriptor churn.

**Fix (yrmpc-jma)**: Add persistent `read_file` handle, use `FileExt::read_at` (pread).

## Configuration

```ron
// Configured via AudioFileManagerConfig
streaming: (
    cache_dir: "~/.cache/rmpc/streaming/",
    max_size_bytes: 104857600,  // 100 MB
)
```

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Audio stalls mid-track | Download slower than playback | Check network, `bytes_available_from()` |
| "Download failed" error | Network issue or URL expired | Check `has_error()`, URL resolver logs |
| High disk I/O | Frequent seeks or no caching | Check prefetch window, LRU eviction |
| Cache filling disk | Eviction not triggering | Check `max_size_bytes`, priority settings |
| Seek takes long time | Waiting for range download | Check `request_range()` being called |
| Memory growth | Too many files open | Check `file_count()`, eviction |

## Key Files

| File | Purpose |
|------|---------|
| `streaming_audio_file.rs` | Core streaming file implementation |
| `audio_file_manager.rs` | File lifecycle and cache management |
| `range_set.rs` | Byte range tracking |
| `services/playback_service.rs` | Uses manager for playback |

## See Also

- [playback-engine.md](playback-engine.md) - Overall playback architecture
- [YouTube backend README](../backends/youtube/README.md) - Backend overview
- [play-queue.md](play-queue.md) - Queue state management
