# Architecture

## Repository Structure

### Parent: yrmpc
```
yrmpc/
├── rmpc/           # Git submodule → rmpc application
├── config/         # Configuration files
├── cookies.txt     # YouTube auth (gitignored)
└── docs/           # This documentation
```

### Submodule: rmpc
```
rmpc/
├── src/
│   ├── backends/                 # Backend API layer
│   │   ├── api/                  # Universal traits (Discovery, Queue, Playback, Volume)
│   │   ├── mpd/                  # MPD implementation
│   │   ├── youtube/              # YouTube implementation (daemon + client)
│   │   ├── client.rs             # BackendDispatcher
│   │   └── traits.rs             # Legacy MusicBackend (deprecated)
│   ├── domain/
│   │   ├── content.rs            # ContentDetails (Album, Artist, Playlist)
│   │   ├── display.rs            # ListItemDisplay trait
│   │   └── song.rs               # Universal Song type
│   ├── ui/
│   │   ├── panes/
│   │   │   ├── search/           # SearchPaneV1 (legacy)
│   │   │   ├── search_pane_v2.rs # SearchPaneV2 (new architecture)
│   │   │   ├── queue.rs          # QueuePane
│   │   │   └── mod.rs            # Pane container
│   │   ├── widgets/
│   │   │   ├── interactive_list_view.rs  # Vim-style list controls
│   │   │   ├── list_view_state.rs        # Selection, marks, scroll
│   │   │   ├── filter_state.rs           # Text filtering
│   │   │   └── nav_stack.rs              # Navigation stack (was browse_stack)
│   │   ├── dirstack/             # Legacy DirStack (MPD file navigation)
│   │   └── mod.rs                # Ui struct, UiAppEvent handling
│   └── main.rs
└── tests/
```

---

## Universal Streaming Architecture

> **Status**: In Development
> **Goal**: Unified navigation across any streaming source (YouTube, Spotify, etc.)

