# UI/UX Analysis: YouTube Music TUI Adaptation

## Overview

This document analyzes what can be adapted from YouTube Music web to a TUI (Terminal User Interface), what must change due to TUI constraints, and the design decisions made.

---

## Part 1: YouTube Music Web Analysis

### Visual Hierarchy (What Users See)

| Element | Web Implementation | Recognition Speed |
|---------|-------------------|-------------------|
| Cover Art | 40x40px thumbnails inline | ~13ms (image recognition) |
| Type Icons | Implicit in cover shape (round=artist, square=album) | ~50ms |
| Typography | Bold title, gray metadata | ~200ms (text reading) |
| Layout | 2-line per item (title + metadata) | Scannable in clusters |

### Search Results Structure
```
[Top Result]        ← Large card with cover, title, type badge
├── [Artists]       ← Section header
│   ├── 🎤 Artist Name (subscribers)
├── [Songs]
│   ├── 🎵 Song Title
│   │   └── Artist · Album · 3:45
├── [Albums]
│   ├── 💿 Album Title
│   │   └── Artist · Year
└── [Playlists]
```

### Queue/Now Playing
- Large album art (dominant visual)
- Song list with small thumbnails per row
- Currently playing highlighted
- Duration right-aligned

---

## Part 2: TUI Constraints

### What TUI CAN Do
| Capability | Implementation |
|------------|----------------|
| Unicode icons | 🎵 🎤 💿 📁 🎬 |
| Colors per type | ANSI 256 or true color |
| Multi-line list items | ratatui `Text` with multiple `Line`s |
| Images (terminal-dependent) | kitty, sixel, iTerm2, ueberzug protocols |
| Configurable layouts | Via TOML/RON config |

### What TUI CANNOT Do
| Limitation | Reason | Workaround |
|------------|--------|------------|
| Inline images in text flow | Terminal protocols render to fixed rects | Separate column for image |
| Hover effects | No mouse-hover feedback | Selection highlight instead |
| Variable font sizes | Terminal = fixed cell grid | Bold/color for emphasis |
| Rounded corners | Character-based UI | Box-drawing characters |
| Animation | Expensive redraws | Subtle transitions only |

### Terminal Image Protocol Reality
```
❌ Cannot do:  [IMG] Song Title - Artist  (image inline with text)

✅ Can do:    [IMG] | Song Title           (image in fixed column)
              [   ] | Artist · Album
```

**Root cause:** Protocols (kitty, sixel) allocate rectangular cell regions, not inline character positions.

---

## Part 3: Adaptation Decisions

### Decision 1: Two UI Modes (Backward Compatible)

**Requirement:** Original single-line UI must remain available.

```toml
[theme.rich_list]
enabled = false  # Default: original UI
```

| Mode | Layout | Use Case |
|------|--------|----------|
| Classic | `S KIMLONG - ngày dài vắng em` | Minimal terminals, preference |
| Rich | `[Thumb] Title\n        Artist · 3:45` | Visual recognition |

### Decision 2: Thumbnail Column + 2-Line Text

**Reasoning:**
- User stated: "cover photo helps recognize instantly, don't remember song names"
- Web uses ~40px thumbnails; TUI equivalent ≈ 4x2 character cells
- 2-line layout matches web's title + metadata pattern

```
┌────────┬─────────────────────────────┐
│ [COVER]│ ngày dài vắng em           │  ← Line 1: Title
│ [4x2]  │ KIMLONG · bitter · 4:16    │  ← Line 2: Metadata
├────────┼─────────────────────────────┤
│ [COVER]│ nói anh nghe               │
│ [4x2]  │ KIMLONG · Panorama · 3:42  │
└────────┴─────────────────────────────┘
```

### Decision 3: Type-Specific Visual Cues

| Content Type | Icon | Color | Reasoning |
|--------------|------|-------|-----------|
| Song | 🎵 | White (default) | Most common, shouldn't distract |
| Artist | 🎤 | Cyan | Distinct, human association |
| Album | 💿 | Yellow | Warm, collection feel |
| Playlist | 📁 | Magenta | Organization metaphor |
| Video | 🎬 | Red | YouTube brand color |

### Decision 4: Configurable Line Formats

**Requirement:** User requested config-driven, not hardcoded.

```toml
[theme.rich_list]
line1 = [{ property = "Title" }]
line2 = [
    { property = "Artist" },
    { text = " · " },
    { property = "Duration" }
]
```

**Benefits:**
- User can customize what metadata appears
- Different formats for different views (search vs queue)
- Consistent with existing `SongFormat` system

