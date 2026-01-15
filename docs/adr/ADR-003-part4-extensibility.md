## Part 4: Extensibility & Configuration

### 4.1 Extension Scenarios Now Possible

#### Scenario 1: Pre-extract on Search Results

```rust
// User's aggressive optimization in custom search pane
fn on_search_results(&self, results: Vec<Track>) {
    for track in results.iter().take(5) {
        // Hint: might need this, lowest priority
        self.preparer.hint(&track.id, HintPriority::SearchResult);
    }
}

// Later, when user clicks play
fn on_play(&self, track_id: &str) {
    // URL already cached! Only audio loading on critical path
    let media = self.preparer.prepare(track_id, Urgency::Critical)?;
}
```

#### Scenario 2: Proxy-Based Streaming

```rust
let preparer = YouTubeMediaPreparer::builder()
    .resolver(default_resolver())
    .loader(ChunkedLoader::new())
    .output(ProxyOutputBuilder::new(server))  // Swap output builder
    .build();

// MPV receives: http://localhost:8080/abc123
// Proxy handles seeking, buffering, chunk management
```

#### Scenario 3: Memory-Only Cache (Embedded Devices)

```rust
let preparer = YouTubeMediaPreparer::builder()
    .resolver(CachedResolver::memory_only(YtxResolver::new(), 100_mb))
    .loader(MemoryLoader::new(50_mb))  // No disk writes
    .output(PassthroughOutputBuilder)   // No concat, just URL
    .build();
```

#### Scenario 4: S3-Backed Cache (Cloud Deployment)

```rust
let preparer = YouTubeMediaPreparer::builder()
    .resolver(YtxResolver::new())
    .loader(S3CachedLoader::new(HttpLoader::new(), s3_bucket))
    .output(ConcatOutputBuilder::new())
    .build();
```

#### Scenario 5: Different Backend (Spotify)

```rust
impl MediaPreparer for SpotifyMediaPreparer {
    fn prepare(&self, track_id: &str, urgency: Urgency) -> Result<PreparedMedia> {
        // Spotify-specific: SDK handles everything
        let token = self.spotify_api.get_playback_token(track_id)?;
        Ok(PreparedMedia::SpotifyStream { token })
    }
    
    fn prefetch(&self, requests: &[PrefetchRequest]) {
        // Spotify SDK handles prefetching internally
        for req in requests {
            self.spotify_api.prefetch(&req.track_id);
        }
    }
}

// Daemon code unchanged - uses trait MediaPreparer
```

#### Scenario 6: Local Files Backend

```rust
impl MediaPreparer for LocalMediaPreparer {
    fn prepare(&self, track_id: &str, _urgency: Urgency) -> Result<PreparedMedia> {
        let path = PathBuf::from(track_id);
        if path.exists() {
            Ok(PreparedMedia::LocalFile { path })
        } else {
            Err(MediaError::NotFound)
        }
    }
    
    fn prefetch(&self, _requests: &[PrefetchRequest]) {
        // No-op: local files don't need prefetching
    }
    
    fn hint(&self, _track_id: &str, _priority: HintPriority) {
        // No-op
    }
}
```

### 4.2 Builder Pattern Configuration

```rust
// Default configuration (zero config)
let preparer = YouTubeMediaPreparer::new(&config);

// Custom configuration (full control)
let preparer = YouTubeMediaPreparer::builder()
    .resolver(
        CachedResolver::new(
            RateLimitedResolver::new(
                FallbackResolver::new(YtxResolver::new(), YtDlpResolver::new()),
                RateLimit::new(10, Duration::from_secs(1)),
            ),
            Duration::from_secs(6 * 3600),  // 6 hour TTL
        )
    )
    .loader(
        CachedLoader::new(
            PrefixLoader::new(HttpLoader::new(), 200 * 1024),  // 200KB prefix
            DiskStore::new("/cache/audio", 500_mb),
        )
    )
    .output(ConcatOutputBuilder::new())
    .build();
```

### 4.3 Urgency Levels (Replaces Tier)

