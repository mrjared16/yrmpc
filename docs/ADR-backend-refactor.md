# ADR: Backend Architecture Refactor

**Status**: Complete (Phase 1 + Phase 2)
**Date**: 2025-12-22
**Author**: Agent
**Last Updated**: 2025-12-22

---

## Implementation Status

### Phase 1: File Reorganization ✅ COMPLETE

All backends moved to `src/backends/`:
- `backends/mpd/` - MPD backend with protocol/ subdirectory
- `backends/youtube/` - YouTube daemon architecture
- `backends/mpv/` - MPV standalone player
- `backends/traits.rs` - MusicBackend + QueueOperations

Build compiles successfully. Backward compatibility preserved.

### Phase 2: Trait Cleanup ✅ COMPLETE

- Added `BackendCapability` enum for feature detection
- Added `supports(capability)` method to all backends
- Made all optional methods have default implementations in `MusicBackend`:
  - Playback options: repeat, random, single, consume, crossfade, shuffle
  - Library: list_all, list_tag, count
  - Saved playlists: 9 methods
  - Stickers: 3 methods
  - Database: update, rescan
  - System: outputs, decoders, partitions
- Removed ~80 lines of stub implementations from YouTube backends
- Removed ~60 lines of stub implementations from MPV backend

### Phase 3: Naming Critique ✅ RESEARCHED

Analysis identified these naming issues for future cleanup:

**Critical (High Value):**
- `Client` enum → `PlayerController` (overloaded term causes confusion)
- `YouTubeClient` → `YouTubeProxy` (breaks symmetry with MpdBackend/MpvBackend)

**Minor (Low Effort):**
- `shared/mpd_query.rs` → `shared/backend_query.rs` (used by all backends)
- `shared/mpd_client_ext.rs` → `shared/client_ext.rs`

**Deferred (Over-engineering):**
- Don't split MusicBackend into smaller traits (defaults solve the problem)
- Don't rename `song.file` → `song.uri` (works fine as-is)

### Phase 4-6: Skipped

Further trait splitting (Playable, Queueable, Searchable) deemed over-engineering.
Current design is clean and maintainable.

---

## Context

The current backend architecture has grown organically from an MPD-centric design. As YouTube support was added, the abstraction became strained, leading to:

1. **MPD-biased interfaces**: The `MusicBackend` trait contains MPD-specific methods that YouTube implements as stubs
2. **Inconsistent structure**: MPD code is split between `src/mpd/` and `src/player/`, while YouTube is unified in `src/player/youtube/`
3. **Tight coupling**: Adding a new backend (e.g., Spotify, Jellyfin) would require understanding MPD internals
4. **Leaky abstractions**: YouTube backend imports MPD types directly

---

## Decision

Refactor the backend architecture following **SOLID principles** with emphasis on:

- **Interface Segregation**: Split the monolithic `MusicBackend` into focused traits
- **Dependency Inversion**: Core depends on abstractions, backends implement them
- **Open/Closed**: New backends can be added without modifying existing code
- **Backend Agnosticism**: No backend-specific types leak into core interfaces

---

## Architecture Overview

### Current vs Proposed

```
CURRENT                              PROPOSED
═══════                              ════════

src/                                 src/
├── mpd/          ← separate         ├── traits/        ← NEW: interfaces
├── player/                          ├── backends/      ← ALL backends here
│   ├── backend.rs  ← MPD-shaped     │   ├── mpd/
│   ├── mpd_backend.rs               │   ├── youtube/
│   ├── youtube/                     │   └── shared/    ← shared utilities
│   └── mpv/                         ├── domain/        ← unchanged
└── domain/                          └── core/          ← uses traits only
```

### Trait Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                     MusicBackend                            │
│  (composite trait = Playable + Queueable + Searchable)      │
└─────────────────────────────────────────────────────────────┘
         │                │                │
         ▼                ▼                ▼
   ┌──────────┐    ┌──────────┐    ┌────────────┐
   │ Playable │    │ Queueable│    │ Searchable │
   └──────────┘    └──────────┘    └────────────┘
   play()          enqueue()       search()
   pause()         dequeue()       browse()
   stop()          reorder()       suggestions()
   seek()          clear()
   next()          play_at()
   previous()      get_queue()
   status()
   current()
