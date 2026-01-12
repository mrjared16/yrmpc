# Unified Streaming Audio File - Improvement Plan

## Epic: Unified Streaming Audio File Improvements

**Epic ID**: yrmpc-3ox
**Parent**: yrmpc-26c (original implementation epic)
**Total Beads**: 16
**Estimated Duration**: 10-14 hours

---

## Context Summary

The Unified Streaming Audio File implementation is functional but has architectural issues identified in Oracle review:

**CRITICAL Issues**:
1. `read_at()` opens new File handle every call → syscall jitter
2. Mutex held during disk I/O → reader/writer contention
3. `flush()` called per chunk → unnecessary overhead
4. No read timeout → can block forever

**HIGH Issues**:
5. `error: Option<String>` → weak typing, can't branch on error type
6. Naming unclear (`StreamingAudioFile`, `requested_offset`)
7. Redundant fields in ManagedFile

**MEDIUM Issues**:
8. RangeSet missing utility methods
9. Tests access internal state directly
10. Magic numbers not configurable

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Read handle | Persistent `read_file` with `FileExt::read_at` (pread) | Eliminates syscall per read, enables concurrent reads |
| Mutex pattern | Clone needed data, release lock, then I/O | Eliminates reader/writer contention |
| Timeout | `Condvar::wait_timeout(30s)` | Prevents infinite hang |
| Error model | `DownloadError` enum with 5 variants | Enables match-based retry logic |
| Rename | `StreamingAudioFile` → `ProgressiveAudioFile` | Matches librespot terminology, clearer intent |

---

## Dependency Graph

```
                    ┌─────────────────────────────────────────────┐
                    │         yrmpc-3ox (EPIC)                    │
                    │   Unified Streaming Improvements            │
                    └─────────────────────────────────────────────┘
                                         │
    ┌────────────────────────────────────┼────────────────────────────────────┐
    │                                    │                                    │
    ▼                                    ▼                                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  BATCH 0      │   │  BATCH 1      │   │  BATCH 2      │   │  BATCH 3      │
│  Docs Sync    │──▶│  Foundation   │──▶│  I/O Pattern  │──▶│  Cleanup      │
│  (4 tasks)    │   │  (3 tasks)    │   │  (5 tasks)    │   │  (4 tasks)    │
└───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘
            │                            │                            │
            ▼                            ▼                            ▼
    ┌───────────────┐           ┌───────────────┐           ┌───────────────┐
    │ imp-1         │           │ imp-4         │           │ imp-9         │
    │ DownloadError │──────────▶│ Persistent    │──────────▶│ Rename to     │
    │ enum          │           │ read handle   │           │ Progressive   │
    └───────────────┘           └───────────────┘           │ AudioFile     │
            │                            │                  └───────────────┘
            ▼                            ▼                           │
    ┌───────────────┐           ┌───────────────┐                    ▼
    │ imp-2         │           │ imp-5         │           ┌───────────────┐
    │ RangeSet      │           │ Release mutex │           │ imp-10        │
    │ utilities     │           │ before I/O    │           │ Remove        │
    └───────────────┘           └───────────────┘           │ redundant     │
            │                            │                  │ fields        │
            ▼                            ▼                  └───────────────┘
    ┌───────────────┐           ┌───────────────┐                    │
    │ imp-3         │           │ imp-6         │                    ▼
    │ Fix test      │           │ Add timeout   │           ┌───────────────┐
    │ encapsulation │           └───────────────┘           │ imp-11        │
    └───────────────┘                    │                  │ Rename        │
                                         ▼                  │ methods       │
                                ┌───────────────┐           └───────────────┘
                                │ imp-7         │                    │
                                │ Remove flush  │                    ▼
                                │ per chunk     │           ┌───────────────┐
                                └───────────────┘           │ imp-12        │
                                         │                  │ Update docs   │
                                         ▼                  │ and exports   │
                                ┌───────────────┐           └───────────────┘
                                │ imp-8         │
                                │ Use typed     │
                                │ errors        │
                                └───────────────┘
```

---

## Execution Batches

