## Part 2: Problems with Previous Solutions

### 2.1 Problem Analysis: Why ADR-002 Failed

#### Problem 1: No Composition Root

ADR-002 specified components but never specified WHO creates and shares them:

```
ADR-002 said:
  "CacheExecutor handles ALL cache work"
  "UrlResolver extracts URLs"
  "AudioCache manages prefix files"

ADR-002 never said:
  "There is ONE UrlResolver instance"
  "YouTubeServer creates it and passes to all consumers"
  "Creating new instances is forbidden"
```

Without explicit ownership, implementers created new instances everywhere.

#### Problem 2: YouTubeServices Exposed Internals

First fix attempt was a service registry:

```rust
struct YouTubeServices {
    url_resolver: Arc<UrlResolver>,
    audio_cache: Arc<AudioCache>,
    cache_executor: CacheExecutorHandle,
}

// Getters expose internals
fn url_resolver(&self) -> Arc<UrlResolver> { ... }
fn audio_cache(&self) -> Arc<AudioCache> { ... }
```

**Problem**: Consumers could bypass CacheExecutor:

```rust
// BYPASS: Calls resolver directly, skips coalescing!
let url = services.url_resolver().get_url(video_id)?;
```

This is a "bag of services", not a coherent abstraction.

#### Problem 3: CacheExecutor Was Monolithic

```rust
struct CacheExecutor {
    url_resolver: Arc<UrlResolver>,     // Fixed type
    audio_cache: Arc<AudioCache>,       // Fixed type
    // ...
}
```

Problems:
- Cannot swap URL resolution strategy
- Cannot swap caching strategy  
- Cannot add proxy-based streaming
- Cannot reuse for Spotify backend
- All YouTube-specific, nothing reusable

#### Problem 4: Naming Was YouTube-Specific

| Current Name | Problem |
|-------------|---------|
| `video_id` | YouTube-specific |
| `UrlResolver` | Not all backends use URLs |
| `AudioCache` | Conflates storage, fetching, caching |
| `CacheExecutor` | Describes HOW, not WHAT |
| `Tier` | Not industry-standard |

### 2.2 The Playback Flow Problem

Current flow with problems annotated:

```
User clicks "Play Album"
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  TUI: play(PlayIntent::Context { tracks, offset })                          │
│                                                                             │
│  PROBLEM: TUI has to know about PlayIntent structure.                       │
│  Should just send action + track IDs.                                       │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Daemon: handle_play_intent()                                               │
│                                                                             │
│  1. queue.replace(tracks)                                                   │
│  2. cache_executor.preload(track[1..], Gapless/Background)                  │
│  3. cache_executor.prepare(track[0], Immediate)                             │
│                                                                             │
│  PROBLEM: Daemon directly uses CacheExecutor (YouTube-specific).            │
│  Should use trait MediaPreparer (backend-agnostic).                         │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  CacheExecutor.prepare():                                                   │
│                                                                             │
│  1. url_resolver.extract_one(video_id)                                      │
│  2. audio_cache.ensure_prefix(video_id, url)                                │
│  3. build_concat_url(prefix_path, url)                                      │
│                                                                             │
│  PROBLEMS:                                                                  │
│  - url_resolver is concrete Arc<UrlResolver>, not trait                     │
│  - audio_cache is concrete Arc<AudioCache>, not trait                       │
│  - build_concat_url is hardcoded, not swappable                             │
│  - No way to use proxy mode, memory-only cache, etc.                        │
└─────────────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  FfmpegConcatSource.build_mpv_input():                                      │
│                                                                             │
│  PROBLEM: Uses DIFFERENT resolver via closure!                              │
│  let url = (self.url_fn)(video_id)?;  // Different cache!                   │
│                                                                             │
│  This is where the bug lived.                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Extension Scenarios That Current Design Cannot Handle

| Scenario | Current Support | What's Missing |
|----------|-----------------|----------------|
| Pre-extract on search results | ❌ | `hint()` API |
| Proxy-based streaming | ❌ | `OutputBuilder` trait |
| Memory-only cache | ❌ | `AudioLoader` trait |
| S3-backed cache | ❌ | `AudioLoader` trait |
| Spotify backend | ❌ | Generic `MediaPreparer` |
| Local files backend | ❌ | Generic `MediaPreparer` |
| Custom scheduling | ⚠️ | `Scheduler` trait |

### 2.4 Key Insight: Deadline Contract

From architecture review, the universal truth about audio playback:

```
"Playback is a real-time CONTRACT: deliver audible samples on time.
 Everything else exists only to keep that contract unbroken."
```

Implications:
- "Late" is indistinguishable from "broken" (gaps, silence)
- Gapless = next track ready BEFORE current ends
- Fastest first-audio = minimize CRITICAL PATH
- Everything else = SPECULATION (can fail gracefully)

Current Tier system already implements this:
- `Immediate` = critical path, 200ms deadline
- `Gapless` = must be ready before track ends
- `Eager/Background` = speculation

The concept is right. The implementation needs traits.
