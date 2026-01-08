# Capability System

> **Purpose**: Enable plugin extensibility without forking
> **Principle**: "Ask CAN you do X, not ARE you backend Y"

## Overview

yrmpc uses a capability-based architecture where the TUI queries backend capabilities at runtime rather than checking backend types. This allows contributors to implement new backends (Spotify, Tidal, Last.fm, etc.) by implementing only the capabilities their service supports.

```rust
// TUI checks capability, not backend type
if backend.supports(Capability::Playlists) {
    show_playlist_menu();
}
```

## Three-Layer Architecture

### Layer 1: Required (All backends MUST implement)

| Capability | Trait | Purpose |
|------------|-------|---------|
| **Playback** | `api::Playback` | Play, pause, stop, seek |
| **Queue** | `api::Queue` | Add, remove, reorder, clear queue |
| **Discovery** | `api::Discovery` | Search, browse, recommendations, details |
| **Volume** | `api::Volume` | Get/set volume level |

These form the `Backend` trait - every backend implements all four.

### Layer 2: Optional Common (Backends MAY implement)

| Capability | Trait | Purpose | UI Fallback |
|------------|-------|---------|-------------|
| **Playlists** | `api::optional::Playlists` | CRUD playlist operations | Hide playlist menu |
| **PlaylistCreate** | (flag) | Can create new playlists | Hide "New Playlist" |
| **PlaylistEdit** | (flag) | Can modify playlists | Hide edit options |
| **Lyrics** | `api::optional::Lyrics` | Fetch lyrics for track | Hide lyrics pane |
| **Radio** | `api::optional::Radio` | Station/endless mode | Hide radio option |
| **UserPreferences** | `api::optional::UserPreferences` | Like/dislike, history | Hide like button |
| **Sync** | `api::optional::Sync` | 2-way cloud sync | Local-only mode |

**IMPORTANT**: Sync is **OPTIONAL**. A backend without sync works fine - the TUI operates in local-only mode. MPD has no sync. Some users disable sync intentionally.

### Layer 3: Backend-Specific (Only one backend has)

These are NOT portable across backends:
- YouTube: OAuth flow, SAPISID auth, TopResult parsing quirks
- MPD: Protocol commands, local file paths, database updates
- Spotify: (future) OAuth PKCE, Connect API
- Tidal: (future) FLAC streaming, MQA handling

Backend-specific features live in `backends/<name>/` code and docs.

## Capability Matrix

| Capability | YouTube | MPD | Required |
|------------|---------|-----|----------|
| Playback | ✅ | ✅ | **Yes** |
| Queue | ✅ | ✅ | **Yes** |
| Discovery | ✅ | ✅ | **Yes** |
| Volume | ✅ | ✅ | **Yes** |
| Playlists | ✅ | ✅ | No |
| PlaylistCreate | ✅ | ✅ | No |
| PlaylistEdit | ✅ | ✅ | No |
| Lyrics | 🔶 Planned | ❌ | No |
| Radio | 🔶 Planned | ❌ | No |
| UserPreferences | 🔶 Planned | ❌ | No |
| Sync | ✅ (optional) | ❌ N/A | No |

## Declaring Capabilities

Backends declare capabilities via the `capabilities()` method:

```rust
impl Backend for MyBackend {
    fn capabilities(&self) -> &'static [Capability] {
        &[
            Capability::Playback,
            Capability::Queue,
            Capability::Discovery,
            Capability::Volume,
            Capability::Playlists,
            // Only include what you actually support
        ]
    }
    
    fn supports(&self, cap: Capability) -> bool {
        self.capabilities().contains(&cap)
    }
}
```

## Individual Capability Contracts

- [Playback](./playback.md) - Play/pause/seek semantics
- [Queue](./queue.md) - Queue manipulation semantics
- [Discovery](./discovery.md) - Search/browse semantics
- [Playlists](./playlists.md) - Playlist CRUD semantics
- [Sync](./sync.md) - Optional 2-way sync semantics

## Cross-References

- [Contributor Guide](../backends/reference/README.md) - How to implement a new backend
- [YouTube Backend](../backends/youtube/README.md) - Reference implementation
- [Architecture](../ARCHITECTURE.md) - System overview
