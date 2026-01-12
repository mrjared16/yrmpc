# Decisions - Unified Streaming Improvements

## Session: ses_44e2a6b5bffej4Dsb2aV4XuGoM (2026-01-12)

### Key Decisions from Plan

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Read handle | Persistent `read_file` with `FileExt::read_at` (pread) | Eliminates syscall per read, enables concurrent reads |
| Mutex pattern | Clone needed data, release lock, then I/O | Eliminates reader/writer contention |
| Timeout | `Condvar::wait_timeout(30s)` | Prevents infinite hang |
| Error model | `DownloadError` enum with 5 variants | Enables match-based retry logic |
| Rename | `StreamingAudioFile` -> `ProgressiveAudioFile` | Matches librespot terminology, clearer intent |
