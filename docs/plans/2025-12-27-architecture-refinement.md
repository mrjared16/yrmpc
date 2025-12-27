# Architecture Refinement Plan

**Date**: 2025-12-27
**Status**: Analysis Complete, Implementation Pending
**Context**: Deep review of c74b219e refactor against ADR specifications

---

## Executive Summary

The unified view architecture refactor (c74b219e) achieved 40% compliance with the ADR specification. This document provides detailed analysis of each gap, why it matters, and how to fix it.

---

## Current State vs Target State

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    CURRENT STATE (c74b219e)                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Navigator                                                                     │
│       │                                                                         │
│       ├──► SearchPaneV2 ──► [Manual] InputGroups + ContentView                 │
│       │                           │                                             │
│       │                           ▼                                             │
│       │                     ContentView (INTERPRETS actions)                    │
│       │                           │                                             │
│       │                           ▼                                             │
│       │                     SectionList ──► InteractiveListView                │
│       │                                                                         │
│       ├──► QueuePaneV2 ──► InteractiveListView (BYPASSES all layers!)          │
│       │                                                                         │
│       └──► DetailPanes ──► ContentView ──► SectionList ──► InteractiveListView │
│                                                                                 │
│   PROBLEMS:                                                                     │
│   • QueuePane skips 2 layers                                                   │
│   • ContentView decides "play vs navigate" (wrong responsibility)              │
│   • SearchPane doesn't use InputContentView                                    │
│   • Move/Delete actions get dropped at ContentView                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

                                    ▼

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         TARGET STATE (ADR Spec)                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Navigator                                                                     │
│       │                                                                         │
│       ├──► SearchPaneV2 ──► InputContentView<SearchInput, SearchResults>       │
│       │                           │                                             │
│       │                           ├── InputGroups (focus zone 1)               │
│       │                           └── ContentView (focus zone 2)               │
│       │                                   │                                     │
│       │                                   ▼                                     │
│       │                             SectionList                                 │
│       │                                   │                                     │
│       │                                   ▼                                     │
│       │                          InteractiveListView                            │
│       │                                                                         │
│       ├──► QueuePaneV2 ──► ContentView<QueueContent>                           │
│       │                           │                                             │
│       │                           ▼                                             │
│       │                     SectionList (headers: "Up Next", "History")        │
│       │                           │                                             │
│       │                           ▼                                             │
│       │                    InteractiveListView                                  │
│       │                                                                         │
│       └──► DetailPanes ──► ContentView ──► SectionList ──► InteractiveListView │
│                                                                                 │
│   UNIFIED: All panes use same layer stack                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Issue 1: ContentView Interprets Actions

### Current Behavior

```rust
// content_view.rs:249-290
fn translate_activate(&self, item: &DetailItem) -> ContentAction {
    match item {
        DetailItem::Song(song) => ContentAction::Play(song.clone()),
        DetailItem::Artist(a) => ContentAction::NavigateTo(EntityRef::artist(a)),
        DetailItem::Album(a) => ContentAction::NavigateTo(EntityRef::album(a)),
        // ...
    }
}
```

### Why This Is Wrong

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                   SAME ITEM, DIFFERENT CONTEXTS                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Context: SearchPane                    Context: QueuePane                     │
│   ──────────────────                     ─────────────────                      │
│                                                                                 │
│   User selects a Song                    User selects a Song                    │
│           │                                      │                              │
│           ▼                                      ▼                              │
│   Expected: PLAY IT                      Expected: JUMP TO IT                   │
│   (replace queue, start playback)        (scroll queue, highlight)              │
│                                                                                 │
│   But ContentView returns:               But ContentView returns:               │
│   ContentAction::Play(song)              ContentAction::Play(song)  ❌ WRONG!  │
│                                                                                 │
│   The PANE should decide, not ContentView!                                     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### ADR Specification (Lines 175-184)

```rust
enum ContentAction {
    Activate(DetailItem),  // Pane interprets: play? navigate? drill?
    // ...
}
```