### Complete Component Connection Map

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    BACKEND LAYER                                        │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                          api::* Traits (NEW)                                    │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │    │
│  │  │ api::Playback │  │ api::Queue   │  │api::Discovery│  │ api::Volume  │         │    │
│  │  │ play()       │  │ add()        │  │ search()     │  │ set_volume() │         │    │
│  │  │ pause()      │  │ remove()     │  │ browse()     │  └──────────────┘         │    │
│  │  │ next()       │  │ list()       │  │ details() ◄──── Returns ContentDetails   │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                           │    │
│  └────────────────────────────────────────────┬────────────────────────────────────┘    │
│                                               │                                         │
│  ┌────────────────────────────────────────────▼────────────────────────────────────┐    │
│  │                         BackendDispatcher (client.rs)                           │    │
│  │  ┌──────────────────────┐              ┌──────────────────────┐                 │    │
│  │  │    YouTubeProxy      │              │     MpdBackend       │                 │    │
│  │  │ impl api::Discovery  │              │ impl api::Discovery  │                 │    │
│  │  │ impl api::Queue      │              │ impl api::Queue      │                 │    │
│  │  │ impl api::Playback   │              │ impl api::Playback   │                 │    │
│  │  └──────────────────────┘              └──────────────────────┘                 │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                    MusicBackend / QueueOperations (DEPRECATED)                  │    │
│  │                    Legacy traits - being replaced by api::* traits              │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
└───────────────────────────────────────────────┬─────────────────────────────────────────┘
                                                │
                                                │ Returns domain types
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    DOMAIN LAYER                                         │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              Core Types                                           │  │
│  │                                                                                   │  │
│  │  ┌──────────────┐    ┌──────────────────────────────────────────────────────┐     │  │
│  │  │    Song      │    │              ContentDetails                          │     │  │
│  │  │ • id         │    │  ┌──────────────┬──────────────┬──────────────────┐  │     │  │
│  │  │ • title      │    │  │AlbumContent  │ArtistContent │ PlaylistContent  │  │     │  │
│  │  │ • artist     │    │  │ • tracks     │ • top_songs  │ • tracks         │  │     │  │
│  │  │ • album      │    │  │ • artist     │ • albums     │ • author         │  │     │  │
│  │  │ • uri        │    │  │ • year       │ • singles    │ • related        │  │     │  │
│  │  │ • duration   │    │  │ • extensions │ • extensions │ • extensions     │  │     │  │
│  │  └──────────────┘    │  └──────────────┴──────────────┴──────────────────┘  │     │  │
│  │         │            └──────────────────────────────────────────────────────┘     │  │
│  │         │                                    │                                    │  │
│  │         └────────────────┬───────────────────┘                                    │  │
│  │                          │                                                        │  │
│  │                          ▼                                                        │  │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐    │  │
│  │  │                       ListItemDisplay Trait                               │    │  │
│  │  │  Unified rendering interface - anything can be displayed in a list       │    │  │
│  │  │  • primary_text() -> Cow<str>                                             │    │  │
│  │  │  • secondary_text() -> Option<Cow<str>>                                   │    │  │
│  │  │  • type_icon() -> &str                                                    │    │  │
│  │  │  • is_focusable() -> bool                                                 │    │  │
│  │  │  • is_playing() -> bool                                                   │    │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘    │  │
│  │                          ▲                                                        │  │
│  │                          │ impl                                                   │  │
│  │  ┌───────────────────────┴───────────────────────────────────────────────────┐    │  │
│  │  │  Song    ContentRef    DirOrSong    SearchResult    (future: DetailItem) │    │  │
│  │  └───────────────────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
└───────────────────────────────────────────────┬─────────────────────────────────────────┘
                                                │
                                                │ Used by
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  VIEW STATE LAYER                                       │
│                                                                                         │
│   LEGACY (DirStack family)              NEW (NavStack family)                           │
│   For MPD file browser                  For streaming navigation                        │
│                                                                                         │
│   ┌───────────────────────────────┐     ┌───────────────────────────────────┐           │
│   │ DirStack<T, S>                │     │ NavStack<T> (was BrowseStack)     │           │
│   │ • HashMap<Path, Dir>          │     │ • Vec<NavLevel<T>>                │           │
│   │ • path-based lookup           │     │ • stack-based push/pop            │           │
│   └───────────────┬───────────────┘     └───────────────┬───────────────────┘           │
│                   │                                     │                               │
│                   ▼                                     ▼                               │
│   ┌───────────────────────────────┐     ┌───────────────────────────────────┐           │
│   │ Dir<T, S>                     │     │ NavLevel<T> (was BrowseLevel)     │           │
│   │ • items: Vec<T>               │     │ • items: Vec<T>                   │           │
│   │ • state: DirState             │     │ • view: InteractiveListView ◄──┐  │           │
│   │ • filter (EMBEDDED)           │     │ • path_segment: String        │  │           │
│   └───────────────┬───────────────┘     └────────────────────────────────│──┘           │
│                   │                                                      │              │
│                   ▼                                    ┌─────────────────┘              │
│   ┌───────────────────────────────┐                    │                                │
│   │ DirState<S>                   │                    ▼                                │
│   │ • selected: Option<usize>     │     ┌───────────────────────────────────┐           │
│   │ • marked: BTreeSet<usize>     │     │ InteractiveListView (SHARED)      │           │
│   │ • scrollbar                   │     │                                   │           │
│   │ • filter (here too)           │     │ Vim-style controls for ANY list:  │           │
│   └───────────────────────────────┘     │ • j/k navigation                  │           │
│                                         │ • G/gg first/last                 │           │
│   Used by:                              │ • Space mark                      │           │
│   • LibraryPane                         │ • / filter                        │           │
│   • ArtistPane (legacy MPD)             │ • n/N next/prev match             │           │
│   • AlbumsPane (legacy MPD)             │                                   │           │
│   • DirectoriesPane                     │  ┌─────────────────────────────┐  │           │
│                                         │  │ ListViewState               │  │           │
│                                         │  │ • selected                  │  │           │
│                                         │  │ • marked: BTreeSet          │  │           │
│                                         │  │ • scrollbar                 │  │           │
│                                         │  └─────────────────────────────┘  │           │
│                                         │  ┌─────────────────────────────┐  │           │
│                                         │  │ FilterState (COMPOSABLE)    │  │           │
│                                         │  │ • filter_text               │  │           │
│                                         │  │ • matched_indices           │  │           │
│                                         │  │ • current_match             │  │           │
│                                         │  └─────────────────────────────┘  │           │
│                                         └───────────────────────────────────┘           │
│                                                                                         │
│                                         Used by:                                        │
│                                         • SearchPaneV2                                  │
│                                         • QueuePane                                     │
│                                         • FUTURE: DetailStack                           │
│                                                                                         │
└───────────────────────────────────────────────┬─────────────────────────────────────────┘
                                                │
                                                │ Used by
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    UI PANE LAYER                                        │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              Existing Panes                                       │  │
│  │                                                                                   │  │
│  │  ┌────────────────────┐   ┌────────────────────┐   ┌────────────────────────────┐ │  │
│  │  │ SearchPaneV1       │   │ SearchPaneV2       │   │ QueuePane                  │ │  │
│  │  │ (Legacy)           │   │ (New)              │   │                            │ │  │
│  │  │                    │   │                    │   │                            │ │  │
│  │  │ Uses:              │   │ Uses:              │   │ Uses:                      │ │  │
│  │  │ • Dir<Song>        │   │ • NavStack<Song>   │   │ • InteractiveListView      │ │  │
│  │  │ • DirState         │   │ • InteractiveList  │   │ • ListViewState            │ │  │
│  │  │ • Manual filter    │   │   View             │   │                            │ │  │
│  │  │                    │   │ • FilterState      │   │ Can navigate to:           │ │  │
│  │  │ ~2000 lines        │   │   (NOT WIRED!)     │   │ • Artist (via UiAppEvent)  │ │  │
│  │  │                    │   │                    │   │ • Album (via UiAppEvent)   │ │  │
│  │  │                    │   │ ~500 lines         │   │                            │ │  │
│  │  └────────────────────┘   └────────────────────┘   └────────────────────────────┘ │  │
│  │                                                                                   │  │
│  │  ┌────────────────────┐   ┌────────────────────┐   ┌────────────────────────────┐ │  │
│  │  │ LibraryPane        │   │ ArtistPane (MPD)   │   │ AlbumsPane (MPD)           │ │  │
│  │  │ (Legacy)           │   │ (Legacy)           │   │ (Legacy)                   │ │  │
│  │  │                    │   │                    │   │                            │ │  │
│  │  │ Uses:              │   │ Uses:              │   │ Uses:                      │ │  │
│  │  │ • DirStack         │   │ • DirStack         │   │ • DirStack                 │ │  │
│  │  │ • BrowserPane trait│   │ • BrowserPane      │   │ • BrowserPane              │ │  │
│  │  └────────────────────┘   └────────────────────┘   └────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           FUTURE: Detail Views                                    │  │
│  │                                                                                   │  │
│  │  ┌────────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │                           DetailStack (NEW)                                │   │  │
│  │  │  Composable component - embeds into ANY pane                               │   │  │
│  │  │                                                                            │   │  │
│  │  │  SearchPaneV2 + DetailStack:                                               │   │  │
│  │  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │  │
│  │  │  │ if detail_stack.is_active():                                         │  │   │  │
│  │  │  │   render DetailView (artist/album/playlist)                          │  │   │  │
│  │  │  │ else:                                                                │  │   │  │
│  │  │  │   render normal search results                                       │  │   │  │
│  │  │  └──────────────────────────────────────────────────────────────────────┘  │   │  │
│  │  │                                                                            │   │  │
│  │  │  DetailStack internals:                                                    │   │  │
│  │  │  ├── views: Vec<DetailView>                                                │   │  │
│  │  │  ├── breadcrumb: Vec<String>   # ["Search", "KIMLONG", "bittersweet"]      │   │  │
│  │  │  │                                                                         │   │  │
│  │  │  └── DetailView (SECTIONED DESIGN - see below)                             │   │  │
│  │  │      ├── content: ContentDetails (preserved for actions/refresh)          │   │  │
│  │  │      ├── sections: Vec<SectionView>  ← STRUCTURE PRESERVED                 │   │  │
│  │  │      ├── view: InteractiveListView   ← ONE view, flat navigation           │   │  │
│  │  │      └── load_state: LoadState                                             │   │  │
│  │  │                                                                            │   │  │
│  │  │  SectionView (enables flexible layout):                                    │   │  │
│  │  │  ├── key: SectionKey              ← for preset config lookup               │   │  │
│  │  │  ├── title: String                ← section header text                    │   │  │
│  │  │  ├── layout: LayoutKind           ← List | Grid { columns }                │   │  │
│  │  │  └── items: Vec<DetailItem>       ← items in this section                  │   │  │
│  │  │                                                                            │   │  │
│  │  │  DetailItem enum:                                                          │   │  │
│  │  │  ├── Song(Song) ← playable, impl ListItemDisplay                           │   │  │
│  │  │  └── Ref(ContentRef) ← navigable, impl ListItemDisplay                     │   │  │
│  │  │                                                                            │   │  │
│  │  └────────────────────────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
└───────────────────────────────────────────────┬─────────────────────────────────────────┘
                                                │
                                                │ Communicates via
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  EVENT LAYER                                            │
│                                                                                         │
│  ┌───────────────────────────────────────────────────────────────────────────────────┐  │
│  │                              UiAppEvent                                           │  │
│  │                                                                                   │  │
│  │  enum UiAppEvent {                                                                │  │
│  │      // Existing                                                                  │  │
│  │      Modal(Box<dyn Modal>),                                                       │  │
│  │      PopModal(Id),                                                                │  │
│  │      ChangeTab(String),                                                           │  │
│  │      Redraw,                                                                      │  │
│  │                                                                                   │  │
│  │      // Legacy (keep for compatibility)                                           │  │
│  │      OpenAlbum(String),   ← Current: hacks into AlbumsPane                        │  │
│  │      OpenArtist(String),  ← Current: hacks into ArtistsPane                       │  │
│  │      OpenPlaylist(String),← Current: hacks into PlaylistsPane                     │  │
│  │                                                                                   │  │
│  │      // NEW (proposed)                                                            │  │
│  │      NavigateTo { id: String, kind: ContentKind },                                │  │
│  │          │                                                                        │  │
│  │          └──► Handler:                                                            │  │
│  │              1. Close modal if active                                             │  │
│  │              2. Find pane that can show content                                   │  │
│  │              3. Call api::Discovery::details(id, kind)                            │  │
│  │              4. Push to pane's DetailStack                                        │  │
│  │  }                                                                                │  │
│  │                                                                                   │  │
│  │  Emitted by:                                                                      │  │
│  │  • Any pane via ctx.app_event_sender.send(AppEvent::UiEvent(...))                 │  │
│  │  • Modal queue when navigating to artist                                          │  │
│  │                                                                                   │  │
│  │  Handled by:                                                                      │  │
│  │  • Ui::on_ui_app_event() in ui/mod.rs                                             │  │
│  └───────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Reuse Matrix

