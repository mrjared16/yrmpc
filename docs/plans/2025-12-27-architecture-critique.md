# Architecture Critique: 10x Engineer Review

**Date**: 2025-12-27
**Reviewer**: Principal Engineer Perspective
**Scope**: Full architecture review of yrmpc after c74b219e refactor
**Status**: Complete Analysis

---

## Executive Summary

The refactor achieved **solid foundations** but stopped at **40% ADR compliance**. The good news: EDL optimization, rolling prefetch, and gapless playback are **fully implemented and working**. The concern: UI-backend coupling and incomplete action bubbling will become **scaling bottlenecks** as features grow.

| Aspect | Grade | Notes |
|--------|-------|-------|
| **Backend Playback** | A | EDL, prefetch, gapless all working |
| **UI Layer Stack** | B- | ContentView works but interprets instead of bubbling |
| **Backend Abstraction** | C | MPD types leak into UI layer |
| **Queue Architecture** | C- | Bypasses layer stack, race conditions possible |
| **Test Coverage** | D+ | Unit tests exist, integration tests missing |

---

## Part 1: What Was Done Right (Keep These)

### 1.1 EDL Playback Optimization ✅

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         EDL PLAYBACK FLOW                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   User presses Enter on song                                                    │
│           │                                                                     │
│           ▼                                                                     │
│   PlaybackService.build_playback_url()                                          │
│           │                                                                     │
│           ├── Check: Is first 10s cached?                                       │
│           │           │                                                         │
│           │           ├── YES: Build EDL URL                                    │
│           │           │         edl://[local_cache],0,10;[remote],10,           │
│           │           │                                                         │
│           │           └── NO: Use direct remote URL                             │
│           │                                                                     │
│           ▼                                                                     │
│   MPV plays with --gapless-audio=yes --prefetch-playlist=yes                    │
│           │                                                                     │
│           ▼                                                                     │
│   INSTANT PLAYBACK: Local cache → seamless → remote stream                      │
│                                                                                 │
│   Location: rmpc/src/backends/youtube/services/playback_service.rs:373-399      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Why This Is Excellent**:
- Perceived latency drops from 2-5s (network) to <100ms (disk)
- User doesn't wait for network to hear music
- Graceful fallback if cache miss

### 1.2 Rolling Prefetch Window ✅

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    3-TRACK ROLLING WINDOW                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MPV Playlist State:                                                           │
│                                                                                 │
│   ┌─────────┬─────────┬─────────┐                                               │
│   │ Track 1 │ Track 2 │ Track 3 │                                               │
│   │ PLAYING │  NEXT   │ PREFETCH│                                               │
│   └────┬────┴─────────┴─────────┘                                               │
│        │                                                                        │
│        │  Track 1 ends                                                          │
│        ▼                                                                        │
│   ┌─────────┬─────────┬─────────┐                                               │
│   │ Track 2 │ Track 3 │ Track 4 │  ◄── Orchestrator appends Track 4             │
│   │ PLAYING │  NEXT   │ PREFETCH│                                               │
│   └─────────┴─────────┴─────────┘                                               │
│                                                                                 │
│   PREFETCH_WINDOW_SIZE = 3 (orchestrator.rs:20)                                 │
│   handle_within_window_advance() maintains the window                           │
│                                                                                 │
│   Benefits:                                                                     │
│   • Gapless transitions (next track already buffered)                           │
│   • No network stall between songs                                              │
│   • Works with shuffle (window recalculated)                                    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Why This Is Excellent**:
- MPV's internal buffering handles transitions
- No manual crossfade code needed
- Resilient to network hiccups

