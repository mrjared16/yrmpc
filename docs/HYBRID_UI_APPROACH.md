# Hybrid UI Approach: Best of Both Worlds 🎯

## The Synthesis

Combine rmpc's three-column browser with YouTube Music's rich detail views using **adaptive layout modes**.

---

## How It Works

### Two Layout Modes

```rust
enum LayoutMode {
    ThreeColumn,  // Default: browsing with preview
    FullDetail,   // Expanded: full metadata display
}
```

The same `DirStack` powers both modes - only the visual layout changes!

---

## Visual Flow

### Mode 1: Three-Column (Browsing)

**When**: At search results level, browsing

```
┌──────────── Search ─────────────────────────────────────────┐
│ Search Inputs  │  Results          │  Quick Preview         │
│ ──────────────┼───────────────────┼────────────────────────│
│ Query:         │ --- Artists ---   │ [PHOTO]                │
│  kim long      │ ▶Kim Long        │ Kim Long               │
│                │                   │ 450K subscribers       │
│ [Search]       │ --- Songs ---     │                        │
│ [Reset]        │  nói anh nghe    │ Top 3 Songs:           │
│                │  let me go       │  1. Hương Xưa   4:12  │
│                │                   │  2. Đêm Thánh   3:45  │
│                │ --- Playlists --- │  3. Tình Ca     5:01  │
│                │  Như Quỳnh...    │                        │
│                │                   │ [Enter: view all]      │
└────────────────────────────────────────────────────────────┘
[j/k:nav] [Enter:expand] [Tab:switch column] [i:search]
```

**Characteristics:**
- 25% search inputs (left)
- 35% results (middle)  
- 40% preview (right)
- Quick glance at top 3-5 items
- rmpc's familiar three-column layout

---

### Mode 2: Full Detail (Expanded)

**When**: After pressing Enter/l on a result

```
┌────────────────────────────────────────────────────────────┐
│ Search > Artist: Kim Long                       [h/Esc:back] │
├────────────────────────────────────────────────────────────┤
│  ╔═══════════╗    Kim Long                                 │
│  ║  ARTIST   ║    450K subscribers                         │
│  ║  PHOTO    ║    Vietnamese singer since 1985             │
│  ╚═══════════╝                                             │
│                                                             │
│ ─── Top Songs ───────────────────────────────────────────  │
│ ▶ 1. Hương Xưa                                    4:12    │
│   2. Đêm Thánh Vô Cùng                            3:45    │
│   3. Tình Ca                                      5:01    │
│   4. Giấc Mơ Trưa                                 4:23    │
│   5. Người Tình Mùa Đông                          3:58    │
│   6. Mưa Rơi Lặng Lẽ                              4:45    │
│   7. Tình Khúc Cho Em                             3:32    │
│   8. Đêm Nay Anh Cứ Đi Về                         4:11    │
│   9. Hoa Sữa Nhớ Mùa Thu                          3:40    │
│  10. Chiếc Khăn Piêu                              4:28    │
│                                                             │
│ ─── Albums & Singles (15) ────────────────────────────────  │
│   [1] Hương Xưa (2018)        [4] Live Concert (2015)      │
│   [2] Best Hits (2020)        [5] Tình Ca (2017)          │
│   [3] Golden Collection       [6] Nostalgia (2019)        │
│                                                             │
│ ─── Related Artists ────────────────────────────────────── │
│   [1] Như Quỳnh    [2] Khánh Ly    [3] Giao Linh         │
└────────────────────────────────────────────────────────────┘
[j/k:nav] [Enter:open] [1-9:quick jump] [h/Esc:back] [v:visual]
```

**Characteristics:**
- Full screen (100% width)
- All tracks displayed (10/10, not just 3)
- Full metadata (description, subscriber count)
- Featured/related sections fully visible
- Looks like my original full-screen mockup!

---

## The Magic: It's Still Three Columns!

**Conceptually**, full detail mode is just:
- Left column: Hidden/collapsed (0% width)
- Middle column: Hidden/collapsed (0% width)  
- Right column: Expanded (100% width)

The `Browser` widget and `DirStack` still work the same way - we just adjust column widths!

---

## Implementation Structure

### Core State

```rust
struct SearchPane {
    // Navigation (rmpc pattern)
    stack: DirStack<SearchLevel, ListState>,
    
    // Layout control
    layout_mode: LayoutMode,
    
    // Rendering (rmpc pattern)
    browser: Browser<SearchItem>,
    
    // Search state
    inputs: InputGroups,
}

enum SearchLevel {
    Results(Vec<SearchItem>),
    PlaylistDetail(PlaylistDetails),
    AlbumDetail(AlbumDetails),
    ArtistDetail(ArtistDetails),
}

enum LayoutMode {
    ThreeColumn,     // Browsing/preview
    FullDetail,      // Expanded detail view
}
```

### Navigation Logic

```rust
impl SearchPane {
    fn handle_action(&mut self, event: KeyEvent, ctx: &Ctx) {
        match (event, self.layout_mode) {
            // From three-column mode
            (KeyCode::Enter | KeyCode::Char('l'), LayoutMode::ThreeColumn) => {
                // Fetch details for selected item
                self.fetch_detail_for_selected(ctx);
                // Switch to full detail mode
                self.layout_mode = LayoutMode::FullDetail;
                // Browser will render right column at 100% width
            }
            
            // From full detail mode
            (KeyCode::Esc | KeyCode::Char('h'), LayoutMode::FullDetail) => {
                // Pop from stack
                self.stack.pop();
                // Back to three-column mode
                self.layout_mode = LayoutMode::ThreeColumn;
                // Browser renders three columns again
            }
            
            // Can navigate deeper from detail view
            (KeyCode::Enter, LayoutMode::FullDetail) => {
                // e.g., Enter on album in artist detail view
                self.fetch_detail_for_selected(ctx);
                // Stay in FullDetail mode, just push to stack
            }
        }
    }
}
```

