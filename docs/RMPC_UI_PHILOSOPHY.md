# rmpc's Original UI/UX Philosophy

## Core Inspiration

**rmpc is heavily inspired by:**
1. **ncmpcpp** - Terminal MPD client
2. **ranger / lf** - File managers with three-column browser

## Key Design Principles

From README and code analysis:

### 1. **Ranger/LF-like Three-Column Browser** 🎯

The defining characteristic of rmpc's UI is the **three-column browser pattern** used in:
- **DirectoriesPane** - Browse file system
- **AlbumsPane** - Browse albums
- **ArtistPane** - Browse artists  
- **PlaylistPane** - Browse playlists

**Visual Pattern:**
```
┌─────────────────────────────────────────────────────────┐
│  Parent Dir  │  Current Dir   │  Preview/Details        │
│  ────────────┼────────────────┼────────────────────────│
│  Music/      │ Folk/          │ [Preview of Folk/       │
│  Videos/     │▶Rock/          │  contents or song       │
│  Photos/     │ Jazz/          │  details]               │
│              │ Blues/         │                         │
└─────────────────────────────────────────────────────────┘
```

**How it works:**
- **Left column**: Parent directory/level
- **Middle column**: Current selection
- **Right column**: Preview of selected item's contents

### 2. **DirStack Navigation Pattern**

rmpc uses `DirStack` for hierarchical navigation:

```rust
pub struct DirStack<T, S> {
    stack: Vec<Dir<T, S>>,  // Navigation history
    // Going "right" (Enter) pushes to stack
    // Going "left" (h/Esc) pops from stack
}
```

**Navigation:**
- `l` or `→` or `Enter` - Go deeper (push to stack)
- `h` or `←` or `Esc` - Go up (pop from stack)
- State (selection, scroll) is preserved for each level

### 3. **Tab-Based Organization**

Panes are organized in tabs:
```rust
enum Panes {
    Queue,
    Directories,  // File browser
    Artists,      // Artist browser
    Albums,       // Album browser
    Playlists,    // Playlist browser
    Search,       // Search interface
    // ... others
}
```

**User switches between tabs**, not between "views within a tab"

### 4. **BrowserPane Trait**

Common navigation pattern for browser-like panes:

```rust
trait BrowserPane<T> {
    fn stack(&self) -> &DirStack<T, ListState>;
    fn fetch_data(&self, selected: &T, ctx: &Ctx) -> Result<()>;
    fn list_songs_in_item(&self, item: T) -> /* closure */;
    fn enqueue(&self, items: ...) -> ...;
}
```

Panes that browse hierarchical data implement this trait.

### 5. **Optimistic UI Updates**

From project_overview memory:
- **Zero latency UI** - Immediate visual feedback
- **Floating modals** - Avoid context switches
- **Invisible backend** - Complexity hidden from user

---

## What This Means for Detail Views

### ❌ What DOESN'T Fit rmpc's Philosophy

1. **Full-screen view stack within SearchPane**
   - Breaks tab-based organization
   - Doesn't use three-column browser pattern
   - Creates "app within an app"

2. **Modal overlays for details**
   - Not the ranger/lf way
   - Wastes screen space

### ✅ What FITS rmpc's Philosophy

**Option: Enhance Search to use DirStack + Three-Column Browser**

Transform SearchPane to work like DirectoriesPane:

```
┌────────── Search ──────────────────────────────────────┐
│ Search     │  Results       │  Detail Preview          │
│ ────────── ┼────────────────┼──────────────────────── │
│ Query:     │ --- Artists ---│ [ARTIST PHOTO]           │
│   kim long │ ▶Kim Long     │ Kim Long                 │
│            │                │ 450K subscribers         │
│ [Search]   │ --- Songs ---  │                          │
│            │  nói anh nghe  │ Top Songs:               │
│            │  let me go     │  1. Hương Xưa      4:12 │
│            │                │  2. Đêm Thánh Vô...3:45 │
│            │ --- Playlists  │  3. Tình Ca        5:01 │
│            │  Như Quỳnh...  │                          │
└────────────────────────────────────────────────────────┘
```

**How it works:**
1. Left column: Search inputs (stays fixed)
2. Middle column: Search results
3. Right column: **Preview/details of selected item**

