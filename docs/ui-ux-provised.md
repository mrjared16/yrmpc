# UI/UX Provision: Music Streaming TUI

> **Purpose:** Complete UI/UX specification for YouTube Music TUI client.
> **Audience:** LLM agents (parseable structure) + Humans (readable reasoning).
> **Format:** [REQ] = Requirement, [DECISION] = Design choice with reasoning, [INSIGHT] = Research finding.

---

## 1. Design Philosophy

### Core Principles

| Principle | Meaning | Application |
|-----------|---------|-------------|
| **Terminal-Native** | Embrace TUI strengths, not imitate web | Keyboard-first, dense layouts, vim motions |
| **Recognition > Recall** | Users recognize, not remember | Thumbnails, icons, consistent colors |
| **Progressive Disclosure** | Simple defaults, power on demand | Single-line default, rich mode opt-in |
| **Configurable Everything** | Users have different needs | Theme config, not hardcoded |
| **Feedback Always** | Never leave user wondering | Loading states, errors, status bar |

### [INSIGHT] Visual Recognition Speed
```
Image recognition: ~13ms
Icon recognition:  ~50ms  
Text reading:      ~200ms
```
**Implication:** Thumbnails and icons enable faster scanning than text-only UI.

### [INSIGHT] User Quote
> "Cover photos help recognize instantly - I don't remember song names."

This drives the thumbnail-first design approach.

---

## 2. View-by-View UX

### 2.1 Search View

**Purpose:** Discover content across types (songs, albums, artists, playlists, videos).

#### Layout (Miller Columns)
```
┌─────────────┬──────────────────────┬─────────────────┐
│  Category   │   Search Results     │    Preview      │
│  Filters    │   (Rich List)        │   (Detail)      │
│             │                      │                 │
│  ▸ Songs    │ [🎵] ngày dài vắng  │ [Thumbnail]     │
│    Albums   │      KIMLONG · 4:16  │                 │
│    Artists  │ [🎵] nói anh nghe   │ Title: ...      │
│    Playlists│      KIMLONG · 3:42  │ Artist: ...     │
└─────────────┴──────────────────────┴─────────────────┘
```

**[DECISION] Miller Columns:** Matches existing rmpc pattern, provides context (left=filters, right=preview).

**[REQ] R-SEARCH-1:** Search results must distinguish content types visually.
**[REQ] R-SEARCH-2:** Preview panel must show thumbnail when available.
**[REQ] R-SEARCH-3:** Enter on item = play; Shift+Enter = add to queue.

---

### 2.2 Queue View

**Purpose:** Manage current play queue, see what's playing.

#### Layout Options

**Option A: Album Art Dominant**
```
┌────────────┬──────────────────────────────────────┐
│            │  Artist      Title          Duration │
│  [ALBUM]   │  KIMLONG     ngày dài vắng  4:16 ▶  │
│   [ART]    │  KIMLONG     nói anh nghe   3:42    │
│            │  KIMLONG     bitter         3:15    │
└────────────┴──────────────────────────────────────┘
```

**Option B: Per-Row Thumbnails (Rich Mode)**
```
┌────────────────────────────────────────────────────┐
│ [Th] ▶ ngày dài vắng em                      4:16 │
│        KIMLONG · bitter                           │
├────────────────────────────────────────────────────┤
│ [Th]   nói anh nghe                          3:42 │
│        KIMLONG · Panorama                         │
└────────────────────────────────────────────────────┘
```

**[DECISION] Support Both:** Option A = classic, Option B = rich mode. Configurable.

**[REQ] R-QUEUE-1:** Currently playing song must be visually distinct (highlight, ▶ icon).
**[REQ] R-QUEUE-2:** Queue manipulation (remove, reorder) via keyboard.
**[REQ] R-QUEUE-3:** Clear queue must stop playback (already fixed in code).

---

### 2.3 Now Playing View

**Purpose:** Focus on current song with large album art and controls.

