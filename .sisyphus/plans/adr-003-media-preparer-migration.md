# ADR-003: MediaPreparer Architecture Migration Plan

## Epic: yrmpc-q8xi

**Goal**: Migrate from YouTube-specific CacheExecutor to backend-agnostic MediaPreparer architecture

**Principles**: 
1. Loosely coupled traits (not concrete types)
2. Decorator pattern for cross-cutting concerns
3. Intent-driven API (TUI sends WHAT, backend decides HOW)
4. Backend agnostic (YouTube/Spotify/Local ready)
5. **Functional core, imperative shell** - pure business logic separate from IO

---

## Current State (from codebase analysis)

| Component | Location | Role |
|-----------|----------|------|
| `CacheExecutor` | `services/cache_executor.rs:148` | Orchestrates URL resolution + audio caching |
| `UrlResolver` | `services/url_resolver.rs` | Extracts streaming URLs via ytx/yt-dlp |
| `AudioCache` | `services/audio/cache.rs` | Downloads audio prefix for gapless |
| `FfmpegConcatSource` | `services/audio/concat.rs` | Builds ffconcat for MPV |
| `YouTubeServices` | `services/registry.rs` | Composition root (Arc sharing) |
| `PreloadTier` | `play_intent.rs` | Background/Eager/Gapless/Immediate |

**Fixed Bug**: Single `UrlResolver` shared via `YouTubeServices` (no more 3 instances)

---

## Target Architecture

```
TUI (backend-agnostic)
    ↓ PlayIntent
Daemon Core
    ↓ Arc<dyn MediaPreparer>
Backend (YouTube impl)
    ├── Arc<dyn TrackResolver>  (URL extraction)
    ├── Arc<dyn AudioLoader>    (audio downloading)
    └── Arc<dyn OutputBuilder>  (MPV input building)
```

### New Naming Convention (SA Consultant Aligned)

| Current | Trait (New) | Concrete (Keep) | Reason |
|---------|-------------|-----------------|--------|
| `CacheExecutor` | `MediaPreparer` | `YouTubeMediaPreparer` | YouTube-specific impl |
| `UrlResolver` | `StreamResolver` | `UrlResolver` | Aligns with StreamInfo, keeps concrete |
| `AudioCache` | `AudioLoader` | `AudioCache` | Keep existing, just add trait |
| `FfmpegConcatSource` | `MpvInputBuilder` | `ConcatMpvInputBuilder` | Explicit about output type |
| `PreloadTier` | **KEEP** | `PreloadTier` | High churn to rename, serde/IPC compat |
| `Preparer` | N/A | `PlaybackPreparer` | Rename to avoid collision |
| `PreparedPlayback` | N/A | `PreparedMedia` | Standardize on one result type |

### PreloadTier Levels (Keep Existing Names)

| Level | Meaning | Deadline |
|-------|---------|----------|
| `Immediate` | User pressed play | 200ms |
| `Gapless` | Next track in queue | Before current ends |
| `Eager` | Visible in UI | 30s |
| `Background` | Background prefetch | No deadline |

---

## Phase 1: Define Traits (Additive, No Breaking Changes)

**Ready beads** (can start immediately - no dependencies):

### yrmpc-8mfc: Define MediaPreparer trait
**File**: `rmpc/src/backends/youtube/media/mod.rs` (new)

```rust
/// Core trait for preparing media for playback
#[async_trait]
pub trait MediaPreparer: Send + Sync {
    /// Prepare track for immediate playback (blocks until ready)
    async fn prepare(&self, track_id: &str, tier: PreloadTier) -> Result<PreparedMedia>;
    
    /// Prefetch track in background (fire-and-forget)
    fn prefetch(&self, track_id: &str, tier: PreloadTier);
    
    // NOTE: hint(), cancel(), status() REMOVED as of 2026-01-21
    // - cancel() was no-op (identity mismatch: track_id vs request_id)
    // - status() always returned Unknown
    // - hint() was never called
    // If needed, redesign with PrepareHandle for proper identity tracking
}
```

**Acceptance**:
- [x] Trait compiles with `#[async_trait]`
- [x] `cargo clippy` passes
- [x] Lying methods (cancel/status/hint) removed

---

### yrmpc-ib59: Define StreamResolver trait
**File**: `rmpc/src/backends/youtube/media/resolver.rs` (new)