| Component | SearchV1 | SearchV2 | QueuePane | Legacy MPD | Future Detail |
|-----------|----------|----------|-----------|------------|---------------|
| `DirStack` | ❌ | ❌ | ❌ | ✅ | ❌ |
| `Dir` | ✅ partial | ❌ | ❌ | ✅ | ❌ |
| `DirState` | ✅ partial | ❌ | ❌ | ✅ | ❌ |
| `NavStack` | ❌ | ✅ | ❌ | ❌ | ✅ **via NavStack<DetailItem>** |
| `NavLevel` | ❌ | ✅ | ❌ | ❌ | ✅ |
| `InteractiveListView` | ❌ | ✅ | ✅ | ❌ | ✅ **REUSE** |
| `ListViewState` | ❌ | ✅ | ✅ | ❌ | ✅ **REUSE** |
| `FilterState` | embedded | ✅ (not wired) | ❌ | ❌ | ✅ **REUSE** |
| `ListItemDisplay` | ❌ | ✅ | ✅ | ❌ | ✅ **REUSE** |
| `DetailItem` | ❌ | ✅ **NEW** | ❌ | ❌ | ✅ **NEW** |
| `ContentDetails` | ❌ | ✅ **via flatten** | ❌ | ❌ | ✅ |
| `DetailStack` | ❌ | ❌ | ❌ | ❌ | ✅ **READY** |