#### Layout
```
┌────────────────────────────────────────┐
│                                        │
│           [LARGE ALBUM ART]            │
│               200x200                  │
│                                        │
├────────────────────────────────────────┤
│         ngày dài vắng em               │
│         KIMLONG · bittersweet          │
├────────────────────────────────────────┤
│  ◀◀    ▶/⏸    ▶▶    🔀    🔁          │
├────────────────────────────────────────┤
│  1:23 ━━━━━━━━━━●━━━━━━━━━━━━━━ 4:16   │
└────────────────────────────────────────┘
```

**[REQ] R-NOW-1:** Must show album art (existing album_art.rs pane).
**[REQ] R-NOW-2:** Playback controls accessible via keyboard.
**[REQ] R-NOW-3:** Progress bar with elapsed/total time.

---

### 2.4 Artist/Album/Playlist Detail Views

**Purpose:** Navigate into containers to see their contents.

#### Artist View
```
┌────────────────────────────────────────────────────┐
│ [Artist Photo]  KIMLONG                            │
│                 1.2M subscribers                   │
├────────────────────────────────────────────────────┤
│ Top Songs                                          │
│ [🎵] ngày dài vắng em · 4:16                       │
│ [🎵] nói anh nghe · 3:42                           │
├────────────────────────────────────────────────────┤
│ Albums                                             │
│ [💿] bittersweet · 2024                            │
│ [💿] Panorama · 2023                               │
└────────────────────────────────────────────────────┘
```

**[DECISION] Sectioned Layout:** Group by content type within artist.

**[REQ] R-DETAIL-1:** "Play All" action for albums/playlists.
**[REQ] R-DETAIL-2:** Navigation back to previous view (Backspace/Esc).

---

## 3. Interaction Patterns

### 3.1 Navigation

| Key | Action | Context |
|-----|--------|---------|
| `j/k` or `↓/↑` | Move selection | Lists |
| `h/l` or `←/→` | Navigate columns | Miller browser |
| `Enter` | Confirm/Play | Selected item |
| `Esc/Backspace` | Back/Cancel | Navigation |
| `/` | Search | Global |
| `g` | Go to... (modal) | Global |
| `q` | Queue view | Global |
| `1-9` | Tab switch | Panes |

**[DECISION] Vim-Compatible:** j/k/h/l for users familiar with vim. Arrow keys for everyone else.

### 3.2 Actions

| Key | Action | Context |
|-----|--------|---------|
| `Enter` | Play (replace queue) | Song |
| `a` | Add to queue | Song |
| `A` | Add all to queue | Album/Playlist |
| `d/x` | Remove from queue | Queue item |
| `Space` | Toggle play/pause | Global |
| `>/<` | Next/Previous track | Global |
| `m` | Mark/select multiple | Lists |
| `y` | Yank (copy to clipboard) | URL/info |

**[DECISION] Mnemonic Keys:** `a` for add, `d` for delete, `m` for mark.

### 3.3 Modals

For complex actions (add to playlist, confirm delete):

```
┌──────────────────────────────────────┐
│  Add to Playlist                     │
├──────────────────────────────────────┤
│  ▸ Favorites                         │
│    Workout Mix                       │
│    Chill Vibes                       │
├──────────────────────────────────────┤
│  [Enter] Select  [Esc] Cancel        │
└──────────────────────────────────────┘
```

**[REQ] R-MODAL-1:** Modals must be dismissable with Esc.
**[REQ] R-MODAL-2:** Show available actions in footer.

---

## 4. Visual System

### 4.1 Content Type Icons

| Type | Icon | Hex Color | Reasoning |
|------|------|-----------|-----------|
| Song | 🎵 | `#FFFFFF` (white) | Most common, neutral |
| Artist | 🎤 | `#00FFFF` (cyan) | Human/performer |
| Album | 💿 | `#FFD700` (gold) | Collection, warm |
| Playlist | 📁 | `#FF00FF` (magenta) | User-created |
| Video | 🎬 | `#FF0000` (red) | YouTube brand |
| Podcast | 🎙️ | `#00FF00` (green) | Voice/talk |

**[DECISION] Semantic Colors:** Colors have meaning, not just decoration.

