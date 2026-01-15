## Part 3: Proposed Solution - Layered Architecture

### 3.1 Architecture Overview

Three layers with clear responsibilities:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  LAYER 1: TUI (Backend-Agnostic)                                            │
│                                                                             │
│  KNOWS: Queue, playback state, user actions                                 │
│  SENDS: PlayIntent, QueueAction                                             │
│  RECEIVES: PlaybackState, QueueState                                        │
│  DOES NOT KNOW: video_id, ytx, ffmpeg, caching details                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ IPC (track_id is opaque string)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  LAYER 2: DAEMON CORE (Backend-Agnostic Coordinator)                        │
│                                                                             │
│  KNOWS: Queue management, urgency levels, playback coordination             │
│  USES: trait MediaPreparer (abstraction over backends)                      │
│  DOES NOT KNOW: How YouTube/Spotify extraction works                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ trait MediaPreparer
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  LAYER 3: BACKEND (YouTube/Spotify/Local Implementation)                    │
│                                                                             │
│  KNOWS: All backend-specific details                                        │
│  YouTube: video_id, ytx/yt-dlp, ffmpeg concat, prefix caching               │
│  Spotify: track URI, SDK, DRM handling                                      │
│  Local: file paths, direct playback                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Industry-Standard Naming

| Current Name | Proposed Name | Rationale |
|-------------|---------------|-----------|
| `CacheExecutor` | `MediaPreparer` | Describes WHAT (prepare media), not HOW |
| `UrlResolver` | `TrackResolver` | Generic track resolution |
| `AudioCache` | `AudioLoader` | Loads audio content |
| `FfmpegConcatSource` | `OutputBuilder` | Builds player-ready output |
| `PrepareResult` | `PreparedMedia` | Result of preparation |
| `Tier` | `Urgency` | Industry-standard term |
| `Tier::Immediate` | `Urgency::Critical` | User waiting NOW |
| `Tier::Gapless` | `Urgency::Seamless` | Gapless transition needed |
| `Tier::Eager` | `Urgency::Soon` | Upcoming tracks |
| `Tier::Background` | `Urgency::Opportunistic` | Low priority |
| `preload()` | `prefetch()` | Industry-standard term |
| `video_id` | `track_id` (at interface) | Backend-agnostic |

### 3.3 Core Trait: MediaPreparer

The main abstraction used by daemon core:

```rust
/// Backend-agnostic media preparation.
/// Daemon uses this trait. Each backend implements it.
pub trait MediaPreparer: Send + Sync {
    /// Prepare track for immediate playback.
    /// Blocks until ready (respecting urgency deadline).
    fn prepare(&self, track_id: &str, urgency: Urgency) -> Result<PreparedMedia>;
    
    /// Prefetch tracks for future playback (fire-and-forget).
    fn prefetch(&self, requests: &[PrefetchRequest]);
    
    /// Hint that track might be needed (speculative, lowest priority).
    /// Use case: Pre-resolve URLs when search results appear.
    fn hint(&self, track_id: &str, priority: HintPriority);
    
    /// Cancel pending work for a track.
    fn cancel(&self, track_id: &str);
    
    /// Check current preparation status.
    fn status(&self, track_id: &str) -> MediaStatus;
}
```

### 3.4 YouTube Backend Implementation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  YouTubeMediaPreparer                                                       │
│  (Implements MediaPreparer for YouTube backend)                             │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  resolver: Arc<dyn TrackResolver>                                     │  │
│  │    └── CachedResolver<RateLimited<Fallback<YtxResolver, YtDlpResolver>>>│ │
│  │                                                                       │  │
│  │  loader: Arc<dyn AudioLoader>                                         │  │
│  │    └── CachedLoader<PrefixLoader<HttpLoader>>                         │  │
│  │                                                                       │  │
│  │  output: Arc<dyn OutputBuilder>                                       │  │
│  │    └── ConcatOutputBuilder (ffmpeg concat+subfile)                    │  │
│  │                                                                       │  │
│  │  in_flight: DashMap<String, InFlightJob>  ← Coalescing                │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  impl MediaPreparer for YouTubeMediaPreparer {                              │
│      fn prepare(&self, track_id, urgency) -> PreparedMedia {                │
│          // 1. Coalesce concurrent requests (in_flight map)                 │
│          // 2. Resolve: resolver.resolve(track_id) → StreamInfo             │
│          // 3. Load: loader.load(track_id, stream_info, urgency)            │
│          // 4. Build: output.build(loaded_audio, stream_info)               │
│      }                                                                      │
│  }                                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.5 Internal Traits (Swappable Components)

```rust
/// Resolves track ID to stream information.
pub trait TrackResolver: Send + Sync {
    fn resolve(&self, track_id: &str) -> Result<StreamInfo>;
}

// Implementations (YouTube-specific):
// - YtxResolver (fast, preferred)
// - YtDlpResolver (fallback)
// - CachedResolver<R> (decorator: URL caching)
// - RateLimitedResolver<R> (decorator: rate limiting)
// - FallbackResolver<R1, R2> (decorator: fallback chain)
```

```rust
/// Loads audio content for playback.
pub trait AudioLoader: Send + Sync {
    fn load(&self, track_id: &str, stream: &StreamInfo, urgency: Urgency) 
        -> Result<LoadedAudio>;
    fn status(&self, track_id: &str) -> LoadStatus;
}

// Implementations:
// - PrefixLoader (first N bytes for gapless)
// - ChunkedLoader (progressive download)
// - PassthroughLoader (no caching)
// - CachedLoader<L> (decorator: disk caching)
```

```rust
/// Builds player-ready output.
pub trait OutputBuilder: Send + Sync {
    fn build(&self, audio: LoadedAudio, stream: &StreamInfo) -> PreparedMedia;
}

// Implementations:
// - ConcatOutputBuilder (ffmpeg concat+subfile for gapless)
// - DirectOutputBuilder (just URL, no gapless)
// - ProxyOutputBuilder (localhost proxy URL)
```

### 3.6 Decorator Chains (Your Proven Pattern)

Same pattern as existing CachedExtractor:

```
Resolver chain:
┌───────────────────────────────────────────────────────────────────────────┐
│  CachedResolver                         ← URL caching (6hr TTL)           │
│  ┌───────────────────────────────────────────────────────────────────────┐│
│  │ RateLimitedResolver                  ← Prevent API flooding           ││
│  │ ┌───────────────────────────────────────────────────────────────────┐ ││
│  │ │ FallbackResolver                   ← Try ytx first, then yt-dlp   │ ││
│  │ │ ┌─────────────────┐ ┌─────────────────────────────────────────────┐│││
│  │ │ │ YtxResolver     │ │ YtDlpResolver                               ││││
│  │ │ │ (200ms)         │ │ (4s fallback)                               ││││
│  │ │ └─────────────────┘ └─────────────────────────────────────────────┘│││
│  │ └───────────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────────┘

Loader chain:
┌───────────────────────────────────────────────────────────────────────────┐
│  CachedLoader                           ← Disk cache                      │
│  ┌───────────────────────────────────────────────────────────────────────┐│
│  │ PrefixLoader                         ← First 200KB only               ││
│  │ ┌───────────────────────────────────────────────────────────────────┐ ││
│  │ │ RateLimitedLoader                  ← Prevent bandwidth flood       │ ││
│  │ │ ┌───────────────────────────────────────────────────────────────┐  │││
│  │ │ │ HttpLoader                       ← Actual HTTP download        │  │││
│  │ │ └───────────────────────────────────────────────────────────────┘  │││
│  │ └───────────────────────────────────────────────────────────────────┘ ││
│  └───────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────────┘
```
