# Codebase Map

> **Updated**: 2026-01-02 — Paths reflect `player/` → `backends/` refactor

## Quick Navigation

### I want to...

**...modify search result types**
→ `rmpc/src/domain/search/` (SearchItem enum)
→ `rmpc/src/domain/media_item.rs` (MediaItem - unified type)

**...change search API**
→ `rmpc/src/backends/youtube/api.rs` (search methods)

**...change search UI**
→ `rmpc/src/ui/panes/search_pane_v2.rs` (SearchPaneV2)
→ `rmpc/src/ui/panes/search/mod.rs` (legacy)

**...change queue UI**
→ `rmpc/src/ui/panes/queue_pane_v2.rs` (QueuePaneV2)
→ `rmpc/src/ui/modals/queue_modal.rs` (QueueModal)

**...create reusable list components**
→ `rmpc/src/ui/widgets/selectable_list.rs` (generic list)
→ `rmpc/src/ui/widgets/item_list.rs` (rich item rendering)

**...fix IPC protocol**
→ `rmpc/src/backends/youtube/protocol.rs`

**...modify daemon/server**
→ `rmpc/src/backends/youtube/server/mod.rs`
→ `rmpc/src/backends/youtube/server/handlers/` (search, queue, playback)

**...modify client**
→ `rmpc/src/backends/youtube/client.rs` (YouTubeProxy)

**...work with backend API traits**
→ `rmpc/src/backends/api/` (Playback, Queue, Discovery traits in separate files)

**...update config**
→ `rmpc/src/config/search.rs`

## Directory Tree

```
yrmpc/
├── config/rmpc.ron               # Runtime config
├── docs/                         # Documentation
├── rmpc/                         # Main application
│   ├── src/
│   │   ├── backends/             # ⭐ Backend implementations
│   │   │   ├── api/              #   Playback, Queue, Discovery traits
│   │   │   ├── traits.rs         #   MusicBackend trait (deprecated)
│   │   │   ├── mpd/              #   MPD backend
│   │   │   └── youtube/          #   YouTube backend
│   │   │       ├── api.rs        #     YouTube API wrapper
│   │   │       ├── client.rs     #     YouTubeProxy (TUI-side)
│   │   │       ├── protocol.rs   #     IPC protocol
│   │   │       ├── server/       #     Daemon server + handlers
│   │   │       ├── services/     #     Api, Playback, Queue services
│   │   │       ├── extractor/    #     Stream URL extraction (ytx, yt-dlp)
│   │   │       └── mpv/          #     MPV IPC wrapper
│   │   ├── domain/
│   │   │   ├── media_item.rs     # ⭐ MediaItem (unified type)
│   │   │   ├── content.rs        #   ContentDetails, Section types
│   │   │   └── search/           #   Search types (legacy)
│   │   ├── ui/
│   │   │   ├── panes/
│   │   │   │   ├── navigator.rs  # ⭐ Central UI controller
│   │   │   │   ├── search_pane_v2.rs
│   │   │   │   ├── queue_pane_v2.rs
│   │   │   │   └── search/       #   Legacy search pane
│   │   │   └── widgets/
│   │   │       ├── content_view.rs
│   │   │       ├── selectable_list.rs
│   │   │       └── item_list.rs
│   │   └── config/
│   │       └── search.rs         #   Search config
│   └── tests/                    # Rust integration tests
└── AGENTS.md                     # LLM entry point
```

## Key Types

### MediaItem (domain/media_item.rs) — NEW, Preferred
```rust
pub enum MediaItem {
    Track(Track),
    Artist(Artist),
    Album(Album),
    Playlist(Playlist),
}
```

### SearchItem (domain/search/mod.rs) — Legacy
```rust
pub enum SearchItem {
    Playable(PlayableItem),   // Song, Video → queues directly
    Browsable(BrowsableItem), // Artist, Album, Playlist → detail view
    Header(String),           // Section separator
}
```

### ServerResponse (backends/youtube/protocol.rs)
```rust
pub enum ServerResponse {
    Ok,
    Error(String),
    SearchResults(Vec<MediaItem>),  // Now uses MediaItem directly
    Suggestions(Vec<String>),
    PlaylistDetails(PlaylistDetailsData),
    AlbumDetails(AlbumDetailsData),
    ArtistDetails(ArtistDetailsData),
    // ... other variants
}
```

## Data Flow (Updated)

```
User types search query
  ↓
UI → ServerCommand::Search { query }
  ↓
YouTubeServer → ApiService.search()
  ↓
ytmapi-rs → YouTube Music API
  ↓
Parse → Vec<MediaItem>        ← Direct, no intermediate types
  ↓
IPC → ServerResponse::SearchResults(Vec<MediaItem>)
  ↓
YouTubeProxy → returns Vec<MediaItem>
  ↓
UI → Navigator → SearchPaneV2 → display
```

## Backend API Traits

```rust
// rmpc/src/backends/api/  (directory with separate trait files)
// playback.rs, queue.rs, discovery.rs, etc.

pub trait Playback {
    fn play(&mut self) -> Result<()>;
    fn pause(&mut self) -> Result<()>;
    fn next(&mut self) -> Result<()>;
    fn previous(&mut self) -> Result<()>;
    // ...
}

pub trait Queue {
    fn add(&mut self, item: &MediaItem) -> Result<()>;
    fn clear(&mut self) -> Result<()>;
    fn get_queue(&self) -> Result<Vec<MediaItem>>;
    // ...
}

pub trait Discovery {
    fn search(&mut self, query: &str) -> Result<Vec<MediaItem>>;
    fn browse(&mut self, uri: &str) -> Result<ContentDetails>;
    // ...
}
```

## Configuration

### config/rmpc.ron
```ron
legacy_panes: (
    enabled: false,  // Use Navigator architecture
),
```

### Cookie file (~/.config/rmpc/cookie.txt)
Netscape format, extracted via yt-dlp.
