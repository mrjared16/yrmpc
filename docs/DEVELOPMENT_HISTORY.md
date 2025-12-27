# Development History

**Project**: yrmpc - YouTube Music TUI Client
**Origin**: Fork of rmpc (MPD client)
**Vision**: Universal streaming music app with backend-agnostic architecture

---

## The Journey: From MPD Client to Streaming-First Architecture

### Phase 1: The Fork (Pre-2025)

yrmpc began as a fork of [rmpc](https://github.com/mierak/rmpc), an excellent MPD (Music Player Daemon) client. The original codebase was designed around local music files with MPD as the playback engine.

**Initial Goal**: Add YouTube Music streaming capability while preserving MPD compatibility.

### Phase 2: First YouTube Integration (Early December 2025)

**The Problem**: The original UI was built specifically for local files using `dir`/`dirstack` patterns. The first attempt to add streaming was the `SearchPane`, which tried to evolve from the built-in filename search with multiple tags.

**What Happened**:
- Required extensive hacks to work with streaming content
- Search suggestions stopped working
- Content sections didn't follow config order like v1
- Code became a maze of MPD-specific assumptions

**Lesson Learned**: You can't bolt streaming onto a local-file architecture. The UI assumptions were too deeply embedded.

### Phase 3: SearchPaneV2 - First Streaming-Native UI (Mid-December 2025)

**Decision**: Build a new pane that connects directly to `MusicBackend` instead of through MPD abstractions.

**Result**: SearchPaneV2 was usable but had unresolved issues. Rather than fix them, priority shifted to queue and playback - the core streaming experience.

### Phase 4: Queue and Playback Optimization (December 2025)

**Goal**: Make playback feel native, not like a hack.

**Work Done**:
- Modal for queue access from anywhere
- Abstracted queue logic to share between QueuePane and Modal
- Optimized queue-backend consistency

**Problems Encountered**:
- Items couldn't be moved up/down in queue
- Queue state inconsistent with backend
- Long playback wait times
- Auto-advance broke
- No filter/find mode in lists

### Phase 5: EDL Mode & Pre-extraction (December 2025)

**Innovation**: Leveraged MPV's EDL (Edit Decision List) mode for seamless streaming.

**Implementation**:
- Async worker pre-extracts stream URLs on queue changes
- Pre-downloads initial bytes for instant playback start
- Rolling prefetch window for gapless transitions

**Bug Discovery**: During this work, a bug emerged and the LLM kept getting confused by the codebase. It would explore MPD-backend logic when working on YouTube features due to naming confusion and tangled dependencies.

**Realization**: The codebase needed a full refactor, not more patches.

### Phase 6: The Vision Shift (December 2025)

**New Vision**: A universal music app designed with streaming in mind, that happens to also support local playback via MPD.

**Goals**:
1. Remove legacy naming coupled to MPD/local concepts
2. Don't break MPD backend (backward compatibility)
3. Design for open-source future - others can implement Spotify, Apple Music, etc.
4. Backend architecture as focused traits, not monolithic interfaces

### Phase 7: Backend Refactor (December 22-23, 2025)

**Old Architecture**:
```
MusicBackend (monolithic trait)
├── 50+ methods
├── MPD-specific assumptions baked in
├── YouTube backend = 90% stub implementations
└── Player/Queue/Search/Volume all mixed
```

**New Architecture**:
```
api::Playback     - play, pause, stop, seek
api::Queue        - add, remove, move, clear
api::Discovery    - search, browse, suggestions
api::Volume       - get, set, mute

BackendDispatcher - routes to active backend
MusicBackend      - deprecated, default no-ops
```

**Key Decisions**:
- Interface Segregation: Small, focused traits
- Backend Agnosticism: No MPD/MPV types in core interfaces
- Symmetry: MPD and YouTube have parallel structures
- Extensibility: New backends don't modify existing code

### Phase 8: TUI Refactor - The Unified View Architecture (December 2025)

**Problem**: Three different paths for displaying lists:
1. DetailPanes → ContentView → SectionList → InteractiveListView
2. SearchPane → NavStack → InteractiveListView
3. QueuePane → InteractiveListView directly

**Symptoms**:
- Duplicate key handling logic
- Inconsistent user experience
- Bug fixes needed in multiple places
- DRY violations everywhere

**Solution**: Layered SOLID architecture with single responsibility per layer:

```
Layer 0: InteractiveListView  - List state (selection, scroll, marks, find)
Layer 1: SectionList          - Section structure (headers, Tab/Shift-Tab)
Layer 2: ContentView<C>       - Stack management (push/pop)
Layer 3: Panes                - Map keys to actions (ONLY THIS)
Layer 4: Navigator            - Pane routing, action execution
```

**Key Insight**: "Pane's ONLY job is mapping keys to actions. No business logic in panes."

### Phase 9: Navigator Integration (December 27, 2025)

**Discovery**: Previous integration was in `actor.rs` which was never compiled (not declared as a module). The real `Ui` struct was in `ui/mod.rs`.

**Work Done**:
- Added Navigator to ui/mod.rs
- Route handle_key/render/on_event through Navigator
- Extended NavigatorPane trait with event methods
- Deleted dead actor.rs

**Result**: Unified architecture now active with `legacy_panes.enabled=false` (default).

---

## Design Principles Emerged

### 1. Streaming-First, Not Streaming-Added
Design for streaming latency, async fetching, and dynamic content. Local playback is a special case of streaming (latency = 0).

### 2. Backend Agnosticism
Core interfaces use abstract concepts (Song, Queue, Status). Backend-specific features use extension traits.

### 3. Single Path Architecture
One component hierarchy, one key handling flow, one rendering path. No "legacy" and "new" running in parallel long-term.

### 4. Vim-Style UX
Find (highlight) not Filter (hide). Modes (Normal/Edit/Find). Single-key actions (d=delete, J/K=move).

### 5. Minimal Pane Logic
Panes translate keys to actions. Actions bubble up. Navigator/ContentView handle business logic.

---

## Lessons Learned

1. **Naming matters**: MPD-specific names in generic code confuses both humans and LLMs.

2. **Stubs are technical debt**: Every `unimplemented!()` is a landmine. Default trait implementations are cleaner.

3. **Refactor early**: The longer you wait, the more tangled the dependencies. The December refactor should have happened earlier.

4. **Document decisions**: ADRs (Architecture Decision Records) prevent re-litigating solved problems.

5. **LLMs get confused by messy code**: If an AI agent keeps exploring the wrong module, the architecture probably needs clarification.

---

## Timeline Summary

| Date | Milestone |
|------|-----------|
| Pre-2025 | Fork of rmpc (MPD client) |
| Early Dec | First YouTube integration (hacky) |
| Mid Dec | SearchPaneV2 - streaming-native |
| Dec 16 | CPU fix, queue optimization |
| Dec 21 | EDL mode, pre-extraction |
| Dec 22 | Backend refactor begins |
| Dec 23 | Backend refactor complete |
| Dec 26 | Unified view architecture ADR |
| Dec 27 | Navigator integration, docs sync |

---

## Future Vision

The architecture is now ready for:

1. **Additional Backends**: Spotify, Apple Music, SoundCloud - implement the `api::*` traits
2. **Detail Views**: Artist/Album/Playlist panes (infrastructure ready)
3. **Grid Layouts**: LayoutKind::Grid defined, rendering TBD
4. **Library Sync**: Two-way playlist sync with YouTube Music

The goal: A terminal music player that feels native regardless of where the music lives.