### 1.3 Layered UI Architecture ✅

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LAYERED ARCHITECTURE (TARGET)                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Layer 4: Navigator                                                            │
│            │ Routes actions to backend, manages pane history                    │
│            ▼                                                                    │
│   Layer 3: Panes (SearchPane, QueuePane, DetailPanes)                           │
│            │ Map domain actions to PaneActions                                  │
│            ▼                                                                    │
│   Layer 2: ContentView<C>                                                       │
│            │ Stack management (push/pop levels)                                 │
│            ▼                                                                    │
│   Layer 1: SectionList                                                          │
│            │ Section headers, Tab navigation                                    │
│            ▼                                                                    │
│   Layer 0: InteractiveListView                                                  │
│            │ Selection, marks, find mode, vim keys                              │
│                                                                                 │
│   SOLID Compliance:                                                             │
│   • SRP: Each layer has one responsibility                                      │
│   • OCP: Add pane = new struct, lower layers unchanged                          │
│   • LSP: All ContentViewable types work with ContentView                        │
│   • ISP: Each layer only knows its own concern                                  │
│   • DIP: Layers communicate via Action enums                                    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Why This Is Excellent**:
- Single path for all list-based UIs
- Bug fixes in SectionList apply everywhere
- Adding new panes is ~80 lines of code

### 1.4 Backend Trait Segregation ✅

```rust
// api.rs - SOLID Interface Segregation
pub trait Playback: Send + Sync {
    fn play(&self) -> Result<()>;
    fn pause(&self) -> Result<()>;
    fn stop(&self) -> Result<()>;
    fn seek(&self, position: Duration) -> Result<()>;
}

pub trait Queue: Send + Sync {
    fn add(&self, song: &Song, position: Option<usize>) -> Result<()>;
    fn remove(&self, id: u32) -> Result<()>;
    fn move_id(&self, id: u32, to: usize) -> Result<()>;
    fn clear(&self) -> Result<()>;
}

pub trait Discovery: Send + Sync {
    fn search(&self, query: &str, filter: SearchFilter) -> Result<Vec<SearchResult>>;
    fn get_artist(&self, id: &str) -> Result<ArtistDetails>;
    fn get_album(&self, id: &str) -> Result<AlbumDetails>;
}
```

**Why This Is Excellent**:
- YouTube backend only implements what it supports
- No 50-method god interface with 40 stubs
- Easy to add new backends

---

## Part 2: Critical Issues (Fix Before New Features)

### 2.1 ContentView Interprets Actions (VIOLATES ADR)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ISSUE: CONTEXT-BLIND INTERPRETATION                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   CURRENT BEHAVIOR (WRONG):                                                     │
│                                                                                 │
│   User selects Song in SearchPane          User selects Song in QueuePane       │
│           │                                        │                            │
│           ▼                                        ▼                            │
│   ContentView.translate_activate()         ContentView.translate_activate()     │
│           │                                        │                            │
│           ▼                                        ▼                            │
│   ContentAction::Play(song) ✅             ContentAction::Play(song) ❌         │
│                                                                                 │
│   Expected for Queue: JUMP to song, not play!                                   │
│                                                                                 │
│   ─────────────────────────────────────────────────────────────────────────     │
│                                                                                 │
│   TARGET BEHAVIOR (ADR SPEC):                                                   │
│                                                                                 │
│   ContentView returns:                                                          │
│       ContentAction::Activate(item)  ◄── Just bubble, don't interpret           │
│                                                                                 │
│   Pane interprets:                                                              │
│       SearchPane: Activate(song) → Play(song)                                   │
│       QueuePane:  Activate(song) → JumpTo(song)                                 │
│       Library:    Activate(playlist) → NavigateTo(playlist)                     │
│                                                                                 │
│   Location: rmpc/src/ui/widgets/content_view.rs:249-290                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Pros of Current (Wrong) Approach

| Pro | Explanation |
|-----|-------------|
| Less pane code | Panes don't need switch statements |
| Works for DetailPanes | All want same behavior (play songs, navigate entities) |
| Centralized | One place to change default behavior |

#### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **Context blindness** | ContentView doesn't know which pane | QueuePane can't have different behavior for same item type |
| **SRP violation** | ContentView: stack + interpretation | Changing activation logic requires widget modification |
| **Extensibility blocked** | New item types need ContentView changes | Adding "Podcast" requires touching widget layer |
| **Testing harder** | Can't unit test pane interpretation | Must integration test through ContentView |

#### Why This Becomes Obstacle

1. **Queue Pane**: Selecting song should scroll/highlight, not replace queue
2. **Library Pane**: Selecting playlist should open it, not play
3. **History Pane**: Selecting song should show context menu
4. **Settings Pane**: Items aren't playable at all
5. **Multi-select operations**: Different panes need different bulk actions

