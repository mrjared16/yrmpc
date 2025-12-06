# Current Session State (Updated: 2025-12-07)

## Project Status
**Playable but Terrible UX**

### What Works
- Search with categories (Artists, Songs, Albums, Playlists)
- Playback on Enter (5-6s delay from yt-dlp extraction)
- Queue refresh after AddSong

### What's Broken
- MPRIS displays URL garbage instead of song title
- Artist/Playlist/Album views not implemented
- Queue operations wait for network (feels slow)

## Code Changes This Session
1. `search/mod.rs:991` - AutoplayKind::First (fixes playback on Enter)
2. `image_cache.rs:63` - std::thread::spawn (fixes Tokio panic)
3. `mpd_client_ext.rs:49-61` - GLOBAL_QUEUE_UPDATE query after YouTube enqueue

## Future Plans

### Local-First Queue
Queue operations should update UI immediately, then sync to daemon:
- Add/Delete/Move → instant UI update
- Daemon sync in background
- No blocking on network

### 10-Second Prefetch
Pre-fetch first 10 seconds of audio for visible songs:
- Background: yt-dlp extracts URL + curl fetches 10s
- Cache in ~/.cache/yrmpc/
- Enter → instant playback from cache

## Key Files
- `playback_service.rs:76` - needs MPRIS fix (set media-title)
- `mpd_client_ext.rs` - queue operations
- `stream.rs` - prefetch implementation location