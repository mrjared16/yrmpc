# Architecture

## Design Principles

1. **TabPane + DetailPane** - Two types of panes with clear purposes
2. **Three-level navigation** - Mode → Stage/Stack → Pane
3. **Content stacking** - Each pane maintains its own content stack via `ContentView<C>`
4. **Find, not Filter** - Highlight matches, don't hide non-matches
5. **Vim-style modes** - Normal, Edit, Find modes
6. **Single path** - One unified component hierarchy, no parallel implementations

---

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Navigator | ✅ Integrated | Lives in `ui/mod.rs`, handles pane routing |
| ContentView | ✅ Used | All V2 panes use ContentView for stacking |
| InputContentView | ✅ Used | SearchPane composes InputGroups + ContentView |
| Legacy Flag | ✅ Removed | V2 panes are now the only implementation |

---

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COMPONENT HIERARCHY                                  │
│                         ═══════════════════                                  │
│                                                                             │
│                           ┌─────────────┐                                   │
│                           │     Ui      │                                   │
│                           │             │                                   │
│                           │ Modal stack │                                   │
│                           │ Event route │                                   │
│                           └──────┬──────┘                                   │
│                                  │                                          │
│                                  ▼                                          │
│                           ┌─────────────┐                                   │
│                           │  Navigator  │                                   │
│                           │             │                                   │
│                           │ Pane history│                                   │
│                           │ Tab hotkeys │                                   │
│                           │ Action exec │                                   │
│                           └──────┬──────┘                                   │
│                                  │                                          │
│              ┌───────────────────┼───────────────────┐                      │
│              │                   │                   │                      │
│              ▼                   ▼                   ▼                      │
│       ┌───────────┐       ┌───────────┐       ┌───────────┐                │
│       │  TabPane  │       │  TabPane  │       │DetailPane │                │
│       │  Search   │       │Queue/Lib  │       │Artist/etc │                │
│       │           │       │           │       │           │                │
│       │ stages    │       │ no stages │       │ stacking  │                │
│       └─────┬─────┘       └─────┬─────┘       └─────┬─────┘                │
│             │                   │                   │                      │
│             └───────────────────┴───────────────────┘                      │
│                                 │                                          │
│                                 ▼                                          │
│                          ╔═════════════╗                                   │
│                          ║ContentView<C>║  ◄── UNIFIED COMPONENT            │
│                          ║             ║                                   │
│                          ║ Stack<Level>║                                   │
│                          ║ handle_key()║                                   │
│                          ╚══════╤══════╝                                   │
│                                 │                                          │
│                                 ▼                                          │
│                          ┌─────────────┐                                   │
│                          │ SectionList │                                   │
│                          │             │                                   │
│                          │handle_key() │                                   │
│                          │Tab nav      │                                   │
│                          └──────┬──────┘                                   │
│                                 │                                          │
│                                 ▼                                          │
│                          ┌─────────────┐                                   │
│                          │Interactive- │                                   │
│                          │ ListView    │                                   │
│                          │             │                                   │
│                          │Mode/Find/Nav│                                   │
│                          └─────────────┘                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Pane Types

### TabPane (Always Available)

Has dedicated tab in navigation bar, accessible via hotkey.

| Pane | Hotkey | Purpose |
|------|--------|---------|
| Search | 1 | Search YouTube, browse results |
| Queue | 2 | Current playback queue |
| Library | 3 | User's synced playlists (2-way sync) |

**Note:** SearchPane uses `InputContentView` which composes `InputGroups` (for search input) + `ContentView` (for results).

### DetailPane (Shown When Populated)

No tab, only accessible via navigation. Each has a content stack.

