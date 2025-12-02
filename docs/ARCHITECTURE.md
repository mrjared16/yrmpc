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

**Purpose**: Project root, configuration, authentication files

### Submodule: rmpc
```
rmpc/
├── src/
│   ├── player/
│   │   ├── youtube_backend.rs    # YouTube Music implementation
│   │   └── client.rs              # Backend abstraction
│   ├── ui/
│   │   ├── panes/
│   │   │   ├── search/            # Search UI
│   │   │   ├── artists/           # Artist browsing
│   │   │   ├── albums/            # Album browsing
│   │   │   └── playlists/         # Playlist browsing
│   │   └── mod.rs                 # UI event handlers
│   └── main.rs
├── tests/
│   └── youtube_search_integration_tests.rs
└── youtui/         # Nested submodule → ytmapi-rs
```

**Purpose**: Main application, UI, YouTube backend

### Nested Submodule: youtui (ytmapi-rs)
```
youtui/ytmapi-rs/
├── src/
│   ├── auth/       # YouTube authentication
│   ├── query/      # Search, browse queries
│   └── parse/      # JSON response parsing
```

**Purpose**: YouTube Music API client library

## Why This Structure?

### Submodule: rmpc
- **Fork of upstream**: Original `rmpc` is MPD-only
- **Custom changes**: Added YouTube backend, modified UI
- **Independent updates**: Can pull upstream MPD fixes without conflicts
- **Separation of concerns**: Application vs project config

### Nested Submodule: youtui
- **Shared library**: Used by multiple projects
- **API encapsulation**: Hides YouTube Music internals
- **Version pinning**: Project controls which API version to use
- **Upstream tracking**: Can update library independently

## Data Flow

```
User Input → TUI (ratatui)
           → UI Event Handler
           → Backend (YouTubeBackend)
           → ytmapi-rs (API calls)
           → YouTube Music API
           → Parse response
           → MPV (playback) or UI (navigation)
```

### Search Flow Example
```
1. User types "/son tung mtp" <Enter>
2. SearchPane → UiAppEvent::Search
3. YouTubeBackend::search()
4. ytmapi-rs::SearchQuery → YouTube API
5. Parse SearchResults (artists, albums, songs)
6. Map to Song objects with metadata
7. Display in SearchPane
8. User selects → Navigate or Play
```

## Key Components

### Backend Abstraction (`player/client.rs`)
```rust
enum Client {
    Mpd(MpdClient),
    Mpv(MpvClient),
    YouTube(YouTubeBackend),
}
```
Unified interface for different music sources.

### YouTube Backend (`player/youtube_backend.rs`)
- **Authentication**: Cookie-based via `BrowserToken`
- **Search**: General search returning all content types
- **Browse**: Artist/album/playlist detail pages
- **Playback**: MPV spawning and control

### UI Event System (`ui/mod.rs`)
```rust
enum UiAppEvent {
    OpenAlbum(String),   // Navigate to album via ID
    OpenArtist(String),  // Navigate to artist via ID
    OpenPlaylist(String),// Navigate to playlist via ID
}
```
Cross-pane navigation system.

## Authentication Architecture

### Cookie Flow
```
1. User exports cookies from browser (EditThisCookie extension)
2. Saves to ~/.config/rmpc/cookie.txt (Netscape format)
3. rmpc parses cookies
4. Creates BrowserToken with SAPISID + SAPISIDHASH
5. ytmapi-rs sends cookies with each API request
```

### Why Cookies (Not OAuth)?
- **No token expiry**: Cookies last months
- **No refresh logic**: Simpler implementation
- **Browser parity**: Same auth as web client
- **Headless friendly**: No interactive login needed

## Build System

### Cargo Workspace (rmpc)
```toml
[dependencies]
ytmapi-rs = { path = "../youtui/ytmapi-rs" }
rusty_ytdl = "..."  # YouTube video URL extraction
ratatui = "..."     # TUI framework
```

### Feature Flags
- `youtube` - Enable YouTube backend (always on for this fork)

## Testing Strategy

### Unit Tests
- In-file `#[cfg(test)]` modules
- Test ID formats, metadata parsing, enum handling

### Integration Tests
- `tests/youtube_search_integration_tests.rs`
- Test search result structure, type detection

### Manual Testing
- tmux session with rmpc
- Search, navigate, play workflow
