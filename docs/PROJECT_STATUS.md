# Project Status

**Last Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Use

---

## Recent Completions (This Session)

| Feature | Status |
|---------|--------|
| **Header Skip Navigation** | ✅ j/k skips unfocusable headers |
| **Metadata Display (Browsables)** | ✅ Artist subscribers, album year, playlist track count |
| **Filter Highlighting (Rich Mode)** | ✅ Blue text for matched items |
| **Rich Preview Panel** | ✅ Search preview uses rich mode |
| **is_focusable() Trait** | ✅ Added to ListItemDisplay and DirStackItem |

## Previously Completed

| Feature | Status |
|---------|--------|
| Rich List UI | ✅ |
| Search Display Refactor | ✅ |
| Configurable Section Order | ✅ |
| TopResult Support | ✅ |
| Autocomplete Suggestions | ✅ |
| Daemon Architecture | ✅ |

---

## Known Issues

| Issue | Priority | Notes |
|-------|----------|-------|
| High CPU idle | P1 | Needs profiling |
| Slow cold start | P2 | First search ~3s |

---

## Backlog (Prioritized)

> **Full UI/UX Spec:** [ui-ux-provised.md](ui-ux-provised.md) (contains detailed layouts and reasoning)  
> **Grid Design:** [grid-layout-design.md](grid-layout-design.md)  
> **Rich List ADR:** [ADR-rich-list-ui.md](ADR-rich-list-ui.md)

### P0 - Critical
| REQ | Task | Implementation |
|-----|------|----------------|
| R-QUEUE-1 | Queue Playing Highlight | Use `ListItemDisplay.is_playing()` → Bold + ▶ icon |

### P1 - High Priority
| REQ | Task | Implementation |
|-----|------|----------------|
| R-QUEUE-2 | Queue View Revamp | Apply **Rich List UI** (`ItemListWidget`) to QueuePane |
| R-QUEUE-3 | Queue Manipulation | Remove (d/x), reorder via keyboard |
| R-DETAIL-1 | Artist/Album Detail | **Rich List** for songs + **Grid** for albums (needs P3) |
| R-DETAIL-2 | Back Navigation | Backspace/Esc returns to previous view |
| - | High CPU Idle Fix | Profiling and optimization |

### P2 - Medium Priority
| REQ | Task | Implementation |
|-----|------|----------------|
| R-NOW-1 | Now Playing View | Large album art (existing `album_art.rs`) |
| R-NOW-2/3 | Playback Controls | Keyboard controls + progress bar |
| R-SEARCH-3 | Play vs Add | Enter=play, Shift+Enter=add to queue |
| - | Metadata Consistency | Fix case mismatch in Song.album() - see [backlog doc](backlog-metadata-consistency.md) |
| - | Prefetch | Buffer next tracks for gapless playback |

### P3 - Low Priority
| REQ | Task | Implementation |
|-----|------|----------------|
| - | Grid View | Implement `ListRenderMode::Grid` per [design doc](grid-layout-design.md) |
| - | API Filtering | Fetch only displayed sections |

### ✅ Completed (This Session)
| REQ | Task |
|-----|------|
| R-SEARCH-1 | Content type distinction (icons, colors) |
| R-SEARCH-2 | Preview panel with rich mode |
| - | Filter highlighting in rich mode |
| - | Header skip navigation (`is_focusable()`) |
| - | Metadata display for browsables (subtitle) |

### P4 - Future
| Task | Notes |
|------|-------|
| Unit Tests | Tests for `ListItemDisplay`, `ItemListWidget` |
| R-MODAL-1/2 | Modal system (add to playlist, confirm) |

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