### Pros of Current (Wrong) Approach

| Pro | Why It Seems Good |
|-----|-------------------|
| Less code in panes | Panes don't need switch statements |
| Centralized logic | One place to change behavior |
| Works for DetailPanes | All DetailPanes want same behavior |

### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **Context blindness** | ContentView doesn't know which pane it's in | QueuePane can't have different behavior |
| **SRP violation** | ContentView has 2 jobs: stack + interpretation | Changes to behavior require ContentView changes |
| **Can't extend** | New item types need ContentView changes | Adding "Podcast" type requires ContentView modification |
| **Testing harder** | Must mock ContentView to test pane logic | Integration tests only, no unit tests for interpretation |

### Future Obstacles

1. **Library Pane**: Selecting a playlist should OPEN it, not play it
2. **History Pane**: Selecting a song should show context, not play
3. **Settings Pane**: Items aren't playable at all
4. **Queue Reorder**: J/K should move, not play

### Fix Required

```rust
// BEFORE (content_view.rs)
fn handle_key(&mut self, key: KeyEvent) -> ContentAction {
    match self.section_list.handle_key(key) {
        SectionAction::Activate(item) => self.translate_activate(&item), // ❌
        // ...
    }
}

// AFTER (content_view.rs)
fn handle_key(&mut self, key: KeyEvent) -> ContentAction {
    match self.section_list.handle_key(key) {
        SectionAction::Activate(item) => ContentAction::Activate(item), // ✅ Just bubble
        // ...
    }
}

// AFTER (each pane)
fn handle_key(&mut self, key: KeyEvent) -> PaneAction {
    match self.content_view.handle_key(key) {
        ContentAction::Activate(item) => self.interpret_activation(item), // ✅ Pane decides
        // ...
    }
}
```

### Files to Modify

| File | Change |
|------|--------|
| `ui/widgets/content_view.rs` | Remove `translate_activate`, bubble `Activate(item)` |
| `ui/panes/search_pane_v2.rs` | Add `interpret_activation()` method |
| `ui/panes/queue_pane_v2.rs` | Add `interpret_activation()` method |
| `ui/panes/*_detail.rs` | Add `interpret_activation()` method |

---

## Issue 2: ContentAction Missing Move/Delete Variants

### Current Behavior

```rust
// content_view.rs:236-242
match section_action {
    SectionAction::MoveUp(items) => ContentAction::Handled,   // ❌ DROPPED!
    SectionAction::MoveDown(items) => ContentAction::Handled, // ❌ DROPPED!
    SectionAction::Delete(items) => ContentAction::Handled,   // ❌ DROPPED!
}
```

### Why This Is Wrong

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ACTION BUBBLING - CURRENT VS TARGET                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   CURRENT: Actions get LOST                                                     │
│   ─────────────────────────                                                     │
│                                                                                 │
│   User presses 'J' (move down)                                                  │
│           │                                                                     │
│           ▼                                                                     │
│   InteractiveListView                                                           │
│           │                                                                     │
│           ▼                                                                     │
│   ListAction::MoveDown([0, 1])                                                  │
│           │                                                                     │
│           ▼                                                                     │
│   SectionList translates                                                        │
│           │                                                                     │
│           ▼                                                                     │
│   SectionAction::MoveDown([item0, item1])                                       │
│           │                                                                     │
│           ▼                                                                     │
│   ContentView receives...                                                       │
│           │                                                                     │
│           ▼                                                                     │
│   return ContentAction::Handled  ◄──── ACTION LOST! Never reaches Navigator    │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   TARGET: Actions BUBBLE UP                                                     │
│   ─────────────────────────                                                     │
│                                                                                 │
│   User presses 'J' (move down)                                                  │
│           │                                                                     │
│           ▼                                                                     │
│   InteractiveListView ──► ListAction::MoveDown([0, 1])                         │
│           │                                                                     │
│           ▼                                                                     │
│   SectionList ──► SectionAction::MoveDown([item0, item1])                      │
│           │                                                                     │
│           ▼                                                                     │
│   ContentView ──► ContentAction::MoveDown([item0, item1])  ◄── BUBBLED!        │
│           │                                                                     │
│           ▼                                                                     │
│   QueuePane ──► PaneAction::QueueMoveDown([id0, id1])                          │
│           │                                                                     │
│           ▼                                                                     │
│   Navigator executes against backend                                            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### ADR Specification (Lines 175-184)

