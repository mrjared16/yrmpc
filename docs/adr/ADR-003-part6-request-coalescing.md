# ADR-003-part6: Request Coalescing as Cross-Cutting Concern

**Status**: Proposed  
**Date**: 2026-01-22  
**Supplements**: ADR-003 (MediaPreparer Architecture)

---

## Context

ADR-003 introduced trait-based media preparation with coalescing at `YouTubeMediaPreparer` level:

```
┌─────────────────────────────────────────────────────────┐
│              YouTubeMediaPreparer                        │
│  in_flight: DashMap<String, InFlightJob>  ← ONLY HERE   │
│              │                                          │
│              ▼                                          │
│  TrackResolver │ AudioLoader │ OutputBuilder            │
│   (no dedup)   │ (no dedup)  │                          │
│       ↓        │      ↓      │                          │
│  CachedExt     │ AudioCache  │ ← RACE CONDITION         │
│  (has OnceLock)│ (NOTHING!)  │                          │
└─────────────────────────────────────────────────────────┘
```

**Problem**: Coalescing embedded in concrete type, not cross-cutting decorator.

**Evidence**: `AudioCache::ensure_prefix()` downloads same file twice:
```
[16:35:30.465Z] [CACHE] miss video_id=fJ9cJXotuXM downloading...
[16:35:30.517Z] [CACHE] miss video_id=fJ9cJXotuXM downloading...  ← DUPE
```

### Existing Patterns (6 hardcoded, none reusable)

| Pattern | Location | Mechanism |
|---------|----------|-----------|
| Async Notify | `media/preparer.rs` | `InFlightJob` + `Notify` |
| Sync OnceLock | `extractor/cached.rs` | `HashMap<K, Arc<OnceLock<V>>>` |
| Condvar | `streaming_audio_file.rs` | Blocking wait |
| HashSet Guard | `image_cache.rs` | `pending_fetch` |
| Static HashSet | `orchestrator.rs` | `PREFETCH_TRIGGERED` |
| Heap+Set | `audio_prefetcher.rs` | `pending_ids` |

---

## Decision

Introduce `Dedup<K, V>` - a unified, reusable request coalescing abstraction.

### Design Principles (Architecture Skill Aligned)

| Pillar | Application |
|--------|-------------|
| **Simplicity** | One purpose: deduplicate. No channels, no E: Clone |
| **FCIS** | Pure coordination logic. I/O in caller's closure |
| **Coupling** | Data coupling only (key + closure). No dependencies |

---

## Specification

### Core Abstraction: `Dedup<K, V>`

```
┌─────────────────────────────────────────────────────────┐
│                      Dedup<K, V>                        │
│                                                         │
│  slots: DashMap<K, Arc<Slot<V>>>                        │
│                                                         │
│  Slot<V> {                                              │
│      value: OnceLock<V>,    ← stores result             │
│      notify: Notify,        ← wakes waiters             │
│  }                                                      │
│                                                         │
│  FLOW:                                                  │
│                                                         │
│  get_or_init(key, || compute)                           │
│       │                                                 │
│       ▼                                                 │
│  ┌─────────────┐                                        │
│  │ slots.entry │  ← atomic via DashMap                  │
│  └──────┬──────┘                                        │
│         │                                               │
│    ┌────┴────┐                                          │
│    ▼         ▼                                          │
│  [NEW]    [EXISTS]                                      │
│    │         │                                          │
│    │    ┌────┴────┐                                     │
│    │    │ value   │──── yes ───▶ return clone           │
│    │    │ filled? │                                     │
│    │    └────┬────┘                                     │
│    │         │ no                                       │
│    │         ▼                                          │
│    │    notify.wait()  ← follower waits                 │
│    │         │                                          │
│    │         ▼                                          │
│    │    return clone                                    │
│    │                                                    │
│    ▼                                                    │
│  compute()  ← only leader does work                     │
│    │                                                    │
│    ▼                                                    │
│  store + notify_waiters()                               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Implementation

```rust
// rmpc/src/shared/dedup.rs

use dashmap::DashMap;
use std::hash::Hash;
use std::sync::{Arc, OnceLock};
use tokio::sync::Notify;

struct Slot<V> {
    value: OnceLock<V>,
    notify: Notify,
}

/// Deduplicates concurrent requests for the same key.
/// 
/// - First caller becomes "leader" and computes
/// - Subsequent callers wait for leader's result
/// - No Clone requirement on errors (caller handles Result)
/// - Panic-safe (OnceLock guarantees)
pub struct Dedup<K, V> {
    slots: DashMap<K, Arc<Slot<V>>>,
}