### Rendering Logic

```rust
impl SearchPane {
    fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) {
        match self.layout_mode {
            LayoutMode::ThreeColumn => {
                // Split into three columns
                let columns = Layout::horizontal([
                    Constraint::Percentage(25),  // Search inputs
                    Constraint::Percentage(35),  // Results
                    Constraint::Percentage(40),  // Preview
                ]).split(area);
                
                self.render_search_inputs(frame, columns[0], ctx);
                self.render_results(frame, columns[1], ctx);
                self.render_preview(frame, columns[2], ctx);
            }
            
            LayoutMode::FullDetail => {
                // Use full area for detail view
                let top_bar = 1;  // For breadcrumb
                let chunks = Layout::vertical([
                    Constraint::Length(top_bar),
                    Constraint::Min(0),
                ]).split(area);
                
                self.render_breadcrumb(frame, chunks[0], ctx);
                self.render_full_detail(frame, chunks[1], ctx);
            }
        }
    }
}
```

---

## Benefits of Hybrid Approach

| Feature | Three-Column | Full Detail | Hybrid |
|---------|-------------|-------------|--------|
| rmpc consistency | ✅ | ❌ | ✅ |
| Quick preview | ✅ | ❌ | ✅ |
| Full metadata | ❌ | ✅ | ✅ |
| Screen real estate | Medium | Maximum | Both! |
| Context preservation | ✅ | ⚠️ (via breadcrumb) | ✅ |
| DirStack navigation | ✅ | ❌ (in my original plan) | ✅ |
| Browser widget reuse | ✅ | ❌ (in my original plan) | ✅ |
| Deep navigation | ✅ | ✅ | ✅ |

---

## User Workflow Examples

### Example 1: Quick Preview Workflow

1. Search "kim long"
2. Use `j/k` to browse results (three-column mode)
3. See preview in right column (top 3 songs)
4. Press `Space` or `Enter` to play without expanding
5. Continue browsing

**No mode switch needed for quick actions!**

### Example 2: Deep Exploration Workflow

1. Search "kim long"  
2. Navigate to artist (three-column mode shows preview)
3. Press `Enter` → **Expand to full detail mode**
4. Browse all 10 top songs, albums, related artists
5. Press `Enter` on an album → **Navigate deeper** (still full detail)
6. View all album tracks, artist info
7. Press `1` to quick-jump to featured artist → **Navigate again**
8. Press `h` or `Esc` → **Back to previous level** (full detail)
9. Press `h` again → **Back to artist** (full detail)
10. Press `h` again → **Back to search results** (three-column mode)

**Uses DirStack navigation throughout!**

### Example 3: Hybrid Workflow

1. Search results (three-column)
2. Preview artist (right column shows top 3)
3. Decide to explore → Enter (expand to full detail)
4. See all 10 songs, realize this is the right artist
5. Press `h` → Back to search (three-column)
6. Navigate to different result
7. Preview in right column
8. Not interested → Keep browsing (stay in three-column)

**Smooth transition between browse and detail modes!**

---

## Comparison to Original Approaches

### vs Pure Three-Column
**Added**: Can expand to full detail when needed  
**Kept**: Three-column layout for browsing, DirStack, Browser widget

### vs Pure Full-Screen
**Added**: Quick preview without navigation  
**Kept**: Full metadata display, rich detail views

### Hybrid = Evolution of Three-Column
The hybrid is actually just **enhanced three-column browser** with:
- Dynamic column widths
- Context-aware layout mode
- Same navigation model

---

## Implementation Complexity

**Low!** Because we're reusing existing infrastructure:

1. ✅ DirStack - Already exists
2. ✅ Browser widget - Already exists  
3. ✅ Three-column rendering - Already implemented in other panes
4. ⚠️ Layout mode switching - NEW but simple (just column width logic)
5. ⚠️ Full detail rendering - NEW but similar to FEATURES.md mockups

**Estimated effort**: 60% of pure full-screen approach, 120% of pure three-column.

---

## Alignment with rmpc Philosophy

✅ **Uses ranger/lf pattern** - Three columns + expandable detail (ranger does this!)  
✅ **DirStack navigation** - Core rmpc pattern  
✅ **Browser widget** - Reuses existing widget  
✅ **Keyboard-first** - No mouse dependency  
✅ **Context preservation** - Can see navigation history  
✅ **Optimistic UI** - Fast layout switching

**And adds**:
✅ **Rich metadata** - Like YouTube Music  
✅ **Flexible workflow** - Browse or dive deep

---

## Recommendation

**Implement the Hybrid Approach** because:

1. ✅ Best of both worlds (literally)
2. ✅ Low implementation cost (reuses infrastructure)
3. ✅ Familiar to rmpc users (three-column default)
4. ✅ Powerful for deep exploration (full detail mode)
5. ✅ Aligns with rmpc philosophy (ranger-inspired)
6. ✅ Matches your vision (full metadata display)

**This is the optimal synthesis!**
