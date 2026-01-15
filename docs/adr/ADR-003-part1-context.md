# ADR-003: Backend-Agnostic Media Preparation Architecture

**Status**: Proposed  
**Date**: 2026-01-17  
**Supersedes**: ADR-002 (partially - retains intent system, replaces CacheExecutor design)

---

## Part 1: Context, Philosophy & Evolution

### 1.1 Project Vision

yrmpc is a YouTube Music TUI client prioritizing:
1. **Fastest time-to-first-audio** (<500ms from click to sound)
2. **Gapless playback** (no stutter between tracks)
3. **Extensible architecture** (community can implement alternatives)

### 1.2 Design Philosophy (Non-Negotiable Principles)

These principles emerged from real implementation experience:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PRINCIPLE 1: LOOSELY COUPLED                                               │
│                                                                             │
│  "Community can implement their own if they can do it better."              │
│                                                                             │
│  Every major component should be a trait, not a concrete struct.            │
│  Users should be able to swap implementations without forking.              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  PRINCIPLE 2: DECORATOR PATTERN FOR CROSS-CUTTING CONCERNS                 │
│                                                                             │
│  Proven successful with Extractor:                                          │
│                                                                             │
│    CachedExtractor<FallbackExtractor<YtxExtractor, YtDlpExtractor>>        │
│                                                                             │
│  Caching, rate limiting, retries, fallbacks = decorators, not services.    │
│  Each layer is independent, testable, composable.                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  PRINCIPLE 3: INTENT-DRIVEN API                                             │
│                                                                             │
│  TUI sends WHAT (PlayIntent), not HOW.                                      │
│  Backend decides how to optimize for that intent.                           │
│                                                                             │
│    PlayIntent::Context { tracks, offset }  →  "Play album from track 3"    │
│    PlayIntent::Next                        →  "Skip to next"               │
│                                                                             │
│  Intent enables intelligent prefetching without TUI knowing details.        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  PRINCIPLE 4: BACKEND AGNOSTIC                                              │
│                                                                             │
│  TUI should work with YouTube, Spotify, local files, or future backends.   │
│  All backend-specific knowledge stays in backend implementations.          │
│                                                                             │
│  TUI knows: tracks have id, title, artist, duration                        │
│  TUI does NOT know: video_id, ytx, yt-dlp, ffmpeg, concat protocol         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  PRINCIPLE 5: CONFIGURABLE WITHOUT CODE CHANGE                              │
│                                                                             │
│  Builder pattern at every layer.                                            │
│  Power users can tune behavior via configuration.                           │
│  Aggressive users can pre-extract on search results.                        │
│  Minimal users can disable caching entirely.                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 Evolution Story

#### Phase 1: Simple Extractor
Started with yt-dlp, the widely-adopted tool:
```
video_id → yt-dlp → stream URL → MPV
```
Problem: yt-dlp was too slow (~4 seconds per extraction).

#### Phase 2: Custom Extractor (ytx)
Wrote custom extractor for speed (~200ms):
```
trait Extractor { fn extract_batch(...); }
├── YtxExtractor (fast, preferred)
└── YtDlpExtractor (fallback)
```

#### Phase 3: Dependency Inversion
Made extractor configurable with fallback:
```
FallbackExtractor<YtxExtractor, YtDlpExtractor>
```

#### Phase 4: Bulk Extraction Optimization
Recognized need for batch extraction (play album = 50 tracks):
```
trait Extractor {
    fn extract_batch(&self, ids: &[String]) -> HashMap<String, Result<String>>;
}
```

#### Phase 5: Extraction Caching
Noticed repeated extractions for same track:
```
CachedExtractor<E: Extractor>
├── cache: LruCache<video_id, url>
├── in_flight: DashMap (coalesce concurrent requests)
└── ttl: 6 hours (URL expiration)
```

#### Phase 6: Audio Prefix Caching (Gapless)
For gapless playback, needed audio ready before track ends:
```
AudioCache
├── Download first ~200KB of audio
├── Store as prefix file on disk
└── Use ffmpeg concat+subfile protocol

concat:{prefix}|subfile,,start,{offset},...,:{url}
```

#### Phase 7: Intent System
Simple play/pause wasn't enough. Needed context:
```
enum PlayIntent {
    Context { tracks, offset, shuffle },  // Play album/playlist
    Next,                                  // Skip to next
    Append { tracks },                     // Add to queue
    Radio { seed_track },                  // Start radio
}
```

#### Phase 8: Tier-Based Prefetching (Current)
Different urgency for different tracks:
```
enum Tier {
    Immediate,   // User waiting NOW, 200ms deadline
    Gapless,     // Next track, must be ready before current ends
    Eager,       // Upcoming tracks
    Background,  // Opportunistic prefetch
}
```

#### Phase 9: Unified CacheExecutor (ADR-002)
Combined all cache work into single executor:
```
CacheExecutor
├── url_resolver: Arc<UrlResolver>
├── audio_cache: Arc<AudioCache>
├── in_flight: DashMap (coalescing)
└── tier_permits: TierPermits (concurrency control)
```

### 1.4 The Critical Bug That Exposed Design Flaws

After implementing CacheExecutor, prefetch was USELESS:

```
EXPECTED:
  Prefetch extracts URL → caches in resolver
  Playback needs URL → cache HIT → instant

ACTUAL:
  Prefetch extracts URL → caches in resolver_A
  Playback needs URL → resolver_B has empty cache → MISS → extracts AGAIN
```

**Root Cause**: Three separate UrlResolver instances, each with own cache.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  server/mod.rs created:                                                     │
│                                                                             │
│  UrlResolver (instance 1) → CacheExecutor                                   │
│  UrlResolver (instance 2) → FfmpegConcatSource                              │
│  UrlResolver (instance 3) → PlaybackService                                 │
│                                                                             │
│  Three caches. Never shared. Prefetch work wasted.                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

This bug revealed deeper architectural problems documented in Part 2.
