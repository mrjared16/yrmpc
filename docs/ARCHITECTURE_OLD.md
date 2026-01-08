# Architecture

## Design Principles

1. **TabPane + DetailPane** - Two types of panes with clear purposes
2. **Three-level navigation** - Mode → Stage/Stack → Pane
3. **Content stacking** - Each pane maintains its own content stack via `ContentView<C>`
4. **Find, not Filter** - Highlight matches, don't hide non-matches
5. **Vim-style modes** - Normal, Edit, Find modes
6. **Single path** - One unified component hierarchy, no parallel implementations
7. **Sections as Containers** - Sections are first-class domain objects, not markers in flat lists

---

## Section Architecture (Backend-Agnostic)

### The Problem with Markers

❌ **Anti-pattern**: Using `Header` items as markers in a flat list:
```
items = [Header("Songs"), Song, Song, Header("Albums"), Album, ...]
```
This requires scanning/reconstruction at every layer, leading to bugs and duplication.

### The Solution: Sections as Containers

✅ **Correct pattern**: Sections contain their items:
```
sections = [
    Section { key: "songs", title: "Songs", items: [Song, Song] },
    Section { key: "albums", title: "Albums", items: [Album] },
]
```

### Layer Responsibilities

```
┌─────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER                              │
│                                                              │
│   struct Section {                                           │
│       key: String,           // "songs", "albums", etc.     │
│       title: String,         // Display name                 │
│       items: Vec<MediaItem>, // Content                      │
│   }                                                          │
│                                                              │
│   struct SearchResults {                                     │
│       query: String,                                         │
│       sections: Vec<Section>, // Structured, not flat!      │
│   }                                                          │
│                                                              │
│   // Utility for backends without native sections           │
│   fn group_items_into_sections(items) -> Vec<Section>       │
│                                                              │
│   NO CONFIG AWARENESS - pure data structures                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND LAYER                             │
│                                                              │
│   YouTube: Parse shelves → Vec<Section> directly            │
│   MPD: Use group_items_into_sections() utility              │
│                                                              │
│   Returns SearchResults in NATIVE order (no config)         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    UI LAYER                                  │
│                                                              │
│   fn apply_config_order(sections, config) -> Vec<Section>  │
│                                                              │
│   Config ordering is a PRESENTATION concern.                │
│   UI reorders sections, then maps to SectionView.           │
└─────────────────────────────────────────────────────────────┘
```

### Key Insight

- **Config ordering** belongs in UI layer (presentation concern)
- **Section structure** belongs in domain layer (data concern)
- **Backends** return sections in their native order
- **No `MediaItem::Header`** needed - sections are containers, not markers

---

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Navigator | ⚠️ Refactor Planned | Hardcoded tabs being replaced with config-driven architecture |
| ContentView | ✅ Used | All V2 panes use ContentView for stacking |
| InputContentView | ✅ Used | SearchPane composes InputGroups + ContentView |
| Legacy Flag | ✅ Removed | V2 panes are now the only implementation |

### Navigator Refactor (In Progress)

The Navigator is being refactored to fix a dual pane system conflict:

- **Problem**: Navigator has hardcoded `TabId { Search, Queue, Library }` enum and owns duplicate pane instances, causing state desync between `Navigator.active` and `AppState.active_tab`
- **Solution**: Consolidate state in `AppState`, make Navigator access panes via `PaneContainer` reference, use config-driven tab registry
- **Status**: Planning complete, implementation pending (see `.agent/handoffs/2026-01-02-navigator-architecture-refactor.md`)

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
│      │   │Activate(item) │       │          │         │                │
│      │   └───────┬───────┘       │          ▼         ▼                │
│      │           │               │       Handled   BackStage          │
│      │           ▼               │                    │                │
│      │     Pane.resolve_action() │                    │                │
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
│      ├── Play(song) → convert to Intent, dispatch to handlers          │
│      ├── PlayAll → convert to Intent, dispatch to handlers             │
│      ├── Enqueue → convert to Intent, dispatch to handlers             │
│      └── Execute(Intent) → dispatch directly to handlers               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Action System (Intent → Dispatcher → Handler)