---

## Part 4: Implementation Pattern

### Proven by Existing Code

`album_art.rs:62-68` already renders YouTube thumbnails:
```rust
if let Some(url) = song.metadata.get("thumbnail").and_then(|v| v.first()) {
    frame.render_widget(AsyncImage::new(&ctx.image_cache, Some(url.clone())), rect);
}
```

### Rich List Item Rendering

```rust
for (idx, item) in visible_items.iter().enumerate() {
    let row_height = 2;
    let row_rect = Rect { x, y: base_y + (idx * row_height), width, height: row_height };
    
    // Split: [thumbnail] [text]
    let [thumb_rect, text_rect] = Layout::horizontal([
        Constraint::Length(4),
        Constraint::Min(0)
    ]).areas(row_rect);
    
    // Render thumbnail if enabled and available
    if config.rich_list.show_thumbnail {
        if let Some(url) = item.thumbnail() {
            frame.render_widget(AsyncImage::new(&ctx.image_cache, Some(url)), thumb_rect);
        }
    }
    
    // Render 2-line text
    let text = Text::from(vec![
        Line::from(format!("{} {}", item.icon(), item.title())),
        Line::styled(item.metadata_line(), dim_style),
    ]);
    frame.render_widget(text, text_rect);
}
```

### Why Not Table Widget

| Approach | Limitation |
|----------|------------|
| `Table` → `Row` → `Cell` | Cell only contains `Text`, not arbitrary widgets |
| Custom row layout | Full control, can mix `AsyncImage` + `Text` |

**Decision:** Custom row rendering, not ratatui `Table`.

---

## Part 5: View-Specific Adaptations

### Search View

**Web:** 3-column with left sidebar, main results, right preview
**TUI:** 3-column miller browser (existing rmpc pattern)

| Column | Purpose |
|--------|---------|
| Left | Category filter / previous level |
| Center | Search results (rich list) |
| Right | Preview panel with thumbnail |

**Preview Panel Enhancement:**
```
┌─────────────────────┐
│    [Thumbnail]      │  ← AsyncImage
│                     │
├─────────────────────┤
│ Title: Song Name    │
│ Artist: KIMLONG     │  ← Metadata
│ Album: bittersweet  │
│ Duration: 4:16      │
└─────────────────────┘
```

### Queue View

**Web:** Album art dominant, song list minimal
**TUI Adaptation:**

Option A (Current): Large album art pane + table
```
┌──────────┬─────────────────────────────────────┐
│          │ Artist    Title            Duration │
│ [Album]  │ KIMLONG   ngày dài vắng   4:16     │
│ [Art]    │ KIMLONG   nói anh nghe    3:42     │
└──────────┴─────────────────────────────────────┘
```

Option B (Rich): Small thumbnails per row
```
┌────────────────────────────────────────────────┐
│ [Th] ngày dài vắng em                     4:16 │
│      KIMLONG · bitter                          │
├────────────────────────────────────────────────┤
│ [Th] nói anh nghe                        3:42 │
│      KIMLONG · Panorama                        │
└────────────────────────────────────────────────┘
```

**Trade-off:** Option B shows more items; Option A has larger art for current song.

---

## Part 6: UX Best Practices Applied

### 1. Recognition Over Recall
- Thumbnails enable visual memory
- Icons reduce cognitive load
- Consistent type→color mapping

### 2. Progressive Disclosure
- Single-line mode for power users
- Rich mode for visual browsers
- Preview panel for details

### 3. Minimal Input Required
- Enter = play (most common action)
- j/k navigation (vim-style)
- / for search (universal)

### 4. Feedback
- Highlight current playing
- Loading indicator for thumbnails
- Status bar for errors

### 5. Configurable, Not Hardcoded
- All layouts via theme config
- Column widths adjustable
- Line formats customizable

---

## Part 7: Requirements Summary

| ID | Requirement | Status |
|----|-------------|--------|
| R1 | Original UI remains default | ✅ Designed |
| R2 | Thumbnail + 2-line layout opt-in | ✅ Designed |
| R3 | Type icons distinguish content | ✅ Designed |
| R4 | Config-driven, not hardcoded | ✅ Designed |
| R5 | Preview panel shows thumbnail | ✅ Designed |
| R6 | Backward compatible | ✅ Designed |

---

## Part 8: Open Questions

1. **Thumbnail size:** Is 4x2 cells enough for recognition?
2. **Scroll performance:** Many thumbnails per frame?
3. **Fallback:** What to show when no thumbnail URL?
4. **Grid view:** Separate mode for album browsing?