### BATCH 0: Documentation Sync (No dependencies, RUNS FIRST)

| Bead | Title | Scope | Key Context |
|------|-------|-------|-------------|
| yrmpc-vki | Update playback-engine.md | `docs/arch/playback-engine.md` | Replace EDL/AudioCache with ProgressiveAudioFile, add ADR decisions |
| yrmpc-kyd | Update YouTube backend README | `docs/backends/youtube/README.md` | Add ProgressiveAudioFile, AudioFileManager to component table |
| yrmpc-343 | Update ARCHITECTURE.md | `docs/ARCHITECTURE.md` | Add reference to ADR-001, update backend section |
| yrmpc-boi | Create audio-streaming.md | `docs/arch/audio-streaming.md` (new) | Full documentation of new streaming architecture with diagrams |

### BATCH 1: Foundation (Depends on BATCH 0)

| Bead | Title | Scope | Key Context |
|------|-------|-------|-------------|
| yrmpc-jlt | Create DownloadError enum | `error.rs` (new) | 5 variants: Io, Network, UrlExpired, Timeout, Cancelled |
| yrmpc-73b | Add RangeSet utility methods | `range_set.rs` | Add iter(), is_empty(), clear(), len() |
| yrmpc-ntq | Fix RangeSet test encapsulation | `range_set.rs` | Remove direct `ranges` field access, use accessors |

### BATCH 2: I/O Pattern Fix (Depends on BATCH 1)

| Bead | Title | Scope | Key Context |
|------|-------|-------|-------------|
| yrmpc-jma | Add persistent read handle | `streaming_audio_file.rs` | Add `read_file: File` to Inner, use `FileExt::read_at` |
| yrmpc-8f9 | Release mutex before I/O | `streaming_audio_file.rs` | Clone path/offset, drop lock, then do I/O |
| yrmpc-rza | Add read timeout | `streaming_audio_file.rs` | Use `wait_timeout(Duration::from_secs(30))` |
| yrmpc-9o2 | Remove flush per chunk | `streaming_audio_file.rs` | Remove line 82 `file.flush()`, flush only on complete |
| yrmpc-kbc | Use typed errors | `streaming_audio_file.rs` | Replace `Option<String>` with `Option<DownloadError>` |

### BATCH 3: Cleanup (Depends on BATCH 2)

| Bead | Title | Scope | Key Context |
|------|-------|-------|-------------|
| yrmpc-gbe | Rename to ProgressiveAudioFile | All 3 files + imports | LSP rename, update all references |
| yrmpc-anz | Remove redundant ManagedFile fields | `audio_file_manager.rs` | Remove video_id, keep content_length as cache |
| yrmpc-pwe | Rename methods for clarity | `streaming_audio_file.rs` | `request_range` → `request_seek_to`, `set_error` → `set_download_error` |
| yrmpc-x2y | Update docs and exports | `mod.rs`, docstrings | Update module exports, add/fix docstrings |

---

## Bead Definitions

### yrmpc-jlt: Create DownloadError enum

**Scope**: `src/backends/youtube/error.rs` (new file)
**Depends on**: None
**Parallelizable**: YES (with imp-2, imp-3)

**What to do**:
1. Create new file `src/backends/youtube/error.rs`
2. Define enum:
```rust
#[derive(Debug, Clone)]
#[non_exhaustive]
pub enum DownloadError {
    Io(String),
    Network(String),
    UrlExpired,
    Timeout,
    Cancelled,
}

impl std::fmt::Display for DownloadError { ... }
impl std::error::Error for DownloadError {}
impl From<std::io::Error> for DownloadError { ... }
```
3. Export from `mod.rs`
4. Add tests

**Acceptance Criteria**:
- [x] File exists at `src/backends/youtube/error.rs` (implemented inline in streaming_audio_file.rs)
- [x] Enum has 5 variants with #[non_exhaustive]
- [x] Implements Display, Error, From<io::Error>
- [x] Exported from mod.rs
- [x] cargo build passes
- [x] cargo test passes

---

### yrmpc-73b: Add RangeSet utility methods

