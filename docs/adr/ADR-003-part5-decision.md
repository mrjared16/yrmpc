## Part 6: Decision & Summary

### 6.1 Decision

**Adopt the layered, trait-based MediaPreparer architecture.**

This decision is based on:
1. Alignment with project philosophy (loosely coupled, community extensible)
2. Proven decorator pattern already successful with Extractor
3. Minimal logic changes (rename + trait extraction)
4. Enables all identified extension scenarios
5. Backend-agnostic foundation for future backends

### 6.2 Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              TUI LAYER                                      │
│                         (Backend-Agnostic)                                  │
│                                                                             │
│   Sends: PlayIntent { action, tracks }                                      │
│   Knows: track has id, title, artist, duration                              │
│   Does NOT know: video_id, ytx, ffmpeg, caching                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DAEMON CORE                                       │
│                      (Backend-Agnostic Coordinator)                         │
│                                                                             │
│   Uses: trait MediaPreparer                                                 │
│   Manages: Queue, urgency, playback coordination                            │
│   Does NOT know: How backends prepare media                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND LAYER                                       │
│              (YouTubeMediaPreparer / SpotifyMediaPreparer / etc)            │
│                                                                             │
│   Implements: trait MediaPreparer                                           │
│   Uses internally:                                                          │
│     - trait TrackResolver (with decorator chain)                            │
│     - trait AudioLoader (with decorator chain)                              │
│     - trait OutputBuilder (swappable output format)                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Trait Hierarchy

```
trait MediaPreparer                    ← Daemon uses this (backend-agnostic)
    │
    └── YouTubeMediaPreparer           ← YouTube implementation
            │
            ├── resolver: Arc<dyn TrackResolver>
            │       └── CachedResolver<RateLimited<Fallback<Ytx, YtDlp>>>
            │
            ├── loader: Arc<dyn AudioLoader>
            │       └── CachedLoader<PrefixLoader<HttpLoader>>
            │
            └── output: Arc<dyn OutputBuilder>
                    └── ConcatOutputBuilder
```

### 6.4 Key Design Principles Enforced

| Principle | How Enforced |
|-----------|--------------|
| No bypass | MediaPreparer is ONLY public API. No access to resolver/loader |
| Sharing automatic | Components created once in builder, passed as Arc |
| Decorator pattern | Same as CachedExtractor - proven to work |
| Backend agnostic | Daemon uses trait, not concrete type |
| Configurable | Builder pattern at every layer |
| Industry naming | MediaPreparer, TrackResolver, Urgency, prefetch |

### 6.5 Gapless Optimization Flow (Fixed)

```
User clicks "Play Album" (50 tracks)
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Daemon: PlaybackCoordinator                                                │
│                                                                             │
│  1. queue.set(tracks)                                                       │
│  2. preparer.prefetch([                                                     │
│        (track[1], Urgency::Seamless),      ← Gapless for next track         │
│        (track[2..10], Urgency::Soon),      ← Eager for upcoming             │
│     ])                                                                      │
│  3. let media = preparer.prepare(track[0], Urgency::Critical)               │
│  4. player.play(media)                                                      │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  YouTubeMediaPreparer.prepare(track[0], Critical):                          │
│                                                                             │
│  1. Coalesce: check in_flight map                                           │
│  2. Resolve: resolver.resolve(track_id) → StreamInfo                        │
│     └── CachedResolver checks cache → MISS → YtxResolver extracts           │
│  3. Load: loader.load(track_id, stream_info, Critical)                      │
│     └── CachedLoader checks disk → MISS → PrefixLoader downloads 200KB      │
│     └── Deadline: 200ms. If timeout → return Direct (no prefix)             │
│  4. Build: output.build(loaded_audio, stream_info)                          │
│     └── ConcatOutputBuilder creates concat:{prefix}|subfile,...,:{url}      │
│  5. Return PreparedMedia::Concat { mpv_input, duration }                    │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Meanwhile (parallel): prefetch(track[1], Seamless)                         │
│                                                                             │
│  Same flow, but:                                                            │
│  - No immediate deadline pressure                                           │
│  - Stores in SAME resolver cache (Arc shared!)                              │
│  - Stores in SAME loader cache (Arc shared!)                                │
│                                                                             │
│  When track[0] ends and track[1] is needed:                                 │
│  - resolver.resolve(track[1]) → CACHE HIT! (same Arc)                       │
│  - loader.load(track[1]) → CACHE HIT! (same Arc)                            │
│  - Gapless transition achieved                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.6 Why Previous Bug Cannot Happen

```
BEFORE (Bug possible):
────────────────────────────────────────────────────────────────────────────────
  server/mod.rs created multiple UrlResolver instances.
  Each had own cache. Sharing was by discipline, not structure.

AFTER (Bug impossible):
────────────────────────────────────────────────────────────────────────────────
  YouTubeMediaPreparer.builder() creates ONE resolver, ONE loader.
  Passes Arc<dyn TrackResolver> to internal components.
  No public access to create new resolvers.
  Sharing enforced by ENCAPSULATION, not discipline.
```

### 6.7 Future Work

1. **Implement Spotify backend** - `SpotifyMediaPreparer`
2. **Implement Local files backend** - `LocalMediaPreparer`
3. **Add proxy output mode** - `ProxyOutputBuilder`
4. **Add chunk-based loading** - `ChunkedLoader`
5. **Add adaptive scheduling** - Network-aware urgency adjustment

### 6.8 References

- ADR-001: Audio Streaming Architecture (ffmpeg concat+subfile)
- ADR-002: PlayIntent Architecture (intent system, tier-based prefetch)
- docs/arch/playback-flow.md: Detailed playback flow documentation

---

## Appendix A: Type Definitions Summary

```rust
// === PUBLIC API (Daemon uses these) ===

pub trait MediaPreparer: Send + Sync {
    fn prepare(&self, track_id: &str, urgency: Urgency) -> Result<PreparedMedia>;
    fn prefetch(&self, requests: &[PrefetchRequest]);
    fn hint(&self, track_id: &str, priority: HintPriority);
    fn cancel(&self, track_id: &str);
    fn status(&self, track_id: &str) -> MediaStatus;
}

pub enum Urgency { Critical, Seamless, Soon, Opportunistic }
pub enum PreparedMedia { Concat{..}, Direct{..}, Proxy{..}, LocalFile{..} }
pub enum MediaStatus { Cold, Resolving, Loading{pct}, Ready }

// === INTERNAL TRAITS (Backend swaps these) ===

pub trait TrackResolver: Send + Sync {
    fn resolve(&self, track_id: &str) -> Result<StreamInfo>;
}

pub trait AudioLoader: Send + Sync {
    fn load(&self, id: &str, stream: &StreamInfo, urgency: Urgency) -> Result<LoadedAudio>;
    fn status(&self, id: &str) -> LoadStatus;
}

pub trait OutputBuilder: Send + Sync {
    fn build(&self, audio: LoadedAudio, stream: &StreamInfo) -> PreparedMedia;
}
```

---

**End of ADR-003**