```rust
enum ContentAction {
    Handled,
    Activate(DetailItem),
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),    // ◄── REQUIRED
    MoveDown(Vec<DetailItem>),  // ◄── REQUIRED
    Delete(Vec<DetailItem>),    // ◄── REQUIRED
    Back,
}
```

### Pros of Current (Wrong) Approach

| Pro | Why It Seems Good |
|-----|-------------------|
| Simpler ContentAction | Fewer variants to handle |
| DetailPanes don't need Move/Delete | Only QueuePane does |

### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **QueuePane must bypass** | Forces QueuePane to use InteractiveListView directly | Can't migrate Queue to unified architecture |
| **Inconsistent UX** | Move/Delete work differently in Queue vs other panes | Users confused by different behavior |
| **Code duplication** | QueuePane reimplements navigation logic | Bug fixes don't apply to Queue |
| **Can't add features** | Playlist editing needs Move/Delete too | Library pane blocked |

### Future Obstacles

1. **Library Pane**: Reorder playlists (Move)
2. **Library Pane**: Remove from playlist (Delete)
3. **History Pane**: Clear history items (Delete)
4. **Bulk Operations**: Multi-select + delete across any pane

### Fix Required

```rust
// content_view.rs - ADD variants
pub enum ContentAction {
    Handled,
    Activate(DetailItem),
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),   // ADD
    MoveDown(Vec<DetailItem>), // ADD
    Delete(Vec<DetailItem>),   // ADD
    Back,
    Passthrough,
}

// content_view.rs - BUBBLE instead of drop
match section_action {
    SectionAction::MoveUp(items) => ContentAction::MoveUp(items),     // ✅
    SectionAction::MoveDown(items) => ContentAction::MoveDown(items), // ✅
    SectionAction::Delete(items) => ContentAction::Delete(items),     // ✅
}
```

### Files to Modify

| File | Change |
|------|--------|
| `ui/widgets/content_view.rs` | Add variants, bubble actions |
| `ui/panes/navigator_types.rs` | Ensure ContentAction matches |
| `ui/panes/queue_pane_v2.rs` | Handle MoveUp/MoveDown/Delete → PaneAction |

---

## Issue 3: QueuePane Bypasses Layer Stack

### Current Architecture

```rust
// queue_pane_v2.rs:61
pub struct QueuePaneV2 {
    list_view: InteractiveListView,  // DIRECT ACCESS
    // No ContentView, no SectionList
}
```

### Why This Is Wrong

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    QUEUE PANE - LAYER BYPASS PROBLEM                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   What OTHER panes do:                What QUEUE pane does:                     │
│   ────────────────────                ─────────────────────                     │
│                                                                                 │
│   Pane                                QueuePaneV2                               │
│     │                                    │                                      │
│     ▼                                    │                                      │
│   ContentView                            │ (SKIPPED)                            │
│     │                                    │                                      │
│     ▼                                    │                                      │
│   SectionList                            │ (SKIPPED)                            │
│     │                                    │                                      │
│     ▼                                    ▼                                      │
│   InteractiveListView               InteractiveListView                         │
│                                                                                 │
│   CONSEQUENCES:                                                                 │
│   • No section headers ("Now Playing", "Up Next", "History")                   │
│   • Find mode reimplemented                                                     │
│   • Tab navigation reimplemented                                                │
│   • Bug fixes to SectionList don't apply                                        │
│   • Can't stack content (drill into song details)                              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### ADR Specification

