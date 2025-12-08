# Grid Layout Design (Backlog)

> **Status:** Backlog - P2 (after core search/filter fixes)  
> **Estimated Effort:** Medium-High

---

## Design Goal

Enable visual browsing of albums/artists/playlists with cover art prominence, matching Spotify/YouTube Music web experience while respecting TUI constraints.

## Grid Cell Anatomy

```
┌─────────────────┐
│   ┌─────────┐   │
│   │  COVER  │   │   Cell: 12 cols × 5 rows
│   │  8×4    │   │   Cover: 8×4 centered
│   └─────────┘   │
│   Album Title   │
│   2024          │
└─────────────────┘
```

| Property | Value | Reasoning |
|----------|-------|-----------|
| Cell width | 12-16 cols | Fits 2 cols on 80-col terminal |
| Cell height | 5-6 rows | Cover (4) + title (1) + subtitle (1) |
| Cover size | 8×4 | Larger than list mode for prominence |

---

## Critical Analysis

### Challenge 1: 2D Navigation

**Problem:** Grid requires 2D (h/j/k/l) vs TUI's 1D expectation (j/k)

**Solution: Linearized Navigation**
```
Grid:    [1] [2] [3]     j = next (1→2→3→4→5...)
         [4] [5] [6]     k = prev
         [7] [8] [9]     No h/l needed in grid
```

### Challenge 2: Responsive Columns

**Solution:**
```rust
fn calculate_grid_columns(width: u16, min_cell_width: u16) -> u16 {
    (width / min_cell_width).max(1).min(MAX_GRID_COLS)
}
```

| Terminal | Columns |
|----------|---------|
| 80 cols  | 2       |
| 120 cols | 4       |
| 200 cols | 6 (max) |

### Challenge 3: Image Performance

**Mitigations:**
1. Only fetch visible row images (virtualization)
2. Limit concurrent fetches (ImageCache already has this)
3. Placeholder boxes for instant layout

### Challenge 4: Mixed List+Grid in Same View

**Solution: SectionedView**
```rust
struct SectionedView<'a> {
    sections: Vec<Section<'a>>,
    focused_section: usize,
}
```

---

## Reusable Design

### Extend `ListRenderMode`

```rust
pub enum ListRenderMode {
    Compact,   // Single line, text only
    Rich,      // Two lines, thumbnail + metadata
    Grid,      // Grid layout, large covers (NEW)
}
```

Same `ListItemDisplay` trait - no new implementations needed.

### Config

```ron
theme: (
    list_display: (
        mode: "rich",
        grid_columns: 4,        // max columns
        grid_cell_width: 15,    // min cell width
    ),
)
```

---

## Implementation Phases

1. **Phase 1:** Add `ListRenderMode::Grid`, `render_grid()` in ItemListWidget
2. **Phase 2:** Integrate with album/artist/playlist browse views
3. **Phase 3:** `SectionedView` for mixed layouts (Artist detail)

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Linear j/k navigation | Simpler than 2D, matches TUI expectations |
| Same trait, new render mode | Reuse existing abstractions |
| Responsive columns | Support all terminal sizes |
| Defer to backlog | Core features first |