#### Fix Effort: MEDIUM (1 session)

```rust
// content_view.rs - BEFORE
SectionAction::Activate(item) => self.translate_activate(&item),

// content_view.rs - AFTER
SectionAction::Activate(item) => ContentAction::Activate(item),

// Each pane - ADD
fn interpret_activation(&self, item: DetailItem) -> PaneAction {
    match item {
        DetailItem::Song(s) => PaneAction::Play(s),
        DetailItem::Artist(a) => PaneAction::NavigateTo(EntityRef::artist(a)),
        // ...
    }
}
```

---

### 2.2 ContentAction Missing Move/Delete Variants

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ISSUE: ACTIONS GET DROPPED                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   User presses 'J' (Shift+j = Move Down)                                        │
│           │                                                                     │
│           ▼                                                                     │
│   InteractiveListView                                                           │
│           │                                                                     │
│           ▼                                                                     │
│   ListAction::MoveDown([0, 1])                                                  │
│           │                                                                     │
│           ▼                                                                     │
│   SectionList                                                                   │
│           │                                                                     │
│           ▼                                                                     │
│   SectionAction::MoveDown([item0, item1])                                       │
│           │                                                                     │
│           ▼                                                                     │
│   ContentView receives...                                                       │
│           │                                                                     │
│           ▼                                                                     │
│   return ContentAction::Handled  ◄──── ACTION DROPPED! Never reaches Navigator │
│                                                                                 │
│   ADR Spec says ContentAction should have:                                      │
│   • MoveUp(Vec<DetailItem>)                                                     │
│   • MoveDown(Vec<DetailItem>)                                                   │
│   • Delete(Vec<DetailItem>)                                                     │
│                                                                                 │
│   Location: content_view.rs:236-242                                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Pros of Current (Wrong) Approach

| Pro | Explanation |
|-----|-------------|
| Simpler enum | Fewer variants to match |
| DetailPanes don't need it | Only QueuePane needs move/delete |

#### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **Forces bypass** | QueuePane MUST use InteractiveListView directly | Can't use unified architecture |
| **Inconsistent UX** | J/K/d work differently in Queue vs other panes | User confusion |
| **Code duplication** | QueuePane reimplements vim navigation | Double maintenance burden |
| **Feature blocked** | Playlist editing needs Move/Delete too | Library pane blocked |

#### Why This Becomes Obstacle

1. **Library Pane**: Reorder saved playlists (Move)
2. **Library Pane**: Remove from playlist (Delete)
3. **History Pane**: Clear history items (Delete)
4. **Any editable list**: Bulk operations

#### Fix Effort: LOW (0.5 session)

```rust
// content_view.rs - ADD variants
pub enum ContentAction {
    Handled,
    Activate(DetailItem),
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),    // ADD
    MoveDown(Vec<DetailItem>),  // ADD
    Delete(Vec<DetailItem>),    // ADD
    Back,
    Passthrough,
}

// content_view.rs - BUBBLE instead of drop
SectionAction::MoveUp(items) => ContentAction::MoveUp(items),
SectionAction::MoveDown(items) => ContentAction::MoveDown(items),
SectionAction::Delete(items) => ContentAction::Delete(items),
```

---

### 2.3 QueuePane Bypasses Layer Stack

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ISSUE: QUEUE PANE LAYER BYPASS                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   OTHER PANES:                          QUEUE PANE:                             │
│   ────────────                          ──────────                              │
│                                                                                 │
│   Pane                                  QueuePaneV2                             │
│     │                                       │                                   │
│     ▼                                       │                                   │
│   ContentView                               │ (SKIPPED)                         │
│     │                                       │                                   │
│     ▼                                       │                                   │
│   SectionList                               │ (SKIPPED)                         │
│     │                                       │                                   │
│     ▼                                       ▼                                   │
│   InteractiveListView              InteractiveListView                          │
│                                                                                 │
│   CONSEQUENCES:                                                                 │
│   ─────────────                                                                 │
│   • No section headers ("Now Playing", "Up Next", "History")                    │
│   • Find mode reimplemented (or missing?)                                       │
│   • Tab navigation reimplemented (or missing?)                                  │
│   • Bug fixes to SectionList don't apply to Queue                               │
│   • Can't stack content (drill into song → show lyrics)                         │
│   • Different code path = different bugs                                        │
│                                                                                 │
│   Location: rmpc/src/ui/panes/queue_pane_v2.rs:61                               │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Pros of Current (Wrong) Approach

