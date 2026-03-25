# Design B: Resource Pool + Orchestrator

## Concept
Separate WHAT (resources) from HOW (orchestration). Two layers:
1. ResourcePool: Owns shared infrastructure (traits)
2. PlaybackOrchestrator: Coordinates work, ONLY public API

## Layer 1: Resource Pool
```
ResourcePool (private, internal)
├── extractor: Arc<dyn Extractor>      ← Your existing trait
├── audio_store: Arc<dyn AudioStore>   ← New trait
└── rate_limiter: Arc<dyn RateLimiter> ← New trait

Created ONCE at startup.
Immutable. Thread-safe.
NOT exposed to consumers.
```

## Layer 2: Orchestrator
```
PlaybackOrchestrator (public API)
├── pool: Arc<ResourcePool>   ← Private access to resources
├── in_flight: DashMap<...>   ← Coalescing logic
└── work_queue: Channel<...>  ← Priority scheduling

PUBLIC METHODS (all consumers use these):
  fn prepare(video_id, tier) → PrepareResult
  fn preload(requests: Vec<PreloadRequest>)
  fn cancel(video_id)
  fn status(video_id) → MediaStatus
```

## Architecture Diagram
```
┌──────────────────────────────────────────────────────────────┐
│                    PlaybackOrchestrator                      │
│                    (ONLY public interface)                   │
│                                                              │
│   prepare() ──┬── check in_flight ── coalesce if exists     │
│               │                                              │
│               └── rate_limit.acquire() ── tier priority     │
│                         │                                    │
│                         ▼                                    │
│               pool.extractor.extract()                       │
│                         │                                    │
│                         ▼                                    │
│               pool.audio_store.ensure_prefix()               │
│                         │                                    │
│                         ▼                                    │
│               build PrepareResult (Concat or Passthrough)    │
└──────────────────────────────────────────────────────────────┘
                          │
     ┌────────────────────┼────────────────────┐
     ▼                    ▼                    ▼
┌──────────┐       ┌──────────┐        ┌──────────┐
│PlayIntent│       │QueueEvent│        │FfmpegSrc │
│Handler   │       │Handler   │        │          │
│          │       │          │        │          │
│.preload()│       │.preload()│        │.prepare()│
└──────────┘       └──────────┘        └──────────┘

ALL consumers use orchestrator. CANNOT access pool directly.
```

## Trait Definitions (Community Implements)
```rust
trait Extractor { ... }        // Already exists
trait AudioStore { ... }       // New: get_prefix, store_prefix, evict
trait RateLimiter { ... }      // New: acquire, release
trait PlaybackOrchestrator { ... } // New: prepare, preload, cancel, status
```

## Why Bypass is Impossible
```
Consumer receives: Arc<dyn PlaybackOrchestrator>

Consumer CAN:
  - orchestrator.prepare("abc", Tier::Immediate)
  - orchestrator.preload(requests)

Consumer CANNOT:
  - Access pool.extractor (pool is private)
  - Access pool.audio_store (pool is private)
  - Create new instances (constructors private)

Sharing enforced by STRUCTURE, not discipline.
```

## Extensibility
```
Custom Orchestrator:
  impl PlaybackOrchestrator for MyOrchestrator { ... }
  
  Different strategies:
  - DefaultOrchestrator (gapless + passthrough fallback)
  - PassthroughOnlyOrchestrator (no caching)
  - ProxyOrchestrator (routes through server)

Custom Resources:
  impl Extractor for MyExtractor { ... }
  impl AudioStore for S3Store { ... }
  impl RateLimiter for AdaptiveRateLimiter { ... }
```

## Pros
- Clean separation: resources vs coordination
- Bypass impossible by design
- Traits at every extension point
- Matches your Extractor philosophy
- Easy to test (mock orchestrator trait)

## Cons
- Two layers (pool + orchestrator) vs one
- Orchestrator becomes "god object"?
- More indirection than direct calls
