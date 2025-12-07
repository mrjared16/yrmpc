# LLM Agent Guidelines - yrmpc Project

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Last Updated**: 2025-12-07  
**Status**: Playable but Terrible UX

---

## Current State

### Works
- Search → shows results (categories)
- Enter on song → plays (5-6s delay)
- Queue → refreshes after adding

### Broken
| Issue | Root Cause |
|-------|-----------|
| 5-6s delay | yt-dlp URL extraction |
| ~~MPRIS garbage~~ | ✅ Fixed: set force-media-title before loadfile |
| Artist/playlist views | Not implemented |
| Status polling | 1s interval (configurable, wastes CPU) |

---

## Backlog (Strategic Priority)

### P0 - Must Fix (Blocking Primary Use Case)
1. **Enter on song only adds queue, no play** - Should clear queue, add, and play
2. **Clear queue doesn't stop MPV playback** - `clear()` should stop current playback in MPV

### P1 - Should Fix (Bugs Affecting UX)
2. **TopResult parsing failure** - Artists without browse_id fail to parse

### P2 - Nice to Have
3. ~~**MPRIS metadata**~~ - ✅ Fixed (2025-12-07)
4. **Views**: Artist, Playlist, Album - Not implemented
5. **Local-first queue** - UI updates before network (rofi prep)
6. **Status polling** - Push-based updates or increase interval
7. **10s audio prefetch** - Pre-fetch audio for visible songs

### P3 - Future
8. **Search suggestions** - Autocomplete

---

## Key Files

| File | Purpose |
|------|---------|
| `playback_service.rs` | MPV control (MPRIS fix attempt here) |
| `server.rs:110-126` | Changed logs to DEBUG |
| `mpd_client_ext.rs` | Queue operations |

---

## Build & Test

```bash
cd rmpc && cargo build --release
pkill rmpcd; ./restart_daemon.sh
./rmpc/target/release/rmpc --config setup/config.ron
```

---

## DO NOT Touch
- `setup/*` - systemd config
- `bin/rmpcd.rs` - daemon entry
