# Pluggable Audio Source Architecture - Implementation Plan

## Epic: Pluggable Audio Source with concat+subfile

**Plan ID**: pluggable-audio-source
**Created**: 2025-01-13
**Status**: COMPLETE
**Total Tasks**: 18
**Estimated Duration**: 12-16 hours

---

## Context Summary

### Problem Statement
EDL-based audio caching failed because EDL uses TIME offsets, not BYTE offsets, causing audible gaps at the junction between cached prefix and YouTube stream.

### Solution
Use ffmpeg's `concat:` + `subfile:` protocol for byte-perfect playback:
```
concat:/cache/{video_id}.m4a|subfile,,start,{BYTE_OFFSET},end,0,,:${YOUTUBE_URL}
```

### Verification
- POC tested with real YouTube audio
- PCM MD5 comparison: IDENTICAL hashes (byte-perfect verified)
- Duration: 213.089s matches original

### Architecture
Pluggable design via Strategy Pattern:
- `MpvAudioSource` trait with `startup()`/`shutdown()`/`build_mpv_input()`
- `ConcatSource` (DEFAULT) - stateless, ~50 lines
- `ProxySource` (FUTURE) - HTTP server for offline/metrics
- Shared `AudioCache` for prefix files and eviction

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary strategy | concat+subfile | Byte-perfect, minimal code, no new deps |
| Architecture | Strategy Pattern | Open/Closed, future-proof for proxy |
| Cache ownership | Shared AudioCache | Cross-cutting concern, centralized eviction |
| RangeSet | KEEP | Useful for future proxy seek tracking |
| AudioFileManager | DELETE | Replace with simpler AudioCache |
| ProgressiveAudioFile | KEEP DORMANT | Refactor when proxy implemented |

---

## Dependency Graph

```
                    ┌─────────────────────────────────────────────┐
                    │         EPIC: Pluggable Audio Source        │
                    └─────────────────────────────────────────────┘
                                         │
    ┌────────────────────────────────────┼────────────────────────────────────┐
    │                                    │                                    │
    ▼                                    ▼                                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  BATCH 0      │   │  BATCH 1      │   │  BATCH 2      │   │  BATCH 3      │
│  Docs Update  │──▶│  Foundation   │──▶│  Integration  │──▶│  Cleanup      │
│  (4 tasks)    │   │  (5 tasks)    │   │  (5 tasks)    │   │  (4 tasks)    │
└───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘
```

---

## Execution Batches

### BATCH 0: Documentation Updates (Parallelizable)

Update outdated docs to reflect new architecture BEFORE implementation.

| Task ID | Title | Scope | Priority |
|---------|-------|-------|----------|
| doc-1 | Update audio-streaming.md | `docs/arch/audio-streaming.md` | High |
| doc-2 | Update playback-flow.md | `docs/arch/playback-flow.md` | High |
| doc-3 | Update playback-engine.md | `docs/arch/playback-engine.md` | Medium |
| doc-4 | Update youtube README | `docs/backends/youtube/README.md` | Medium |

### BATCH 1: Foundation (Sequential)

Create shared infrastructure and trait definition.

| Task ID | Title | Scope | Depends On |
|---------|-------|-------|------------|
| found-1 | Create audio module structure | `src/backends/youtube/audio/mod.rs` | doc-* |
| found-2 | Define MpvAudioSource trait | `src/backends/youtube/audio/mpv_source.rs` | found-1 |
| found-3 | Implement AudioCache | `src/backends/youtube/audio/cache.rs` | found-1 |
| found-4 | Add prefix download logic | `src/backends/youtube/audio/cache.rs` | found-3 |
| found-5 | Add LRU eviction | `src/backends/youtube/audio/cache.rs` | found-4 |

### BATCH 2: Integration (Sequential)

Implement ConcatSource and wire into playback.

| Task ID | Title | Scope | Depends On |
|---------|-------|-------|------------|
| int-1 | Implement ConcatSource | `src/backends/youtube/audio/sources/concat.rs` | found-2, found-3 |
| int-2 | Add protocol_whitelist config | `src/config.rs`, MPV args | int-1 |
| int-3 | Wire into playback_service | `src/backends/youtube/services/playback_service.rs` | int-1, int-2 |
| int-4 | Add source selection config | `src/config.rs` | int-3 |
| int-5 | Integration tests | `tests/audio_source_test.rs` | int-3 |

### BATCH 3: Cleanup (Parallelizable after int-5)

Remove dead code and finalize.

