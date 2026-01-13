# ADR-001: Audio Streaming Architecture for Gapless Playback

## Status

**Accepted** - Validated via POC testing (2025-01-13)

## Context

yrmpc is a YouTube Music TUI client. We need gapless audio playback where songs in the queue play instantly without network delay after the initial load.

### Problem Statement

The original EDL approach failed:
```
edl://cache.opus,0,10;{youtube_url},10,
                   ↑              ↑
              TIME offset    TIME offset
```

**Flaw**: EDL uses TIME offsets, not BYTE offsets. The cache file ends at BYTE 200,000, but YouTube stream seeks to TIME 10.0s (which might be BYTE 198,000 or 202,000). Result: 5-50ms audible gap/pop at junction.

## Decision Drivers

From user requirements (`.sisyphus/drafts/clarification.md`):

| Priority | Requirement |
|----------|-------------|
| 1 | Gapless after first wait - play every song in queue without network wait |
| 2 | Cache budget: <200MB for up to 100 songs (~200KB per song) |
| 3 | First play latency acceptable, subsequent plays must be instant |
| 4 | Uninterrupted playback > Instant queue play > Allow interrupt outside queue |
| 5 | Minimum 50Mbps network assumption |

## Considered Options

### Option 1: Original EDL Approach (REJECTED)

```
edl://cache.opus,0,10;{youtube_url},10,
```

- ✅ Lightweight (~200KB per song cache)
- ✅ Simple implementation
- ❌ **TIME offset ≠ BYTE offset → audible gap at junction**

### Option 2: ProgressiveAudioFile + HTTP Proxy (REJECTED)

Pre-allocate full 4MB file per song, HTTP proxy with blocking reads (condvar), RangeSet byte tracking.

- ✅ Byte-perfect
- ❌ **4MB × 100 songs = 400MB (violates <200MB constraint)**
- ❌ Complex infrastructure (condvar, mutex, RangeSet)
- ❌ Over-engineered for the problem

### Option 3: ffmpeg concat + subfile with byte offset (ACCEPTED)

```
concat:/cache.m4a|subfile,,start,200000,end,0,,:$YOUTUBE_URL
```

With protocol whitelist: `file,http,https,tcp,tls,crypto,subfile,concat`

- ✅ **Byte-perfect** (verified via PCM MD5 comparison)
- ✅ Lightweight (~200KB per song cache)
- ✅ Uses existing ffmpeg/MPV capabilities (no custom proxy)
- ✅ Supports seeking (MPV can do Range reads)
- ⚠️ Requires protocol_whitelist configuration

### Option 4: Minimal HTTP Splice Proxy (FALLBACK)

Tiny proxy (~200 lines) that serves cached prefix + upstream bytes.

- ✅ Byte-perfect
- ✅ ~200KB per song cache
- ✅ Supports seeking
- ⚠️ More code than Option 3
- ⚠️ New component to maintain

## Decision

**Use Option 3: ffmpeg concat + subfile protocol**

### Syntax

```
concat:/path/to/cache/{video_id}.m4a|subfile,,start,{BYTE_OFFSET},end,0,,:${YOUTUBE_STREAM_URL}
```

### MPV Configuration

```
--demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat
```

Or via `mpv.conf`:
```
demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat
```

### Workflow

1. **Prefetch**: Download first N bytes (e.g., 200KB) of each song in queue
   ```
   GET {youtube_url}
   Range: bytes=0-199999
   Save to: ~/.cache/rmpc/audio/{video_id}.m4a
   Store: content_length (for byte offset calculation)
   ```

2. **On Play**: Build concat URL
   ```
   concat:~/.cache/rmpc/audio/{video_id}.m4a|subfile,,start,200000,end,0,,:${youtube_url}
   ```

3. **MPV plays**: Reads cache instantly, streams remainder from YouTube at correct byte offset

## Consequences

### Positive

- **Byte-perfect audio**: Verified via decoded PCM MD5 comparison (identical hashes)
- **Lightweight cache**: ~200KB per song (100 songs = 20MB)
- **No custom infrastructure**: Uses existing ffmpeg/MPV protocols
- **Instant playback**: Cached prefix plays immediately
- **Seeking works**: MPV can seek within the concat stream

### Negative

- **Protocol whitelist required**: Must configure `protocol_whitelist` in MPV
- **URL escaping**: YouTube URLs contain special characters that may need escaping for concat syntax
- **URL expiry**: YouTube URLs expire (~6 hours). Need to handle re-resolution for long sessions.

### Risks

| Risk | Mitigation |
|------|------------|
| Protocol whitelist not set | Add to default MPV config in yrmpc |
| URL contains `|` character | URL-encode or escape properly |
| YouTube URL expires mid-song | Fallback to direct URL; refresh URLs proactively |
| subfile protocol removed in future ffmpeg | Unlikely (stable protocol); fallback to HTTP proxy |

## Validation Results (POC)

Tested on 2025-01-13 with real YouTube audio:

```bash
# Cache prefix (200KB)
curl -r 0-199999 "$YOUTUBE_URL" -o /tmp/cache_prefix.m4a

# Concat with byte-offset suffix
ffprobe -protocol_whitelist file,http,https,tcp,tls,crypto,subfile,concat \
  "concat:/tmp/cache_prefix.m4a|subfile,,start,200000,end,0,,:$YOUTUBE_URL"

# Result: Duration 213.089s (matches original)
```

**PCM Comparison**:
```
Original:  95b18b494d5e777c111f934b89b99b9f  (MD5 of decoded PCM)
Concat:    95b18b494d5e777c111f934b89b99b9f  (MD5 of decoded PCM)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                    IDENTICAL
```

## Implementation Notes

### Key Functions to Modify

1. **Prefetch** (`audio_cache.rs` or equivalent):
   - Download `Range: bytes=0-{CACHE_SIZE}` 
   - Store `content_length` from response headers
   - Save to `~/.cache/rmpc/audio/{video_id}.m4a`

2. **Build Playback URL** (`playback_service.rs`):
   ```rust
   fn build_playback_url(video_id: &str, cache_path: &Path, cache_size: u64, stream_url: &str) -> String {
       format!(
           "concat:{}|subfile,,start,{},end,0,,:{}",
           cache_path.display(),
           cache_size,
           stream_url
       )
   }
   ```

3. **MPV Configuration**:
   - Set `demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat`

### Escaping Rules

The `subfile` protocol uses `,,` as option separator. If URL contains `,,`, it needs escaping. Current YouTube URLs don't contain this pattern.

## References

- [ffmpeg subfile protocol docs](https://ffmpeg.org/ffmpeg-protocols.html#subfile)
- Commit `d819ee0b2dea` - Previous EDL implementation (replaced)

## Pluggable Architecture (Future-Proofing)

To support future features (offline mode, metrics, URL refresh), the implementation uses a **Strategy Pattern**:

### Trait Definition

```rust
/// Return type for MPV input - URL + any required MPV args
pub struct MpvInput {
    pub url: String,
    pub mpv_args: Vec<String>,  // e.g., protocol_whitelist for concat
}

/// Pluggable audio source strategy
pub trait MpvAudioSource: Send {
    fn startup(&mut self) -> anyhow::Result<()> { Ok(()) }
    fn shutdown(&mut self) {}
    fn build_mpv_input(&mut self, video_id: &str) -> anyhow::Result<MpvInput>;
}
```

### Implementations

| Strategy | Status | Use Case |
|----------|--------|----------|
| `ConcatSource` | **DEFAULT** | Normal playback, stateless, ~50 lines |
| `ProxySource` | FUTURE | Offline mode, metrics, URL refresh, seek handling |

### Shared Infrastructure

Both strategies share `AudioCache`:
- Prefix files: `~/.cache/rmpc/audio/{video_id}.m4a` (~200KB)
- Metadata: `content_length`, `expires_at`
- LRU eviction: <200MB budget
- API: `ensure_prefix(video_id)` → guarantees instant start

### Code Structure

```
rmpc/src/backends/youtube/audio/
├── mod.rs                      # Module exports
├── cache.rs                    # AudioCache (shared prefix/eviction)
├── mpv_source.rs               # MpvAudioSource trait + MpvInput
├── sources/
│   ├── concat.rs               # ConcatSource (DEFAULT)
│   └── proxy/                  # ProxySource (FUTURE)
│       ├── mod.rs
│       └── server.rs
└── range_set.rs                # Keep for proxy seek/metrics
```

### SOLID Principles Applied

| Principle | Application |
|-----------|-------------|
| Single Responsibility | AudioCache handles caching. Sources handle MPV presentation. |
| Open/Closed | New strategy = new MpvAudioSource impl. No caller changes. |
| Liskov Substitution | ConcatSource and ProxySource are interchangeable. |
| Interface Segregation | MpvAudioSource has only 3 methods. |
| Dependency Inversion | PlaybackService depends on trait, not concrete impl. |

### Decision: Existing ProgressiveAudioFile

The existing `ProgressiveAudioFile`, `AudioFileManager`, and `RangeSet` from commits `d819ee0b2dea` and `457e9d24f61d` are:

| Component | Decision | Rationale |
|-----------|----------|-----------|
| `RangeSet` | **KEEP** | Useful for proxy seek tracking and metrics |
| `ProgressiveAudioFile` | **REFACTOR** | Rename to `RangedCacheFile`, align with shared cache path |
| `AudioFileManager` | **DELETE** | Replace with simpler `AudioCache` |

These components are currently dormant (not connected to playback). They will be integrated when `ProxySource` is implemented.

## Changelog

| Date | Change |
|------|--------|
| 2025-01-13 | Initial draft, validated via POC |
| 2025-01-13 | Added pluggable architecture (MpvAudioSource trait) |
| 2025-01-13 | Documented decision on ProgressiveAudioFile (keep RangeSet, refactor file, delete manager) |