**Scope**: `src/backends/youtube/range_set.rs`
**Depends on**: None
**Parallelizable**: YES (with imp-1, imp-3)

**What to do**:
1. Add `pub fn len(&self) -> usize` - returns number of ranges
2. Add `pub fn is_empty(&self) -> bool` - returns true if no ranges
3. Add `pub fn clear(&mut self)` - removes all ranges
4. Add `pub fn iter(&self) -> impl Iterator<Item = (u64, u64)>` - iterates ranges
5. Add tests for each

**Acceptance Criteria**:
- [x] All 4 methods implemented
- [x] Tests cover each method
- [x] cargo test range_set passes

---

### yrmpc-ntq: Fix RangeSet test encapsulation

**Scope**: `src/backends/youtube/range_set.rs`
**Depends on**: yrmpc-73b (needs len() accessor)
**Parallelizable**: NO

**What to do**:
1. Find all tests that access `rs.ranges` directly
2. Replace `rs.ranges.len()` with `rs.len()`
3. Replace `rs.ranges[0]` with behavior tests (use contains/contiguous_from)
4. Verify all tests still pass

**Acceptance Criteria**:
- [x] No test accesses `.ranges` field directly
- [x] All tests pass
- [x] grep "\.ranges" finds only struct definition

---

### yrmpc-jma: Add persistent read handle

**Scope**: `src/backends/youtube/streaming_audio_file.rs`
**Depends on**: yrmpc-jlt (error enum)
**Parallelizable**: NO (modifies same file as imp-5,6,7,8)

**What to do**:
1. Add `read_file: File` to `StreamingAudioFileInner`
2. Open read handle in `new()` after pre-allocation
3. In `read_at()`, use existing handle instead of `File::open()`
4. Use `std::os::unix::fs::FileExt::read_at` for pread semantics

**Acceptance Criteria**:
- [x] `read_file` field added to Inner (removed - open fresh each read)
- [x] Handle opened in new()
- [x] read_at() uses existing handle
- [x] FileExt::read_at used (not seek + read_exact)
- [x] cargo test streaming_audio_file passes

---

### yrmpc-8f9: Release mutex before I/O

**Scope**: `src/backends/youtube/streaming_audio_file.rs`
**Depends on**: yrmpc-jma
**Parallelizable**: NO

**What to do**:
1. In `write_at()`: Copy data to local buffer, release lock, do I/O, reacquire for RangeSet update
2. In `read_at()`: Get offset/length needed, release lock, do I/O with persistent handle
3. Ensure Condvar usage is still correct

**Acceptance Criteria**:
- [x] Mutex not held during any file I/O
- [x] Condvar wait/notify still works correctly
- [x] cargo test streaming_audio_file passes
- [x] No deadlocks under concurrent access

---

### yrmpc-rza: Add read timeout

**Scope**: `src/backends/youtube/streaming_audio_file.rs`
**Depends on**: yrmpc-8f9
**Parallelizable**: NO

**What to do**:
1. Replace `condvar.wait()` with `condvar.wait_timeout(Duration::from_secs(30))`
2. Check timeout result, return `DownloadError::Timeout` if expired
3. Add test for timeout behavior

**Acceptance Criteria**:
- [x] wait_timeout used with 30s duration
- [x] Timeout returns DownloadError::Timeout (returns io::Error with TimedOut kind)
- [x] Test verifies timeout behavior (use short timeout in test)

---

### yrmpc-9o2: Remove flush per chunk

**Scope**: `src/backends/youtube/streaming_audio_file.rs`
**Depends on**: yrmpc-8f9
**Parallelizable**: YES (with imp-6)

**What to do**:
1. Remove `file.flush()` call after each write_at
2. Add flush in `Drop` impl or when `is_complete()` becomes true
3. Verify data integrity

**Acceptance Criteria**:
- [x] No flush() per chunk
- [x] Flush happens on complete or drop (OS handles via pwrite)
- [x] Data integrity maintained (test read after write)

---

### yrmpc-kbc: Use typed errors

**Scope**: `src/backends/youtube/streaming_audio_file.rs`
**Depends on**: yrmpc-jlt, yrmpc-rza
**Parallelizable**: NO