---

## Data Flow Example: Search → Artist → Album

```
User types "KIMLONG" in SearchPaneV2
                │
                ▼
ctx.query() → api::Discovery::search("KIMLONG")
Returns: Vec<Song> (mixed: songs, albums, artists with uri like "artist:...")
                │
                ▼
NavStack Level 0: Search Results
┌────────────────────────────────────────────────────────────────────────┐
│ [🎵] ngày dài vắng em (Song)                                           │
│ [🎤] KIMLONG (Artist) ◄─── User presses Enter                          │
│ [💿] bittersweet (Album)                                               │
└────────────────────────────────────────────────────────────────────────┘
                │
                ▼
api::Discovery::details(Item::Artist("UC..."))
Returns: ContentDetails::Artist(ArtistContent {
    id: "UC...",
    name: "KIMLONG",
    top_songs: Vec<Song>,
    extensions: { Albums: [...], Singles: [...], Related: [...] }
})
                │
                ▼
DetailStack.push(ArtistContent)
  1. Flatten content into DetailItem list:
     ┌─────────────────────────────────────────────────────────────────────┐
     │ Header("Top Songs")           ← non-focusable                       │
     │ Song(ngày dài vắng em)        ← focusable, playable                 │
     │ Song(bitter)                  ← focusable, playable                 │
     │ Header("Albums")              ← non-focusable                       │
     │ Ref(bittersweet, Album)       ← focusable, navigable ◄── Enter      │
     │ Ref(Panorama, Album)          ← focusable, navigable                │
     │ Header("Fans also like")      ← non-focusable                       │
     │ Ref(Obito, Artist)            ← focusable, navigable                │
     └─────────────────────────────────────────────────────────────────────┘
  
  2. Create InteractiveListView for this DetailView
     - All vim controls work (j/k, G/gg, Space, /)
     - j/k skips headers automatically (is_focusable() = false)
  
  3. Add breadcrumb: ["KIMLONG"]
                │
                │ User presses Enter on "bittersweet" album
                ▼
api::Discovery::details(Item::Album("MPR..."))
Returns: ContentDetails::Album(AlbumContent { ... })
                │
                ▼
DetailStack.push(AlbumContent)
  Breadcrumb: ["KIMLONG", "bittersweet"]
  Flat items: [Header("Tracks"), Song(1), Song(2), ..., Header("More by KIMLONG"), ...]
```