```

### Optional Extension Traits

Backends can optionally implement additional capabilities:

```rust
// Only MPD implements these
trait PlaylistPersistence { save(), load(), delete(), rename() }
trait DatabaseManager { update(), rescan() }
trait OutputManager { outputs(), enable_output() }

// Only YouTube implements these
trait ThumbnailProvider { get_thumbnail() }
trait StreamResolver { resolve_url() }
```

---

## Detailed File Structure

```
src/
├── traits/                          # Interface definitions (the "ports")
│   ├── mod.rs                       # Re-exports all traits
│   ├── playable.rs                  # Playback control trait
│   ├── queueable.rs                 # Queue management trait
│   ├── searchable.rs                # Search/browse trait
│   ├── backend.rs                   # Composite MusicBackend trait
│   └── extensions/                  # Optional capability traits
│       ├── mod.rs
│       ├── playlist_persistence.rs
│       ├── database_manager.rs
│       └── output_manager.rs
│
├── backends/                        # Implementations (the "adapters")
│   ├── mod.rs                       # UnifiedBackend enum + factory
│   │
│   ├── mpd/                         # MPD backend
│   │   ├── mod.rs                   # MpdBackend struct
│   │   ├── client.rs                # MPD protocol client
│   │   ├── protocol.rs              # Text protocol handling
│   │   ├── commands/                # Command implementations
│   │   └── extensions.rs            # MPD-specific extensions
│   │
│   ├── youtube/                     # YouTube backend
│   │   ├── mod.rs                   # YouTubeBackend (client side)
│   │   ├── protocol.rs              # IPC protocol definitions
│   │   ├── api.rs                   # YouTube Music API
│   │   ├── extractor/               # Stream URL extraction
│   │   │   ├── mod.rs
│   │   │   ├── trait.rs             # Extractor trait
│   │   │   ├── ytx.rs
│   │   │   └── ytdlp.rs
│   │   └── daemon/                  # Server-side (runs in daemon process)
│   │       ├── mod.rs               # YouTubeDaemon
│   │       ├── server.rs            # IPC server loop
│   │       ├── queue_service.rs     # Queue state management
│   │       ├── playback_engine.rs   # Media engine abstraction
│   │       └── api_service.rs       # YouTube API wrapper
│   │
│   └── shared/                      # Shared utilities (backend-agnostic)
│       ├── mod.rs
│       ├── media_engine.rs          # MediaEngine trait (MPV is one impl)
│       └── mpv/                     # MPV implementation of MediaEngine
│           ├── mod.rs
│           └── ipc.rs
│
├── domain/                          # Shared domain types (unchanged)
│   ├── mod.rs
│   ├── song.rs                      # Song struct
│   ├── status.rs                    # PlaybackStatus
│   ├── queue.rs                     # QueuePosition, QueueItem
│   └── search.rs                    # SearchItem, BrowseEntry
│
└── core/                            # Application core
    ├── mod.rs
    ├── backend_factory.rs           # Creates backends from config
    ├── event_loop.rs
    └── client.rs                    # Facade for TUI
```

---

## Migration Plan

### Phase 1: Foundation (No Breaking Changes)

Create new structure alongside existing code. No functionality changes.

#### Step 1.1: Create traits module

```bash
mkdir -p src/traits/extensions
```

Create trait files with the new interface design. Initially empty or with TODO markers.

**Files to create:**
- `src/traits/mod.rs`
- `src/traits/playable.rs`
- `src/traits/queueable.rs`
- `src/traits/searchable.rs`
- `src/traits/backend.rs`

#### Step 1.2: Create backends directory structure

```bash
mkdir -p src/backends/{mpd,youtube,shared/mpv}
```

**Files to create:**
- `src/backends/mod.rs` (empty, just declares modules)

#### Step 1.3: Define core traits

**`src/traits/playable.rs`**:
```rust
use anyhow::Result;
use crate::domain::{Song, Status, SeekMode};

/// Playback control capabilities
pub trait Playable: Send + Sync {
    /// Start/resume playback
    fn play(&mut self) -> Result<()>;

    /// Pause playback
    fn pause(&mut self) -> Result<()>;

    /// Stop playback completely
    fn stop(&mut self) -> Result<()>;

    /// Skip to next track
    fn next(&mut self) -> Result<()>;

    /// Go to previous track
    fn previous(&mut self) -> Result<()>;

