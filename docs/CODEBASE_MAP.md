# Codebase Map

## Quick Navigation

### I want to...

**...add a new search filter**
→ `rmpc/src/player/youtube_backend.rs` (search method)

**...change search UI**
→ `rmpc/src/ui/panes/search/mod.rs`

**...fix navigation to artist/album**
→ `rmpc/src/ui/mod.rs` (UiAppEvent handlers)

**...modify how search results are parsed**
→ `rmpc/src/player/youtube_backend.rs` (search method, lines 950-1135)

**...update authentication**
→ `rmpc/src/player/youtube_backend.rs` (load_api method, lines 865-895)

**...change MPV behavior**
→ `rmpc/src/player/youtube_backend.rs` (constructor, MPV spawn args)

**...understand YouTube API responses**
→ `youtui/ytmapi-rs/src/parse/search.rs`

**...add tests**
→ `rmpc/tests/youtube_search_integration_tests.rs` or inline in source files

## Directory Tree (Key Files Only)

```
yrmpc/
├── config/
│   └── rmpc.ron                    # Runtime config (backend, auth_file)
├── docs/                           # THIS documentation
│   ├── PROJECT_OVERVIEW.md
│   ├── ARCHITECTURE.md
│   ├── CODEBASE_MAP.md
│   ├── DEVELOPMENT.md
│   ├── YOUTUBE_API.md
│   └── COMMON_TASKS.md
└── rmpc/                           # SUBMODULE
    ├── src/
    │   ├── main.rs                 # Entry point
    │   ├── player/
    │   │   ├── youtube_backend.rs  # ⭐ YouTube integration (1200 lines)
    │   │   ├── client.rs           # Backend abstraction
    │   │   └── mod.rs
    │   ├── ui/
    │   │   ├── mod.rs              # ⭐ UI event routing, navigation handlers
    │   │   ├── panes/
    │   │   │   ├── search/
    │   │   │   │   └── mod.rs      # ⭐ Search UI, result handling
    │   │   │   ├── artists/mod.rs  # Artist browsing pane
    │   │   │   ├── albums/mod.rs   # Album browsing pane
    │   │   │   └── playlists/mod.rs# Playlist browsing pane
    │   │   └── browser.rs          # Generic browser trait
    │   └── config/
    │       └── mod.rs              # Config parsing
    ├── tests/
    │   └── youtube_search_integration_tests.rs  # ⭐ 23 tests
    ├── TESTING.md                  # Test suite documentation
    └── youtui/                     # NESTED SUBMODULE
        └── ytmapi-rs/
            ├── src/
            │   ├── auth/
            │   │   └── browser.rs  # Cookie → BrowserToken
            │   ├── query/
            │   │   ├── search.rs   # Search query builder
            │   │   └── browse.rs   # Browse (artist/album) queries
            │   ├── parse/
            │   │   ├── search.rs   # ⭐ Parse search JSON (1385 lines)
            │   │   └── browse.rs   # Parse browse responses
            │   └── nav_consts.rs   # JSON path constants
```

## Core Files Explained

### `rmpc/src/player/youtube_backend.rs` (1200+ lines)
**Most important file for YouTube functionality**

Sections:
- Lines 1-100: Imports, struct definition
- Lines 865-895: `load_api()` - Cookie parsing, authentication
- Lines 950-1135: `search()` - ⭐ **Main search logic**
  - Parses artists, albums, songs, videos, playlists, podcasts
  - Maps to `Song` objects with metadata
  - ID prefixing (artist:, album:, playlist:, podcast:)
- Lines 1213+: Unit tests (youtube_backend_tests, search_navigation_tests)

### `rmpc/src/ui/panes/search/mod.rs` (800 lines)
**Search UI and result handling**

Key methods:
- `handle_result_phase_action()` - User presses Enter on search result
  - Detects type from metadata ("artist", "album", "song", etc.)
  - Sends navigation events (OpenAlbum, OpenArtist, OpenPlaylist)
  - Or enqueues song/video for playback

### `rmpc/src/ui/mod.rs` (1249 lines)
**UI event routing and navigation**

Key sections:
- Line 724-917: `on_ui_app_event()` - Handles navigation events
  - `UiAppEvent::OpenAlbum` → Switch to Albums tab, load album
  - `UiAppEvent::OpenArtist` → Switch to Artists tab, load artist
  - `UiAppEvent::OpenPlaylist` → Switch to Playlists tab, load playlist

### `youtui/ytmapi-rs/src/parse/search.rs` (1385 lines)
**YouTube API response parsing**

Important structs:
- `SearchResults` - Top-level container
- `SearchResultArtist` - Has `browse_id: ArtistChannelID`
- `SearchResultAlbum` - Has `album_id: AlbumID`
- `SearchResultSong` - Has `video_id: VideoID`
- `SearchResultVideo` - Enum (Video | VideoEpisode)
- `BasicSearchResultCommunityPlaylist` - Enum (Playlist | Podcast)

## Data Structures

### Song (rmpc)
```rust
struct Song {
    id: Option<u64>,
    file: String,           // ID or prefixed ID (artist:, album:, etc.)
    duration: Option<u64>,
    metadata: HashMap<String, Vec<String>>,
    last_modified: Option<DateTime<Utc>>,
    added: Option<DateTime<Utc>>,
}
```

**Critical**: `metadata["type"]` determines navigation vs playback
- `"artist"` → Navigate to artist page
- `"album"` → Navigate to album page  
- `"song"` → Play immediately
- `"video"` → Play immediately
- `"playlist"` → Navigate to playlist page
- `"podcast"` → Navigate to podcast page

### ID Prefixing Scheme
```
artist:UC3muIvzjhubNpJ4Pn_0kCQw    # Artist browse ID
album:MPREb_1234567890             # Album ID
playlist:RDCLAK5uy_123             # Playlist ID
podcast:MPSP123                    # Podcast ID
dQw4w9WgXcQ                        # Song/video (no prefix)
```

## Navigation Flow (Code Path)

```
User presses Enter on search result
  ↓
SearchPane::handle_result_phase_action()
  ↓
Check metadata["type"]
  ↓
If artist/album/playlist:
  Send UiAppEvent::Open{Type}(id)
    ↓
  Ui::on_ui_app_event()
    ↓
  Find appropriate tab
    ↓
  Switch to tab
    ↓
  Call pane.fetch_data(id)
    ↓
  YouTubeBackend::lsinfo(id)
    ↓
  ytmapi-rs browse query
    ↓
  Parse response
    ↓
  Display in pane

If song/video:
  Enqueue for playback
    ↓
  YouTubeBackend::add_to_queue()
    ↓
  rusty_ytdl extract URL
    ↓
  MPV play
```

## Configuration Files

### `config/rmpc.ron`
```ron
(
    backend: youtube,
    youtube: (
        auth_file: Some("~/.config/rmpc/cookie.txt"),
    ),
    theme: Some("default"),
)
```

### `~/.config/rmpc/cookie.txt` (Netscape format)
```
.youtube.com	TRUE	/	TRUE	...	SAPISID	...
.youtube.com	TRUE	/	TRUE	...	__Secure-3PAPISID	...
```

## Test Files

### `rmpc/tests/youtube_search_integration_tests.rs`
- 9 integration tests
- ID format validation
- Duration parsing
- Enum variant handling

### Inline tests (youtube_backend.rs)
- 14 unit tests
- Metadata structure
- Navigation event detection
