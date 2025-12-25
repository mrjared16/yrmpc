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
│  │  │  └── DetailView                                                            │   │  │
│  │  │      ├── content: ContentDetails (from api::Discovery::details())          │   │  │
│  │  │      ├── flat_items: Vec<DetailItem>  (flattened sections)                 │   │  │
│  │  │      ├── view: InteractiveListView  ◄── REUSES same component!             │   │  │
│  │  │      └── load_state: LoadState                                             │   │  │
│  │  │                                                                            │   │  │
│  │  │  DetailItem enum:                                                          │   │  │
│  │  │  ├── Header { title } ← non-focusable section header                       │   │  │
│  │  │  ├── Song(Song) ← playable, impl ListItemDisplay                           │   │  │
│  │  │  └── Ref(ContentRef) ← navigable, impl ListItemDisplay + Navigable         │   │  │
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

## Implementation Plan

| Phase | Task | Files | Status |
|-------|------|-------|--------|
| **0** | Rename `BrowseStack` → `NavStack`, fix V2 filter | `nav_stack.rs`, `search_pane_v2.rs` | ✅ Done |
| **1** | Create `LoadState` enum | In `detail_stack.rs` | ✅ Done |
| **2** | Create `DetailItem` + `ListItemDisplay` impl | `domain/detail_item.rs` | ✅ Done |
| **3** | Create `Navigable` trait | Replaced with `is_navigable()` method | ✅ Done |
| **4** | Create `DetailView` struct | In `detail_stack.rs` | ✅ Done |
| **5** | Create `DetailStack` with push/pop/render | `ui/widgets/detail_stack.rs` | ✅ Done |
| **6** | Implement `flatten_content()` | In `detail_stack.rs` | ✅ Done |
| **7** | Add `UiAppEvent::NavigateTo` | `ui/mod.rs` | 🔄 Pending |
| **8** | Implement handler in `Ui::on_ui_app_event` | `ui/mod.rs` | 🔄 Pending |
| **9** | Integrate `DetailItem` into `SearchPaneV2` | `search_pane_v2.rs` | ✅ Done (via NavStack<DetailItem>) |
| **10** | Add breadcrumb to pane title | `search_pane_v2.rs` | ✅ Done (via NavStack.path()) |
| **11** | Integrate `DetailStack` into `QueuePane` | `queue.rs` | 🔄 Pending |
| **12** | Handle modal queue → main UI navigation | `ui/mod.rs` | 🔄 Pending |

**Progress: 8/12 phases complete**

### Architecture Notes

**Simplification from original plan:**
- Phases 2-6 were consolidated: `DetailItem` is in domain layer, `DetailStack` + `flatten_content` are in view layer
- `Navigable` trait replaced with `DetailItem::is_navigable()` method (simpler, YAGNI)
- SearchPaneV2 uses `NavStack<DetailItem>` directly instead of separate DetailStack embedding

---

## Future Extensibility (Backlog)

These features require NO breaking changes to the architecture above:

| Feature | How to Add | Priority |
|---------|------------|----------|
| **Presets** | Add `preset: Option<String>` to `DetailView`, change `flatten_content()` | Low |
| **Grid layout** | Add `layout: LayoutKind` to sections, branch in `render()` | Low |
| **Tab between sections** | Replace `flat_items` with `sections: Vec<SectionView>` | Low |
| **More backends** | Implement `api::*` traits for Spotify/SoundCloud | Medium |

---

## Legacy Reference

### Thread Model
See `core/client.rs` for the client thread system (idle/request pattern).

### Authentication
Cookie-based via `cookies.txt` and `BrowserToken`. No OAuth.

### Backend Abstraction
`MusicBackend` trait is deprecated. Use `api::*` traits via `BackendDispatcher`.