| Pane | Content Stack | Purpose |
|------|---------------|---------|
| Artist | `ContentView<ArtistContent>` | Artist details, discography |
| Album | `ContentView<AlbumContent>` | Album tracks, metadata |
| Playlist | `ContentView<PlaylistContent>` | External/community playlists |

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI Layout                                   │
├─────────────────────────────────────────────────────────────────────────┤
│ [1:Search] [2:Queue] [3:Library]          ← Only TabPanes               │
├─────────────────────────────────────────────────────────────────────────┤
│ ← Artist: KIMLONG (2/3)                   ← DetailPane header           │
│           ▲                                 (shows stack position)      │
│           └─ Back arrow when in DetailPane                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  [FIND]: query_                           ← Find mode indicator         │
│                                                                         │
│  ─── Top Songs ──────────────────────────────────────────────────────  │
│  🎵 ngày dài vắng em                                         [3:45]   │
│  🎵 bitter                                                   [4:12]   │
│                                                                         │
│  ─── Albums ─────────────────────────────────────────────────────────  │
│  💿 First Album                                                        │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│ Esc:Back │ Backspace:Pop │ /:Find │ Tab:NextSection │ Enter:Open       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Three-Level Navigation

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  LEVEL 1: MODE (innermost)                                              │
│  ─────────────────────────                                              │
│                                                                         │
│  ┌─────────┐     Esc      ┌─────────┐      /       ┌─────────┐          │
│  │  Edit   │ ───────────► │ Normal  │ ◄──────────► │  Find   │          │
│  │         │              │         │              │         │          │
│  │ (search │   Esc clears │         │   Esc clears │ (typing │          │
│  │  input) │   find first │         │   find query │  query) │          │
│  └─────────┘              └─────────┘              └─────────┘          │
│                                                                         │
│  Edit: Typing in search input (SearchPane only)                         │
│  Find: Typing find query (any pane with list)                           │
│  Normal: Navigation mode                                                │
│                                                                         │
│  Key handling in each mode:                                             │
│  ┌──────────┬──────────────────┬──────────────────┬───────────────────┐ │
│  │ Key      │ Edit Mode        │ Find Mode        │ Normal Mode       │ │
│  ├──────────┼──────────────────┼──────────────────┼───────────────────┤ │
│  │ chars    │ Insert to input  │ Add to query     │ (action keys)     │ │
│  │ Backspace│ Delete char      │ Delete char      │ Pop stack/stage   │ │
│  │ Enter    │ Submit search    │ Confirm, keep HL │ Activate item     │ │
│  │ Esc      │ Exit to Normal   │ Clear & exit     │ Clear HL or Back  │ │
│  │ Tab      │ -                │ -                │ Next section      │ │
│  └──────────┴──────────────────┴──────────────────┴───────────────────┘ │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  LEVEL 2: INTRA-PANE (Backspace in Normal mode)                         │
│  ──────────────────────────────────────────────                         │
│                                                                         │
│  DetailPane: Pop content stack (ContentView.pop())                      │
│    ArtistPane.stack: [A, B, C] → Backspace → [A, B]                     │
│    At single item: Backspace does nothing                               │
│                                                                         │
│  TabPane: Back to previous stage                                        │
│    SearchPane: Results → Input                                          │
│    Queue/Library: single stage, Backspace does nothing                  │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  LEVEL 3: PANE HISTORY (Esc in Normal mode, no active find)             │
│  ──────────────────────────────────────────────────────────             │
│                                                                         │
│  history: [Search, Artist, Album, Artist]                               │
│  Esc pops history, switches to previous pane                            │
│  Empty DetailPanes are skipped                                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ContentView<C> - The Unified Component

