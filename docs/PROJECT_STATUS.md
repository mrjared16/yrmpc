# Project Status

**Last Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Used

---

## Recent Completions

| Feature | Status |
|---------|--------|
| **Search Display Refactor** | ✅ |
| **Configurable Section Order** | ✅ |
| **TopResult Support** | ✅ |
| **Autocomplete Suggestions** | ✅ |
| **Daemon Architecture** | ✅ |

---

## Current State

### Working ✅
- Search with all content types (songs, artists, albums, playlists)
- Playback via MPV with streaming URLs
- Queue management (add, remove, play next/last)
- MPRIS integration
- Daemon mode with systemd

### Known Issues
| Issue | Priority | Notes |
|-------|----------|-------|
| High CPU idle | P1 | Needs profiling |
| Slow cold start | P2 | First search takes ~3s |

---

## Next Tasks

| Task | Priority | Description |
|------|----------|-------------|
| **Rich List UI** | P1 | Thumbnail + 2-line layout (opt-in) |
| **API Filtering** | P2 | Only fetch sections user wants |
| **Repeat/Shuffle** | P2 | Queue playback modes |

---

## Quick Commands

```bash
# Rebuild
cd rmpc && cargo build --release

# Restart daemon  
./restart_daemon.sh

# Run client
./rmpc/target/release/rmpc --config config/rmpc.ron
```