**Context (Line 14):**
> "QueuePane → InteractiveListView directly ❌ (bypasses layers!)"

**Migration Phase 4 (Lines 250-254):**
> "Migrate QueuePane - Create QueueContent implementing ContentViewable - Use ContentView<QueueContent>"

### Pros of Current (Wrong) Approach

| Pro | Why It Seems Good |
|-----|-------------------|
| Simpler implementation | No wrapper overhead |
| Direct control | QueuePane owns all state |
| Works for now | Basic functionality exists |

### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **No sections** | Can't show "Now Playing" header | UX worse than Spotify |
| **Duplicate logic** | Find mode, vim keys reimplemented | Double maintenance |
| **No stacking** | Can't drill into song details | "Go to Album" doesn't work |
| **Inconsistent UX** | Tab doesn't work same as other panes | User confusion |
| **Testing fragile** | Different code paths for same behavior | More test cases needed |

### Future Obstacles

1. **Queue Sections**: "Now Playing" / "Up Next" / "History" headers
2. **Song Details**: Drill into song → show lyrics, credits
3. **Album Context**: Show album art, other tracks in queue
4. **Smart Shuffle**: Section for "Similar to current" suggestions

### Fix Required

```rust
// 1. Create QueueContent in domain/content.rs
pub struct QueueContent {
    pub songs: Vec<Song>,
    pub current_index: Option<usize>,
}

impl ContentViewable for QueueContent {
    fn title(&self) -> &str { "Queue" }
    fn content_id(&self) -> &str { "queue" }
    fn to_content_details(&self) -> ContentDetails {
        ContentDetails::with_sections(vec![
            Section::new("Now Playing", vec![/* current song */]),
            Section::new("Up Next", vec![/* remaining songs */]),
        ])
    }
}

// 2. Refactor QueuePaneV2
pub struct QueuePaneV2 {
    content_view: ContentView<QueueContent>,  // ✅ Use layer stack
}

impl QueuePaneV2 {
    fn handle_key(&mut self, key: KeyEvent) -> PaneAction {
        match self.content_view.handle_key(key) {
            ContentAction::Activate(item) => PaneAction::JumpToSong(item.id()),
            ContentAction::MoveUp(items) => PaneAction::QueueMoveUp(items.ids()),
            ContentAction::MoveDown(items) => PaneAction::QueueMoveDown(items.ids()),
            ContentAction::Delete(items) => PaneAction::QueueDelete(items.ids()),
            // ...
        }
    }
}
```

### Files to Modify

| File | Change |
|------|--------|
| `domain/content.rs` | Add `QueueContent` implementing `ContentViewable` |
| `ui/panes/queue_pane_v2.rs` | Replace `InteractiveListView` with `ContentView<QueueContent>` |
| `ui/panes/navigator.rs` | Update queue refresh to use new structure |

---

## Issue 4: SearchPane Doesn't Use InputContentView

### Current Architecture

```rust
// search_pane_v2.rs - Manual composition
pub struct SearchPaneV2 {
    input_groups: InputGroups,      // Manual
    content_view: ContentView<...>, // Manual
    focus: SearchFocus,             // Manual focus management
}

impl SearchPaneV2 {
    fn handle_key(&mut self, key: KeyEvent) -> PaneAction {
        match self.focus {
            SearchFocus::Input => self.handle_input_key(key),
            SearchFocus::Results => self.handle_results_key(key),
        }
        // Manual focus switching with arrow keys
    }
}
```

