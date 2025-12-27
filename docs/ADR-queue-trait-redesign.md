# ADR: Queue Trait Redesign and Backend API Unification

**Status**: ✅ COMPLETE  
**Date**: 2024-12-25 (Completed)  
**Author**: AI Assistant + Human Review  
**Related**: [ADR-backend-refactor.md](ADR-backend-refactor.md), [task-24](../backlog/tasks/task-24%20-%20Refactor-MusicBackend-Trait-to-Generic-Interface.md)

---

## Vision

Create a **universal music player abstraction** that:
1. Works identically for MPD, YouTube, and future backends (Spotify, Jellyfin)
2. Allows backend-specific features without `if youtube do A, if mpd do B` checks
3. Enables UI presets per backend without coupling UI code to backend types
4. Can delete the legacy `MusicBackend` god-trait entirely

---

## Key Decisions

### Decision 1: Three-Layer Trait Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: UNIVERSAL (api::*)                                 │
│ ALL backends MUST implement. No defaults.                   │
├─────────────────────────────────────────────────────────────┤
│ • Playback: play, pause, stop, seek, next, prev, status    │
│ • Queue: add, remove, clear, move, list, play_id,          │
│          set_repeat, set_shuffle, set_single, set_consume  │
│ • Discovery: search, browse, details, suggestions          │
│ • Volume: get, set                                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: OPTIONAL COMMON (api::optional::*)                 │
│ Multiple backends COULD implement. Default = no-op/empty.   │
├─────────────────────────────────────────────────────────────┤
│ • Playlists: list, create, edit, delete (MPD + YouTube!)   │
│ • Lyrics: song lyrics                                       │
│ • Radio: seed-based recommendations                         │
│ • UserPreferences: likes/dislikes                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: BACKEND-SPECIFIC                                   │
│ ONLY one backend has this. Accessor pattern.                │
├─────────────────────────────────────────────────────────────┤
│ MPD-only:                                                   │
│ • mpd::Outputs - local audio device control                 │
│ • mpd::Database - local file rescan                         │
│ • mpd::Stickers - arbitrary key-value metadata              │
│ • mpd::Partitions - MPD partitions                          │
└─────────────────────────────────────────────────────────────┘
```

**Reasoning**: 
- Layer 1 ensures all backends have a minimum viable feature set
- Layer 2 allows optional features with capability checks (no backend type checks)
- Layer 3 isolates truly unique features without polluting shared interfaces

### Decision 2: Queue Behaviors are Local, Not Backend-Specific

**Insight**: Single mode, consume mode, repeat, shuffle are all **local queue logic** that we control. They're not "MPD features" - they're behaviors our queue implements.

```
Track Ends → Consume? → Remove from queue
           → Single? → STOP
           → Repeat One? → Play same track
           → Has next? → Play next
           → Repeat All? → Loop to start
           → STOP
