# ADR-003: Backend-Agnostic Media Preparation Architecture

**Status**: Implemented  
**Date**: 2026-01-17 → implemented 2026-03

> This is a summary document. The full decision record lives in `ADR-003-part1-context.md` through `ADR-003-part6-request-coalescing.md`.

---

## Decision

Adopt the layered, trait-based `MediaPreparer` architecture to replace the tightly coupled `CacheExecutor`.

---

## Problem

Three separate `UrlResolver` instances at runtime — each with its own cache — meant prefetch work was silently thrown away. URL extraction happened twice per track.

---

## Architecture (Implemented)

```text
┌─────────────────────────────────────────────────────────────┐
│                        TUI Layer                            │
│  PlayIntent → PlayQueue (L1 pure state) → QueueEvent       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Daemon Core (L2 Bridge)                 │
│  Orchestrator uses: Arc<dyn MediaPreparer>                  │
│  Manages: queue, urgency, playback coordination             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              YouTubeMediaPreparer                           │
│   resolver: Arc<dyn TrackResolver>                          │
│       └─ CachedResolver<RateLimited<Fallback<Ytx,YtDlp>>>  │
│   loader:   Arc<dyn AudioLoader>                            │
│       └─ AudioCache (prefix download + LRU eviction)       │
│   (output is handled by PlaybackService::build_runtime_input│
│    branching to RelayRuntime or FfmpegConcatSource)         │
└─────────────────────────────────────────────────────────────┘
```

**PreparedMedia** (transport-neutral output of prepare):
- `StagedPrefix { path, bytes, url, content_length }` — local prefix + remote tail
- `Direct { url }` — full remote URL (fallback when deadline missed)
- `LocalFile { path }` — local audio file

**PlaybackService::build_runtime_input** (the transport boundary):
- `LocalRelay` transport → `RelayRuntime::register_session` → local HTTP URL
- `Combined/Direct` transport → `FfmpegConcatSource::build_from_prepared` → `lavf://concat` or direct URL

---

## Key Traits

| Trait | Role |
|-------|------|
| `MediaPreparer` | Daemon contract — `prepare(id, tier)`, `prefetch(id, tier)` |
| `TrackResolver` | URL extraction with caching/fallback chain |
| `AudioLoader` | Prefix download + disk cache |

---

## Tier System (PreloadTier)

| Tier | Meaning | Deadline |
|------|---------|----------|
| `Immediate` | User pressed play | 300ms (falls back to `Direct`) |
| `Gapless` | Next track in queue | Before current track ends |
| `Eager` | Visible in queue | ~30s |
| `Background` | Opportunistic warm-up | None |

---

## Parts Reference

| Part | Content |
|------|---------|
| [Part 1](ADR-003-part1-context.md) | Design philosophy + evolution from CacheExecutor |
| [Part 2](ADR-003-part2-problems.md) | Coupling issues, bypass paths, naming problems |
| [Part 3](ADR-003-part3-solution.md) | Trait-based architecture proposal |
| [Part 4](ADR-003-part4-extensibility.md) | Decorator pattern scenarios |
| [Part 5](ADR-003-part5-decision.md) | Final adoption decision + type hierarchy |
| [Part 6](ADR-003-part6-request-coalescing.md) | `Dedup<K,V>` request coalescing abstraction |