```rust
/// Resolves track ID to playable stream info
#[async_trait]
pub trait StreamResolver: Send + Sync {
    /// Get streaming URL/info for track
    async fn resolve(&self, track_id: &str) -> Result<StreamInfo>;
    
    /// Check if resolution is cached
    fn is_cached(&self, track_id: &str) -> bool;
    
    /// Invalidate cached resolution
    fn invalidate(&self, track_id: &str);
}

/// Stream information (URL + metadata)
pub struct StreamInfo {
    pub url: String,
    pub expires_at: Option<Instant>,
    pub format: AudioFormat,
}
```

**Acceptance**:
- [x] Trait compiles
- [x] `ResolvedTrack` includes expiry for URL rotation

---

### yrmpc-qb1i: Define AudioLoader trait
**File**: `rmpc/src/backends/youtube/media/loader.rs` (new)

```rust
/// Downloads/caches audio content
#[async_trait]
pub trait AudioLoader: Send + Sync {
    /// Ensure audio prefix is available
    async fn ensure_prefix(&self, track_id: &str, url: &str, prefix_bytes: u64) -> Result<PathBuf>;
    
    /// Check if audio is cached
    fn is_cached(&self, track_id: &str) -> bool;
    
    /// Get cache path if available
    fn cached_path(&self, track_id: &str) -> Option<PathBuf>;
}
```

**Acceptance**:
- [x] Trait compiles
- [x] PathBuf return enables MPV input building

---

### yrmpc-3e37: Define MpvInputBuilder trait
**File**: `rmpc/src/backends/youtube/media/output.rs` (new)

```rust
/// Builds MPV input from resolved stream and optional cache
pub trait MpvInputBuilder: Send + Sync {
    /// Build MPV-compatible input from stream info and optional cached path
    fn build(&self, track_id: &str, stream: &StreamInfo, cached_path: Option<&Path>) -> PreparedMedia;
}

pub enum PreparedMedia {
    /// FFmpeg concat (cached prefix + streaming remainder)
    Concat { concat_path: PathBuf },
    /// Direct URL streaming (no cache)
    Direct { url: String },
    /// Local file path
    LocalFile { path: PathBuf },
    /// Passthrough (existing MpvInput)
    Passthrough { input: MpvInput },
}
```

**Acceptance**:
- [x] Enum covers all playback scenarios from ADR-003
- [x] `Concat` variant works with existing MPV integration

---

### yrmpc-da10: Define Urgency enum and PrepareStatus
**File**: `rmpc/src/backends/youtube/media/types.rs` (new)

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Urgency {
    Opportunistic = 0,  // No deadline
    Soon = 1,           // ~30s
    Seamless = 2,       // Before current track ends
    Critical = 3,       // User pressed play NOW
}

#[derive(Debug, Clone)]
pub enum PrepareStatus {
    Unknown,
    Pending { urgency: Urgency },
    InProgress { started: Instant, urgency: Urgency },
    Ready { prepared: PreparedMedia },
    Failed { error: String },
}
```

**Acceptance**:
- [x] `Urgency` derives `Ord` for priority comparison
- [x] Maps cleanly to current `PreloadTier` values

---

### yrmpc-2pjx: Create media/mod.rs module structure
**File**: `rmpc/src/backends/youtube/media/mod.rs`

```rust
mod types;
mod resolver;
mod loader;
mod output;

pub use types::{Urgency, PrepareStatus, PreparedMedia};
pub use resolver::{TrackResolver, ResolvedTrack};
pub use loader::AudioLoader;
pub use output::OutputBuilder;

// Re-export the main trait
mod preparer;
pub use preparer::MediaPreparer;
```

**Acceptance**:
- [x] `cargo build` succeeds
- [x] All traits accessible via `use crate::backends::youtube::media::*`

---

## Phase 2: Implement Traits on Existing Types

**Dependencies**: All of Phase 1 must be complete

### yrmpc-5jaf: Impl TrackResolver for UrlResolver
**Depends on**: yrmpc-ib59

**File**: `rmpc/src/backends/youtube/services/url_resolver.rs`

```rust
impl TrackResolver for UrlResolver {
    async fn resolve(&self, track_id: &str) -> Result<ResolvedTrack> {
        let url = self.get_url(track_id).await?;
        Ok(ResolvedTrack {
            url,
            expires_at: Some(Instant::now() + Duration::from_secs(3600)),
            format: AudioFormat::default(),
        })
    }
    
