# Session Context: YouTube Backend Integration Fix

## Session ID: youtube_backend_fix_001
## Date Started: 2025-12-06
## Status: Planning Phase

---

## Background

### The Problem
The YouTube backend has a **fundamental architecture mismatch** after refactoring:
- **Before**: `Client::YouTube` held `YouTubeBackend` (in-process)
- **After**: `Client::YouTube` holds `YouTubeClient` (thin daemon RPC client)

The `YouTubeClient` is **incomplete** - many methods are stubs or missing.

### Symptoms Observed
1. **No search suggestions** - autocomplete doesn't work
2. **"YouTube backend not available"** when selecting albums/playlists
3. **Queue shows "Unknown - Unknown Album"** - metadata not flowing
4. **No audio playback** - "Song not found" error
5. **Artists/playlists view broken**

### Root Cause Analysis
See: `~/.gemini/antigravity/brain/64cc79dc-ab0b-4eed-9901-9d1b166e618e/deep_analysis.md`

Key findings:
- `YouTubeClient` has stub methods (suggestions returns empty)
- Missing `ServerCommand` types for browse operations
- Queue IDs not synchronized between client and daemon
- Metadata not properly flowing from daemon to client

---

## Fixes Already Applied

### 1. Stream Cloning Panic (FIXED)
- **File**: `rmpc/src/player/youtube/client.rs`
- **Fix**: `try_clone_stream()` now properly clones stream

### 2. Protocol Corruption (FIXED)
- **Files**: `player/client.rs`, `core/client.rs`
- **Fix**: Added `YouTubeStream` wrapper with no-op `write_noidle()`

---

## Current Status

**Playback now works!** (after Tier 0 fixes)
- Takes 6s to start (expected - yt-dlp extraction)
- Second attempt works reliably

## Remaining Issues - Strategic Tiers

### Tier 1: Core Fixes (P0) - NOT STARTED
| Issue | Root Cause | Fix Location |
|-------|------------|--------------|
| Queue fills with ALL songs | search/mod.rs passes all songs | `search/mod.rs` |
| Raw IDs instead of metadata | Add command only sends URI | `protocol.rs`, `server.rs`, `client.rs` |

### Tier 2: Reliability (P0)
| Issue | Root Cause | Fix |
|-------|------------|-----|
| First Enter fails | Race between clear/add/play | Verify queue populated before play |

### Tier 3: UI Updates (P1)
- Queue requires restart to see changes → Add polling

### Tier 4: Features (P1-P2)
- Album/playlist browsing
- Play next/play last
- Search suggestions

## Completed Fixes (Tier 0)
- `try_clone_stream()` panic → Clone from BufReader
- `noidle` protocol corruption → Custom write_noidle()
- `song.id = None` → Set in queue_service.add()
- `play_id` stale data → Use play_pos() directly
- `set_property` JSON format → Native JSON values


---

## Architecture Decision

**User Decision (2025-12-06):**
- ✅ **Daemon mode only** - no in-process fallback
- ✅ Remove any obsolete in-process logic
- ✅ rmpc = caller + data handling only (not fetch logic)
- ✅ Fix playback first (P0)
- ✅ Log-based tests (crossterm key sending unreliable)

---

---

## Key Files

### Client-side (TUI)
- `rmpc/src/player/client.rs` - Client enum, dispatch logic
- `rmpc/src/player/youtube/client.rs` - YouTubeClient (RPC)
- `rmpc/src/shared/mpd_client_ext.rs` - Queue operations

### Server-side (Daemon)
- `rmpc/src/player/youtube/server.rs` - Command handler
- `rmpc/src/player/youtube/protocol.rs` - IPC messages
- `rmpc/src/player/youtube/services/` - ApiService, QueueService, etc.

### In-process (unused currently)
- `rmpc/src/player/youtube_backend.rs` - Full implementation

---

## Log Files
- Manual test log: `rmpc/actual_log.log`
- Test scripts: `tests/verify_protocol_fix.sh`, `tests/test_search_flow.sh`

---

## Next Steps
1. Get user decision on architecture approach
2. Create detailed implementation plan
3. Execute fixes in priority order
4. Verify with E2E tests

---

## MPRIS Fix Session (2025-12-07)

### Root Cause Analysis
The MPRIS metadata shows URL garbage because:
- `playback_service.rs:76` sends `loadfile` without `force-media-title` option
- `title` and `artist` parameters are passed but ignored (prefixed with `_`)
- Previous attempt failed because `media-title` is READ-ONLY in MPV

**Solution:** Use `loadfile` 4th parameter (options object) with `force-media-title`:
```json
{"command": ["loadfile", "url", "replace", {"force-media-title": "Artist - Title"}]}
```

### Files to Modify
1. `rmpc/src/player/mpv_ipc.rs` - Add `loadfile_with_options()` method
2. `rmpc/src/player/youtube/services/playback_service.rs` - Use new method in `play()`

### TDD Approach
1. Write test: `rmpc/tests/mpris_metadata_test.rs`
2. Test expects `media-title` property to match forced title
3. Run test → expect fail
4. Implement fix
5. Run test → expect pass

### Backlog Updates
Added to backlog:
- **UX Queue Optimization** - Local-first queue ops for rofi integration readiness
- **Search View UI** - Better category separation, loading indicators
- **Queue View UI** - Currently playing highlight, duration display

### Fix Status: ✅ COMPLETE (2025-12-07)

**Implementation:**
- Modified `playback_service.rs:play()` to call `set_property("force-media-title", title)` before `loadfile`
- Title format: "Artist - Title" (or just "Title" if no artist)
- Added debug logging for troubleshooting

**Verification:**
- Unit test `test_loadfile_with_force_media_title` passed
- Build successful (release)
- Daemon restarted with fix

