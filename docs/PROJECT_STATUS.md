# Project Status

**Last Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Use

---

## Recent Completions

| Feature | Status |
|---------|--------|
| **Rich List UI** | ✅ |
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
| Thumbnail renders corner only | P1 | Element sizing issue |
| High CPU idle | P1 | Needs profiling |
| Slow cold start | P2 | First search takes ~3s |

---

## Backlog (Prioritized)

> **UI/UX Spec:** See [docs/ui-ux-provised.md](docs/ui-ux-provised.md) for full specification.
> **Architecture:** See [docs/ADR-rich-list-ui.md](docs/ADR-rich-list-ui.md) for Rich List implementation.

### P0 - Critical
| Task | Description |
|------|-------------|
| Queue Playing Highlight | R-QUEUE-1: Bold + ▶ icon for current track |

### P1 - High Priority
| Task | Description |
|------|-------------|
| **Thumbnail Rendering Fix** | Displays corner only, need proper scaling |
| **Queue View Revamp** | R-QUEUE-2/3: Rich mode thumbnail per-row, reorder, remove |
| **Search Preview Thumbnail** | R-SEARCH-2: Show cover in preview column |
| **Artist View** | R-DETAIL-1/2: Sectioned layout with top songs, albums |
| **Playlist/Album Detail** | R-DETAIL-1/2: Play All, navigation back |
| High CPU Idle | Profiling needed |

### P2 - Medium Priority
| Task | Description |
|------|-------------|
| Prefetch | Buffer next tracks for gapless playback |
| Now Playing View | R-NOW-1/2/3: Large album art, progress bar, controls |
| Repeat/Shuffle | Queue playback modes |
| Play Next/Last | Queue position control (Shift+Enter) |

### P3 - Low Priority
| Task | Description |
|------|-------------|
| API Filtering | Fetch only needed sections |
| Grid View | Album grid for browsing |

### P4 - Future
| Task | Description |
|------|-------------|
| Unit Tests: Rich List | Tests for `ListItemDisplay`, `ItemListWidget` |

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