    fn is_cached(&self, track_id: &str) -> bool {
        self.cache.contains_key(track_id)
    }
    
    fn invalidate(&self, track_id: &str) {
        self.cache.remove(track_id);
    }
}
```

**Acceptance**:
- [x] Existing `get_url()` behavior preserved
- [x] `cargo test` passes

---

### yrmpc-ooj5: Impl AudioLoader for AudioCache
**Depends on**: yrmpc-qb1i

**File**: `rmpc/src/backends/youtube/services/audio/cache.rs`

```rust
impl AudioLoader for AudioCache {
    async fn ensure_prefix(&self, track_id: &str, url: &str, prefix_bytes: u64) -> Result<PathBuf> {
        self.download_prefix(track_id, url, prefix_bytes).await
    }
    
    fn is_cached(&self, track_id: &str) -> bool {
        self.cache_path(track_id).exists()
    }
    
    fn cached_path(&self, track_id: &str) -> Option<PathBuf> {
        let path = self.cache_path(track_id);
        path.exists().then_some(path)
    }
}
```

**Acceptance**:
- [x] Delegates to existing methods
- [x] Cache check uses real filesystem, not stub

---

### yrmpc-sxwo: Impl OutputBuilder for FfmpegConcatSource
**Depends on**: yrmpc-3e37

**File**: `rmpc/src/backends/youtube/services/audio/concat.rs`

```rust
impl OutputBuilder for FfmpegConcatSource {
    fn build(&self, track_id: &str, resolved: &ResolvedTrack, cached_path: Option<&Path>) -> PreparedMedia {
        match cached_path {
            Some(prefix) => {
                let concat_path = self.build_concat_file(prefix, &resolved.url);
                PreparedMedia::Concat { concat_path }
            }
            None => PreparedMedia::Direct { url: resolved.url.clone() },
        }
    }
}
```

**Acceptance**:
- [x] Concat file generated correctly
- [x] MPV can play resulting concat path

---

### yrmpc-6c8k: Impl MediaPreparer for CacheExecutor
**Depends on**: yrmpc-8mfc, yrmpc-5jaf, yrmpc-ooj5, yrmpc-sxwo

**File**: `rmpc/src/backends/youtube/services/cache_executor.rs`

```rust
impl MediaPreparer for CacheExecutorHandle {
    async fn prepare(&self, track_id: &str, urgency: Urgency) -> Result<PreparedMedia> {
        let tier = urgency.into(); // Map to PreloadTier for now
        self.prepare_inner(track_id, tier).await
    }
    
    fn prefetch(&self, track_id: &str, urgency: Urgency) {
        let tier = urgency.into();
        let _ = self.tx.try_send(CacheRequest::Preload { 
            track_id: track_id.to_string(), 
            tier,
            request_id: Uuid::new_v4(),
        });
    }
    
    fn hint(&self, track_id: &str) {
        self.prefetch(track_id, Urgency::Opportunistic);
    }
    
    fn cancel(&self, track_id: &str) {
        // Find and cancel by track_id
    }
    
    fn status(&self, track_id: &str) -> PrepareStatus {
        PrepareStatus::Unknown // TODO: Add status tracking
    }
}
```

**Acceptance**:
- [ ] `MediaPreparer` trait fully implemented
- [ ] Existing channel-based logic preserved
- [ ] `cargo test` passes

---

## Phase 3: Update Daemon to Use Traits

### yrmpc-hscm: Update daemon to use Arc<dyn MediaPreparer>
**Depends on**: yrmpc-6c8k

**File**: `rmpc/src/backends/youtube/server/mod.rs`

Change:
```rust
// Before
pub cache_executor: CacheExecutorHandle,

// After  
pub media_preparer: Arc<dyn MediaPreparer>,
```

**Acceptance**:
- [ ] Server holds `Arc<dyn MediaPreparer>`
- [ ] Construction still uses `CacheExecutor::spawn()`
- [ ] Compile succeeds

---

### yrmpc-07r3: Update PlaybackService to use MediaPreparer
**Depends on**: yrmpc-hscm

**File**: `rmpc/src/backends/youtube/services/playback.rs`

Replace direct `CacheExecutorHandle` usage with `MediaPreparer` trait calls.

**Acceptance**:
- [ ] PlaybackService uses `media_preparer.prepare()`
- [ ] PlaybackService uses `media_preparer.prefetch()`
- [ ] Playback still works end-to-end

---

### yrmpc-713b: Replace YouTubeServices with trait-based composition
**Depends on**: yrmpc-07r3

Create builder pattern for YouTube backend:

```rust
pub struct YouTubeBackendBuilder {
    resolver: Option<Arc<dyn TrackResolver>>,
    loader: Option<Arc<dyn AudioLoader>>,
    output: Option<Arc<dyn OutputBuilder>>,
}