---

## Sectioned DetailView Design

> **Key Decision**: Preserve structure for future flexibility (grid layout, presets, collapsible sections)

### Why Sectioned Instead of Flat?

| Approach | Pros | Cons |
|----------|------|------|
| **Flat** (`Vec<DetailItem>`) | Simple | Loses structure, can't do grid per section |
| **Sectioned** (`Vec<SectionView>`) | Enables presets, grid, collapse | Slightly more complex |

**Decision**: Use sectioned design. Navigation stays flat (one `InteractiveListView`), but rendering can vary per section.

### Data Flow

```
ContentDetails ──► build_sections() ──► Vec<SectionView> ──► DetailView
                   (preserves structure)                      │
                                                              ├─► items() iterator for navigation
                                                              └─► sections for rendering
```

### Types

```rust
pub enum LayoutKind {
    List,                    // Default: vertical list
    Grid { columns: u8 },    // Future: grid with N columns
}

pub struct SectionView {
    pub key: SectionKey,     // For preset config lookup
    pub title: String,       // Header text
    pub layout: LayoutKind,  // Rendering hint
    pub items: Vec<DetailItem>,
}

pub struct DetailView {
    pub content: ContentDetails,    // Preserved for actions/refresh
    pub sections: Vec<SectionView>, // Structured for flexible rendering
    pub view: InteractiveListView,  // ONE view, flat navigation
    pub load_state: LoadState,
    pub title: String,
}
```

### Navigation vs Rendering

- **Navigation**: Flat. `j/k` moves through all items across all sections.
- **Rendering**: Sectioned. Each section rendered with its own layout.

```rust
impl DetailView {
    /// Flat iteration for navigation
    pub fn items(&self) -> impl Iterator<Item = &DetailItem> {
        self.sections.iter().flat_map(|s| s.items.iter())
    }
}
```