ContentView is the single component used by ALL panes that display content.
It replaces the previous NavStack and manual stack implementations.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          ContentView<C>                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Generic over C: ContentViewable trait (defined in domain/content.rs)  │
│                                                                         │
│  struct ContentView<C: ContentViewable> {                               │
│      stack: Vec<ContentLevel<C>>,                                       │
│  }                                                                      │
│                                                                         │
│  struct ContentLevel<C> {                                               │
│      content: C,                                                        │
│      section_list: SectionList,                                         │
│  }                                                                      │
│                                                                         │
│  trait ContentViewable: Clone + Debug + Send + 'static {                │
│      fn title(&self) -> &str;                                           │
│      fn content_id(&self) -> &str;                                      │
│      fn to_content_details(&self) -> ContentDetails;                    │
│  }                                                                      │
│                                                                         │
│  Methods:                                                               │
│  ────────                                                               │
│  push(content: C)           Push new content onto stack                 │
│  pop() -> bool              Pop stack, returns false if at bottom       │
│  clear()                    Clear all content                           │
│  has_content() -> bool      Check if stack is non-empty                 │
│  stack_depth() -> usize     Get stack size                              │
│                                                                         │
│  handle_key(key, ctx) -> ContentAction                                  │
│    Delegates to SectionList, translates SectionAction to ContentAction  │
│                                                                         │
│  render(frame, area, ctx)                                               │
│    Renders current level's SectionList                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

ContentViewable Implementations (in domain/content.rs):
────────────────────────────────────────────────────────

impl ContentViewable for ArtistContent { ... }
impl ContentViewable for AlbumContent { ... }
impl ContentViewable for PlaylistContent { ... }
impl ContentViewable for SearchResultsContent { ... }
```

---

## SectionList - The Facade

SectionList provides a single handle_key() entry point that encapsulates
all vim-style key handling logic.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SectionList                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  struct SectionList {                                                   │
│      sections: Vec<SectionView>,         // Preserved structure         │
│      flat_items: Vec<DetailItem>,        // Cached for navigation       │
│      list_view: InteractiveListView,     // State management            │
│      title: String,                                                     │
│  }                                                                      │
│                                                                         │
│  KEY METHOD:                                                            │
│  ───────────                                                            │
│                                                                         │
│  fn handle_key(&mut self, key: &mut KeyEvent, ctx: &Ctx) -> SectionAction│
│                                                                         │
│  This ONE method handles ALL key logic:                                 │
│  • Mode checking (Normal/Find/Edit)                                     │
│  • Navigation (j/k/G/gg/Ctrl-d/u)                                       │
│  • Find mode (/, n/N, Esc to clear)                                     │
│  • Section navigation (Tab/Shift-Tab)                                   │
│  • Selection (Enter -> Select(item))                                    │
│  • Marks (Space)                                                        │
│  • Esc/Backspace priority handling                                      │
│                                                                         │
│  Returns SectionAction (not PaneAction) for separation of concerns.    │
│                                                                         │
│  enum SectionAction {                                                   │
│      Handled,              // Key was handled                           │
│      Select(DetailItem),   // Enter pressed on item                     │
│      Mark(Vec<usize>),     // Items marked                              │
│      BackPane,             // Esc with nothing to clear                 │
│      BackInternal,         // Backspace with nothing to pop             │
│      Passthrough,          // Key not handled                           │
│  }                                                                      │
│                                                                         │
│  SECTION NAVIGATION:                                                    │
│  ───────────────────                                                    │
│                                                                         │
│  Tab        → Jump to first item of next section                        │
│  Shift-Tab  → Jump to first item of previous section                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Action Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ACTION FLOW                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Key Event                                                              │
│      │                                                                  │
│      ▼                                                                  │
│  Navigator                                                              │
│      │                                                                  │
│      ├── mode == Normal? Check 1/2/3 hotkeys                           │
│      │                                                                  │
│      ▼                                                                  │
│  Pane.handle_key()                                                      │
│      │                                                                  │
│      ▼                                                                  │
│  ContentView.handle_key()                                               │
│      │                                                                  │
│      ▼                                                                  │
│  SectionList.handle_key()                                               │
│      │                                                                  │
│      ▼                                                                  │
│  SectionAction                                                          │
│      │                                                                  │
│      │  ┌────────────────┬────────────────┬────────────────┐           │
│      │  │                │                │                │           │
│      ▼  ▼                ▼                ▼                ▼           │
│  Handled    Select(item)     BackPane       BackInternal               │
│      │           │               │               │                     │
│      │           ▼               │               ▼                     │
│      │     ContentView           │          ContentView                 │
│      │     translates to         │          tries pop()                │
│      │     ContentAction         │               │                     │
│      │           │               │          ┌────┴────┐                │
│      │           ▼               │          ▼         ▼                │
│      │   ┌───────────────┐       │       Success   Failure             │
│      │   │NavigateTo     │       │          │         │                │
│      │   │Play(song)     │       │          ▼         ▼                │
│      │   │PlayAll        │       │       Handled   BackStage          │
│      │   │Enqueue        │       │                    │                │
│      │   └───────┬───────┘       │                    │                │
│      │           │               │                    │                │
│      │           ▼               ▼                    ▼                │
│      │       PaneAction      PaneAction           PaneAction           │
│      │           │               │                    │                │
│      │           └───────────────┼────────────────────┘                │
│      │                           │                                     │
│      ▼                           ▼                                     │
│  Navigator.handle_pane_action()                                        │
│      │                                                                  │
│      ├── NavigateTo(entity) → fetch content, push to DetailPane        │
│      ├── BackPane → pop history, switch pane                           │
│      ├── Play(song) → execute playback                                 │
│      ├── PlayAll → clear queue, add songs, play                        │
│      └── Enqueue → add to queue                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Types

```rust
// Pane identification
enum PaneId {
    Tab(TabId),
    Detail(DetailId),
}

