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
| MPRIS garbage | media-title property access fails in MPV |
| Artist/playlist views | Not implemented |
| Status polling | 1s interval (configurable, wastes CPU) |

---

## Backlog (Priority Order)

1. **MPRIS metadata** - media-title fails, need MPV script-message or alternative
2. **Status polling** - Push-based updates or increase interval
3. **10s audio prefetch** - Pre-fetch audio for visible songs
4. **Local-first queue** - UI updates before network
5. **Views**: Artist, Playlist, Album
6. **Search suggestions** - Autocomplete

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