### Why This Is Wrong

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 INPUT + CONTENT COMPOSITION PATTERNS                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   CURRENT: Manual Composition (DRY Violation)                                   │
│   ──────────────────────────────────────────                                    │
│                                                                                 │
│   SearchPaneV2                           LibraryPane (future)                   │
│   ┌─────────────┐                        ┌─────────────┐                        │
│   │ InputGroups │                        │ FilterInput │                        │
│   │ ContentView │                        │ ContentView │                        │
│   │ focus enum  │ ◄── DUPLICATE ──────►  │ focus enum  │                        │
│   │ arrow keys  │                        │ arrow keys  │                        │
│   │ Tab switch  │                        │ Tab switch  │                        │
│   └─────────────┘                        └─────────────┘                        │
│                                                                                 │
│   ADR TARGET: InputContentView Composition                                      │
│   ────────────────────────────────────────                                      │
│                                                                                 │
│   SearchPaneV2                           LibraryPane (future)                   │
│   ┌─────────────────────────────┐        ┌─────────────────────────────┐        │
│   │ InputContentView<           │        │ InputContentView<           │        │
│   │   SearchInput,              │        │   FilterInput,              │        │
│   │   SearchResults             │        │   PlaylistContent           │        │
│   │ >                           │        │ >                           │        │
│   │                             │        │                             │        │
│   │ ┌─────────────────────────┐ │        │ (Same component handles     │        │
│   │ │ Focus management        │ │        │  focus, arrow keys, Tab)    │        │
│   │ │ Arrow key switching     │ │        │                             │        │
│   │ │ Tab zone cycling        │ │        │                             │        │
│   │ └─────────────────────────┘ │        │                             │        │
│   └─────────────────────────────┘        └─────────────────────────────┘        │
│                                                                                 │
│   ONE implementation, MANY uses                                                 │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### ADR Specification (Lines 101-121)

```
InputContentView<I, C>
═══════════════════════
Composes:
  - Input zone (I: provides input UI)
  - Content zone (ContentView<C>)
Focus management:
  - Arrow keys switch between Input and Content
  - Each zone handles its own keys when focused
Usage:
  SearchPane = InputContentView<SearchInputGroups, SearchResultsContent>
  LibraryPane = InputContentView<FilterInput, PlaylistContent> (future)
```

### Pros of Current (Wrong) Approach

| Pro | Why It Seems Good |
|-----|-------------------|
| Works now | SearchPane functions |
| Full control | Can customize everything |
| No new component | Less abstraction |

### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **DRY violation** | LibraryPane will duplicate focus logic | Double maintenance |
| **Inconsistent UX** | Arrow key behavior may differ | User confusion |
| **Testing burden** | Must test focus in each pane | More test code |
| **Bug propagation** | Fix in one pane, forget another | Regressions |

### Future Obstacles

1. **Library Pane**: Filter input + playlist list
2. **Settings Pane**: Search input + settings list
3. **Help Pane**: Search input + keybinding list
4. **Any Input+List Pane**: All need same pattern

### Fix Required

The file `ui/widgets/input_content_view.rs` already exists! Just use it:

```rust
// BEFORE: search_pane_v2.rs
pub struct SearchPaneV2 {
    input_groups: InputGroups,
    content_view: ContentView<SearchResultsContent>,
    focus: SearchFocus,
}

// AFTER: search_pane_v2.rs
pub struct SearchPaneV2 {
    input_content: InputContentView<InputGroups, SearchResultsContent>,
    // Focus management handled by InputContentView
}
```

### Files to Modify

| File | Change |
|------|--------|
| `ui/panes/search_pane_v2.rs` | Use `InputContentView` instead of manual composition |

---

## Issue 5: Backend Abstraction Leaks MPD Types

### Current Behavior

```rust
// ui/mod.rs:303-312 - UI knows MPD error codes!
match err {
    MpdError::NoExist => {
        // Handle "thing doesn't exist" error
    }
    MpdFailureResponse { code: 50, .. } => {
        // Handle permission error
    }
}

// ui/mod.rs:1013 - UI branches on backend type!
fn pause_toggle(&mut self) {
    match self.backend_type {
        BackendType::Mpd => { /* MPD-specific logic */ }
        BackendType::YouTube => { /* YouTube-specific logic */ }
    }
}

// backends/client.rs - Escape hatch exists
pub fn as_mpd(&self) -> Option<&MpdBackend> { ... }
```

