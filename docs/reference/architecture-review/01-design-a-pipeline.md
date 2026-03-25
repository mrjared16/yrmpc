# Design A: Pipeline Stages

## Concept
Intent flows through linear stages. Each stage is a trait. Stages share resources via PrepareContext.

## Structure
```
PlayIntent → [Stage1] → [Stage2] → [Stage3] → PrepareResult

PrepareContext carries state between stages:
  - video_id, tier, deadline
  - url: Option<String>        ← filled by ExtractStage
  - audio_prefix: Option<Path> ← filled by CacheStage
```

## Traits
```rust
trait PipelineStage: Send + Sync {
    fn process(&self, ctx: PrepareContext) -> StageResult;
}

enum StageResult {
    Continue(PrepareContext),  // Next stage
    Complete(PrepareResult),   // Short-circuit
    Skip(PrepareContext),      // Pass through
}
```

## Default Pipeline
```
[RateLimit] → [Coalesce] → [Extract] → [AudioCache] → [BuildResult]
     │             │            │            │
     │             │            ▼            ▼
     │             │      Arc<Extractor>  Arc<AudioStore>
     │             │      (shared)        (shared)
     │             ▼
     │        DashMap (in_flight dedup)
     ▼
   Semaphore (rate limiting)
```

## Extensibility
```
Community adds ProxyStage:
[RateLimit] → [Proxy] → [Coalesce] → [Extract] → [AudioCache] → [BuildResult]
                 ↑
            Insert here

Community replaces AudioCache:
[RateLimit] → [Coalesce] → [Extract] → [S3Cache] → [BuildResult]
                                           ↑
                                      Swap impl
```

## Pros
- Stages are independent, reorderable
- Easy to add/remove stages
- Clear observability (log each stage)
- Async-friendly (sequential stages)

## Cons
- New pattern (not like Extractor decorator)
- Context struct can grow unbounded
- Stage ordering is runtime, not compile-time enforced
- Stages must handle "previous stage didn't run" cases
