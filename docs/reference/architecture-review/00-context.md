# Architecture Review Context

## Project: yrmpc - YouTube Music TUI Client (Rust + Ratatui)

## Goal
Fastest time-to-first-audio + gapless streaming without stutter.

## Design Philosophy (NON-NEGOTIABLE)
1. **Loosely coupled**: Community can implement their own components
2. **Composable**: Decorator pattern for cross-cutting concerns
3. **Intent-driven**: PlayIntent describes WHAT, not HOW
4. **Configurable**: Swap implementations without recompile
5. **Reusable**: Components work across different backends

## The Bug That Started This
```
Prefetch extracted URLs → stored in Cache A
Playback extracted URLs → stored in Cache B (different instance!)
Result: Prefetch was USELESS. Always cache miss.
```

Root cause: 3 separate UrlResolver instances, each with own DashMap cache.

## Existing Patterns That Work

### Extractor (Your Successful Pattern)
```
trait Extractor
    ├── YtxExtractor        (fast, custom)
    ├── YtDlpExtractor      (fallback)
    ├── CachedExtractor<E>  (decorator: adds caching)
    └── FallbackExtractor<E>(decorator: adds fallback)

Composition: CachedExtractor<FallbackExtractor<YtxExtractor, YtDlpExtractor>>
```

### PlayIntent (Your Intent System)
```
enum PlayIntent { Context, Next, Append, Radio }
    ↓
derive_priorities() → Vec<(Song, Tier)>
    ↓
submit to executor with tier-based deadlines
```

## Current Architecture (Broken)
```
YouTubeServer
├── UrlResolver (instance 1) → CacheExecutor
├── UrlResolver (instance 2) → FfmpegConcatSource  
├── UrlResolver (instance 3) → PlaybackService
└── AudioCache (shared, but accessed inconsistently)

Problem: Multiple instances, no enforced sharing.
```

## Failed Fix Attempt: YouTubeServices Registry
```
YouTubeServices
├── url_resolver: Arc<UrlResolver>
├── audio_cache: Arc<AudioCache>
└── cache_executor: CacheExecutorHandle

Getters return Arc::clone() to consumers.

Problem: Consumers can BYPASS orchestration!
  - FfmpegConcatSource calls resolver.get_url() directly
  - Skips coalescing, rate limiting, scheduling
  - Just a bag of services, not a coherent abstraction
```