| Pro | Explanation |
|-----|-------------|
| Simpler | No wrapper overhead |
| Direct control | QueuePane owns all state |
| Works now | Basic functionality exists |

#### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **No sections** | Can't show "Now Playing" header | UX worse than Spotify/Apple Music |
| **Duplicate logic** | Find, vim keys reimplemented | Double maintenance |
| **No stacking** | Can't drill into song details | "Go to Album" from queue blocked |
| **Inconsistent UX** | Tab doesn't work same as other panes | User confusion |

#### Why This Becomes Obstacle

1. **Queue Sections**: "Now Playing" / "Up Next" / "History" headers
2. **Song Context**: Drill into song → show lyrics, credits
3. **Album Context**: Show album art, other tracks
4. **Smart Shuffle**: Section for "Similar to current" suggestions
5. **Unified Testing**: Can't share test cases with other panes

#### Fix Effort: HIGH (2 sessions)

```rust
// 1. Create QueueContent in domain/content.rs
pub struct QueueContent {
    pub songs: Vec<Song>,
    pub current_index: Option<usize>,
}

impl ContentViewable for QueueContent {
    fn to_content_details(&self) -> ContentDetails {
        ContentDetails::with_sections(vec![
            Section::new("Now Playing", vec![/* current */]),
            Section::new("Up Next", vec![/* remaining */]),
        ])
    }
}

// 2. Refactor QueuePaneV2
pub struct QueuePaneV2 {
    content_view: ContentView<QueueContent>,  // Use layer stack
}
```

---

### 2.4 Backend Types Leak Into UI

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ISSUE: MPD TYPES IN UI LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   VIOLATIONS FOUND:                                                             │
│                                                                                 │
│   ui/mod.rs:40                                                                  │
│   ├── imports: MpdError, MpdFailureResponse, ErrorCode                          │
│   │                                                                             │
│   ui/mod.rs:303                                                                 │
│   ├── match e.downcast_ref::<MpdError>() { ... }                                │
│   │                                                                             │
│   ui/mod.rs:606, 616, 659, 727                                                  │
│   ├── Capability::MpdDatabase, Capability::MpdOutputs                           │
│   │                                                                             │
│   ui/mod.rs:672                                                                 │
│   ├── if ctx.is_mpd() { show decoder modal }                                    │
│   │                                                                             │
│   ui/panes/queue_pane_v2.rs:26                                                  │
│   ├── use crate::mpd::commands::SeekPosition                                    │
│   │                                                                             │
│   ui/panes/search_pane_v2.rs:162                                                │
│   └── crate::mpd::mpd_client::Filter                                            │
│                                                                                 │
│   WHAT THIS MEANS:                                                              │
│   Adding Spotify backend requires:                                              │
│   1. Add BackendType::Spotify                                                   │
│   2. Update EVERY "if mpd / if youtube" in UI  ◄── O(N×M) scaling              │
│   3. Handle SpotifyError in UI                                                  │
│   4. Maybe add Capability::SpotifyPlaylist, etc.                                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Pros of Current (Wrong) Approach

| Pro | Explanation |
|-----|-------------|
| Works now | MPD and YouTube both work |
| Explicit | Can see exactly what's happening |
| Fine-grained | MPD-specific features accessible |

#### Cons of Current Approach

| Con | Impact | Future Obstacle |
|-----|--------|-----------------|
| **O(N×M) scaling** | N backends × M UI locations | Adding backend = touching many files |
| **Capability names** | `MpdDatabase`, `MpdStickers` | Names reveal backend implementation |
| **Escape hatches** | `as_mpd()` bypasses abstraction | Defeats purpose of traits |
| **Error handling scattered** | UI knows MPD error codes | Each backend needs UI awareness |