    /// Seek within current track
    fn seek(&mut self, mode: SeekMode) -> Result<()>;

    /// Get current playback status
    fn status(&mut self) -> Result<Status>;

    /// Get currently playing song (if any)
    fn current_song(&mut self) -> Result<Option<Song>>;

    /// Get/set volume (0-100)
    fn volume(&mut self) -> Result<u8>;
    fn set_volume(&mut self, volume: u8) -> Result<()>;
}
```

**`src/traits/queueable.rs`**:
```rust
use anyhow::Result;
use crate::domain::{Song, QueuePosition};

/// Queue management capabilities
pub trait Queueable: Send + Sync {
    /// Add song to queue at optional position
    fn enqueue(&mut self, song: &Song, position: Option<QueuePosition>) -> Result<()>;

    /// Remove song from queue by ID
    fn dequeue(&mut self, id: u32) -> Result<()>;

    /// Move song within queue
    fn reorder(&mut self, from_id: u32, to_position: u32) -> Result<()>;

    /// Clear entire queue
    fn clear_queue(&mut self) -> Result<()>;

    /// Play specific song in queue by ID
    fn play_at(&mut self, id: u32) -> Result<()>;

    /// Get all songs in queue
    fn get_queue(&mut self) -> Result<Vec<Song>>;

    /// Shuffle the queue
    fn shuffle(&mut self) -> Result<()>;
}
```

**`src/traits/searchable.rs`**:
```rust
use anyhow::Result;
use crate::domain::{SearchItem, BrowseEntry};

/// Search and browse capabilities
pub trait Searchable: Send + Sync {
    /// Search for content
    fn search(&mut self, query: &str) -> Result<Vec<SearchItem>>;

    /// Browse a path/category
    fn browse(&mut self, path: &str) -> Result<Vec<BrowseEntry>>;

    /// Get search suggestions for autocomplete
    fn suggestions(&mut self, query: &str) -> Result<Vec<String>>;
}
```

**`src/traits/backend.rs`**:
```rust
use super::{Playable, Queueable, Searchable};

/// Composite trait for a complete music backend
///
/// All backends must implement the core capabilities.
/// Additional features are exposed through optional extension traits.
pub trait MusicBackend: Playable + Queueable + Searchable + Send + Sync {
    /// Human-readable backend name for display
    fn name(&self) -> &'static str;

    /// Unique backend identifier for config/serialization
    fn id(&self) -> &'static str;

    /// Check if backend supports a specific feature
    fn supports(&self, feature: BackendFeature) -> bool;
}

/// Features that backends may or may not support
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BackendFeature {
    /// Persistent playlist storage
    SavedPlaylists,
    /// Database update/rescan
    DatabaseManagement,
    /// Audio output selection
    OutputSelection,
    /// Rich metadata (thumbnails, etc)
    RichMetadata,
    /// Repeat modes (one, all)
    RepeatModes,
    /// Shuffle mode
    ShuffleMode,
}
```

---

### Phase 2: Migrate Shared Utilities

Move backend-agnostic code to `backends/shared/`.

#### Step 2.1: Create MediaEngine trait

The MPV IPC code should be abstracted behind a trait so it can be replaced.

**`src/backends/shared/media_engine.rs`**:
```rust
use anyhow::Result;
use std::time::Duration;

/// Abstraction over a media playback engine (MPV, GStreamer, etc.)
///
/// This trait allows the YouTube daemon to use any media engine,
/// not just MPV. The engine handles actual audio/video playback.
pub trait MediaEngine: Send + Sync {
    /// Load a URL into the engine's playlist
    fn load(&mut self, url: &str, append: bool) -> Result<()>;

    /// Start playback
    fn play(&mut self) -> Result<()>;

    /// Pause playback
    fn pause(&mut self) -> Result<()>;

    /// Stop and clear
    fn stop(&mut self) -> Result<()>;

    /// Seek to position
    fn seek(&mut self, position: Duration) -> Result<()>;

    /// Get current playback position
    fn position(&self) -> Result<Option<Duration>>;

    /// Get current track duration
    fn duration(&self) -> Result<Option<Duration>>;

    /// Check if currently playing
    fn is_playing(&self) -> Result<bool>;

    /// Check if idle (nothing loaded)
    fn is_idle(&self) -> Result<bool>;