### Why This Is Wrong

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    BACKEND ABSTRACTION LEAK ANALYSIS                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   CURRENT: UI Knows Backend Details                                             │
│   ─────────────────────────────────                                             │
│                                                                                 │
│   UI Layer                                                                      │
│       │                                                                         │
│       ├── knows MpdError variants                                               │
│       ├── knows MpdFailureResponse codes                                        │
│       ├── checks BackendType enum                                               │
│       └── uses as_mpd() escape hatch                                            │
│                                                                                 │
│   To add Spotify backend, you must:                                             │
│   1. Add BackendType::Spotify                                                   │
│   2. Update EVERY match statement in UI  ◄── SCALING PROBLEM                   │
│   3. Handle SpotifyError in UI                                                  │
│   4. Maybe add as_spotify() escape hatch                                        │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────    │
│                                                                                 │
│   TARGET: UI Uses Abstract Types Only                                           │
│   ───────────────────────────────────                                           │
│                                                                                 │
│   UI Layer                                                                      │
│       │                                                                         │
│       └── uses BackendError::NotFound, ::PermissionDenied                      │
│           uses Capability::LibraryManagement, ::AudioOutputs                    │
│           NEVER branches on backend type                                        │
│                                                                                 │
│   To add Spotify backend, you must:                                             │
│   1. Implement api::Playback, api::Queue, api::Discovery                       │
│   2. Map SpotifyError → BackendError                                            │
│   3. Declare capabilities                                                       │
│   4. UI UNCHANGED  ◄── SCALABLE                                                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Pros of Current (Wrong) Approach

| Pro | Why It Seems Good |
|-----|-------------------|
| Works now | MPD and YouTube both work |
| Explicit | Can see exactly what's happening |
| Fine-grained | MPD-specific features accessible |

### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **Scaling O(N×M)** | N backends × M UI locations | Adding backend = touching many files |
| **Capability names leak** | `MpdDatabase`, `MpdStickers` | Names reveal backend |
| **Escape hatches** | `as_mpd()` bypasses abstraction | Defeats purpose of abstraction |
| **Error handling scattered** | UI knows MPD error codes | Each backend needs UI awareness |

### Future Obstacles

1. **Spotify Backend**: Must update all UI match statements
2. **SoundCloud Backend**: Same problem
3. **Local Files Backend**: Same problem
4. **Multi-Backend Mode**: UI can't handle multiple simultaneous

### Fix Required

```rust
// 1. Abstract error type in backends/api.rs
pub enum BackendError {
    NotFound { kind: &'static str, id: String },
    PermissionDenied { operation: &'static str },
    NetworkError { message: String },
    RateLimited { retry_after: Option<Duration> },
    NotSupported { feature: &'static str },
}

// 2. Backend maps internal errors
impl From<MpdError> for BackendError {
    fn from(err: MpdError) -> Self {
        match err {
            MpdError::NoExist => BackendError::NotFound { ... },
            MpdError::Permission => BackendError::PermissionDenied { ... },
            // ...
        }
    }
}

// 3. UI uses abstract errors
match result {
    Err(BackendError::NotFound { kind, id }) => {
        show_error(format!("{} '{}' not found", kind, id));
    }
    // No MPD-specific code!
}

// 4. Rename capabilities
pub enum Capability {
    LibraryManagement,  // was: MpdDatabase
    AudioOutputs,       // was: MpdOutputs
    UserAnnotations,    // was: MpdStickers
}
```

### Files to Modify

| File | Change |
|------|--------|
| `backends/api.rs` | Add `BackendError` enum |
| `backends/mpd/backend.rs` | Implement `From<MpdError> for BackendError` |
| `backends/youtube/backend.rs` | Implement error mapping |
| `ui/mod.rs` | Replace MPD error handling with abstract |
| `backends/api/content.rs` | Rename capability variants |

---