The action system provides a unified way to handle user actions across panes.
Instead of each pane implementing its own action logic, they build an Intent
and let the ActionDispatcher dispatch to appropriate handlers.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ACTION SYSTEM                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PaneAction::Play(song) / PlayAll / Enqueue / Execute(Intent)          │
│      │                                                                  │
│      ▼                                                                  │
│  Navigator.handle_pane_action()                                         │
│      │                                                                  │
│      │  Converts to Intent { action: IntentKind, selection: Selection } │
│      │                                                                  │
│      ▼                                                                  │
│  ActionDispatcher.dispatch(&Intent, ctx)                                │
│      │                                                                  │
│      │  Handlers called in priority order (highest first)              │
│      │                                                                  │
│      ├───────────────────────────────────────────────────────┐         │
│      ▼                   ▼                   ▼               ▼         │
│  ┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐    │
│  │TogglePlay  │   │PlayHandler │   │QueueHandler│   │SaveHandler │    │
│  │  Handler   │   │            │   │            │   │            │    │
│  │ (pri: 10)  │   │ (pri: 0)   │   │ (pri: 0)   │   │ (pri: 0)   │    │
│  └────────────┘   └────────────┘   └────────────┘   └────────────┘    │
│         │                │                │               │            │
│         ▼                ▼                ▼               ▼            │
│      ┌────────────────────────────────────────────────────────┐       │
│      │                    HandleResult                         │       │
│      │  Done          - Action handled successfully            │       │
│      │  NotApplicable - Handler can't handle, try next         │       │
│      │  Skip          - Silently pass to next handler          │       │
│      └────────────────────────────────────────────────────────┘       │
│                                                                         │
│  EXTENSIBILITY:                                                         │
│  ──────────────                                                         │
│  • Add YouTubePlayHandler with priority 5 to intercept Play intents    │
│  • Add LoggingHandler with priority 100 for analytics                  │
│  • Backend-specific handlers can override default behavior             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Intent and Selection

```rust
// The kind of action the user wants to perform
enum IntentKind {
    Play,              // Play selected content
    TogglePlayback,    // Toggle play/pause (no selection needed)
    AddToQueue,        // Add to queue
    RemoveFromQueue,   // Remove from queue
    MoveUp,            // Move up in queue
    MoveDown,          // Move down in queue
    SaveToLibrary,     // Save to library
}

// User intent: what action on what selection
struct Intent {
    action: IntentKind,
    selection: Selection,
}

// A selection of items to act upon
struct Selection {
    items: Vec<DetailItem>,
}

impl Selection {
    fn is_empty(&self) -> bool;
    fn songs_cloned(&self) -> Vec<Song>;
    fn has_only(&self, types: &[ContentType]) -> bool;
    fn find_song_index(&self, uri: &str) -> Option<usize>;
}
```

### Layer Separation (UI vs Domain)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         LAYER SEPARATION                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  UI Layer (ListItem) - ui/widgets/list_item.rs                         │
│  ─────────────────────────────────────────────                         │
│  Used for LIST RENDERING. Non-actionable items included.               │
│                                                                         │
│  enum ListItem {                                                        │
│      Content(DetailItem),  // Wraps actionable domain item              │
│      Header(String),       // Section header (non-focusable)            │
│      Spacer,               // Visual spacing                            │
│  }                                                                      │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  Domain Layer (DetailItem) - domain/detail_item.rs                     │
│  ─────────────────────────────────────────────────                     │
│  Used for ACTION HANDLING. Only actionable content.                    │
│                                                                         │
│  enum DetailItem {                                                      │
│      Song(Song),           // Playable content                          │
│      Ref(ContentRef),      // Navigable reference (album, artist, etc.) │
│      Header { title }      // DEPRECATED - use ListItem::Header         │
│  }                                                                      │
│                                                                         │
│  Selection is built from DetailItem, never ListItem.                   │
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
    Play(Song),                                  // Converted to Intent internally
    PlayAll { songs: Vec<Song>, start_index },   // Converted to Intent internally
    Enqueue(Vec<Song>),                          // Converted to Intent internally
    Execute(Intent),                             // Direct Intent execution
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
├── actions/                         # Action System (Intent → Dispatcher → Handler)
│   ├── mod.rs                       # Public exports
│   ├── intent.rs                    # IntentKind, Intent, Selection
│   ├── dispatcher.rs                # ActionDispatcher
│   ├── handler.rs                   # Handler trait, HandleResult
│   └── handlers/
│       ├── mod.rs                   # Handler registrations
│       ├── play.rs                  # PlayHandler
│       ├── playback.rs              # TogglePlaybackHandler
│       ├── queue.rs                 # QueueHandler
│       └── save.rs                  # SaveHandler
│
├── ui/
│   ├── mod.rs                       # Ui struct, event routing
│   │
│   ├── panes/
│   │   ├── mod.rs                   # Pane traits, pane registration
│   │   ├── navigator_types.rs       # NavigatorPane, TabPane, DetailPane traits
│   │   ├── navigator.rs             # Navigator controller (owns ActionDispatcher)
│   │
│   │   ├── search_pane_v2.rs        # SearchPane (uses InputContentView)
│   │   ├── queue_pane_v2.rs         # QueuePane (uses ContentView)
│   │   ├── library_tab.rs           # LibraryPane (uses ContentView)
│   │   │
│   │   ├── artist_detail.rs         # ArtistDetailPane (thin wrapper)
│   │   ├── album_detail.rs          # AlbumDetailPane (thin wrapper)
│   │   └── playlist_detail.rs       # PlaylistDetailPane (thin wrapper)
│   │
│   └── widgets/
│       ├── content_view.rs          # ContentView<C> - unified stacking
│       ├── input_content_view.rs    # InputContentView - input + content
│       ├── section_list.rs          # SectionList with handle_key(), get_selection()
│       ├── selectable_list.rs       # Core navigation state
│       ├── list_view_state.rs       # Selection, scroll, marks
│       ├── list_item.rs             # ListItem UI wrapper (Header/Spacer/Content)
│       ├── find_state.rs            # Find mode state
│       └── item_list.rs             # Item rendering widget
│
├── domain/
│   ├── content.rs                   # ContentViewable trait, ArtistContent, etc.
│   ├── detail_item.rs               # DetailItem enum (Song/Ref, deprecated Header)
│   ├── display.rs                   # ListItemDisplay trait
│   └── song.rs                      # Song struct
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
| `Ctx::queue` field | `QueueStore` via `ctx.queue_store()` |
| `ctx.queue_add/remove/move/clear` | `ctx.queue_store().add/remove_ids/move_id/clear` |