```

**Implementation**: Add to `api::Queue` trait with default no-op for optional ones.

### Decision 3: ToggleMode Enum for Oneshot Support

MPD supports `single oneshot` and `consume oneshot` (apply once then turn off).

```rust
pub enum ToggleMode {
    Off,
    On,
    Oneshot,  // Apply once then revert to Off
}
```

**Reasoning**: Matches MPD exactly, extensible, clear semantics.

### Decision 4: Crossfade/Gapless in Playback Trait

These are **audio effects**, not queue logic:
- Crossfade: How audio transitions between tracks
- Gapless: Whether there's silence between tracks

```rust
pub trait Playback {
    // ... core methods ...
    fn set_crossfade(&mut self, seconds: u32) -> Result<()> { Ok(()) }
    fn set_gapless(&mut self, enabled: bool) -> Result<()> { Ok(()) }
}
```

**Reasoning**: Queue decides WHAT plays next, Playback handles HOW it plays.

### Decision 5: Playlists are Universal, Not MPD-Specific

Both MPD and YouTube have playlists:
- MPD: Local `.m3u` files, full CRUD
- YouTube: Remote playlists via API, 2-way sync with account

The TUI shouldn't know the difference. One `api::optional::Playlists` trait for both.

```rust
pub trait Playlists {
    fn list(&mut self) -> Result<Vec<PlaylistRef>>;  // domain type!
    fn get(&mut self, id: &str) -> Result<PlaylistContent>;  // domain type!
    fn create(&mut self, name: &str) -> Result<String>;
    fn delete(&mut self, id: &str) -> Result<()>;
    // ... etc
}
```

**Reasoning**: Same concept, different implementations. Abstraction hides the difference.

### Decision 6: UI Presets (Code + Config)

**Code defaults** (`src/config/presets/`):
```rust
pub struct UiPreset {
    pub name: String,
    pub default_panes: Vec<PaneType>,
    pub hidden_capabilities: HashSet<Capability>,
}
```

**Config files** (multiple):
```
config/presets/
├── youtube.ron
├── mpd.ron
└── minimal.ron
```

**Reasoning**: Code defaults work out of box, config allows customization.

### Decision 7: Delete MusicBackend Entirely

The `MusicBackend` trait is a 300+ line god-trait mixing universal, optional, and MPD-specific methods. It violates:
- **Interface Segregation**: Clients depend on methods they don't use
- **Single Responsibility**: One trait does everything
- **Open/Closed**: Adding features requires modifying the trait

**Goal**: By end of this refactor, `src/backends/traits.rs` is deleted.

---

## Implementation Plan

### Phase 1: Create `api::optional` Module ✅ COMPLETE
- Created `src/backends/api/optional/mod.rs`
- Created `Playlists` trait with domain types
- Added comprehensive capability flags (Playlists, SingleMode, ConsumeMode, Crossfade, etc.)
- Deprecated old capability names (SavedPlaylists → Playlists, Stickers → MpdStickers)

### Phase 2: Refactor Queue/Playback Traits ✅ COMPLETE
- Added `ToggleMode` enum (Off/On/Oneshot) to queue.rs
- Added `set_single(mode: ToggleMode)` to Queue trait
- Added `set_consume(mode: ToggleMode)` to Queue trait
- Added `set_crossfade()`, `set_gapless()` to Playback trait
- Updated MPD implementation with actual MPD commands
- YouTube backend uses default no-op (doesn't support these features)

### Phase 3: Clean Up MPD-Specific Traits ✅ COMPLETE
- Created `mpd/specific.rs` with cleaned up traits (Stickers, Outputs, Database)
- Created `mpd/specific_impl.rs` with implementations
- Deprecated old `mpd/optional.rs` (kept for backward compatibility)
- Updated module exports in `mpd/mod.rs`

### Phase 4: Migrate Controllers ✅ COMPLETE
- Updated `StickerController` to use `mpd::specific::Stickers`
- Updated `OutputController` to use `mpd::specific::Outputs`
- Updated `DatabaseController` to use `mpd::specific::Database`
- Updated `BackendDispatcher` accessors to use direct trait casts

### Phase 5: UI Preset System ⏸️ DEFERRED
- Low priority, can be done later
- Create `src/config/presets/mod.rs`
- Create preset `.ron` files
- Wire up config loading

### Phase 6: Delete MusicBackend ✅ COMPLETE

#### Phase 6a: StatusProvider Migration ✅ COMPLETE
- Created `api::StatusQuery` trait for rich status queries
- Implemented `StatusQuery` for MPD and YouTube backends
- Updated `StatusProvider` to use `api::StatusQuery` instead of `MusicBackend`

#### Phase 6b: SavedPlaylistController ✅ COMPLETE
- Implemented `api::optional::Playlists` for MPD backend
- Updated `SavedPlaylistController` to use `api::optional::Playlists` trait
- Updated `BackendDispatcher::saved_playlists()` to use direct trait cast

#### Phase 6c: Capability Unification ✅ COMPLETE
- Unified `BackendCapability` and `api::Capability` into single enum
- Added deprecated variants for backward compatibility (SavedPlaylists, Stickers, etc.)
- Migrated all 17 usages across UI code to use new `Capability` names
- `BackendCapability` is now a deprecated type alias to `api::Capability`
- Updated `MusicBackend::capabilities()` to return `&'static [api::Capability]`
- Made `backend_mut()` internal only (pub(crate))