### 4.2 State Styles

| State | Style | Example |
|-------|-------|---------|
| Normal | Default fg | `Song Title` |
| Selected | Inverse/Highlight | `▸ Song Title` |
| Playing | Bold + ▶ | `▶ Song Title` |
| Dimmed | Gray fg | `Artist · 3:42` |
| Error | Red fg | `Failed to load` |
| Loading | Animated | `Loading...` |

### 4.3 Layout Density

| Mode | Lines/Item | Use Case |
|------|------------|----------|
| Compact | 1 | Maximum items visible |
| Normal | 1 | Default |
| Rich | 2 | Thumbnail + metadata |
| Spacious | 3+ | Focus mode |

**[DECISION] Configurable Density:** Default = Normal, Rich = opt-in via `[theme.rich_list].enabled`.

---

## 5. Technical Constraints

### 5.1 Terminal Image Protocols

| Protocol | Terminals | Notes |
|----------|-----------|-------|
| Kitty Graphics | Kitty | Best quality, cell-aligned |
| Sixel | xterm, mlterm, foot | Wide support |
| iTerm2 | iTerm2 | macOS only |
| Ueberzug | X11 terminals | External process |
| Block | Any | ASCII art fallback |

**[INSIGHT] Critical Limitation:**
```
❌ Cannot: [IMG] Song Title (inline)
✅ Can:    [IMG] | Song Title (fixed column)
```

Protocols render to fixed rectangular regions, NOT inline with text.

### 5.2 Existing Infrastructure

| Component | Location | Capability |
|-----------|----------|------------|
| `AsyncImage` | `ui/widgets/async_image.rs` | Async download + render |
| Image cache | `ctx.image_cache` | Prevents re-download |
| Thumbnail URLs | `song.metadata.get("thumbnail")` | Already stored |

**[INSIGHT] Proven Pattern:** `album_art.rs:62-68` already renders YouTube thumbnails successfully.

### 5.3 Performance Considerations

| Concern | Mitigation |
|---------|------------|
| Many thumbnails per frame | Virtualize: only render visible |
| Image loading latency | Async + placeholder |
| Re-renders on scroll | Cache rendered content |

---

## 6. Rich List Component (Core Feature)

> **Design Goal:** Enable instant visual recognition of content through album art and structured metadata, matching the scanning experience of Spotify/YouTube Music.

### 6.1 Anatomy of a Rich List Item

