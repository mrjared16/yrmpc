# Project Status

**Last Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Use

---

## Recent Completions

| Feature | Status |
|---------|--------|
| Search Display Refactor | ✅ |
| Configurable Section Order | ✅ |
| TopResult Support | ✅ |
| Autocomplete Suggestions | ✅ |
| Daemon Architecture | ✅ |

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

## Next Tasks: Rich UI

> **Spec:** See [docs/ui-ux-provised.md](docs/ui-ux-provised.md) for full UI/UX specification.

| ID | Task | Priority | Description |
|----|------|----------|-------------|
| R-RICH-1 | Rich List Component | P1 | Thumbnail + 2-line layout per item |
| R-RICH-2 | Adaptive Behavior | P2 | Graceful degradation on narrow terminals |
| R-SEARCH-2 | Preview Panel Thumbnail | P2 | Show cover in preview column |
| R-QUEUE-1 | Playing Highlight | P0 | Bold + ▶ icon for current track |

---

## Backlog

| Priority | Task | Description |
|----------|------|-------------|
| P1 | Rich List UI | Thumbnail + 2-line items (opt-in) |
| P1 | High CPU Idle | Profiling needed |
| P2 | API Filtering | Fetch only needed sections |
| P2 | Repeat/Shuffle | Queue playback modes |
| P2 | Play Next/Last | Queue position control |
| P3 | Prefetch | Buffer next tracks |
| P3 | Grid View | Album grid for browsing |

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