enum TabId { Search, Queue, Library }
enum DetailId { Artist, Album, Playlist }

// Input modes
enum InputMode {
    Normal,   // Navigation
    Edit,     // Typing in text input (SearchPane)
    Find,     // Typing find query
}

// Section-level actions (from SectionList)
enum SectionAction {
    Handled,              // Key was handled internally
    Select(DetailItem),   // Item selected (Enter)
    Mark(Vec<usize>),     // Items marked
    BackPane,             // Esc with nothing to clear
    BackInternal,         // Backspace with nothing to pop
    Passthrough,          // Key not handled
}

// Content-level actions (from ContentView)
enum ContentAction {
    Handled,                         // Handled internally
    NavigateTo(EntityRef),           // Navigate to entity
    BackPane,                        // Go back to previous pane
    BackStage,                       // Go back to previous stage (TabPane)
    Play(Song),                      // Play single song
    PlayAll { songs: Vec<Song>, start_index: usize },
    Enqueue(Vec<Song>),              // Add to queue
}

// Pane-level actions (to Navigator)
enum PaneAction {
    Handled,
    NavigateTo(EntityRef),
    BackPane,
    Play(Song),
    PlayAll { songs: Vec<Song>, start_index: usize },
    Enqueue(Vec<Song>),
}

// Entity reference for navigation
struct EntityRef {
    entity_type: DetailId,
    id: String,
    name: String,
}
```

---

## File Structure

```
rmpc/src/
├── ui/
│   ├── mod.rs                    # Ui struct, event routing
│   │
│   ├── panes/
│   │   ├── mod.rs                # Pane traits, pane registration
│   │   ├── navigator_types.rs    # NavigatorPane, TabPane, DetailPane traits
│   │   ├── navigator.rs          # Navigator controller
│   │
│   │   ├── search_pane_v2.rs     # SearchPane (uses InputContentView)
│   │   ├── queue_pane_v2.rs      # QueuePane (uses ContentView)
│   │   ├── library_pane.rs       # LibraryPane (uses ContentView)
│   │   │
│   │   ├── artist_detail.rs      # ArtistDetailPane (thin wrapper)
│   │   ├── album_detail.rs       # AlbumDetailPane (thin wrapper)
│   │   └── playlist_detail.rs    # PlaylistDetailPane (thin wrapper)
│   │
│   └── widgets/
│       ├── content_view.rs       # ContentView<C> - unified stacking
│       ├── input_content_view.rs # InputContentView - input + content
│       ├── section_list.rs       # SectionList with handle_key()
│       ├── interactive_list_view.rs  # Core navigation state
│       ├── list_view_state.rs    # Selection, scroll, marks
│       ├── find_state.rs         # Find mode state
│       ├── section_view.rs       # Section structure
│       └── item_list.rs          # Item rendering widget
│
├── domain/
│   ├── content.rs                # Content trait, ArtistContent, etc.
│   ├── detail_item.rs            # DetailItem enum
│   ├── display.rs                # ListItemDisplay trait
│   └── song.rs                   # Song struct
│
└── backends/
    └── ...
