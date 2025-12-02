# Project Status

**Last Updated**: 2024-12-02  
**Status**: ❌ Core functionality broken

---

## Current State (Verified by Manual Testing)

### ❌ What's NOT Working

| Feature | Expected | Actual | Bug |
|---------|----------|--------|-----|
| Enter on song | Play audio | Nothing happens | Bug #1 |
| Enter on artist | Show artist page | HTTP 400, blank page | Bug #2 |
| Enter on playlist | Show playlist | HTTP 400, blank page | Bug #2 |
| Audio playback | Hear music | No audio | Bug #1 |

### ✅ What IS Working

- App starts without crashing
- UI renders correctly
- Navigation (j/k, tabs) works
- Search input accepts text
- Search returns results (visually)
- MPV process runs in background

---

## Test Status

### E2E Tests (TypeScript)
```
npm test → 3 passed, 3 failed
```

| Test | Status | What it Verifies |
|------|--------|------------------|
| UI Visibility (3 tests) | ✅ Pass | App starts, tabs visible |
| FEATURE: play song | ❌ Fail | MPV loadfile command sent |
| FEATURE: view artist | ❌ Fail | browse_artist called without HTTP 400 |
| FEATURE: view playlist | ❌ Fail | browse_playlist called without HTTP 400 |

**These feature tests use `RMPC_LOG_FILE` env var to capture logs and verify actual behavior.**

### Rust Integration Tests
```bash
cd rmpc && cargo test --test youtube_backend_tests
```
13 unit tests for ID format validation and expected behavior.

### Manual Testing
```bash
./rmpc/target/release/rmpc --config ./config/rmpc.ron
```

---

## Known Bugs

### Bug #1: Enter Key on Song Does Nothing
- **Severity**: Critical
- **Root Cause**: `enqueue_multiple` in `shared/mpd_client_ext.rs` is a no-op for YouTube backend
- **Location**: Lines 769-775 in `rmpc/src/shared/mpd_client_ext.rs`
- **Code**:
  ```rust
  crate::player::Client::YouTube(_) => {
      log::debug!("enqueue_multiple not fully supported in MPV/YouTube backend");
      Ok(())
  }
  ```
- **Fix Required**: Implement actual queue/play logic for YouTube backend
- **Test**: `npm test` - "FEATURE: play song" should pass when fixed

### Bug #2: HTTP 400 on Artist/Playlist Browse  
- **Severity**: Critical
- **Root Cause**: IDs have prefixes like `"artist:UC..."` but ytmapi-rs expects raw IDs
- **Location**: `rmpc/src/player/youtube_backend.rs` - `browse_artist()`, `browse_playlist()`
- **Fix Required**: Strip prefix before calling API:
  ```rust
  let raw_id = artist_id.strip_prefix("artist:").unwrap_or(artist_id);
  ```
- **Test**: `npm test` - "FEATURE: view artist/playlist" should pass when fixed

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  yrmpc TUI (Rust/Ratatui)                   │
│  - Search pane: mod.rs                      │
│  - Enter handler: CommonAction::Confirm     │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  YouTubeBackend (youtube_backend.rs)        │
│  - search() → ytmapi-rs → YouTube API       │
│  - browse_*() → fetch detail pages          │
│  - get_stream_url() → rusty_ytdl            │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  MpvIpc (mpv_ipc.rs)                        │
│  - Unix socket: /tmp/rmpc-mpv.sock          │
│  - Commands: loadfile, pause, volume        │
└─────────────────┬───────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────┐
│  MPV Process                                │
│  - mpv --idle=yes --vo=null                 │
│  - Decodes audio, outputs to PulseAudio     │
└─────────────────────────────────────────────┘
```

---

## Files To Investigate

| Priority | File | Why |
|----------|------|-----|
| 1 | `rmpc/src/ui/panes/search/mod.rs` | Enter key handler |
| 2 | `rmpc/src/player/youtube_backend.rs` | browse_* functions, HTTP 400 |
| 3 | `rmpc/src/player/mpv_ipc.rs` | MPV communication |
| 4 | `config/rmpc.ron` | Configuration |

---

## Next Steps

1. **Investigate Bug #1**: Why Enter on song does nothing
   - Find the `CommonAction::Confirm` handler for songs
   - Add logging to trace execution
   - Check if enqueue is called

2. **Investigate Bug #2**: Why HTTP 400 on browse
   - Check YouTube API authentication
   - Verify cookie file is valid
   - Check API request format

3. **Fix and verify** with manual testing (not E2E tests)

---

## Testing Guidelines

### DO NOT Trust
- `npm test` results
- `tests/integration_test.sh`
- Any automated TUI interaction

### DO Trust
- `cargo test` in rmpc/
- `python3 tests/verify_audio.py`
- Manual testing with actual keyboard input
