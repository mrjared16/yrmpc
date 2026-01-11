# ADR-001: Unified Streaming Audio File Architecture

**Status**: Proposed  
**Date**: 2026-01-12  
**Author**: Sisyphus (AI) + User  
**Supersedes**: Current EDL-based cache approach

---

## Context

### Current Architecture (EDL Splice)

```
┌─────────────────────────────────────────────────────────────────┐
│                     CURRENT APPROACH                            │
└─────────────────────────────────────────────────────────────────┘

  audio_cache.rs:
    - Downloads first 10s to ~/.cache/rmpc/audio/{id}.webm
    - Partial file (360KB at 288kbps)

  playback_service.rs:
    - Builds EDL URL: edl://{cache},length=10;{stream},start=10
    - Two separate sources for one track

  MPV Playback:
    1. Opens cache file → decoder init
    2. Plays 0-10s from cache
    3. Opens stream URL → decoder RE-INIT  ← Problem!
    4. Plays 10s+ from stream

  Result: ~20ms audio glitch at 10s mark
```

### Problems with Current Approach

1. **Decoder reinit glitch**: MPV treats cache and stream as two files
2. **Truncated WebM**: Partial download causes decoder errors at boundary
3. **Fixed boundary**: 10s is arbitrary, causes audible artifact
4. **No seek support**: Can't seek past cache without network latency

### User Requirements

1. **Instant playback**: Any queued song plays immediately (no network wait)
2. **Gapless transitions**: Zero gap between songs (future: crossfade)
3. **Minimal disk usage**: Limited disk space, can't store full songs
4. **Audiophile quality**: 20ms glitch is noticeable and unacceptable

---

## Decision