**Key insight**: The right column shows detail preview, NOT a separate fullscreen view!

---

## Revised Approach: Three-Column Search Browser

### Implementation Strategy

```rust
struct SearchPane {
    inputs: InputGroups,
    results_stack: DirStack<SearchResult, ListState>,  // Use DirStack!
    browser: Browser<SearchResult>,  // Three-column browser widget
}

enum SearchResult {
    Song(Song),
    Artist { id: String, name: String, preview: Option<ArtistDetails> },
    Album { id: String, name: String, preview: Option<AlbumDetails> },
    Playlist { id: String, name: String, preview: Option<PlaylistDetails> },
}
```

### Navigation Flow

1. **User searches** "kim long"
2. **Middle column** shows results (artists, songs, playlists)
3. **Right column** shows **preview** of selected item:
   - If artist selected → Show top 3 songs, subscriber count
   - If album →Show top 5 tracks, year, artist
   - If playlist → Show first 5 tracks, track count
4. **Press Enter/l** on artist in middle → **Navigate INTO artist**:
   - Left column: Previous results (dimmed/summarized)
   - Middle column: Artist's albums/singles
   - Right column: Album preview
5. **Press h/Esc** → Go back to search results

### Benefits

✅ Follows rmpc's three-column pattern  
✅ Uses existing DirStack navigation  
✅ Uses existing Browser widget  
✅ Feels consistent with DirectoriesPane  
✅ No new navigation paradigm  
✅ Preview on right = quick info without navigation

### Comparison with YouTube Music

**YouTube Music**: Full-screen navigation  
**rmpc philosophy**: Three-column browser with previews

**Adaptation**: Instead of full-screen detail pages, we show detailed **previews in the third column**.

---

## Modified FEATURES.md Mockup

Instead of full-screen views, use three columns:

```
┌───────────────────────────────────────────────────────────────────────┐
│ Search > Playlist: Như Quỳnh - Kim Long                               │
├────────────┬───────────────────────┬──────────────────────────────────┤
│ [Back]     │ Playlist Tracks       │  Album Preview                   │
│            │ ────────────────────  │  ──────────────────────────────  │
│ Search     │ ▶1. Đêm Lạnh         │  [ALBUM COVER]                   │
│ Results    │  2. Biển Tình        │  Best of Như Quỳnh               │
│            │  3. Hương Xưa        │  24 tracks • 1998                │
│ Artists    │  4. Tình Xa          │                                  │
│  Kim Long  │  5. Đêm Buồn         │  Top 3 tracks:                   │
│            │  6. Người Tình       │   1. Đêm Lạnh         4:32      │
│ Songs      │  7. Mưa Rơi          │   2. Tình Xa          4:20      │
│  nói anh.. │  8. Giấc Mơ          │   3. Đêm Buồn         3:45      │
│            │                       │                                  │
│ Playlists  │ [Feature Artists]     │  [Enter to open album]           │
│ ▶Như Quỳnh.│  [1] Như Quỳnh       │                                  │
└────────────┴───────────────────────┴──────────────────────────────────┘
[h/←:back] [l/→:open] [j/k:nav] [Tab:switch column] [v:visual]
```

### Column Roles

**Left**: Navigation breadcrumb + quick jump to previous levels  
**Middle**: Current focus (playlist tracks, artist albums, etc.)  
**Right**: Preview of selected middle item

---

## Actionable Decision

**I recommend: Three-Column Browser Pattern**

### Why?
1. ✅ **Consistent with rmpc's design language**
2. ✅ **Reuses existing infrastructure** (DirStack, Browser widget)
3. ✅ **Familiar to rmpc users** (same as Directories/Albums/Artists panes)
4. ✅ **Shows preview without context switch**
5. ✅ **Keyboard-accessible** (same h/l/j/k navigation)

### Trade-offs vs Full-Screen Views

**Lose**: Full screen for metadata  
**Gain**: Consistency, context preservation, faster navigation

### User's Call

Does this align with your vision? Or do you prefer full-screen detail views even if it breaks rmpc's three-column convention?

The three-column approach is more "rmpc native" but less like YouTube Music web.