## Implementation Priority Matrix

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                       PRIORITY vs EFFORT MATRIX                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   HIGH ▲                                                                        │
│        │                                                                        │
│   I    │  ┌──────────────┐    ┌───────────────────────┐                        │
│   M    │  │ 2. Add Move/ │    │ 3. QueuePane uses     │                        │
│   P    │  │    Delete to │    │    ContentView        │                        │
│   A    │  │    Content   │    │                       │                        │
│   C    │  │    Action    │    │    EFFORT: HIGH       │                        │
│   T    │  │              │    │    (new QueueContent, │                        │
│        │  │ EFFORT: LOW  │    │     refactor pane)    │                        │
│        │  └──────────────┘    └───────────────────────┘                        │
│        │                                                                        │
│   MED  │  ┌──────────────┐    ┌───────────────────────┐                        │
│        │  │ 1. Content   │    │ 5. Abstract backend   │                        │
│        │  │    View stops│    │    errors             │                        │
│        │  │    interpret │    │                       │                        │
│        │  │              │    │    EFFORT: HIGH       │                        │
│        │  │ EFFORT: MED  │    │    (error enum,       │                        │
│        │  │ (move logic  │    │     all backends)     │                        │
│        │  │  to panes)   │    │                       │                        │
│        │  └──────────────┘    └───────────────────────┘                        │
│        │                                                                        │
│   LOW  │  ┌──────────────┐                                                     │
│        │  │ 4. Search    │                                                     │
│        │  │    uses Input│                                                     │
│        │  │    ContentV  │                                                     │
│        │  │              │                                                     │
│        │  │ EFFORT: LOW  │                                                     │
│        │  │ (file exists)│                                                     │
│        │  └──────────────┘                                                     │
│        │                                                                        │
│        └────────────────────────────────────────────────────────────────────►  │
│                    LOW                    MED                    HIGH           │
│                                         EFFORT                                  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Recommended Execution Order

### Phase 1: Enable Action Bubbling (Unblocks Queue)

**Duration**: 1 session
**Files**: 3

1. Add MoveUp/MoveDown/Delete to ContentAction enum
2. ContentView bubbles these actions instead of dropping
3. Verify SectionList → ContentView → Pane flow works

### Phase 2: ContentView Stops Interpreting (Unblocks Custom Behaviors)

**Duration**: 1 session
**Files**: 5+

1. Remove `translate_activate` from ContentView
2. Return `ContentAction::Activate(item)` instead
3. Add `interpret_activation` to each pane
4. Update all DetailPanes
5. Update SearchPaneV2

### Phase 3: QueuePane Uses Layer Stack (Unblocks Queue Features)

**Duration**: 2 sessions
**Files**: 4

1. Create `QueueContent` in `domain/content.rs`
2. Implement `ContentViewable` for QueueContent
3. Refactor `QueuePaneV2` to use `ContentView<QueueContent>`
4. Add section headers ("Now Playing", "Up Next")

### Phase 4: SearchPane Uses InputContentView (Nice to Have)

**Duration**: 0.5 session
**Files**: 1

1. Replace manual composition with InputContentView
2. Remove duplicate focus management code

### Phase 5: Abstract Backend Errors (Future-Proofs)

**Duration**: 2 sessions
**Files**: 6+

1. Create `BackendError` enum
2. Implement `From<MpdError>` for BackendError
3. Update YouTube backend error handling
4. Replace UI error handling with abstract
5. Rename capability variants

---

## Success Metrics

After completing all phases:

| Metric | Current | Target |
|--------|---------|--------|
| ADR Compliance | 40% | 100% |
| Panes using ContentView | 4/6 | 6/6 |
| Backend conditionals in UI | 3+ | 0 |
| Duplicate focus management | 2 panes | 0 (shared) |
| Action types that bubble | 3/6 | 6/6 |

---

## References

- ADR: `docs/ADR-unified-view-architecture.md`
- Architecture: `docs/ARCHITECTURE.md`
- Commit reviewed: c74b219e
- Session: 2025-12-27