### Current vs Future Rendering

```
NOW (List only):                    FUTURE (Mixed layouts):
┌────────────────────────┐          ┌────────────────────────┐
│ ── Top Songs ────────  │          │ ▼ Top Songs            │
│   🎵 Song 1            │          │   🎵 Song 1            │
│   🎵 Song 2            │          │   🎵 Song 2            │
│ ── Albums ───────────  │          ├────────────────────────┤
│   💿 Album 1           │          │ ▼ Albums (Grid 3x)     │
│   💿 Album 2           │          │ ┌──────┬──────┬──────┐ │
│   💿 Album 3           │          │ │ A1   │ A2   │ A3   │ │
│ ── Related ──────────  │          │ └──────┴──────┴──────┘ │
│   🎤 Artist 1          │          ├────────────────────────┤
└────────────────────────┘          │ ▶ Related (collapsed)  │
                                    └────────────────────────┘
```

---

## Implementation Plan

| Phase | Task | Files | Status |
|-------|------|-------|--------|
| **0** | Rename `BrowseStack` → `NavStack`, fix V2 filter | `nav_stack.rs`, `search_pane_v2.rs` | ✅ Done |
| **1** | Create `LoadState` enum | In `detail_stack.rs` | ✅ Done |
| **2** | Create `DetailItem` + `ListItemDisplay` impl | `domain/detail_item.rs` | ✅ Done |
| **3** | Create `Navigable` trait | Replaced with `is_navigable()` method | ✅ Done |
| **4** | Create `SectionView` + `LayoutKind` | In `detail_stack.rs` | 🔄 In Progress |
| **5** | Create `build_sections()` replacing `flatten_content()` | In `detail_stack.rs` | 🔄 In Progress |
| **6** | Update `DetailView` to use `Vec<SectionView>` | In `detail_stack.rs` | 🔄 In Progress |
| **7** | Add `UiAppEvent::NavigateTo` | `ui/mod.rs` | 🔄 Pending |
| **8** | Implement handler in `Ui::on_ui_app_event` | `ui/mod.rs` | 🔄 Pending |
| **9** | Integrate sectioned `DetailView` into `SearchPaneV2` | `search_pane_v2.rs` | 🔄 Pending |
| **10** | Add breadcrumb to pane title | `search_pane_v2.rs` | ✅ Done (via NavStack.path()) |
| **11** | Integrate `DetailStack` into `QueuePane` | `queue.rs` | 🔄 Pending |
| **12** | Handle modal queue → main UI navigation | `ui/mod.rs` | 🔄 Pending |

**Progress: 4/12 phases complete, 3 in progress**

### Architecture Notes

**Sectioned Design Decision (2025-12-25):**

The original plan used `flatten_content()` to convert `ContentDetails` → `Vec<DetailItem>`.
This was changed to `build_sections()` → `Vec<SectionView>` for these reasons:

1. **Preserves structure**: Sections remain distinct, enabling per-section layout
2. **Future-proof**: Grid layout, presets, collapse can be added without redesign
3. **No data loss**: Original `ContentDetails` kept for actions/refresh
4. **Same navigation**: Still uses one `InteractiveListView` with flat item iteration

**Key insight**: Navigation is flat (j/k through all items), rendering is sectioned (each section can have different layout).

---

## Future Extensibility (Backlog)

These features require NO breaking changes to the sectioned architecture:

| Feature | How to Add | Priority |
|---------|------------|----------|
| **Presets** | `build_sections()` reads config, sets layout per section | Medium |
| **Grid layout** | Check `section.layout` in render loop, branch to grid renderer | Medium |
| **Collapse sections** | Add `collapsed: bool` to `SectionView`, skip rendering if true | Low |
| **Tab between sections** | Track `active_section`, Tab jumps to next section's first item | Low |
| **More backends** | Implement `api::*` traits for Spotify/SoundCloud | Medium |

---

## Legacy Reference

### Thread Model
See `core/client.rs` for the client thread system (idle/request pattern).

### Authentication
Cookie-based via `cookies.txt` and `BrowserToken`. No OAuth.

### Backend Abstraction
`MusicBackend` trait is deprecated. Use `api::*` traits via `BackendDispatcher`.