impl<K, V> Dedup<K, V>
where
    K: Eq + Hash + Clone,
    V: Clone,
{
    pub fn new() -> Self {
        Self { slots: DashMap::new() }
    }

    /// Async: Get cached value or compute it.
    pub async fn get_or_init<F, Fut>(&self, key: K, compute: F) -> V
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = V>,
    {
        let slot = self.slots
            .entry(key.clone())
            .or_insert_with(|| Arc::new(Slot {
                value: OnceLock::new(),
                notify: Notify::new(),
            }))
            .clone();

        // Fast path: already computed
        if let Some(v) = slot.value.get() {
            return v.clone();
        }

        // Try to become leader
        if slot.value.get().is_none() {
            let result = compute().await;
            let _ = slot.value.set(result);
            slot.notify.notify_waiters();
        }

        // Wait if still not ready
        loop {
            if let Some(v) = slot.value.get() {
                return v.clone();
            }
            slot.notify.notified().await;
        }
    }

    /// Sync: For blocking contexts
    pub fn get_or_init_sync<F>(&self, key: K, compute: F) -> V
    where
        F: FnOnce() -> V,
    {
        let slot = self.slots
            .entry(key.clone())
            .or_insert_with(|| Arc::new(Slot {
                value: OnceLock::new(),
                notify: Notify::new(),
            }))
            .clone();

        slot.value.get_or_init(compute).clone()
    }

    /// Remove entry (for TTL or explicit invalidation)
    pub fn invalidate(&self, key: &K) {
        self.slots.remove(key);
    }
}
```

---

## Application

### Before/After Comparison

```
BEFORE (6 scattered patterns):

  CachedExtractor ──┐
                    │   Different implementations
  ImageCache ───────┼── of same concept
                    │   (inconsistent, error-prone)
  AudioCache ───────┘


AFTER (unified):

                 ┌─────────────────┐
                 │   Dedup<K, V>   │  ← shared/dedup.rs
                 └────────┬────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ AudioCache   │  │ ImageCache   │  │ CachedExtract│
│ dedup:       │  │ dedup:       │  │ dedup:       │
│ Dedup<       │  │ Dedup<       │  │ Dedup<       │
│   VideoId,   │  │   Url,       │  │   VideoId,   │
│   PathBuf    │  │   Image      │  │   StreamUrl  │
│ >            │  │ >            │  │ >            │
└──────────────┘  └──────────────┘  └──────────────┘
```

### AudioCache Fix

```rust
impl AudioCache {
    dedup: Dedup<String, Result<PathBuf, CacheError>>,
    
    pub async fn ensure_prefix(&self, video_id: &str, url: &str) -> Result<PathBuf> {
        self.dedup.get_or_init(
            video_id.to_string(),
            || self.download_prefix_inner(video_id, url)
        ).await
    }
}
```

### MediaPreparer Coalescing Boundary

`DedupMediaPreparer` was proposed during design, but not adopted in production.
The implemented boundary is:

- `YouTubeMediaPreparer` owns in-flight coalescing for preparation jobs
- `AudioCache` uses `Dedup<K, V>` for prefix download coalescing
- `CachedExtractor` uses `Dedup<K, V>` for URL extraction coalescing

This keeps coalescing close to real execution paths instead of adding a generic
decorator layer that is easy to leave unwired.

---

## Architecture Compliance

| Pillar | Requirement | Dedup Design |
|--------|-------------|--------------|
| **Simplicity** | One purpose per thing | Dedup = request deduplication only |
| **Simplicity** | No hidden complexity | DashMap + OnceLock + Notify (all std/tokio) |
| **FCIS** | Pure core, I/O at edges | Coordination is pure; compute closure does I/O |
| **FCIS** | Testable without mocks | Test with fake async closures |
| **Coupling** | Minimal interface | 3 methods: `get_or_init`, `get_or_init_sync`, `invalidate` |
| **Coupling** | Data coupling only | Passes key + closure, nothing else |

---

## Migration Path

| Phase | Task | Effort |
|-------|------|--------|
| 1 | Create `shared/dedup.rs` | 1h |
| 2 | Add to `AudioCache::ensure_prefix` | 1h |
| 3 | Migrate `ImageCache` | 2h |
| 4 | Finalize MediaPreparer in-flight coalescing path | 1h |
| 5 | Add CI check + docs | 1h |

**Total**: ~6 hours

---

## Consequences

### Positive
- Single pattern for all coalescing
- Coalescing lives in active runtime paths
- Testable in isolation
- Prevents future race conditions

### Negative
- V must be Clone (Arc workaround if needed)
- One new module to learn

### Risks
- **Deadlock**: If compute() calls get_or_init() recursively with same key. Mitigated: DashMap entry API doesn't hold lock during compute.

---

## References

- `.sisyphus/plans/demand-scheduler-infrastructure.md` - Original design
- `rmpc/src/backends/youtube/extractor/cached.rs` - OnceLock pattern
- Go's `singleflight` package - Inspiration