### Migration Path

1. ✅ Create `ContentView<C>` as unified component
2. ✅ Add `handle_key()` to `SectionList`
3. ✅ Refactor DetailPanes to use ContentView
4. ✅ Refactor SearchPaneV2 to use ContentView
5. ✅ Refactor SearchPaneV2 to use InputContentView
6. ✅ Clean up (actor.rs deleted, Navigator integrated into ui/mod.rs)
7. ✅ Migrate `Ctx::queue` to `QueueStore` (optimistic updates + reconciliation)

---

## QueueStore Architecture

The QueueStore is the single source of truth for queue state, enabling optimistic UI updates
with backend reconciliation. This is required because the YouTube backend doesn't emit MPD
idle events, so relying on `IdleEvent::Playlist` for UI queue refresh doesn't work reliably.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         QUEUE STORE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  User Action                                                            │
│      │                                                                  │
│      ▼                                                                  │
│  ctx.queue_store().add(songs) / remove_ids() / move_id() / clear()     │
│      │                                                                  │
│      ├─────────────────────────────────────────────────────────────────│
│      │                                                                  │
│      │  1. OPTIMISTIC UPDATE                                            │
│      │     └── Immediately update local RwLock<Vec<Song>>              │
│      │     └── New items marked with id=None until confirmed           │
│      │                                                                  │
│      │  2. NOTIFY UI                                                    │
│      │     └── Send AppEvent::RequestRender                            │
│      │     └── UI re-reads queue_store().read() instantly              │
│      │                                                                  │
│      │  3. SEND TO DAEMON                                               │
│      │     └── QueueDaemon trait sends ClientRequest::Command          │
│      │                                                                  │
│      │  4. REQUEST RECONCILIATION                                       │
│      │     └── QueueDaemon.refresh() queries backend for truth         │
│      │                                                                  │
│      ▼                                                                  │
│  Backend responds → QueryResult::Queue(songs)                           │
│      │                                                                  │
│      ▼                                                                  │
│  ctx.queue_store().reconcile(songs)                                     │
│      │                                                                  │
│      └── Replaces local state with backend snapshot                    │
│      └── Corrects any optimistic divergence                            │
│      └── Notifies UI again                                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Components

```rust
// core/queue_store.rs
pub struct QueueStore {
    inner: Arc<RwLock<Vec<Song>>>,   // Thread-safe queue state
    ui_tx: Sender<AppEvent>,          // UI notification channel
    daemon: Arc<dyn QueueDaemon>,     // Backend abstraction
}

impl QueueStore {
    // READ API
    fn read() -> RwLockReadGuard<Vec<Song>>;  // Get queue snapshot
    fn len() -> usize;
    fn get(idx: usize) -> Option<Song>;       // Cloned to avoid lock issues
    fn find_by_id(id: u32) -> Option<(usize, Song)>;
    
    // WRITE API (Optimistic + Notify + Command + Refresh)
    fn add(songs: Vec<Song>);
    fn add_and_play(songs: Vec<Song>);
    fn remove_ids(ids: &[u32]);
    fn move_id(id: u32, to_index: usize);
    fn clear();
    
    // RECONCILIATION
    fn reconcile(backend_queue: Vec<Song>);  // Backend wins
}

// Trait for daemon communication (allows mocking in tests)
pub trait QueueDaemon: Send + Sync + 'static {
    fn add(&self, songs: Vec<Song>);
    fn add_and_play(&self, songs: Vec<Song>);
    fn remove_ids(&self, ids: Vec<u32>);
    fn move_id(&self, id: u32, to_position: u32);
    fn clear(&self);
    fn refresh(&self);  // Request reconciliation
}
```