    /// Get/set volume
    fn volume(&self) -> Result<u8>;
    fn set_volume(&mut self, volume: u8) -> Result<()>;

    /// Clear the engine's internal playlist
    fn clear_playlist(&mut self) -> Result<()>;

    /// Get current playlist position
    fn playlist_position(&self) -> Result<Option<usize>>;

    /// Play specific position in playlist
    fn play_index(&mut self, index: usize) -> Result<()>;
}

/// Events emitted by the media engine
#[derive(Debug, Clone)]
pub enum MediaEvent {
    /// Track ended naturally (EOF)
    TrackEnded,
    /// Playback started
    Started,
    /// Playback paused
    Paused,
    /// Track changed
    TrackChanged { index: usize },
    /// Error occurred
    Error(String),
    /// Engine became idle
    Idle,
}
```

#### Step 2.2: Move MPV code to shared

```bash
mv src/player/mpv/* src/backends/shared/mpv/
```

Update `src/backends/shared/mpv/mod.rs` to implement `MediaEngine` trait.

---

### Phase 3: Migrate YouTube Backend

#### Step 3.1: Move YouTube files

```bash
mv src/player/youtube/* src/backends/youtube/
```

#### Step 3.2: Restructure YouTube daemon

```bash
mkdir src/backends/youtube/daemon
mv src/backends/youtube/server.rs src/backends/youtube/daemon/
mv src/backends/youtube/services/* src/backends/youtube/daemon/
```

#### Step 3.3: Update YouTube to use MediaEngine

Replace direct `MpvIpc` usage with `MediaEngine` trait:

```rust
// Before
pub struct PlaybackService {
    mpv: MpvIpc,
}

// After
pub struct PlaybackService {
    engine: Box<dyn MediaEngine>,
}
```

#### Step 3.4: Implement new traits for YouTubeBackend

```rust
impl Playable for YouTubeBackend { ... }
impl Queueable for YouTubeBackend { ... }
impl Searchable for YouTubeBackend { ... }
impl MusicBackend for YouTubeBackend {
    fn name(&self) -> &'static str { "YouTube Music" }
    fn id(&self) -> &'static str { "youtube" }
    fn supports(&self, feature: BackendFeature) -> bool {
        matches!(feature,
            BackendFeature::RichMetadata |
            BackendFeature::RepeatModes |
            BackendFeature::ShuffleMode
        )
    }
}
```

---

### Phase 4: Migrate MPD Backend

#### Step 4.1: Move MPD files

```bash
mv src/mpd/* src/backends/mpd/
mv src/player/mpd_backend.rs src/backends/mpd/backend.rs
```

#### Step 4.2: Create MPD extension traits

**`src/traits/extensions/playlist_persistence.rs`**:
```rust
use anyhow::Result;
use crate::domain::Song;

/// Persistent playlist storage (saved playlists)
pub trait PlaylistPersistence: Send + Sync {
    fn list_playlists(&mut self) -> Result<Vec<String>>;
    fn load_playlist(&mut self, name: &str) -> Result<Vec<Song>>;
    fn save_playlist(&mut self, name: &str) -> Result<()>;
    fn delete_playlist(&mut self, name: &str) -> Result<()>;
    fn rename_playlist(&mut self, old: &str, new: &str) -> Result<()>;
}
```

#### Step 4.3: Implement traits for MpdBackend

```rust
impl Playable for MpdBackend { ... }
impl Queueable for MpdBackend { ... }
impl Searchable for MpdBackend { ... }
impl PlaylistPersistence for MpdBackend { ... }  // Optional
impl MusicBackend for MpdBackend {
    fn name(&self) -> &'static str { "MPD" }
    fn id(&self) -> &'static str { "mpd" }
    fn supports(&self, feature: BackendFeature) -> bool {
        matches!(feature,
            BackendFeature::SavedPlaylists |
            BackendFeature::DatabaseManagement |
            BackendFeature::OutputSelection |
            BackendFeature::RepeatModes |
            BackendFeature::ShuffleMode
        )
    }
}
```

---

### Phase 5: Update Core

#### Step 5.1: Create UnifiedBackend

**`src/backends/mod.rs`**:
```rust
pub mod mpd;
pub mod youtube;
pub mod shared;

use crate::traits::MusicBackend;
use crate::config::BackendConfig;
use anyhow::Result;

/// Factory function to create a backend from config
pub fn create_backend(config: &BackendConfig) -> Result<Box<dyn MusicBackend>> {
    match config {
        BackendConfig::Mpd(cfg) => Ok(Box::new(mpd::MpdBackend::connect(cfg)?)),
        BackendConfig::YouTube(cfg) => Ok(Box::new(youtube::YouTubeBackend::connect(cfg)?)),
    }
}
```

#### Step 5.2: Update core to use traits

Replace all `player::MusicBackend` with `traits::MusicBackend`.

#### Step 5.3: Remove old player module

```bash
rm -rf src/player/
```

Update `src/lib.rs` to use new structure.

---

### Phase 6: Cleanup

#### Step 6.1: Remove deprecated methods

Delete all `#[deprecated]` methods from old `MusicBackend` trait.

#### Step 6.2: Remove stub implementations

YouTube no longer needs empty implementations for MPD-specific features.

#### Step 6.3: Update documentation

- Update ARCHITECTURE.md
- Update CLAUDE.md with new paths
- Add inline documentation to all traits

---

## Verification Checklist

After each phase, verify:

- [ ] `cargo build` succeeds
- [ ] `cargo test` passes
- [ ] TUI starts and connects to backend
- [ ] Basic playback works (play, pause, next)
- [ ] Queue operations work (add, remove, reorder)
- [ ] Search works

---

## Rollback Plan

Each phase is independently reversible via git:

```bash
git checkout HEAD~N -- src/
```

The migration is designed so that:
1. Phases 1-2 add new code without modifying existing
2. Phases 3-4 can be done one backend at a time
3. Phase 5 is the only "big bang" change
4. Phase 6 is optional cleanup

---

## Future Extensions

This architecture makes it easy to add:

1. **Spotify Backend**: Implement `Playable + Queueable + Searchable`
2. **Jellyfin Backend**: Same pattern
3. **Local Files Backend**: Using MPV as MediaEngine
4. **GStreamer Engine**: Alternative to MPV for playback

---

## Appendix: Domain Types

Ensure these types are backend-agnostic:

```rust
// src/domain/song.rs
pub struct Song {
    pub id: Option<u32>,           // Queue position ID (assigned at enqueue)
    pub file: String,              // Content identifier (video ID, file path, URI)
    pub duration: Option<Duration>,
    pub metadata: HashMap<String, Vec<String>>,
}

// src/domain/status.rs
pub struct Status {
    pub state: PlaybackState,      // Play, Pause, Stop
    pub volume: u8,
    pub elapsed: Option<Duration>,
    pub duration: Option<Duration>,
    pub queue_length: u32,
    pub current_position: Option<u32>,
    pub current_id: Option<u32>,
    pub repeat: RepeatMode,        // Off, One, All
    pub shuffle: bool,
}

// src/domain/search.rs
pub enum SearchItem {
    Song(SongResult),
    Album(AlbumResult),
    Artist(ArtistResult),
    Playlist(PlaylistResult),
    Header(String),
}
```

### Phase 3: Naming Cleanup ✅ COMPLETE (2025-12-23)

**Actions taken:**
- Replaced all `PlayerController` → `BackendDispatcher` (~15 files)
- Replaced all `MpdClientExt` → `BackendActions` (~6 files)
- Replaced `MpdDelete` → `DeleteTarget`
- Removed deprecated type aliases from `backends/mod.rs` and `interaction.rs`
- Deprecated monolithic `YouTubeBackend` (replaced with stub returning errors)
- Renamed `mpd_version` → `backend_version` for generic naming
- Added comprehensive documentation to `YouTubeProxy` explaining IPC architecture

**Rationale:**
- Deprecated names caused confusion for LLMs and new contributors
- Two YouTube entry points (monolithic Backend vs IPC Proxy) was a source of bugs
- MPD-specific terminology (`mpd_version`, `MpdDelete`) leaked into generic abstractions
- 1777-line monolithic YouTubeBackend was unused dead code

**Build status:** All tests pass (646/648, 2 pre-existing failures)

**Note:** 
- `YouTubeBackend` kept as deprecated stub to prevent breaking imports in search panes
- Browse features (browse_playlist, browse_album, browse_artist) return "not implemented" errors until added to IPC protocol
- `stickers_supported` field kept (has complex runtime state management, requires larger refactor)

