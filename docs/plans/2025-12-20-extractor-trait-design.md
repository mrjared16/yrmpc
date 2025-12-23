# Extractor Trait Refactor Design

**Date:** 2025-12-20
**Status:** Approved

## Problem

The current `StreamExtractor` has several issues:
- Sequential prefetching (10 songs × 0.5s = 5s wasted)
- ytx `--bulk` mode unused (could do 10 songs in ~0.6s)
- No fallback mechanism (if ytx fails, can't try yt-dlp)
- Adding new extractors requires modifying enum + all match statements
- Cache logic intertwined with extraction logic

## Solution

Trait-based design with decorator pattern for composable behaviors.

### Core Trait

```rust
pub trait Extractor: Send + Sync {
    fn extract_batch(&self, video_ids: &[String]) -> HashMap<String, Result<String>>;
    fn name(&self) -> &'static str;

    fn extract_one(&self, video_id: &str) -> Result<String> {
        // Default: delegates to batch
    }
}
```

### Implementations

| Struct | Purpose |
|--------|---------|
| `YtxExtractor` | Uses `ytx music --bulk` for batch extraction |
| `YtDlpExtractor` | Sequential yt-dlp calls (safe, no rate limit risk) |
| `CachedExtractor<E>` | LRU + TTL caching decorator |
| `FallbackExtractor<P, F>` | Try primary, fallback on failure |

### Composition Example

```rust
let extractor = CachedExtractor::new(
    FallbackExtractor::new(
        YtxExtractor::new(),
        YtDlpExtractor::new(),
    ),
    CacheConfig::default(),
);
```

## Flow: Queue with Partial Cache Hit

```
New queue: [A, C, X, Y, Z]  (A, C already cached)
                    │
                    ▼
        CachedExtractor.extract_batch()
                    │
    ┌───────────────┴───────────────┐
    │                               │
    ▼                               ▼
A, C → Cache HIT              X, Y, Z → Cache MISS
(return immediately)                    │
                                        ▼
                            inner.extract_batch([X,Y,Z])
                                        │
                                        ▼
                              ytx music --bulk X,Y,Z
                                        │
                                        ▼
                              Cache X, Y, Z results
                                        │
                    ┌───────────────────┘
                    ▼
        Return merged: {A, C, X, Y, Z}
```

## Files to Create/Modify

1. `rmpc/src/player/youtube/extractor/mod.rs` - Module + trait
2. `rmpc/src/player/youtube/extractor/ytx.rs` - YtxExtractor
3. `rmpc/src/player/youtube/extractor/ytdlp.rs` - YtDlpExtractor
4. `rmpc/src/player/youtube/extractor/cached.rs` - CachedExtractor
5. `rmpc/src/player/youtube/extractor/fallback.rs` - FallbackExtractor
6. `rmpc/src/player/youtube/stream.rs` - Remove old impl, use new extractors
7. `rmpc/src/player/youtube/mod.rs` - Export new module
