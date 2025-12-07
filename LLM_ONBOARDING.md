# LLM Onboarding - yrmpc

**Status**: ✅ Core Complete  
**Updated**: 2025-12-08

---

## CRITICAL INSIGHTS (Preserve This Research)

### 1. Thumbnail + 2-Line Layout IS FEASIBLE
**Proven by:** `album_art.rs` lines 62-68 already renders YouTube thumbnails:
```rust
if let Some(url) = song.metadata.get("thumbnail").and_then(|v| v.first()) {
    frame.render_widget(AsyncImage::new(&ctx.image_cache, Some(url.clone())), rect);
}
```

### 2. DON'T Use Table Widget for Images
- `Table` → `Row` → `Cell` → **only Text**
- Images need direct `Rect` rendering
- **Solution:** Custom row layout with `Layout::horizontal`

> **Deep Dive:** See [docs/ui-ux-analysis.md](docs/ui-ux-analysis.md) for full TUI constraints, implementation patterns, and design decisions.

### 3. Thumbnail URLs Already Exist
YouTube backend stores them in `song.metadata.get("thumbnail")`.

### 4. Config System Is Powerful
- `SongFormat`, `SongProperty`, `SymbolsConfig` all configurable
- Column widths, formats, styles via theme config
- **Use it** - don't hardcode

---

## Rich List Implementation Pattern

```rust
// For each visible item in list:
let row_rect = Rect { x, y: base_y + (idx * 2), width, height: 2 };

let [thumb_rect, text_rect] = Layout::horizontal([
    Constraint::Length(4), Constraint::Min(0)
]).areas(row_rect);

// Thumbnail
frame.render_widget(AsyncImage::new(&ctx.image_cache, Some(url)), thumb_rect);

// 2-line text  
frame.render_widget(Text::from(vec![
    Line::from(title),
    Line::styled(format!("{} · {}", artist, duration), dim_style),
]), text_rect);
```

---

## Proposed Config for Rich UI

```toml
[theme.rich_list]
enabled = false  # Original UI default - backward compatible
thumbnail_width = 4
row_height = 2
```

---

## Key Files

| Purpose | File |
|---------|------|
| Thumbnail proof | `ui/panes/album_art.rs:62-68` |
| AsyncImage widget | `ui/widgets/async_image.rs` |
| List rendering | `ui/dirstack/mod.rs` → `to_list_item()` |
| Search pane | `ui/panes/search/mod.rs` |
| SearchItem types | `domain/search/` |
| Config theme | `config/theme/mod.rs` |
| YouTube metadata | `player/youtube_backend.rs` |

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