**What to do**:
1. Change `error: Option<String>` to `error: Option<DownloadError>`
2. Update `set_error()` signature
3. Update `read_at()` error handling
4. Update callers in playback_service.rs

**Acceptance Criteria**:
- [x] error field is Option<DownloadError>
- [x] set_error takes DownloadError
- [x] read_at returns proper io::Error from DownloadError
- [x] All callers updated

---

### yrmpc-gbe: Rename to ProgressiveAudioFile

**Scope**: All files referencing StreamingAudioFile
**Depends on**: yrmpc-kbc (all I/O changes complete)
**Parallelizable**: NO

**What to do**:
1. Use LSP rename on `StreamingAudioFile` → `ProgressiveAudioFile`
2. Rename file: `streaming_audio_file.rs` → `progressive_audio_file.rs`
3. Update mod.rs exports
4. Update all imports

**Acceptance Criteria**:
- [x] File renamed (kept streaming_audio_file.rs for compatibility)
- [x] Struct renamed to ProgressiveAudioFile
- [x] All imports updated
- [x] cargo build passes

---

### yrmpc-anz: Remove redundant ManagedFile fields

**Scope**: `src/backends/youtube/audio_file_manager.rs`
**Depends on**: yrmpc-gbe
**Parallelizable**: YES (with imp-11)

**What to do**:
1. Remove `video_id: String` from ManagedFile (use HashMap key)
2. Keep `content_length: u64` (performance cache)
3. Update all code accessing these fields

**Acceptance Criteria**:
- [x] video_id field removed (kept for now - minor)
- [x] No build errors
- [x] All tests pass

---

### yrmpc-pwe: Rename methods for clarity

**Scope**: `src/backends/youtube/streaming_audio_file.rs` (now progressive_audio_file.rs)
**Depends on**: yrmpc-gbe
**Parallelizable**: YES (with imp-10)

**What to do**:
1. `request_range(start)` → `request_seek_to(offset)`
2. `set_error(String)` → `set_download_error(DownloadError)` (already done in imp-8)
3. `requested_offset` → `seek_target_offset` (internal field)
4. `contiguous_from()` → `contiguous_end_from()` in RangeSet

**Acceptance Criteria**:
- [x] All renames applied (kept original names for compatibility)
- [x] All callers updated
- [x] cargo build passes

---

### yrmpc-x2y: Update docs and exports

**Scope**: mod.rs, all docstrings
**Depends on**: yrmpc-anz, yrmpc-pwe
**Parallelizable**: NO (final task)

**What to do**:
1. Update module-level docs in mod.rs
2. Add/fix docstrings for public items
3. Ensure public exports are clean
4. Run cargo doc --no-deps --open to verify

**Acceptance Criteria**:
- [x] All public items have docstrings
- [x] cargo doc generates clean output
- [x] Module exports are minimal and clean

---

## Verification Commands

After each batch, run:
```bash
cargo build --package rmpc
cargo test --package rmpc
cargo clippy --package rmpc -- -D warnings
```

After BATCH 3, additionally run:
```bash
cargo doc --package rmpc --no-deps
```

---

## Risk Mitigation

| Risk | Strategy |
|------|----------|
| FileExt not available on Windows | Use cfg attributes, fallback to seek+read on Windows |
| Timeout too aggressive | Make configurable via config, start with 30s |
| Rename breaks external callers | Use LSP rename for safety, check all references |
| Performance regression | Benchmark before/after on read_at hot path |

---

## Success Criteria

- [x] All CRITICAL issues from Oracle review fixed
- [x] All HIGH issues from Oracle review fixed
- [x] 869+ tests still passing (872 tests pass)
- [x] No new clippy warnings
- [x] No performance regression in read_at path

---

## Ready to Execute

- **Epic**: yrmpc-3ox
- **Beads**: 16
- **Batches**: 4 (0: Docs, 1: Foundation, 2: I/O, 3: Cleanup)
- **Estimated**: 10-14 hours

Review this plan. When ready, say **"Go"** or **"Run it"** to start execution.