**Adopt the Unified Streaming Audio File pattern** inspired by librespot (Spotify's open-source client).

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                     NEW APPROACH                                │
└─────────────────────────────────────────────────────────────────┘

  StreamingAudioFile:
    - Pre-allocate temp file to full content-length
    - Background download fills file progressively
    - RangeSet tracks which bytes are downloaded
    - MPV reads from ONE file (no splice)

  Playback:
    1. MPV opens temp file → decoder init (ONCE)
    2. Reads bytes 0..N (already downloaded)
    3. Download continues in background
    4. MPV continues reading (same file, same decoder)
    5. If read catches up to download → natural buffering

  Result: ZERO glitch, ONE decoder session
```

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STREAMING AUDIO ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────┐  │
│  │   Queue     │────▶│  AudioFileManager │────▶│  StreamingAudioFile(s) │  │
│  │  Service    │     │                  │     │                         │  │
│  └─────────────┘     │  - get_or_create │     │  - file_path            │  │
│                      │  - prefetch_next │     │  - downloaded: RangeSet │  │
│                      │  - evict_lru     │     │  - write_file           │  │
│                      └──────────────────┘     │  - read_file            │  │
│                             │                 └────────────┬────────────┘  │
│                             │                              │               │
│                             ▼                              ▼               │
│                      ┌──────────────────┐     ┌─────────────────────────┐  │
│                      │  DownloadPool    │     │  Temp Files             │  │
│                      │  (3 concurrent)  │     │  ~/.cache/rmpc/audio/   │  │
│                      │                  │     │  {video_id}.webm.part   │  │
│                      └──────────────────┘     └─────────────────────────┘  │
│                                                            │               │
│                                                            ▼               │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────────────────┐  │
│  │  Playback   │────▶│  MPV (IPC)       │────▶│  File Read              │  │
│  │  Service    │     │  loadfile path   │     │  (single source)        │  │
│  └─────────────┘     └──────────────────┘     └─────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. QUEUE ADD EVENT                                                         │
│     └── QueueService.add(video_id)                                          │
│         └── UrlResolver.resolve(video_id) → stream_url (~200ms)             │
│         └── AudioFileManager.get_or_create(video_id, stream_url)            │
│             └── Create temp file, set_len(content_length)                   │
│             └── Spawn download task (if within prefetch window)             │
│                                                                             │
│  2. PREFETCH WINDOW (Sliding)                                               │
│                                                                             │
│     Queue: [A] [B] [C] [D] [E] [F] [G] ...                                  │
│             ▲                                                               │
│          Current                                                            │
│                                                                             │
│     Download Priority:                                                      │
│     ├── A (current):  FULL download, HIGH priority                          │
│     ├── B (next):     FULL download, MEDIUM priority                        │
│     ├── C (next+1):   30s prefetch, LOW priority                            │
│     ├── D (next+2):   30s prefetch, LOW priority                            │
│     └── E+ (beyond):  URL resolved only, NO download                        │
│                                                                             │
│  3. PLAY EVENT                                                              │
│     └── PlaybackService.play(video_id)                                      │
│         └── audio_file = AudioFileManager.get(video_id)                     │
│         └── audio_file.wait_for_minimum_bytes(64KB)?                        │
│         └── mpv.loadfile(audio_file.path())                                 │
│                                                                             │
│  4. TRACK ADVANCEMENT                                                       │
│     └── Current track ends (EOF from MPV)                                   │
│         └── QueueService.advance()                                          │
│         └── Reprioritize downloads:                                         │
│             ├── Old current (A): Mark for LRU eviction                      │
│             ├── B → Current: Already full, instant play                     │
│             ├── C → Next: RESUME download from prefetch offset              │
│             ├── D → Next+1: Keep 30s prefetch                               │
│             └── E → Next+2: Start 30s prefetch                              │
│                                                                             │
│  5. SEEK EVENT                                                              │
│     └── User seeks to position T                                            │
│         └── byte_offset = estimate_byte_position(T)                         │
│         └── if !audio_file.has_bytes(byte_offset):                          │
│             └── Pause current downloads                                     │
│             └── Priority download from byte_offset                          │
│             └── Block until minimum bytes available                         │
│         └── MPV seeks (file already has data or will soon)                  │
│                                                                             │
│  6. LRU EVICTION                                                            │
│     └── When total_size > max_size (100MB):                                 │
│         └── Find oldest non-playing file                                    │
│         └── Delete temp file                                                │
│         └── Remove from AudioFileManager                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### RangeSet: Byte Tracking

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RANGESET CONCEPT                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  File: 8,363,048 bytes total (4 min song at 288kbps)                        │
│                                                                             │
│  Download Progress (30s prefetch, then seek to 2:00):                       │
│                                                                             │
│  Bytes:  0        1.2MB    4.0MB    4.5MB              8.3MB                │
│          |         |        |        |                  |                   │
│          [█████████░░░░░░░░░█████████░░░░░░░░░░░░░░░░░░░]                   │
│          ▲         ▲        ▲        ▲                                      │
│          │         │        │        │                                      │
│          │         │        │        └── Download continuing                │
│          │         │        └── Seek requested here, priority downloaded    │
│          │         └── End of 30s prefetch                                  │
│          └── Start                                                          │
│                                                                             │
│  RangeSet state:                                                            │
│    downloaded: [(0, 1228800), (4000000, 4500000)]                           │
│    requested:  [(0, 1228800), (4000000, 8363048)]                           │
│                                                                             │
│  Operations:                                                                │
│    - contains(offset) → Is this byte downloaded?                            │
│    - add_range(start, end) → Mark bytes as downloaded                       │
│    - contiguous_from(offset) → How many bytes available from here?          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Prefetch Timing

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PREFETCH TIMING                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Current Track Timeline:                                                    │
│                                                                             │
│  0:00        1:00        2:00        3:00     3:30     4:00                 │
│  |           |           |           |        |        |                    │
│  [═══════════════════════════════════════════|████████]                     │
│  ▲                                           ▲        ▲                     │
│  │                                           │        │                     │
│  │                                           │        └── Track ends        │
│  │                                           │                              │
│  │                                           └── T-30s: Start FULL          │
│  │                                               download of next track     │
│  │                                                                          │
│  └── Track starts                                                           │
│                                                                             │
│  Why T-30s trigger?                                                         │
│  - 30s = enough buffer for network variance                                 │
│  - At 288kbps, 4min song = 8.3MB                                            │
│  - On 3Mbps connection: 8.3MB / 0.375MB/s = 22s                             │
│  - 30s trigger gives 8s margin for slow networks                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Struct Definitions (Conceptual)

```rust
/// Tracks downloaded byte ranges for a streaming file
pub struct RangeSet {
    ranges: Vec<(u64, u64)>,  // Sorted, non-overlapping
}

impl RangeSet {
    pub fn contains(&self, offset: u64) -> bool;
    pub fn add_range(&mut self, start: u64, end: u64);
    pub fn contiguous_from(&self, offset: u64) -> u64;
}

/// A single audio file being streamed/downloaded
pub struct StreamingAudioFile {
    pub video_id: String,
    pub file_path: PathBuf,
    pub content_length: u64,
    
    // File handles (separate for reader/writer)
    write_file: File,
    read_file: File,
    
    // Byte tracking
    downloaded: RwLock<RangeSet>,
    requested: RwLock<RangeSet>,
    
    // Synchronization
    data_available: Condvar,
    download_complete: AtomicBool,
    
    // Metadata
    created_at: Instant,
    last_accessed: AtomicU64,
}

/// Download priority levels
pub enum DownloadPriority {
    Current,   // Full download, immediate
    Next,      // Full download, background
    Prefetch,  // 30s only
    None,      // URL resolved, no download
}

/// Manages all streaming audio files
pub struct AudioFileManager {
    files: RwLock<HashMap<String, Arc<StreamingAudioFile>>>,
    download_pool: ThreadPool,  // Max 3 concurrent
    
    // Disk management
    cache_dir: PathBuf,
    max_size_bytes: u64,        // 100MB default
    current_size: AtomicU64,
    
    // Eviction
    lru_queue: Mutex<VecDeque<String>>,
}
```

---

## Migration Path

### Phase 1: Basic Streaming File (No EDL)

```
Current Flow:
  prefetch() → partial file → EDL URL → MPV

New Flow:
  get_or_create() → full download to temp → file path → MPV
```

**Changes:**
- Replace `AudioCache` with `AudioFileManager`
- Replace `build_playback_url()` EDL logic with simple file path
- Remove `escape_edl_segment()` and EDL constants

### Phase 2: RangeSet + Resume Downloads

**Changes:**
- Add `RangeSet` for byte tracking
- Implement `resume_download()` from arbitrary offset
- Handle seek to undownloaded regions

### Phase 3: Sliding Prefetch Window

**Changes:**
- Implement priority-based download queue
- T-30s trigger for next track full download
- LRU eviction when over disk limit

### Phase 4: Edge Cases + Polish

**Changes:**
- URL expiration handling (re-resolve + resume)
- Network error recovery
- Graceful degradation (fall back to direct stream)

---

## Files Affected

| File | Change Type | Description |
|------|-------------|-------------|
| `audio_cache.rs` | **DELETE** | Replaced by `streaming_audio_file.rs` |
| `streaming_audio_file.rs` | **NEW** | Core streaming file implementation |
| `audio_file_manager.rs` | **NEW** | Manages multiple streaming files |
| `range_set.rs` | **NEW** | Byte range tracking |
| `playback_service.rs` | **MODIFY** | Use file path instead of EDL |
| `orchestrator.rs` | **MODIFY** | Trigger prefetch on T-30s |
| `queue_service.rs` | **MODIFY** | Notify AudioFileManager on queue changes |

---

## Alternatives Considered

### 1. HTTP Proxy (localhost)

**Approach**: Serve cache + stream as one HTTP response
**Rejected because**: 
- More complexity (HTTP server in daemon)
- Still needs byte tracking for seeks
- No advantage over file-based approach

### 2. MPV Native Cache

**Approach**: Rely on `--cache=yes --cache-secs=N`
**Rejected because**:
- Doesn't solve decoder reinit on EDL boundaries
- Can't control prefetch granularity

### 3. FFmpeg Concat Demuxer

**Approach**: Use FFmpeg to concat cache + stream
**Rejected because**:
- Still two sources = decoder reinit issue
- Extra process overhead

### 4. Named Pipe (FIFO)

**Approach**: Feed bytes to MPV via pipe
**Rejected because**:
- FIFOs are NOT seekable
- User can't seek in track

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| MPV hits incomplete WebM cluster | Medium | Playback fails | Only expose complete clusters |
| URL expires mid-download | Medium | 403 error | Re-resolve + resume from offset |
| Disk fills up | Low | Crash | Aggressive LRU eviction |
| Race condition (reader/writer) | Low | Corruption | Use librespot's proven patterns |
| Slow network | Medium | User waits | Show buffer indicator |

---

## Success Metrics

1. **Zero audible glitch** at any point during playback
2. **Instant start** (<100ms) for any queued song
3. **Disk usage < 50MB** typical, < 100MB max
4. **Gapless track transitions** with `--gapless-audio=yes`
5. **Seek works** to any position (may briefly buffer if undownloaded)

---

## References

- [librespot audio fetch implementation](https://github.com/librespot-org/librespot/tree/dev/audio/src/fetch)
- [WebM container specification](https://www.webmproject.org/docs/container/)
- [MPV EDL documentation](https://github.com/mpv-player/mpv/blob/master/DOCS/edl-mpv.rst)
