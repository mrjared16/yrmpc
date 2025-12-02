# YouTube Music API Guide

## API Overview
YouTube Music uses undocumented internal APIs. The `ytmapi-rs` library reverse-engineers these endpoints.

## Authentication

### How It Works
1. Browser sends cookies with each request
2. Server validates `SAPISID` cookie
3. Client generates `SAPISIDHASH` = `SHA1(timestamp + " " + SAPISID + " " + origin)`
4. Sends as `Authorization: SAPISIDHASH {hash}` header

### Why Cookies?
- **No OAuth flow**: Simpler, headless-friendly
- **Long-lived**: Cookies last months (vs tokens that expire)
- **Browser parity**: Same auth mechanism as web client

### Cookie Export

#### Using yt-dlp (Recommended)
yt-dlp can extract cookies directly from your browser:

```bash
# For Brave browser
yt-dlp --cookies-from-browser brave --cookies ~/.config/rmpc/cookie.txt

# For other browsers (chrome, chromium, firefox, edge, opera, vivaldi, whale)
yt-dlp --cookies-from-browser <browser> --cookies ~/.config/rmpc/cookie.txt
```

This creates a Netscape-format cookie file that works for both:
- **ytmusicapi** (search, browse APIs)
- **yt-dlp** (stream URL extraction with Premium quality)

#### Refreshing Cookies
Cookies expire after several months. When playback fails with auth errors, refresh:

```bash
yt-dlp --cookies-from-browser brave --cookies ~/.config/rmpc/cookie.txt
```

#### yt-dlp Global Config
For automatic cookie usage, add to `~/.config/yt-dlp/config.txt`:

```
--cookies ~/.config/rmpc/cookie.txt
```

This ensures yt-dlp (used as fallback for stream extraction) always uses your Premium credentials.

#### Manual Export (Alternative)
**From Chrome/Brave (EditThisCookie extension):**
1. Visit music.youtube.com
2. Click extension icon
3. Export → Netscape format
4. Save to `~/.config/rmpc/cookie.txt`

**Required cookies:**
- `SAPISID` (domain: .youtube.com)
- `__Secure-3PAPISID` (domain: .youtube.com)

## Search API

### Endpoint
`POST /youtubei/v1/search`

### Request Structure
```json
{
  "query": "search term",
  "params": ""  // Empty for general search, or filter param
}
```

### Response Structure
```json
{
  "contents": {
    "tabbedSearchResultsRenderer": {
      "tabs": [{
        "tabRenderer": {
          "content": {
            "sectionListRenderer": {
              "contents": [
                {
                  "musicShelfRenderer": {
                    "title": { "runs": [{ "text": "Artists" }] },
                    "contents": [/* SearchResultArtist items */]
                  }
                },
                {
                  "musicShelfRenderer": {
                    "title": { "runs": [{ "text": "Albums" }] },
                    "contents": [/* SearchResultAlbum items */]
                  }
                }
                // ... more sections
              ]
            }
          }
        }
      }]
    }
  }
}
```

### Search Result Types

#### Artist
```rust
struct SearchResultArtist {
    artist: String,              // Name
    subscribers: Option<String>, // "1.2M subscribers"
    browse_id: ArtistChannelID,  // UC... (24 chars)
    thumbnails: Vec<Thumbnail>,
}
```

**Browse ID format:** `UC{22 base64 chars}` (e.g., `UC3muIvzjhubNpJ4Pn_0kCQw`)

#### Album
```rust
struct SearchResultAlbum {
    title: String,
    artist: String,
    year: String,
    explicit: Explicit,
    album_id: AlbumID,     // MPREb_... or OLAK5uy_...
    album_type: AlbumType, // Album | Single | EP
    thumbnails: Vec<Thumbnail>,
}
```

**Album ID format:** 
- `MPREb_{base64}` (YouTube Music album)
- `OLAK5uy_{base64}` (Uploaded album)

#### Song
```rust
struct SearchResultSong {
    title: String,
    artist: String,
    album: Option<String>,
    duration: String,      // "3:45" format
    video_id: VideoID,     // 11 chars (e.g., dQw4w9WgXcQ)
    explicit: Explicit,
    thumbnails: Vec<Thumbnail>,
}
```

**Video ID format:** 11 alphanumeric chars (YouTube video ID)

#### Video (Enum!)
```rust
enum SearchResultVideo {
    Video {
        title: String,
        channel_name: String,
        video_id: VideoID,
        views: Option<String>,
        length: Option<String>,
        thumbnails: Vec<Thumbnail>,
    },
    VideoEpisode {
        title: String,
        channel_name: String,
        episode_id: VideoID,
        date: Option<String>,
        thumbnails: Vec<Thumbnail>,
    },
}
```

**Critical:** Match both variants!

