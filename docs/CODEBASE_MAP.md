# Codebase Map

## Quick Navigation

### I want to...

**...modify search result types**
→ `rmpc/src/domain/search/` (SearchItem enum)

**...change search API**
→ `rmpc/src/player/youtube/api.rs` (search_items method)

**...change search UI**
→ `rmpc/src/ui/panes/search/mod.rs`

**...fix IPC protocol**
→ `rmpc/src/player/youtube/protocol.rs`

**...modify daemon/server**
→ `rmpc/src/player/youtube/server.rs`

**...modify client**
→ `rmpc/src/player/youtube/client.rs`

**...update config**
→ `rmpc/src/config/search.rs`

**...understand YouTube API responses**
→ `youtui/ytmapi-rs/src/parse/search.rs`

## Directory Tree

```
yrmpc/
├── config/rmpc.ron               # Runtime config
├── docs/                         # Documentation
├── rmpc/                         # SUBMODULE
│   ├── src/
│   │   ├── domain/
│   │   │   ├── mod.rs
│   │   │   └── search/           # ⭐ Type-safe search types
│   │   │       ├── mod.rs        #   SearchItem, PlayableItem, BrowsableItem
│   │   │       ├── items.rs      #   SongItem, AlbumItem, etc.
│   │   │       ├── convert.rs    #   ytmapi-rs conversions
│   │   │       └── display.rs    #   Displayable trait
│   │   ├── player/youtube/       # ⭐ YouTube backend
│   │   │   ├── api.rs            #   API calls (search_items, browse)
│   │   │   ├── server.rs         #   Daemon server
│   │   │   ├── client.rs         #   Client (connects to daemon)
│   │   │   └── protocol.rs       #   IPC protocol (SearchItemData)
│   │   ├── ui/
│   │   │   ├── panes/search/     #   Search UI
│   │   │   └── dirstack/         #   List display (DirStackItem)
│   │   └── config/
│   │       └── search.rs         #   Search config (sections)
│   └── tests/
└── youtui/                       # ytmapi-rs (local patches)
    └── ytmapi-rs/src/parse/
        └── search.rs             # TopResult parsing patches
```

## Key Types

### SearchItem (domain/search/mod.rs)
```rust
pub enum SearchItem {
    Playable(PlayableItem),   // Song, Video → queues directly
    Browsable(BrowsableItem), // Artist, Album, Playlist → detail view
    Header(String),           // Section separator
}
```

### SearchItemData (protocol.rs)
```rust
pub enum SearchItemData {
    Song(PlayableData),
    Video(PlayableData),
    Artist(BrowsableData),
    Album(BrowsableData),
    Playlist(BrowsableData),
    Header(String),
}
```

### ServerResponse (protocol.rs)
```rust
pub enum ServerResponse {
    SearchResults(Vec<SearchItemData>),
    Suggestions(Vec<String>),
    // ... other variants
}
```

## Data Flow

```
User types search query
  ↓
UI → ServerCommand::Search { query }
  ↓
Server → api.search_items(&query)
  ↓
ytmapi-rs → YouTube Music API
  ↓
Parse → Vec<SearchItem>
  ↓
Convert → Vec<SearchItemData>
  ↓
IPC → ServerResponse::SearchResults
  ↓
Client → convert to Vec<Song>
  ↓
UI → display with headers
```

## Configuration

### config/rmpc.ron
```ron
search: (
    sections: ["top_results", "songs", "artists", "albums", "playlists"],
)
```

### Cookie file (~/.config/rmpc/cookie.txt)
Netscape format, extracted via yt-dlp.