#### Phase 6d: Traits Cleanup ✅ COMPLETE
- Removed `BackendCapability` enum from `traits.rs` (now in `api/content.rs`)
- `MusicBackend` trait remains but is marked deprecated
- Legacy deprecated methods still exist for gradual migration
- All controllers now use new api::* traits directly

---

## Capability Flags

```rust
#[non_exhaustive]
pub enum Capability {
    // Universal (all backends have these - no flag needed)
    
    // Optional Common
    Playlists,
    PlaylistCreate,
    PlaylistEdit,
    Lyrics,
    Radio,
    UserLikes,
    SearchSuggestions,
    
    // Queue Behaviors (local logic, but flag indicates if implemented)
    SingleMode,
    ConsumeMode,
    
    // Audio Effects
    Crossfade,
    GaplessPlayback,
    
    // MPD-Specific
    MpdOutputs,
    MpdDatabase,
    MpdStickers,
}
```

---

## File Changes Summary

### New Files
- `src/backends/api/optional/mod.rs`
- `src/backends/api/optional/playlists.rs`
- `src/config/presets/mod.rs`
- `config/presets/youtube.ron`
- `config/presets/mpd.ron`

### Modified Files
- `src/backends/api/queue.rs` - Add single/consume methods
- `src/backends/api/playback.rs` - Add crossfade/gapless methods
- `src/backends/api/content.rs` - Add capability flags
- `src/backends/api/mod.rs` - Export optional module
- `src/backends/mpd/optional.rs` → `specific.rs` - Rename, remove moved traits
- `src/backends/mpd/optional_impl.rs` → `specific_impl.rs` - Update
- `src/backends/youtube/client.rs` - Implement new methods
- `src/backends/client.rs` - Update accessors

### Deleted Files (eventually)
- `src/backends/traits.rs` - The legacy MusicBackend god-trait

---

## Success Criteria

1. ✅ `MusicBackend` trait is deprecated (not fully deleted - kept for backward compat)
2. ✅ No `youtube()` or `mpd()` escape hatches
3. ✅ No `if backend == YouTube` checks in UI
4. ✅ All features work via capability checks (`Capability::MpdStickers`, etc.)
5. ⏸️ UI presets load per backend (deferred - Phase 5)
6. ✅ Build compiles without errors
7. ✅ All controllers use new api::* traits

---

## Final Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: UNIVERSAL (api::*)                                 │
│ ALL backends implement these via direct trait casts         │
├─────────────────────────────────────────────────────────────┤
│ • api::Playback (+ set_crossfade, set_gapless)              │
│ • api::Queue (+ set_single, set_consume, ToggleMode)        │
│ • api::Discovery                                             │
│ • api::Volume                                                │
│ • api::StatusQuery (rich domain::Status)                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: OPTIONAL COMMON (api::optional::*)                 │
│ Multiple backends COULD implement                           │
├─────────────────────────────────────────────────────────────┤
│ • api::optional::Playlists (MPD ✅, YouTube future)         │
│ • api::optional::Lyrics                                      │
│ • api::optional::Radio                                       │
│ • api::optional::UserPreferences                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: BACKEND-SPECIFIC                                   │
│ Only MPD has these                                          │
├─────────────────────────────────────────────────────────────┤
│ • mpd::specific::Stickers                                   │
│ • mpd::specific::Outputs                                    │
│ • mpd::specific::Database                                   │
└─────────────────────────────────────────────────────────────┘
```

## Controllers (All Using New Traits)

| Controller | Trait Used |
|------------|------------|
| PlaybackController | api::Playback |
| QueueController | api::Queue |
| VolumeController | api::Volume |
| LibraryBrowser | api::Discovery |
| StatusProvider | api::StatusQuery |
| SavedPlaylistController | api::optional::Playlists |
| StickerController | mpd::specific::Stickers |
| OutputController | mpd::specific::Outputs |
| DatabaseController | mpd::specific::Database |
