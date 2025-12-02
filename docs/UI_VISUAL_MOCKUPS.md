# UI/UX Visual Design: What Will It Actually Look Like?

## Understanding the Problem

The partial implementation (switching to Albums/Artist tabs) is **NOT** what you want because:
- ❌ Loses search context
- ❌ No back navigation
- ❌ Doesn't match YouTube Music UX
- ❌ Breaks the discovery workflow

## What YouTube Music Does

1. Search for "kim long"
2. Click on a result (e.g., playlist)
3. **Entire page changes** to show playlist details
4. Browser back button returns to search results
5. Can navigate from playlist → artist → album
6. URL shows current location

## TUI Equivalent: Two Approaches

---

## Approach 1: View Stack (Full Screen Navigation) 🎯

**This is what FEATURES.md describes!**

### Visual Flow

#### Screen 1: Search & Results
```
┌─────────────── Search ───────────────────────────────────────────┐
│ Search > Results                                                  │
├───────────────────────────────────────────────────────────────────┤
│ Search Fields          │  Results                                │
│ ───────────────────────│  ────────────────────────────────────── │
│ Any Tag    : kim long  │  --- Top Result ---                     │
│ Artist     : <None>    │  ▶ Kim Long (Artist)                    │
│ Album      : <None>    │                                          │
│                        │  --- Artists ---                         │
│ [Search] [Reset]       │    Lâm Kim Long                          │
│                        │                                          │
│                        │  --- Songs ---                           │
│                        │    KIMLONG - nói anh nghe               │
│                        │    KIMLONG - let me go                  │
│                        │                                          │
│                        │  --- Playlists ---                       │
│                        │    Như Quỳnh - Kim Long                 │
└────────────────────────────────────────────────────────────────────┘
[j/k:nav] [Enter:open] [Esc:back to search]
```

#### Screen 2: Playlist Detail (after Enter on playlist)
```
┌─────────────── Playlist: Như Quỳnh - Kim Long ──────────────────┐
│ Search > Playlists > Như Quỳnh - Kim Long                        │
├──────────────────────────────────────────────────────────────────┤
│  ╔═══════════╗    Như Quỳnh - Kim Long                          │
│  ║  COVER    ║    Various Artists • 2020                         │
│  ║  IMAGE    ║    156 songs • 8h 24min                           │
│  ╚═══════════╝                                                   │
│                 [P]lay All  [S]huffle  [A]dd to Library          │
│                                                                   │
│ ─── Tracks ──────────────────────────────────────────────────── │
│ ▶ 1. Như Quỳnh - Đêm Lạnh                             4:32      │
│   2. Như Quỳnh - Biển Tình                            5:12      │
│   3. Kim Long - Hương Xưa                             3:45      │
│   4. Như Quỳnh - Tình Xa                              4:20      │
│                                                                   │
│ ─── Featured Artists ─────────────────────────────────────────── │
│   [1] Như Quỳnh       [2] Kim Long       [3] Various            │
│                                                                   │
│ ─── Related Playlists ────────────────────────────────────────── │
│   [1] Bolero Classics    [2] Vietnamese Hits    [3] Nostalgia   │
└──────────────────────────────────────────────────────────────────┘
[j/k:nav] [Enter:select] [1-9:quick jump] [Esc:back] [v:visual]
```

#### Screen 3: Artist Detail (after pressing 2 on "Kim Long")
```
┌─────────────── Artist: Kim Long ─────────────────────────────────┐
│ Search > Playlists > Như Quỳnh - Kim Long > Kim Long            │
├──────────────────────────────────────────────────────────────────┤
│  ╔═══════════╗    Kim Long                                       │
│  ║  ARTIST   ║    450K subscribers                               │
│  ║  PHOTO    ║    Vietnamese singer                              │
│  ╚═══════════╝                                                   │
│                                                                   │
│ ─── Top Songs ────────────────────────────────────────────────── │
│ ▶ 1. Hương Xưa                              4:12                │
│   2. Đêm Thánh Vô Cùng                      3:45                │
│   3. Tình Ca                                5:01                │
│                                                                   │
│ ─── Albums & Singles ──────────────────────────────────────────── │
│   [1] Hương Xưa (2018)    [2] Best Hits    [3] Live Concert     │
│                                                                   │
│ ─── Related Artists ────────────────────────────────────────────── │
│   [1] Như Quỳnh    [2] Khánh Ly    [3] Giao Linh               │
└──────────────────────────────────────────────────────────────────┘
[j/k:nav] [Enter:open] [Esc:back] [q:back to search]
```