```
┌─────────────────────────────────────────────────────────────────┐
│ ┌─────────┐                                                     │
│ │         │  🎵 Song Title That Might Be Long...          4:16  │ ← Row height: 2 lines
│ │  COVER  │     Artist Name · Album Name · 2024                 │
│ │  4×2    │                                                     │
│ └─────────┘                                                     │
├─────────────────────────────────────────────────────────────────┤
│ ┌─────────┐                                                     │
│ │         │  💿 Album Title                              12 tracks │
│ │  COVER  │     Artist Name · 2024                              │
│ └─────────┘                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Visual Hierarchy (Spotify Pattern)

| Layer | Element | Purpose | Style |
|-------|---------|---------|-------|
| **1** | Cover Art | Instant recognition | 4×2 cells, left-aligned |
| **2** | Type Icon | Content type at a glance | Unicode emoji, colored |
| **3** | Primary Text | Main identifier | Bold/bright, truncate with "..." |
| **4** | Secondary Text | Supporting context | Dimmed, separator "·" |
| **5** | Duration/Count | Utility info | Right-aligned, monospace |

### 6.3 Spacing & Rhythm

```
│ 4 cells │ 1 cell │        Variable        │ 6 cells │
│  Cover  │  Gap   │       Text Area        │ Duration│
├─────────┼────────┼────────────────────────┼─────────┤
│ [IMG]   │        │ 🎵 Primary Title...    │   4:16  │
│ [4×2]   │        │    Secondary · Info    │         │
```

**[DECISION] Fixed Cover Width:** 4 cells = approximately 32-40px equivalent, sufficient for pattern recognition while maximizing text space.

### 6.4 States & Transitions

| State | Visual Treatment | Trigger |
|-------|------------------|---------|
| **Default** | Normal colors | - |
| **Hovered/Selected** | Inverse colors, cursor `▸` | j/k navigation |
| **Playing** | Bold + `▶` icon, accent color | Currently playing track |
| **Loading** | Placeholder box, pulsing | Image loading |
| **Error** | Type icon fallback | Image load failed |

### 6.5 Adaptive Behavior

| Terminal Width | Behavior |
|----------------|----------|
| < 60 cols | Hide cover, single-line mode |
| 60-80 cols | Small cover (3×2), truncate text |
| > 80 cols | Full rich mode (4×2 cover) |

**[REQ] R-RICH-1:** Rich mode must gracefully degrade on narrow terminals.

### 6.6 Cover Art Specifications

| Property | Value | Reasoning |
|----------|-------|-----------|
| **Dimensions** | 4 cols × 2 rows | Balance visibility vs density |
| **Aspect Ratio** | Square (cropped if needed) | Consistent visual rhythm |
| **Fallback** | Type icon in box | Never show broken image |
| **Loading** | Dim box with "..." | Indicate pending state |
| **Protocol** | kitty > sixel > disabled | Progressive enhancement |

### 6.7 Text Truncation Rules

| Field | Max Width | Truncation |
|-------|-----------|------------|
| Primary (Title) | Available - 8 | "Long Song Ti..." |
| Secondary (Artist) | Available - 8 | Truncate last segment first |
| Duration | 6 fixed | Never truncate |

**[DECISION] Truncation Priority:** Title > Album > Artist. Most users search by title.

---

## 7. Implementation Reference

### 7.1 Rich List Pattern

```rust
for (idx, item) in visible_items.iter().enumerate() {
    let row_rect = Rect { y: base_y + (idx * 2), height: 2, .. };
    
    let [thumb_rect, text_rect] = Layout::horizontal([
        Constraint::Length(4), Constraint::Min(0)
    ]).areas(row_rect);
    
    // Thumbnail
    if let Some(url) = item.thumbnail() {
        frame.render_widget(AsyncImage::new(&ctx.image_cache, url), thumb_rect);
    }
    
    // 2-line text
    frame.render_widget(Text::from(vec![
        Line::from(format!("{} {}", item.icon(), item.title())),
        Line::styled(item.metadata_line(), dim_style),
    ]), text_rect);
}
```

### 7.2 Why NOT Table Widget

`Table` → `Row` → `Cell` → **only Text**. Cannot embed `AsyncImage` in cells.
**Solution:** Custom row rendering with `Layout::horizontal`.

### 7.3 Configuration Schema

```toml
[theme.rich_list]
enabled = false          # Default: classic single-line
thumbnail_width = 4      # Character cells
row_height = 2           # Lines per item
show_icons = true

[theme.symbols]
song = "🎵"
artist = "🎤"
album = "💿"
playlist = "📁"
video = "🎬"
```

---

## 8. Requirements Checklist

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| R-SEARCH-1 | Visual type distinction in search | P0 | Designed |
| R-SEARCH-2 | Preview panel thumbnail | P1 | Designed |
| R-QUEUE-1 | Highlight currently playing | P0 | Existing |
| R-QUEUE-2 | Keyboard queue manipulation | P1 | Existing |
| R-NOW-1 | Album art in now playing | P0 | Existing |
| R-DETAIL-1 | Play All for containers | P1 | Designed |
| R-COMPAT-1 | Original UI as default | P0 | Designed |
| R-COMPAT-2 | Rich mode opt-in | P0 | Designed |
| R-CONFIG-1 | Theme-based configuration | P0 | Designed |

---

## 9. Open Questions

1. **Thumbnail size:** Is 4x2 cells enough for recognition?
2. **Scroll virtualization:** Needed for performance?
3. **Fallback display:** Icon when no thumbnail?
4. **Grid view:** Album grid for browsing?
5. **Shuffle/Repeat indicators:** Where to show state?