### Usage Pattern

```rust
// READING queue (snapshot)
let queue = ctx.queue_store().read();
for song in queue.iter() { ... }

// READING single item
if let Some(song) = ctx.queue_store().get(idx) { ... }

// MUTATING queue
ctx.queue_store().add(songs);           // Add songs
ctx.queue_store().remove_ids(&[1, 2]);  // Remove by ID
ctx.queue_store().clear();              // Clear all

// TEST SETUP (use reconcile to seed queue)
ctx.queue_store().reconcile(vec![song1, song2]);
```

### Benefits

1. **Instant UI feedback** - Optimistic updates bypass network latency
2. **Backend-agnostic** - Works with MPD (idle events) and YouTube (no events)
3. **Thread-safe** - RwLock allows concurrent reads, exclusive writes
4. **Testable** - QueueDaemon trait enables mocking
5. **Self-correcting** - Reconciliation fixes any UI/backend divergence

---

## YouTube Backend Architecture

### CachedExtractor (Request Coalescing)

The YouTube backend needs to extract stream URLs for playback. This is expensive (~200-500ms per extraction).
CachedExtractor wraps any `Extractor` implementation with LRU caching and request coalescing.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       CACHED EXTRACTOR                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Request("abc123") ─┐                                                   │
│  Request("abc123") ─┼──► CachedExtractor                                │
│  Request("abc123") ─┘         │                                         │
│                               ▼                                         │
│                        ┌─────────────┐                                  │
│                        │ LRU Cache   │ HIT? → Return cached URL         │
│                        │ (100, 1hr)  │                                  │
│                        └──────┬──────┘                                  │
│                               │ MISS                                    │
│                               ▼                                         │
│                        ┌─────────────┐                                  │
│                        │ In-Flight   │ Already extracting?              │
│                        │   Map       │ → Wait for result (coalescing)   │
│                        └──────┬──────┘                                  │
│                               │ NEW                                     │
│                               ▼                                         │
│                        ┌─────────────┐                                  │
│                        │  Extractor  │ ytx/yt-dlp                       │
│                        └─────────────┘                                  │
│                                                                         │
│  Benefits:                                                              │
│  • 1 extraction serves N concurrent waiters (coalescing)                │
│  • Repeat requests hit cache instantly (LRU + TTL)                      │
│  • ytx is default (~200ms), yt-dlp fallback (~500ms)                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### MPV Playback Service (Event-Driven)

The YouTube daemon manages an MPV subprocess for audio playback. Communication uses JSON-IPC over Unix socket.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PLAYBACK SERVICE                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PlaybackService                                                        │
│      │                                                                  │
│      ├── mpv: Mutex<MpvIpc>        ← Commands (loadfile, pause, etc.)  │
│      │                                                                  │
│      └── Event Loop Thread         ← Separate connection for events    │
│              │                                                          │
│              │ observe_property("playlist-pos", "pause", "idle-active") │
│              │                                                          │
│              └── read_event() loop → MpvEvent                           │
│                       │                                                 │
│                       ├── TrackChanged { position }                     │
│                       ├── PauseChanged { paused }                       │
│                       ├── EndFile { reason, file_error }                │
│                       └── IdleChanged { idle }                          │
│                                                                         │
│  Key Points:                                                            │
│  • observe_property MUST be called on the SAME connection that reads    │
│    events (MPV observation is per-connection)                           │
│  • Event loop thread stopped via AtomicBool on Drop                     │
│  • EDL URLs used for audio caching (cache + network fallback)           │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Audio Cache with EDL

For instant playback, the daemon prefetches audio to local cache and uses MPV's EDL (Edit Decision List) format:

```
edl://<cache_path>,0,<cached_duration>;<stream_url>,<cached_duration>,

Example:
edl:///tmp/audio_cache/abc123.m4a,0,10;https://googlevideo.com/...,10,
     └── Play first 10s from cache ──┘  └── Then stream the rest ────┘
```

EDL segment separators (`;`, `,`, `%`) must be percent-encoded in paths/URLs.