### Key Features of This Approach

1. **Full Screen Views**: Each detail view takes entire terminal
2. **Navigation Stack**: 
   - Enter pushes new view
   - Esc pops to previous view
   - q jumps back to search root
3. **Breadcrumb Trail**: Always shows navigation path
4. **State Preservation**: Going back restores previous view state
5. **Deep Navigation**: Can go playlist → artist → album → back → back

### Implementation Structure

```rust
struct SearchPane {
    // Navigation stack
    view_stack: Vec<SearchViewState>,
    
    // Current view determines what's rendered
    current_view: SearchView,
}

enum SearchView {
    SearchResults,
    PlaylistDetail(PlaylistDetails),
    AlbumDetail(AlbumDetails),
    ArtistDetail(ArtistDetails),
}

struct SearchViewState {
    view: SearchView,
    scroll_position: usize,
    selected_item: Option<usize>,
    // Preserve state for back navigation
}

impl SearchPane {
    fn push_view(&mut self, view: SearchView) {
        // Save current state
        self.view_stack.push(self.current_state());
        self.current_view = view;
    }
    
    fn pop_view(&mut self) -> bool {
        if let Some(previous) = self.view_stack.pop() {
            self.restore_state(previous);
            true
        } else {
            false  // Already at root
        }
    }
}
```

---

## Approach 2: Modal Overlay Pattern

**Alternative: Detail views as overlays**

### Visual Flow

#### Base: Search Results (always visible, dimmed when overlay active)
```
┌─────────────── Search ───────────────────────────────────────────┐
│ Search Fields          │  Results                                │
│ ───────────────────────│  ────────────────────────────────────── │
│ Any Tag    : kim long  │  --- Top Result ---                     │
│ Artist     : <None>    │  ▶ Kim Long (Artist)                    │
│ Album      : <None>    │  --- Artists ---                         │
│                        │    Lâm Kim Long                          │
│ [Search] [Reset]       │  --- Songs ---                           │
│                        │    KIMLONG - nói anh nghe               │
└────────────────────────────────────────────────────────────────────┘
```

#### Overlay: Playlist Detail (centered, bordered)
```
┌─────────────── Search ────────────────────────────────────────┐
│ 🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲 │
│ 🔲 ┌───── Playlist: Như Quỳnh - Kim Long ──────────────┐ 🔲 │
│ 🔲 │ ╔════╗  Như Quỳnh - Kim Long                      │ 🔲 │
│ 🔲 │ ║COVR║  156 songs • 8h 24min                      │ 🔲 │
│ 🔲 │ ╚════╝                                            │ 🔲 │
│ 🔲 │ ─── Tracks ─────────────────────────────────────  │ 🔲 │
│ 🔲 │ ▶ 1. Như Quỳnh - Đêm Lạnh               4:32     │ 🔲 │
│ 🔲 │   2. Như Quỳnh - Biển Tình              5:12     │ 🔲 │
│ 🔲 │   3. Kim Long - Hương Xưa               3:45     │ 🔲 │
│ 🔲 │                                                   │ 🔲 │
│ 🔲 │ [Enter:select] [Esc:close]                       │ 🔲 │
│ 🔲 └───────────────────────────────────────────────────┘ 🔲 │
│ 🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲🔲 │
└────────────────────────────────────────────────────────────────┘
         (dimmed background: search results still visible)
```

### Characteristics
- Search results stay visible (dimmed)
- Detail view is a centered bordered overlay
- Esc closes overlay
- Can't navigate from overlay to another overlay (would stack)
- More like current search suggestions pattern