#### Why This Becomes Obstacle

1. **Spotify Backend**: Must update all UI match statements
2. **SoundCloud Backend**: Same problem
3. **Local Files Backend**: Same problem
4. **Multi-Backend Mode**: UI can't handle mixed sources

#### Fix Effort: HIGH (2 sessions)

```rust
// backends/api.rs - Abstract error type
pub enum BackendError {
    NotFound { kind: &'static str, id: String },
    PermissionDenied { operation: &'static str },
    NetworkError { message: String },
    RateLimited { retry_after: Option<Duration> },
    NotSupported { feature: &'static str },
}

// backends/mpd/backend.rs - Map errors
impl From<MpdError> for BackendError {
    fn from(err: MpdError) -> Self {
        match err {
            MpdError::NoExist => BackendError::NotFound { ... },
            // ...
        }
    }
}

// Rename capabilities
Capability::LibraryManagement    // was: MpdDatabase
Capability::AudioOutputs         // was: MpdOutputs
Capability::UserAnnotations      // was: MpdStickers
```

---

### 2.5 Queue Race Conditions

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ISSUE: STALE QUEUE SNAPSHOT                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   execute_queue_move() in navigator.rs:411                                      │
│                                                                                 │
│   TIME ──────────────────────────────────────────────────────────────────►      │
│                                                                                 │
│   T0: User presses 'J' (move down)                                              │
│       │                                                                         │
│       │   ctx.queue = [A, B, C, D]  ◄── UI snapshot                             │
│       │   Selected: B (index 1)                                                 │
│       │   Calculate: move B to index 2                                          │
│       │                                                                         │
│   T1: │   Song A finishes, backend auto-advances                                │
│       │   Backend queue: [B, C, D]  ◄── Queue changed!                          │
│       │                                                                         │
│   T2: │   Command reaches backend                                               │
│       │   "Move item at index 1 to index 2"                                     │
│       │   Actually moves C to after D!  ◄── WRONG ITEM                          │
│       │                                                                         │
│       ▼                                                                         │
│   Result: User wanted to move B, but C got moved                                │
│                                                                                 │
│   RACE WINDOW:                                                                  │
│   • Track ending (queue advances)                                               │
│   • Another client modifying queue                                              │
│   • Shuffle/Repeat toggle                                                       │
│   • Gapless/crossfade completing                                                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

#### Mitigation Already Present

The current implementation uses `move_id(id, position)` instead of `move(from_pos, to_pos)`, which is safer because IDs are stable. However, the position calculation still uses the stale snapshot.

#### Remaining Risk

If the ID exists but its position changed, the target position calculation may still be wrong.

#### Fix Options

| Option | Pros | Cons |
|--------|------|------|
| **Optimistic UI** | Instant feedback, reconcile on event | Complex rollback logic |
| **Queue versioning** | Reject stale operations | Backend may not support |
| **Lock queue** | Guaranteed consistency | Blocks other operations |
| **Accept drift** | Simple, current behavior | Occasional wrong moves |

#### Recommended: Accept + Improve

1. Current behavior is acceptable for MVP
2. Add queue version check before sending command
3. Log warning if version mismatch, retry with fresh data

---

## Part 3: Feature Readiness Assessment

### Can We Build Complex Features On This Foundation?

| Feature | Ready? | Blocker |
|---------|--------|---------|
| **Artist Detail View** | ✅ Yes | None, DetailPane pattern works |
| **Album Detail View** | ✅ Yes | None, DetailPane pattern works |
| **Queue Sections** | ❌ No | QueuePane bypasses SectionList |
| **Playlist Editing** | ❌ No | Move/Delete actions get dropped |
| **Song Context Menu** | ⚠️ Partial | ContentView interprets actions |
| **Multi-Backend** | ❌ No | UI has backend conditionals |
| **Smart Shuffle** | ⚠️ Partial | Queue sections blocked |
| **Lyrics View** | ⚠️ Partial | Queue can't stack content |

### Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    FEATURE DEPENDENCY GRAPH                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌───────────────┐         ┌───────────────┐                                   │
│   │ Add Move/Del  │────────►│ QueuePane     │                                   │
│   │ to Content    │         │ uses Content  │                                   │
│   │ Action        │         │ View          │                                   │
│   └───────────────┘         └───────┬───────┘                                   │
│          ▲                          │                                           │
│          │                          ▼                                           │
│   ┌──────┴────────┐         ┌───────────────┐         ┌───────────────┐         │
│   │ ContentView   │────────►│ Queue         │────────►│ Playlist      │         │
│   │ stops         │         │ Sections      │         │ Editing       │         │
│   │ interpreting  │         │               │         │               │         │
│   └───────────────┘         └───────────────┘         └───────────────┘         │
│          │                                                                      │
│          │                                                                      │
│          ▼                                                                      │
│   ┌───────────────┐         ┌───────────────┐                                   │
│   │ Pane-specific │────────►│ Song Context  │                                   │
│   │ activation    │         │ Menu          │                                   │
│   │ logic         │         │               │                                   │
│   └───────────────┘         └───────────────┘                                   │
│                                                                                 │
│   ┌───────────────┐         ┌───────────────┐         ┌───────────────┐         │
│   │ Abstract      │────────►│ Generic       │────────►│ Multi-Backend │         │
│   │ BackendError  │         │ Capabilities  │         │ Support       │         │
│   └───────────────┘         └───────────────┘         └───────────────┘         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 4: Recommended Execution Order

### Priority Matrix

```
                    IMPACT
                HIGH ▲
                     │   ┌─────────────────┐   ┌─────────────────┐
                     │   │ 2. Add Move/Del │   │ 3. Queue uses   │
                     │   │    to Content   │   │    ContentView  │
                     │   │    Action       │   │                 │
                     │   │    EFFORT: LOW  │   │    EFFORT: HIGH │
                     │   └─────────────────┘   └─────────────────┘
                     │
                MED  │   ┌─────────────────┐   ┌─────────────────┐
                     │   │ 1. ContentView  │   │ 5. Abstract     │
                     │   │    stops        │   │    backend      │
                     │   │    interpreting │   │    errors       │
                     │   │    EFFORT: MED  │   │    EFFORT: HIGH │
                     │   └─────────────────┘   └─────────────────┘
                     │
                LOW  │   ┌─────────────────┐
                     │   │ 4. Search uses  │
                     │   │    InputContent │
                     │   │    View         │
                     │   │    EFFORT: LOW  │
                     │   └─────────────────┘
                     │
                     └─────────────────────────────────────────────►
                              LOW           MED           HIGH
                                          EFFORT
```

### Execution Phases

| Phase | Duration | Changes | Unblocks |
|-------|----------|---------|----------|
| **1. Add Move/Delete variants** | 0.5 session | 3 files | Queue unification |
| **2. ContentView bubbles, doesn't interpret** | 1 session | 5 files | Pane-specific behavior |
| **3. QueuePane uses ContentView** | 2 sessions | 4 files | Queue sections, drill-down |
| **4. SearchPane uses InputContentView** | 0.5 session | 1 file | DRY for input+list panes |
| **5. Abstract backend errors** | 2 sessions | 6+ files | Multi-backend support |

### Total Effort: ~6 sessions

---

## Part 5: Recommendations

### Do Now (Before New Features)

1. **Phase 1**: Add Move/Delete to ContentAction - unblocks everything else
2. **Phase 2**: ContentView stops interpreting - enables pane-specific logic

### Do Soon (Next Sprint)

3. **Phase 3**: QueuePane uses ContentView - enables queue sections

### Do Later (Tech Debt)

4. **Phase 4**: SearchPane uses InputContentView - DRY cleanup
5. **Phase 5**: Abstract backend errors - future-proofing

### Don't Do

- Don't add new features that require queue sections until Phase 3
- Don't add new backends until Phase 5
- Don't refactor Navigator to dynamic panes (OCP analysis concluded: keep concrete)

---

## References

- ADR: `docs/ADR-unified-view-architecture.md`
- Architecture: `docs/ARCHITECTURE.md`
- Navigator Design: `docs/ADR-navigator-design.md`
- Previous Refinement: `docs/plans/2025-12-27-architecture-refinement.md`
- Commit Reviewed: c74b219e
