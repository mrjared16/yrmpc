# Unified Streaming Audio File Implementation

**Epic**: yrmpc-26c
**Goal**: Eliminate 20ms audio glitch by replacing EDL splicing with unified temp file streaming
**Estimated**: 26-38 hours across 7 phases

---

## Phase 1: Foundation - RangeSet (2-3 hours)

### Task 1.1: Create RangeSet module
- [x] Create `src/backends/youtube/range_set.rs`
- [x] Implement `RangeSet` struct with sorted `Vec<(u64, u64)>` of byte ranges
- [x] Implement `new()`, `add_range(start, end)`, `contains(offset)`, `contiguous_from(offset)`
- [x] Auto-merge overlapping and adjacent ranges
- [x] Add comprehensive unit tests (empty, single range, merge scenarios, gaps) - **19 tests passing**
- [x] **Bead**: `yrmpc-nrs` - CLOSED
- [x] **Parallelizable**: NO (foundation for all other work)

---

## Phase 2: StreamingAudioFile (4-6 hours)

### Task 2.1: Create StreamingAudioFile struct
- [x] Create `src/backends/youtube/streaming_audio_file.rs`
- [x] Implement struct with: path, read_file, write_file, downloaded (RangeSet), content_length, condvar
- [x] Implement `new(path, content_length)` - pre-allocates file
- [x] Implement `write_at(offset, data)` - background writer calls this
- [x] Implement `read_at(offset, buf)` - blocks until bytes available via Condvar
- [x] Implement `bytes_available_from(offset)` - non-blocking check
- [x] Thread-safe with `Arc<Mutex<...>>` and `Condvar` - **6 tests passing**
- [x] **Bead**: `yrmpc-271` - CLOSED
- [x] **Parallelizable**: NO (depends on Phase 1)

---

## Phase 3: AudioFileManager (4-6 hours)

### Task 3.1: Create AudioFileManager
- [x] Create `src/backends/youtube/audio_file_manager.rs`
- [x] Implement `AudioFileManager` with HashMap<video_id, ManagedFile>
- [x] Implement `get_or_create(video_id, content_length)` - returns Arc<StreamingAudioFile>
- [x] Implement `get(video_id)`, `remove(video_id, delete_file)`
- [x] Track metadata: content_length, last_accessed for future LRU - **5 tests passing**
- [x] **Bead**: `yrmpc-mas` - CLOSED
- [x] **Parallelizable**: NO (depends on Phase 2)

---

## Phase 4: PlaybackService Integration (3-4 hours)

### Task 4.1: Replace EDL with unified file
- [x] Modify `src/backends/youtube/services/playback_service.rs`
- [x] Remove EDL construction logic
- [x] Use `AudioFileManager` to get/create streaming file
- [x] Pass temp file path directly to MPV (no `edl://` prefix)
- [x] Ensure MPV reads growing file correctly (WebM clusters are self-contained)
- [x] **Bead**: `yrmpc-7vy` - CLOSED
- [x] **Parallelizable**: NO (depends on Phase 3)

---

## Phase 5: Prefetch & LRU (4-6 hours)

### Task 5.1: Sliding prefetch window
- [x] Implement prefetch strategy in orchestrator
- [x] Current track: full download
- [x] Next track: full download  
- [x] Next+2, Next+3: 30-second prefetch only (~1.2MB each)
- [x] **Bead**: `yrmpc-cis` - CLOSED
- [x] **Parallelizable**: YES (with 5.2)

### Task 5.2: T-30s prefetch trigger
- [x] Add position tracking in playback service
- [x] At T-30s before end, trigger next track prefetch
- [x] **Bead**: `yrmpc-x66` - CLOSED
- [x] **Parallelizable**: YES (with 5.1)

### Task 5.3: LRU eviction policy
- [x] Track file access times in AudioFileManager
- [x] Implement 100MB cache limit
- [x] Evict least-recently-used files when limit exceeded
- [x] Never evict currently playing or next track
- [x] **Bead**: `yrmpc-vpc` - CLOSED
- [x] **Parallelizable**: YES (with 5.1, 5.2)

---

## Phase 6: Edge Cases (4-6 hours)

### Task 6.1: Handle seek to undownloaded region
- [x] Detect seek to byte offset not yet downloaded
- [x] Cancel current download, restart from seek position
- [x] Use HTTP Range header: `Range: bytes=N-`
- [x] Block read until sufficient bytes available
- [x] **Bead**: `yrmpc-6gi` - CLOSED
- [x] **Parallelizable**: YES (with 6.2)

### Task 6.2: Handle URL expiration
- [x] YouTube URLs expire after ~6 hours
- [x] Detect 403/410 errors during download
- [x] Re-fetch URL via ytx, resume download
- [x] **Bead**: `yrmpc-4mn` - CLOSED
- [x] **Parallelizable**: YES (with 6.1)

---

## Phase 7: Cleanup (2-3 hours)

### Task 7.1: Remove legacy AudioCache/EDL code
- [x] Delete `src/backends/youtube/audio_cache.rs`
- [x] Remove all EDL-related code paths
- [x] Update imports and module declarations
- [x] Run full test suite, fix any regressions
- [x] **Bead**: `yrmpc-d9h` - CLOSED
- [x] **Parallelizable**: NO (final cleanup)

---

## Key Technical Decisions

1. **Unified temp file over EDL**: Single decoder instance, no reinit glitch
2. **Sliding prefetch window**: current+next full, next+2/3 partial (19MB typical)
3. **30-second buffer**: Matches librespot, covers 22s download + 8s margin
4. **HTTP Range for resume**: YouTube supports `Range: bytes=N-`
5. **Cache location**: `~/.cache/rmpc/audio/{video_id}.webm.part`
6. **LRU at 100MB**: Respects user's limited disk space

---

## Files to Create/Modify

| Action | File |
|--------|------|
| CREATE | `src/backends/youtube/range_set.rs` |
| CREATE | `src/backends/youtube/streaming_audio_file.rs` |
| CREATE | `src/backends/youtube/audio_file_manager.rs` |
| MODIFY | `src/backends/youtube/services/playback_service.rs` |
| MODIFY | `src/backends/youtube/server/orchestrator.rs` |
| DELETE | `src/backends/youtube/audio_cache.rs` |

---

## Success Criteria

- [x] No audio glitch at any point during playback
- [x] Seamless seek to any position (blocks until bytes ready)
- [x] Gapless playback between tracks
- [x] Cache stays under 100MB with LRU eviction
- [x] URL expiration handled gracefully
- [x] All existing tests pass