```

---

## Adding New Pane

### Add New TabPane (e.g., History)

```
1. Create domain/history.rs with HistoryContent implementing Content
2. Create ui/panes/history_pane.rs implementing TabPane
   - Uses ContentView<HistoryContent>
   - ~60 lines of code
3. Add TabId::History to enum
4. Register in Navigator
5. Assign hotkey (e.g., 4)

Files: 3-4
Lines: ~100
```

### Add New DetailPane (e.g., Podcast)

```
1. Create domain/podcast.rs with PodcastContent implementing Content
2. Create ui/panes/podcast_detail.rs implementing DetailPane
   - Uses ContentView<PodcastContent>
   - ~40 lines of code
3. Add DetailId::Podcast to enum
4. Register in Navigator

Files: 3
Lines: ~80
```

---

## Playback Actions

When a song item is selected (Enter pressed):

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PLAYBACK BEHAVIOR                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Song is selected (Enter pressed):                                      │
│                                                                         │
│  1. Check if song is currently playing                                  │
│     └── YES: Toggle play/pause                                          │
│     └── NO:  Continue to step 2                                         │
│                                                                         │
│  2. Clear queue (if not empty and different from current)               │
│                                                                         │
│  3. Add song to queue                                                   │
│                                                                         │
│  4. Play the song                                                       │
│                                                                         │
│                                                                         │
│  Multiple songs selected (marks + Enter):                               │
│                                                                         │
│  1. Clear queue                                                         │
│  2. Add all marked songs to queue                                       │
│  3. Play from the position of the selected song                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Key Bindings Summary

| Context | Key | Action |
|---------|-----|--------|
| **Global** | 1/2/3 | Switch to TabPane (only in Normal mode) |
| **Normal** | Esc | Clear find, or back to prev pane |
| **Normal** | Backspace | Pop stack / back stage |
| **Normal** | / | Enter Find mode |
| **Normal** | n/N | Next/prev find match |
| **Normal** | j/k | Navigate list |
| **Normal** | G/gg | Jump to bottom/top |
| **Normal** | Ctrl-d/u | Half page down/up |
| **Normal** | Tab | Jump to next section |
| **Normal** | Shift-Tab | Jump to previous section |
| **Normal** | Enter | Activate selected item |
| **Normal** | Space | Toggle mark |
| **Find** | chars | Add to query |
| **Find** | Backspace | Delete char |
| **Find** | Enter | Confirm, exit, keep highlights |
| **Find** | Esc | Cancel, exit, clear highlights |
| **Edit** | chars | Add to input |
| **Edit** | Backspace | Delete char |
| **Edit** | Enter | Submit |
| **Edit** | Esc | Exit Edit mode |

---

## Migration from Legacy

### Deprecated Components

The following are deprecated and will be removed:

| Component | Replaced By |
|-----------|-------------|
| `NavStack<T>` | `ContentView<C>` |
| `flatten_content()` | `build_sections()` via Content trait |
| Manual stack in each pane | `ContentView<C>` stack |

### Migration Path

1. ✅ Create `ContentView<C>` as unified component
2. ✅ Add `handle_key()` to `SectionList`
3. ✅ Refactor DetailPanes to use ContentView
4. ✅ Refactor SearchPaneV2 to use ContentView
5. ✅ Refactor SearchPaneV2 to use InputContentView
6. ✅ Clean up (actor.rs deleted, Navigator integrated into ui/mod.rs)