| Task ID | Title | Scope | Depends On |
|---------|-------|-------|------------|
| clean-1 | Delete AudioFileManager | `src/backends/youtube/audio_file_manager.rs` | int-5 |
| clean-2 | Move RangeSet to audio/ | `src/backends/youtube/range_set.rs` → `audio/` | int-5 |
| clean-3 | Mark ProgressiveAudioFile dormant | `src/backends/youtube/streaming_audio_file.rs` | int-5 |
| clean-4 | Update mod.rs exports | `src/backends/youtube/mod.rs` | clean-1, clean-2, clean-3 |

---

## TODOs

### BATCH 0: Documentation

- [x] **doc-1: Update audio-streaming.md**
  
  **What to do**:
  - Mark ProgressiveAudioFile as OPTIONAL/FUTURE proxy infrastructure
  - Add concat+subfile as CURRENT default approach
  - Document MpvAudioSource trait and implementations
  - Add architecture diagram from ADR-001
  
  **References**:
  - `docs/adr/ADR-001-audio-streaming-architecture.md` - Source of truth
  - `.sisyphus/drafts/oracle.md` - Oracle consultation notes
  
  **Acceptance Criteria**:
  - [x] Concat+subfile documented as current approach
  - [x] ProgressiveAudioFile marked as dormant/future
  - [x] Architecture diagram included

---

- [x] **doc-2: Update playback-flow.md**
  
  **What to do**:
  - Update "Current State" to show concat+subfile flow
  - Remove or update "Future State" section
  - Document byte-level flow: cache prefix → subfile offset → YouTube CDN
  
  **Acceptance Criteria**:
  - [x] Current flow shows concat+subfile
  - [x] Byte-perfect junction documented

---

- [x] **doc-3: Update playback-engine.md**
  
  **What to do**:
  - Reference MpvAudioSource trait
  - Update component descriptions
  
  **Acceptance Criteria**:
  - [x] MpvAudioSource trait referenced
  - [x] No references to deleted AudioFileManager

---

- [x] **doc-4: Update youtube README**
  
  **What to do**:
  - Clarify which components are active vs dormant
  - Document AudioCache, ConcatSource as active
  - Mark ProgressiveAudioFile, RangeSet as dormant (for future proxy)
  
  **Acceptance Criteria**:
  - [x] Component status clarified
  - [x] Matches actual codebase state

---

### BATCH 1: Foundation

- [x] **found-1: Create audio module structure**
  
  **What to do**:
  Create directory structure:
  ```
  src/backends/youtube/audio/
  ├── mod.rs
  ├── cache.rs
  ├── mpv_source.rs
  └── sources/
      ├── mod.rs
      └── concat.rs
  ```
  
  **Acceptance Criteria**:
  - [x] Directory structure exists
  - [x] mod.rs exports created
  - [x] `cargo build` passes

---

- [x] **found-2: Define MpvAudioSource trait**
  
  **What to do**:
  ```rust
  // src/backends/youtube/audio/mpv_source.rs
  
  /// Return type for MPV input
  pub struct MpvInput {
      pub url: String,
      pub mpv_args: Vec<String>,
  }
  
  /// Pluggable audio source strategy
  pub trait MpvAudioSource: Send + Sync {
      fn startup(&mut self) -> anyhow::Result<()> { Ok(()) }
      fn shutdown(&mut self) {}
      fn build_mpv_input(&self, video_id: &str, cache_info: &CacheInfo) -> anyhow::Result<MpvInput>;
  }
  
  pub struct CacheInfo {
      pub prefix_path: PathBuf,
      pub prefix_len: u64,
      pub content_length: u64,
      pub stream_url: String,
  }
  ```
  
  **Acceptance Criteria**:
  - [x] Trait defined with 3 methods
  - [x] MpvInput and CacheInfo structs defined
  - [x] Default impls for startup/shutdown
  - [x] `cargo build` passes

---

- [x] **found-3: Implement AudioCache**
  
  **What to do**:
  ```rust
  // src/backends/youtube/audio/cache.rs
  
  pub struct AudioCache {
      cache_dir: PathBuf,
      max_size: u64,  // 200MB default
      entries: RwLock<HashMap<String, CacheEntry>>,
  }
  
  pub struct CacheEntry {
      pub video_id: String,
      pub prefix_path: PathBuf,
      pub prefix_len: u64,
      pub content_length: u64,
      pub last_access: Instant,
  }
  
  impl AudioCache {
      pub fn new(cache_dir: PathBuf, max_size: u64) -> Self;
      pub async fn ensure_prefix(&self, video_id: &str, stream_url: &str, content_length: u64) -> Result<CacheInfo>;
      pub fn get_cache_info(&self, video_id: &str) -> Option<CacheInfo>;
      pub fn evict_lru(&self);
  }
  ```
  
  **References**:
  - Original `audio_cache.rs` (before d819ee0b2dea) for prefix download logic
  - `url_resolver.rs:176` for Range header usage
  
  **Acceptance Criteria**:
  - [x] AudioCache struct with entries HashMap
  - [x] CacheEntry with metadata
  - [x] Cache dir: `~/.cache/rmpc/audio/`
  - [x] `cargo build` passes