---

## Comparison

| Feature | Approach 1: View Stack | Approach 2: Overlay |
|---------|----------------------|---------------------|
| Navigation depth | Unlimited (playlist→artist→album) | Single level only |
| Back navigation | Esc to previous view | Esc closes overlay |
| Breadcrumbs | Yes, full path | No |
| Context preservation | Full state saved | Search results visible |
| Matches YouTube Music UX | ✅ Yes | ❌ No |
| Implementation complexity | Medium | Low |
| Screen real estate | Full screen for content | Need margins for overlay |
| Matches FEATURES.md | ✅ Yes | ❌ No |

---

## Recommendation: Approach 1 (View Stack)

**Why:**
1. ✅ Matches your FEATURES.md wireframes exactly
2. ✅ Allows deep navigation (playlist → artist → album)
3. ✅ Breadcrumb trail shows navigation path
4. ✅ Matches YouTube Music web experience
5. ✅ Full screen for content (no wasted space)
6. ✅ Supports your vision of rich, explorable interface

**Implementation location:**
- **Within SearchPane** (not app-wide)
- Keeps navigation contained to search workflow
- Doesn't affect other tabs

---

## Revised Implementation Strategy

### Phase 1: Add View Stack to SearchPane

```rust
// In search/mod.rs
enum SearchView {
    Results {
        songs: Dir<Song, ListState>,
        showing_suggestions: bool,
    },
    PlaylistDetail {
        id: String,
        details: PlaylistDetails,
        selected_section: DetailSection,
        section_states: SectionStates,
    },
    AlbumDetail {
        id: String,
        details: AlbumDetails,
        selected_section: DetailSection,
        section_states: SectionStates,
    },
    ArtistDetail {
        id: String,
        details: ArtistDetails,
        selected_section: DetailSection,
        section_states: SectionStates,
    },
}

struct SearchPane {
    inputs: InputGroups,
    view_stack: Vec<SearchView>,  // Navigation history
    // current view is view_stack.last()
}
```

### Phase 2: Render Methods for Each View

```rust
impl SearchPane {
    fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) {
        // Render breadcrumb at top
        self.render_breadcrumb(frame, top_area, ctx);
        
        // Render current view
        match self.current_view() {
            SearchView::Results { .. } => self.render_search_results(...),
            SearchView::PlaylistDetail { details, .. } => self.render_playlist_detail(details, ...),
            SearchView::AlbumDetail { details, .. } => self.render_album_detail(details, ...),
            SearchView::ArtistDetail { details, .. } => self.render_artist_detail(details, ...),
        }
    }
    
    fn render_breadcrumb(&self, frame, area, ctx) {
        let path = self.breadcrumb_text();
        // "Search > Playlists > Như Quỳnh - Kim Long > Kim Long"
        frame.render_widget(Paragraph::new(path), area);
    }
}
```

### Phase 3: Navigation Logic

```rust
impl SearchPane {
    fn handle_action(&mut self, event: &mut KeyEvent, ctx: &mut Ctx) {
        match self.current_view() {
            SearchView::Results { .. } => {
                if Enter pressed on item {
                    // Determine item type, fetch details, push new view
                    self.open_detail_view(selected_item, ctx);
                }
            }
            SearchView::PlaylistDetail { .. } | 
            SearchView::AlbumDetail { .. } | 
            SearchView::ArtistDetail { .. } => {
                if Esc pressed {
                    self.pop_view();
                } else if Enter on featured artist {
                    self.open_artist_view(artist_id, ctx);
                }
            }
        }
    }
}
```

---

## Questions for Finalization

1. **Confirm Approach 1?** (View stack within SearchPane)
2. **Breadcrumb location?** Top of screen or in status bar?
3. **Quick navigation?** Should 'q' jump to search root or just Esc repeatedly?
4. **Visual selection in detail views?** Enable V mode for tracks in detail views?

Once confirmed, I'll update implementation_plan.md with this concrete approach.