#### Playlist (Enum!)
```rust
enum BasicSearchResultCommunityPlaylist {
    Playlist(SearchResultCommunityPlaylist),
    Podcast(SearchResultPodcast),
}

struct SearchResultCommunityPlaylist {
    title: String,
    author: String,
    playlist_id: PlaylistID,  // RDCLAK... or PL...
    thumbnails: Vec<Thumbnail>,
}

struct SearchResultPodcast {
    title: String,
    publisher: String,        // NOT "author"!
    podcast_id: PodcastID,    // MPSP...
    thumbnails: Vec<Thumbnail>,
}
```

**Critical:** `Podcast` has `publisher`, not `author`!

### Parsing Browse IDs

**JSON path:** `/navigationEndpoint/browseEndpoint/browseId`

**Constant:** `NAVIGATION_BROWSE_ID` (in `ytmapi-rs/src/nav_consts.rs`)

```rust
let browse_id = mrlir.take_value_pointer(NAVIGATION_BROWSE_ID)?;
```

## Browse API

### Artist Page
**Endpoint:** `POST /youtubei/v1/browse`

```json
{
  "browseId": "UC3muIvzjhubNpJ4Pn_0kCQw"
}
```

**Response:** Artist details, top songs, albums, singles

### Album Page
```json
{
  "browseId": "MPREb_1234567890"
}
```

**Response:** Track list with durations, artists

### Playlist Page
```json
{
  "browseId": "RDCLAK5uy_123"
}
```

**Response:** Playlist tracks

## ID Prefixing (rmpc Convention)

### Why Prefix?
Need to distinguish navigable entities (artists, albums) from playable content (songs, videos) in the same `Song` struct.

### Scheme
```rust
// Navigable (has browse page)
file: "artist:UC3muIvzjhubNpJ4Pn_0kCQw"
file: "album:MPREb_1234567890"
file: "playlist:RDCLAK5uy_123"
file: "podcast:MPSP123"

// Playable (direct video ID)
file: "dQw4w9WgXcQ"  // No prefix
```

### Parsing
```rust
if file.starts_with("artist:") {
    let id = file.strip_prefix("artist:").unwrap();
    // Browse artist page with id
} else if file.starts_with("album:") {
    let id = file.strip_prefix("album:").unwrap();
    // Browse album page with id
} else {
    // Play as video
}
```

## Duration Parsing

### Format
YouTube returns durations as strings: `"3:45"` or `"1:23:45"`

### Parsing to Seconds
```rust
let seconds: u64 = duration_str
    .split(':')
    .try_fold(0u64, |acc, part| {
        part.parse::<u64>().map(|v| acc * 60 + v)
    })?;

// "3:45" → 3*60 + 45 = 225 seconds
// "1:23:45" → 1*3600 + 23*60 + 45 = 5025 seconds
```

## Common Gotchas

### 1. Non-Exhaustive Enums
```rust
#[non_exhaustive]
enum SearchResultVideo { ... }
```

**Must include wildcard:**
```rust
match video {
    SearchResultVideo::Video { ... } => { },
    SearchResultVideo::VideoEpisode { ... } => { },
    _ => { }  // Required!
}
```

### 2. Field Name Variations
- Songs: `artist` field
- Podcasts: `publisher` field (NOT `author`)
- Albums: `artist` field
- Videos: `channel_name` field

### 3. Duration Types
- `SearchResultSong.duration` is `String` (not `Option<String>`)
- Must parse before storing as `Option<u64>` in `Song`

### 4. Borrow Checker
```rust
// ❌ Wrong:
for album in results.albums {
    metadata.insert("title", vec![album.title]);  // First use
    metadata.insert("album", vec![album.title]);  // ERROR: moved
}

// ✅ Correct:
for album in results.albums {
    metadata.insert("title", vec![album.title.clone()]);
    metadata.insert("album", vec![album.title]);
}
```

## Testing API Calls

### Python (ytmusicapi)
```python
from ytmusicapi import YTMusic
ytmusic = YTMusic("cookie.txt")
results = ytmusic.search("son tung mtp")
print(results[0]['browseId'])  # Verify browse ID
```

### Rust (ytmapi-rs)
```rust
use ytmapi_rs::auth::BrowserToken;
use ytmapi_rs::{Client, YtMusicBuilder};
use ytmapi_rs::query::SearchQuery;

let client = Client::new()?;
let token = BrowserToken::from_file("cookie.txt", &client).await?;
let api = YtMusicBuilder::new_with_client(client)
    .with_browser_token(token)
    .build();

let query = SearchQuery::new("son tung mtp");
let results = api.query(query).await?;
println!("{:?}", results.artists);
```

## API Rate Limits

**None observed.** YouTube Music API appears to have no rate limiting for authenticated requests. However:
- Avoid parallel requests (single-threaded client)
- Cache results when possible
- Respect user's bandwidth

## Error Handling

### Common Errors
- `401 Unauthorized` → Cookies expired, re-export
- `404 Not Found` → Invalid browse_id
- `403 Forbidden` → IP blocked (rare, use VPN)
- Network errors → Retry with exponential backoff

### In ytmapi-rs
```rust
match api.query(search_query).await {
    Ok(results) => { /* Process */ },
    Err(e) => {
        log::error!("Search failed: {}", e);
        // Return empty results or retry
    }
}
```
