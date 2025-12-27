# Backend Architecture Refactor Progress

**Last Updated**: 2025-12-23
**Status**: Phase 1 Naming Refactor In Progress (BUILD BROKEN)

## Current Architecture

All backends are now unified under `src/backends/`:

```
src/backends/
├── mod.rs                   # Re-exports with onboarding documentation
├── traits.rs                # MusicBackend + QueueOperations traits
├── client.rs                # BackendDispatcher (was PlayerController) - PARTIAL
├── interaction.rs           # BackendActions trait (was MpdClientExt) - COMPLETE
├── messaging.rs             # Request/response types
├── mpd/
│   ├── mod.rs               # MpdBackend
│   ├── backend.rs           # Implementation
│   └── protocol/            # MPD protocol library
└── youtube/
    ├── mod.rs
    ├── backend.rs           # YouTubeBackend
    ├── client.rs            # YouTubeProxy (was YouTubeClient)
    ├── server/              # Daemon architecture
    │   ├── mod.rs
    │   ├── orchestrator.rs
    │   └── handlers/
    └── ...
```

## What's Done (This Session - 2025-12-23)

### Phase 1 Naming Refactor

- [x] `MpdClientExt` → `BackendActions` (with deprecated alias)
- [x] Updated `backends/mod.rs` with comprehensive onboarding documentation
- [x] Updated `backends/interaction.rs` with trait documentation
- [ ] `PlayerController` → `BackendDispatcher` (PARTIALLY COMPLETE - has remaining reference)

### Previous Sessions

- [x] Phase 1: File reorganization (2025-12-22)
- [x] All backends under src/backends/
- [x] MPD protocol separated into protocol/ subdirectory
- [x] `song.file` → `song.uri` rename (with serde alias)
- [x] YouTube server split into handlers + orchestrator

## Current Issue (BUILD BROKEN)

**Error**: Line 142 in `backends/client.rs` still references `PlayerController::YouTube`

**Fix Command**:
```bash
cd <PROJECT_ROOT>/rmpc
sed -i 's/PlayerController/BackendDispatcher/g' src/backends/client.rs
cargo build
```

## Naming Changes Summary

| Old Name | New Name | Status | File |
|----------|----------|--------|------|
| `MpdClientExt` | `BackendActions` | ✅ Complete | `interaction.rs` |
| `PlayerController` | `BackendDispatcher` | 🔄 Partial | `client.rs` |
| `YouTubeClient` | `YouTubeProxy` | ✅ Complete | `youtube/client.rs` |
| `song.file` | `song.uri` | ✅ Complete | `domain/song.rs` |

## Deprecated Aliases Added

```rust
// In backends/interaction.rs (line 785-789)
#[deprecated(since = "0.11.0", note = "Use BackendActions instead")]
pub use BackendActions as MpdClientExt;

// In backends/mod.rs (line 80-82)
#[deprecated(since = "0.11.0", note = "Use BackendActions instead")]
pub use interaction::MpdClientExt;

// TODO: Add PlayerController alias after completing rename
```

## What's Pending

### Immediate (Fix Build)
- [ ] Fix remaining `PlayerController::YouTube` reference in `client.rs:142`
- [ ] Add `PlayerController` deprecated alias in `mod.rs`

### Phase 1 Remaining
- [ ] Update all `PlayerController` usages across codebase
- [ ] Add deprecation to `player/mod.rs`
- [ ] File renames (deferred): `interaction.rs` → `actions.rs`, `messaging.rs` → `request_types.rs`

### Future Phases
- [ ] Phase 2: Trait split (Core + Extensions: PlaylistOps, LibraryBrowse)
- [ ] Phase 3: Daemon mode (`rmpc --daemon`)

## Import Patterns (Updated)

```rust
// NEW: Use BackendActions for high-level operations
use crate::backends::BackendActions;

// NEW: BackendDispatcher is the main entry point (once rename complete)
use crate::backends::BackendDispatcher;

// Traits
use crate::backends::{MusicBackend, QueueOperations};

// Backends
use crate::backends::{MpdBackend, YouTubeBackend};

// YouTube specifics
use crate::backends::youtube::{YouTubeProxy};

// DEPRECATED but still works:
use crate::backends::MpdClientExt;  // Use BackendActions instead
use crate::backends::PlayerController;  // Use BackendDispatcher instead
```

## Key Design Decisions

1. **Aliasing Strategy**: Use deprecated aliases, not clean breaks (for upstream merge compatibility)
2. **No Config Changes**: All renames are internal only
3. **Phased Approach**: Working build at each step
4. **File Renames Deferred**: Module aliasing doesn't work well, so keep filenames for now