```rust
pub enum Urgency {
    /// User is waiting NOW. 200ms deadline.
    /// If deadline missed, fallback to direct URL (no gapless).
    Critical,
    
    /// Next track. Must be ready before current track ends.
    /// Deadline: current_track_duration - 5s
    Seamless,
    
    /// Upcoming tracks (2-10 in queue).
    /// Deadline: 30s
    Soon,
    
    /// Low priority prefetch. No deadline.
    /// Can be cancelled if higher priority work arrives.
    Opportunistic,
}
```

### 4.4 Prepared Media Output

```rust
pub enum PreparedMedia {
    /// Gapless-ready: ffmpeg concat+subfile protocol
    Concat {
        mpv_input: String,     // concat:{prefix}|subfile,...,:{url}
        duration: Duration,
    },
    
    /// Direct URL: instant but no gapless guarantee
    Direct {
        url: String,
        duration: Duration,
    },
    
    /// Proxy URL: localhost serves the stream
    Proxy {
        url: String,           // http://localhost:8080/{token}
        duration: Duration,
    },
    
    /// Local file path
    LocalFile {
        path: PathBuf,
        duration: Duration,
    },
    
    /// Spotify SDK stream
    SpotifyStream {
        token: String,
        duration: Duration,
    },
}
```

## Part 5: Migration Path

### 5.1 Incremental Migration (No Breaking Changes)

```
Phase 1: Add traits alongside existing code
──────────────────────────────────────────────────────────────────────────────
  - Define trait MediaPreparer
  - Define trait TrackResolver  
  - Define trait AudioLoader
  - Define trait OutputBuilder
  - Existing code continues to work

Phase 2: Implement traits on existing types
──────────────────────────────────────────────────────────────────────────────
  - impl TrackResolver for UrlResolver
  - impl AudioLoader for AudioCache
  - impl OutputBuilder for FfmpegConcatSource
  - impl MediaPreparer for CacheExecutor (wrapper)
  - Existing code continues to work

Phase 3: Update daemon to use traits
──────────────────────────────────────────────────────────────────────────────
  - PlaybackCoordinator uses Arc<dyn MediaPreparer>
  - Inject YouTubeMediaPreparer at startup
  - TUI unchanged

Phase 4: Rename and clean up
──────────────────────────────────────────────────────────────────────────────
  - CacheExecutor → YouTubeMediaPreparer
  - UrlResolver → YtxResolver/YtDlpResolver (with trait TrackResolver)
  - AudioCache → PrefixLoader (with trait AudioLoader)
  - Tier → Urgency
  - preload → prefetch
  - Remove YouTubeServices (no longer needed)
```

### 5.2 File Changes

| Current File | New File | Change Type |
|-------------|----------|-------------|
| `services/cache_executor.rs` | `media/preparer.rs` | Rename + trait extract |
| `url_resolver.rs` | `media/resolver.rs` | Rename + trait extract |
| `audio/cache.rs` | `media/loader.rs` | Rename + trait extract |
| `audio/sources/concat.rs` | `media/output.rs` | Rename + trait extract |
| - | `media/mod.rs` | New: exports traits |
| - | `media/youtube/mod.rs` | New: YouTube implementations |

### 5.3 Logic Preservation

All existing logic is preserved, just restructured:

| Current Logic | New Location | Changes |
|---------------|--------------|---------|
| URL extraction with ytx/yt-dlp | `YtxResolver`, `YtDlpResolver` | None |
| URL caching with TTL | `CachedResolver<R>` decorator | None |
| Rate limiting | `RateLimitedResolver<R>` decorator | None |
| Fallback chain | `FallbackResolver<R1, R2>` decorator | None |
| Prefix download | `PrefixLoader` | None |
| Disk caching | `CachedLoader<L>` decorator | None |
| Concat URL building | `ConcatOutputBuilder` | None |
| In-flight coalescing | `YouTubeMediaPreparer.in_flight` | None |
| Tier-based scheduling | Urgency enum + deadline logic | Rename only |
