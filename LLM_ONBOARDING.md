# LLM Onboarding - yrmpc

**Status**: ✅ Core Complete + Rich List UI  
**Updated**: 2025-12-08

---

## ⚠️ Rich List UI Is IMPLEMENTED (But UI Revamp Continues)

Rich List UI component is done. However, **full UI revamp** for all views is ongoing:

| View | Status | Requirement |
|------|--------|-------------|
| Search Results | ✅ Rich List | R-SEARCH-1 |
| Search Preview | ❌ Needs thumbnail | R-SEARCH-2 |
| Queue View | ❌ Needs revamp | R-QUEUE-1/2/3 |
| Artist View | ❌ Not started | R-DETAIL-1/2 |
| Album/Playlist Detail | ❌ Not started | R-DETAIL-1/2 |
| Now Playing | ⚠️ Partial | R-NOW-1/2/3 |

**Full spec:** [docs/ui-ux-provised.md](docs/ui-ux-provised.md)

---

## Complete Backlog

### P0 - Critical
- **Queue Playing Highlight**: Bold + ▶ icon for current track (R-QUEUE-1)

### P1 - High Priority
- **Thumbnail Rendering Fix**: Displays corner only, needs proper scaling
- **Queue View Revamp**: Rich mode thumbnail per-row, reorder, remove
- **Search Preview Thumbnail**: Show cover in preview column
- **Artist View**: Sectioned layout with top songs, albums
- **Playlist/Album Detail**: Play All, navigation back
- **High CPU Idle**: Profiling needed

### P2 - Medium Priority
- **Prefetch**: Buffer next tracks for gapless playback
- **Now Playing View**: Large album art, progress bar, controls
- **Repeat/Shuffle**: Queue playback modes
- **Play Next/Last**: Queue position control

### P3 - Low Priority
- **API Filtering**: Fetch only needed sections
- **Grid View**: Album grid for browsing

### P4 - Future
- **Unit Tests: Rich List**: Tests for `ListItemDisplay`, `ItemListWidget`

---

## Key Implementation Files

| Purpose | File |
|---------|------|
| **Rich List Widget** | `ui/widgets/item_list.rs` |
| **ListItemDisplay trait** | `domain/display.rs` |
| **Element tree** | `ui/widgets/element.rs` |
| AsyncImage widget | `ui/widgets/async_image.rs` |
| Search pane | `ui/panes/search/mod.rs` |
| Queue pane | `ui/panes/queue.rs` |
| Config theme | `config/theme/mod.rs` |

---

## CRITICAL INSIGHTS (Research - Still Valid)

### 1. Thumbnail Rendering Works
**Proven by:** `album_art.rs` lines 62-68:
```rust
if let Some(url) = song.metadata.get("thumbnail").and_then(|v| v.first()) {
    frame.render_widget(AsyncImage::new(&ctx.image_cache, Some(url.clone())), rect);
}
```

### 2. DON'T Use Table Widget for Images
- `Table` → `Row` → `Cell` → **only Text**
- Images need direct `Rect` rendering
- **Solution:** `ItemListWidget` with Element tree (IMPLEMENTED)

### 3. Use Existing Rich List Component
For new views (Queue, Artist, Playlist), reuse:
```rust
use crate::ui::widgets::item_list::{ItemListWidget, ItemListConfig, ListRenderMode};

// Enable rich mode
let config = ItemListConfig {
    mode: ListRenderMode::Rich,
    thumbnail_width: 4,
    row_height: 2,
};
```

### 4. Config System Is Powerful
- Enable rich mode: `list_display: (rich_mode: true)`
- **Backward compatible**: `rich_mode: false` is default

---

## ytmapi-rs Local Patch

The `youtui/ytmapi-rs` directory contains local patches for:
- TopResult parsing (Playlist, Video, Station types)
- browse_id and video_id extraction

To receive upstream changes:
```bash
cd youtui && git pull origin main
```

Then manually reapply patches if needed.
