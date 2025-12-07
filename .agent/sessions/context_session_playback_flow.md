# Session Context: Playback Flow Fix

## Session ID: playback_flow_fix
## Date Started: 2025-12-07
## Status: Planning

---

## Current Focus

### P0-1: Enter on Song Should PLAY (Not Just Queue)

**Symptom:** Pressing Enter on a song in search results only adds it to the queue but doesn't start playback.

**Expected Behavior:** Enter on song → clears queue → adds song → starts playing

---

### P0-2: Clear Queue Doesn't Stop MPV Playback

**Symptom:** When queue is cleared, MPV continues playing the current song. This likely causes the "Enter doesn't play" issue because the old song keeps playing while the new song is added to an empty queue.

**Root Cause (likely):** `QueueService::clear()` only clears the queue data, doesn't call `playback.stop()`.

**Fix:** In `server.rs`, when handling `Clear` command, also call `playback.stop()`.

---

### P0 Related Files
- `rmpc/src/ui/panes/search/mod.rs` - Search pane Enter handler (lines 941-995)
- `rmpc/src/shared/mpd_client_ext.rs` - enqueue_multiple (lines 907-967)
- `rmpc/src/player/youtube/client.rs` - play_pos (line 127)
- `rmpc/src/player/youtube/server.rs` - play_position (lines 317-348)

**Code Trace (2025-12-07):**
1. Enter key → `resolve_and_enqueue(Position::Replace, AutoplayKind::First)`
2. `enqueue_multiple(items, autoplay_idx=Some(0), position=None, replace=true)`
3. YouTube branch: `clear()` → `add_song()` → `play_pos(0)`
4. Server `play_position(0)` → `get_stream_url()` → `play(url, title, artist)`

**The code path looks correct!** Need runtime debugging to find why play doesn't start.

**Hypothesis:** Either:
1. play_pos returns error (swallowed silently?)
2. get_stream_url fails (5-6s timeout?)
3. add_song didn't complete before play_pos called (unlikely - synchronous IPC)

---

### P1: TopResult Parsing Failure

**Log:**
```
WARN rmpc::player::youtube::api] ✗ Failed to parse top result: TopResult { 
  result_name: "KIMLONG", 
  result_type: Some(Artist), 
  browse_id: None,  // <-- This is the problem
  ...
}
```

**Root Cause:** Some TopResults (Artists) don't have `browse_id`, causing parse failure.

**Impact:** Some search results may be missing or not browsable.

---

## Prioritized Backlog

| Priority | Issue | Impact |
|----------|-------|--------|
| **P0** | Enter on song only adds queue, no play | Blocks primary use case |
| **P1** | TopResult Artist without browse_id | Some search results missing |
| **P2** | Artist/Playlist/Album views | Not implemented |
| **P2** | Local-first queue (rofi prep) | UX improvement |
| **P2** | Status polling optimization | CPU usage |
| **P2** | 10s audio prefetch | UX improvement |
| **P3** | Search suggestions | Nice to have |

---

## Previous Session

MPRIS metadata fix completed (commit 6c82386):
- Set `force-media-title` before `loadfile`
- Test: `test_loadfile_with_force_media_title` passed

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `search/mod.rs` | Search pane, Enter key handler |
| `mpd_client_ext.rs` | Queue operations (enqueue_multiple) |
| `youtube/client.rs` | YouTubeClient RPC methods |
| `api.rs` | Search result parsing, TopResult handling |