impl YouTubeBackendBuilder {
    pub fn new() -> Self { ... }
    pub fn with_resolver(mut self, r: Arc<dyn TrackResolver>) -> Self { ... }
    pub fn build(self) -> Arc<dyn MediaPreparer> { ... }
}
```

**Acceptance**:
- [ ] Builder pattern enables component swapping
- [ ] Default construction works identically to current

---

## Phase 4: Rename and Cleanup

### yrmpc-uah4: Rename CacheExecutor to YouTubeMediaPreparer
**Depends on**: yrmpc-713b

Use `lsp_rename` for safe refactoring:
- `CacheExecutor` → `YouTubeMediaPreparer`
- `CacheExecutorHandle` → `YouTubeMediaPreparerHandle`

**Acceptance**:
- [ ] All references updated
- [ ] `cargo build` succeeds

---

### yrmpc-9h3q: Rename Tier to Urgency enum
**Depends on**: yrmpc-713b

- `PreloadTier` → `Urgency`
- `Background` → `Opportunistic`
- `Eager` → `Soon`
- `Gapless` → `Seamless`
- `Immediate` → `Critical`

**Acceptance**:
- [ ] All callers updated
- [ ] Semantics clearer

---

### yrmpc-1f5c: Rename preload to prefetch across codebase
**Depends on**: yrmpc-713b

Use `ast_grep_replace`:
```
pattern: preload($$$)
rewrite: prefetch($$$)
```

**Acceptance**:
- [ ] Consistent terminology
- [ ] No behavioral changes

---

### yrmpc-h2xa: Move files to media/ module structure
**Depends on**: yrmpc-uah4, yrmpc-9h3q, yrmpc-1f5c

| From | To |
|------|-----|
| `services/cache_executor.rs` | `media/preparer.rs` |
| `services/url_resolver.rs` | `media/resolver.rs` |
| `services/audio/cache.rs` | `media/loader.rs` |
| `services/audio/concat.rs` | `media/output.rs` |

**Acceptance**:
- [ ] All imports updated
- [ ] Module structure matches ADR-003

---

### yrmpc-lrjb: Remove deprecated YouTubeServices struct
**Depends on**: yrmpc-h2xa

Delete `services/registry.rs` and any direct field access.

**Acceptance**:
- [ ] No `YouTubeServices` references remain
- [ ] Encapsulation enforced by trait boundaries

---

### yrmpc-su3k: Update documentation and MEMORY.md
**Depends on**: yrmpc-lrjb

- Update `MEMORY.md` with new patterns
- Update `docs/arch/` with final architecture
- Add decorator pattern examples

**Acceptance**:
- [ ] Documentation reflects new architecture
- [ ] ADR-003 marked as implemented

---

## Dependency Graph

```
Phase 1 (parallel):
  8mfc ─┐
  ib59 ─┼─→ 5jaf ─┐
  qb1i ─┼─→ ooj5 ─┼─→ 6c8k ─→ hscm ─→ 07r3 ─→ 713b ─┬─→ uah4 ─┐
  3e37 ─┼─→ sxwo ─┘                                  ├─→ 9h3q ─┼─→ h2xa ─→ lrjb ─→ su3k
  da10 ─┘                                            └─→ 1f5c ─┘
  2pjx ─┘

Legend:
  ─→ depends on (left blocks right)
  ┼  can run in parallel
```

## Ready to Start

Run `bd ready` to see:
- **yrmpc-8mfc**: Define MediaPreparer trait (no deps)
- **yrmpc-ib59**: Define TrackResolver trait (no deps)
- **yrmpc-qb1i**: Define AudioLoader trait (no deps)
- **yrmpc-3e37**: Define OutputBuilder trait (no deps)
- **yrmpc-da10**: Define Urgency enum (no deps)
- **yrmpc-2pjx**: Create module structure (no deps)

All Phase 1 beads can be executed in parallel!