---

- [x] **found-4: Add prefix download logic**
  
  **What to do**:
  Implement `ensure_prefix()`:
  1. Check if prefix file exists and is valid
  2. If not, download first N bytes: `Range: bytes=0-{PREFIX_LEN-1}`
  3. Save to `{cache_dir}/{video_id}.m4a`
  4. Update entries map
  
  **Constants**:
  ```rust
  const DEFAULT_PREFIX_DURATION_SECS: f64 = 10.0;
  const DEFAULT_BITRATE_KBPS: u64 = 160;
  const PREFIX_MARGIN: f64 = 1.2;
  // PREFIX_LEN = (bitrate / 8) * duration * margin ≈ 240KB
  ```
  
  **Acceptance Criteria**:
  - [x] Download with Range header
  - [x] Save to correct path
  - [x] Return CacheInfo on success
  - [x] Unit test with mock HTTP

---

- [x] **found-5: Add LRU eviction**
  
  **What to do**:
  Implement `evict_lru()`:
  1. Sort entries by `last_access`
  2. While total_size > max_size: delete oldest
  3. Update entries map
  
  **Acceptance Criteria**:
  - [x] Eviction respects max_size (200MB)
  - [x] Oldest entries deleted first
  - [x] Unit test for eviction

---

### BATCH 2: Integration

- [x] **int-1: Implement ConcatSource**
  
  **What to do**:
  ```rust
  // src/backends/youtube/audio/sources/concat.rs
  
  pub struct ConcatSource {
      cache: Arc<AudioCache>,
  }
  
  impl MpvAudioSource for ConcatSource {
      fn build_mpv_input(&self, video_id: &str, cache_info: &CacheInfo) -> Result<MpvInput> {
          let url = format!(
              "concat:{}|subfile,,start,{},end,0,,:{}",
              cache_info.prefix_path.display(),
              cache_info.prefix_len,
              escape_url(&cache_info.stream_url)
          );
          
          Ok(MpvInput {
              url,
              mpv_args: vec![
                  "--demuxer-lavf-o=protocol_whitelist=file,http,https,tcp,tls,crypto,subfile,concat".into()
              ],
          })
      }
  }
  
  fn escape_url(url: &str) -> String {
      // Escape special chars for concat protocol: , | 
      url.replace(',', "%2C").replace('|', "%7C")
  }
  ```
  
  **Acceptance Criteria**:
  - [x] ConcatSource implements MpvAudioSource
  - [x] URL properly formatted
  - [x] Special characters escaped
  - [x] protocol_whitelist included in mpv_args

---

- [x] **int-2: Add protocol_whitelist config**
  
  **What to do**:
  - Ensure MPV receives `--demuxer-lavf-o=protocol_whitelist=...` at startup
  - Modify `connect_or_spawn_mpv()` to accept extra args from MpvInput
  
  **References**:
  - `src/backends/youtube/mpv/ipc.rs` - MPV spawn logic
  
  **Acceptance Criteria**:
  - [x] protocol_whitelist passed to MPV
  - [x] Verified with `mpv --list-protocols`

---

- [x] **int-3: Wire into playback_service**
  
  **What to do**:
  Replace `build_playback_url()` with `MpvAudioSource::build_mpv_input()`:
  
  ```rust
  // Before:
  fn build_playback_url(&self, video_id: &str) -> String {
      self.url_resolver.resolve(video_id)  // Direct YouTube URL
  }
  
  // After:
  fn build_playback_url(&self, video_id: &str) -> Result<MpvInput> {
      let stream_url = self.url_resolver.resolve(video_id)?;
      let cache_info = self.audio_cache.ensure_prefix(video_id, &stream_url, content_length).await?;
      self.audio_source.build_mpv_input(video_id, &cache_info)
  }
  ```
  
  **References**:
  - `src/backends/youtube/services/playback_service.rs:305` - Current build_playback_url
  
  **Acceptance Criteria**:
  - [x] playback_service uses MpvAudioSource
  - [x] Prefix cache checked/downloaded before play
  - [x] `cargo build` passes
  - [x] Manual test: play song, verify instant start

---

- [x] **int-4: Add source selection config**
  
  **What to do**:
  ```rust
  // src/config.rs
  
  #[derive(Default)]
  pub enum AudioSourceType {
      #[default]
      Concat,
      Proxy,  // Future
  }
  
  pub struct YoutubeConfig {
      pub audio_source: AudioSourceType,
      // ...
  }
  ```
  
  **Acceptance Criteria**:
  - [x] Config option added
  - [x] Default is Concat
  - [x] Documented in config example

