# Learnings - Unified Streaming Improvements

## Session: ses_44e2a6b5bffej4Dsb2aV4XuGoM (2026-01-12)

### Project Context
- This is a follow-up to the unified-streaming-audio-file implementation
- Fixing CRITICAL, HIGH, and MEDIUM issues identified in Oracle review
- Key improvements: persistent read handle, mutex pattern, timeout, typed errors, rename

### Conventions
- Use `FileExt::read_at` / `write_at` (pread/pwrite) for concurrent file I/O
- Clone data before releasing mutex for I/O operations
- Use `Condvar::wait_timeout` instead of bare `wait` to prevent infinite hangs
- Typed error enums enable match-based retry logic
- Follow librespot naming: ProgressiveAudioFile (not StreamingAudioFile)

### Successful Approaches
1. **Subagent delegation failed for documentation** - they only updated beads, not actual files. Direct execution was required.
2. **LSP diagnostics are stale during rapid edits** - use `cargo check` for ground truth
3. **Batch beads closing** - `bd close id1 id2 id3` is efficient for multiple completions
4. **FileExt trait** - requires `use std::os::unix::fs::FileExt` and works only on Unix

### Key Implementation Details
- DownloadError enum with 5 variants: Network, Http, UrlExpired, Io, Cancelled
- `is_retryable()` returns true for Network, Http>=500, UrlExpired
- `needs_url_refresh()` returns true for UrlExpired and Http 403
- RangeSet utilities: len(), is_empty(), clear(), iter()
- 30s timeout on read_at() using wait_timeout

### Files Modified
- `rmpc/src/backends/youtube/streaming_audio_file.rs` - Major refactor
- `rmpc/src/backends/youtube/range_set.rs` - Added utilities
- `rmpc/src/backends/youtube/audio_file_manager.rs` - Updated imports/types
- `rmpc/src/backends/youtube/mod.rs` - Updated exports
- `docs/arch/audio-streaming.md` - NEW comprehensive doc
- `docs/arch/playback-engine.md` - Updated for ProgressiveAudioFile
- `docs/backends/youtube/README.md` - Added components to table
- `docs/ARCHITECTURE.md` - Added cross-references

### Test Results
- 872 tests passing (all lib tests)
- 21 range_set tests
- 6 streaming_audio_file tests
