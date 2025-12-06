# Project Status

**Last Updated**: 2025-12-07  
**Status**: ✅ Playable but Terrible UX

---

## Current State

### ✅ What Works
| Feature | Status |
|---------|--------|
| Search | Returns results with categories |
| Enter on song | Plays (5-6s delay) |
| Queue | Updates after adding |
| Audio playback | Works via MPV |
| Daemon | Stable systemd service |

### ❌ What's Broken
| Feature | Issue |
|---------|-------|
| Artist view | Not implemented |
| Playlist view | Not implemented |
| Album view | Not implemented |
| MPRIS | Shows URL instead of title |
| Response time | 5-6s delay (yt-dlp extraction) |

---

## Future Plans

### Local-First Queue
Queue operations should update UI instantly:
- Add/Delete/Move → UI first, then network sync

### 10-Second Audio Prefetch
Pre-fetch first 10s of audio for visible songs:
- Background extraction during browsing
- Instant playback from cache

---

## Key Files

| File | Purpose |
|------|---------|
| `playback_service.rs:76` | MPRIS fix (set media-title) |
| `mpd_client_ext.rs` | Queue operations |
| `stream.rs` | Prefetch implementation |

---

## Build & Test

```bash
# Build
cd rmpc && cargo build --release

# Restart daemon
./restart_daemon.sh

# Run client
./rmpc/target/release/rmpc --config setup/config.ron
```