---

- [x] **int-5: Integration tests**
  
  **What to do**:
  - Test ConcatSource URL generation
  - Test AudioCache prefix download (mock HTTP)
  - Test end-to-end with real YouTube URL (optional, slow)
  
  **Acceptance Criteria**:
  - [x] Unit tests for ConcatSource
  - [x] Unit tests for AudioCache
  - [x] `cargo test` passes

---

### BATCH 3: Cleanup

- [x] **clean-1: Delete AudioFileManager**
  
  **What to do**:
  - Delete `src/backends/youtube/audio_file_manager.rs`
  - Remove from mod.rs exports
  - Remove any unused imports
  
  **Acceptance Criteria**:
  - [x] File deleted
  - [x] `cargo build` passes
  - [x] No orphan imports

---

- [x] **clean-2: Move RangeSet to audio/**
  
  **What to do**:
  - Move `src/backends/youtube/range_set.rs` to `src/backends/youtube/audio/range_set.rs`
  - Update imports
  - Add doc comment: "Reserved for future ProxySource seek tracking"
  
  **Acceptance Criteria**:
  - [x] File moved
  - [x] Imports updated
  - [x] `cargo build` passes

---

- [x] **clean-3: Mark ProgressiveAudioFile dormant**
  
  **What to do**:
  - Add module-level doc comment:
    ```rust
    //! # ProgressiveAudioFile (DORMANT)
    //!
    //! This module is NOT currently used in playback.
    //! Reserved for future HTTP Proxy implementation.
    //! See ADR-001 for architecture decisions.
    ```
  - Keep file but don't export publicly
  
  **Acceptance Criteria**:
  - [x] Doc comment added
  - [x] Not exported from mod.rs
  - [x] `cargo build` passes

---

- [x] **clean-4: Update mod.rs exports**
  
  **What to do**:
  - Export new audio module
  - Remove AudioFileManager export
  - Clean up unused exports
  
  **Acceptance Criteria**:
  - [x] Clean exports
  - [x] `cargo build` passes
  - [x] `cargo doc` generates clean output

---

## Verification Commands

### CRITICAL: Build/Test Policy

**BANNED in subagents:**
- `cargo build` - Only run at batch completion
- `cargo test` - Only run at plan completion  
- `cargo clippy` - Only run at plan completion

**Rationale**: Avoid redundant 45s+ compilation during individual tasks. Batch verification catches all issues efficiently.

### Verification Schedule

| Event | Commands |
|-------|----------|
| After BATCH 0 | None (docs only) |
| After BATCH 1 | `cargo build --package rmpc` |
| After BATCH 2 | `cargo build --package rmpc` |
| After BATCH 3 (Plan Complete) | `cargo build && cargo test && cargo clippy` |

### Final Verification (Plan Complete Only)
```bash
cargo build --package rmpc
cargo test --package rmpc
cargo clippy --package rmpc -- -D warnings
```

After BATCH 3:
```bash
cargo doc --package rmpc --no-deps
```

After BATCH 3:
```bash
cargo doc --package rmpc --no-deps
```

Final verification:
```bash
# Manual test with real YouTube
./target/debug/rmpc --config ./config/rmpc.ron
# Play a song, verify:
# 1. Instant start (prefix cached)
# 2. No gap at ~10s mark (byte-perfect junction)
# 3. Seek works
```

---

## Risk Mitigation

| Risk | Strategy |
|------|----------|
| URL escaping edge cases | Test with URLs containing special chars (, | %) |
| protocol_whitelist not applied | Verify with `mpv --msg-level=all=debug` |
| Cache corruption | Atomic writes, fsync on complete |
| Prefix too small | Calculate from bitrate, not fixed size |

---

## Success Criteria

- [x] Byte-perfect playback (no audible gap at junction)
- [x] Instant start for queued songs (prefix cached)
- [x] All 872+ tests still passing
- [x] No new clippy warnings
- [x] Documentation accurate and up-to-date
- [x] Dead code removed (AudioFileManager deleted)

---

## References

- `docs/adr/ADR-001-audio-streaming-architecture.md` - Architecture decisions
- `.sisyphus/drafts/oracle.md` - Oracle HTTP consultation
- `.sisyphus/drafts/metis.md` - Metis gap analysis
- `.sisyphus/drafts/clarification.md` - User requirements

---

## Ready to Execute

- **Plan**: pluggable-audio-source
- **Tasks**: 18
- **Batches**: 4 (Docs → Foundation → Integration → Cleanup)
- **Estimated**: 12-16 hours

Run `/start-work` to begin execution.
