---
project: rmpc
purpose: Technical context and requirements for Phases 4-6
status: active
last_updated: 2025-11-23
phases_complete: [1, 2, 3]
phases_pending: [4, 5, 6]
---

# Technical Context: YouTube Music Integration

## Completed Foundation

### Phase 1: Backend Abstraction ✅
- `MusicBackend` trait for MPD/MPV
- `Client` enum for unified interface
- 40+ delegated methods

### Phase 2: Domain Models ✅
- Domain types independent of MPD
- `Song`, `Status`, `Queue` abstractions
- Bidirectional conversions

### Phase 3: Queue to App Layer ✅
- `AppState` with in-memory queue (445 LOC)
- Automatic MPD→AppState sync
- Thread-safe via `Arc<RwLock<>>`
- Ready for stateless backends

## Phase 4: YouTube Music Streaming Backend

### Objective
Implement YouTube Music as streaming source with gapless playback and pre-buffering.

### NOT Using youtui's Approach
**youtui limitations:**
- Downloads entire tracks before playing
- No streaming support
- No pre-buffering
- Gaps between tracks
- Uses rodio (not streaming-capable)

### Architecture

```
YouTube Music Track
    ↓
ytmapi-rs (API/metadata)
    ↓
rusty_ytdl (stream URL extraction)
    ↓
MPV Backend (streaming playback)
    ↓
Pre-buffer next 2-3 tracks (gapless)
```

### Key Components

#### 1. API Layer (ytmapi-rs)
```rust
dependencies:
  ytmapi-rs: { path = "../youtui/ytmapi-rs" }
  
features:
  - Search songs/albums/artists
  - Get track metadata  
  - Authentication (cookie/OAuth)
  - Get recommendations
```

#### 2. Stream URL Extraction
```rust
dependencies:
  rusty_ytdl: "0.7.4"
  
purpose:
  - Convert video ID → direct stream URL
  - No downloading, just URL
  - Cache URLs (expire ~1 hour)
```

#### 3. Streaming Playback
```rust
backend: MPV (existing)

flow:
  1. Get stream URL for current track
  2. mpv.play_url(stream_url)
  3. Immediately fetch URLs for next 2-3 tracks
  4. Queue to MPV for gapless playback
```

#### 4. Gapless Implementation
**Reference:** Harmony Music (Flutter app)

**Strategy:**
```rust
fn ensure_gapless(&mut self) -> Result<()> {
    let current_idx = app_state.get_current_index()?;
    let next_tracks = app_state.get_range(current_idx + 1, current_idx + 3);
    
    for track in next_tracks {
        if !self.stream_cache.contains(&track.id) {
            let url = self.get_stream_url(&track.file).await?;
            self.stream_cache.insert(track.id, url);
            self.mpv.queue_next(&url)?;
        }
    }
}
```

### File Structure
```
src/player/
  ├── backend.rs           (trait)
  ├── mpd_backend.rs       (existing)
  ├── mpv_backend.rs       (existing)
  └── youtube_backend.rs   (NEW)
```

### Success Criteria
- [ ] Search YouTube Music via ytmapi-rs
- [ ] Stream tracks via MPV (not download)
- [ ] Gapless playback (no silence)
- [ ] Pre-buffer prevents loading delays
- [ ] Queue via AppState
- [ ] Same UX as MPD

## Phase 5: Config-Driven Backend Selection

### Configuration Schema

```toml
# ~/.config/rmpc/config.toml

# Backend selection
backend = "youtube"  # or "mpd"

[mpd]
address = "localhost:6600"
password = ""

[youtube]
# Authentication: "cookie" or "oauth"
auth_type = "cookie"
auth_file = "~/.config/rmpc/youtube_cookie.txt"

# Streaming quality
quality = "high"  # high/medium/low

# Buffer settings
prebuffer_tracks = 2
stream_cache_ttl = 3600  # seconds
```

### Backend Initialization

```rust
// src/main.rs or src/core/client.rs

let backend = match config.backend.as_str() {
    "mpd" => Client::Mpd(MpdBackend::new(
        MpdClient::connect(&config.mpd.address)?
    )),
    "youtube" => Client::YouTube(YouTubeBackend::new(
        config.youtube,
        ctx.app_state.clone()
    )?),
    _ => bail!("Unknown backend: {}", config.backend),
};
```

### Success Criteria
- [ ] Config parsing for backend selection
- [ ] Runtime backend switching
- [ ] Backend-specific configuration
- [ ] Graceful fallback on errors

## Phase 6: YouTube Music Radio Feature

### YouTube Music Radio
Auto-play similar/recommended music when queue ends.

### API Integration

```rust
// ytmapi-rs provides GetWatchPlaylist endpoint
async fn activate_radio(&mut self) -> Result<()> {
    let recent = self.app_state
        .read()
        .unwrap()
        .get_recent_tracks(10);
    
    // GetWatchPlaylist is YouTube's radio mechanism
    let radio_playlist = self.api
        .get_watch_playlist(recent.last().unwrap().video_id)
        .await?;
    
    for track in radio_playlist.take(10) {
        self.app_state
            .write()
            .unwrap()
            .add(track.into(), None);
    }
}
```

### Event Loop Integration

```rust
// src/core/event_loop.rs

// Detect queue end
if app_state.is_empty() && config.youtube.radio_enabled {
    client.activate_radio().await?;
    ctx.status_message("Radio activated");
}
```

### Configuration

```toml
[youtube]
radio_enabled = true
radio_fetch_count = 10
radio_trigger = "on_queue_end"  # or "always"
```

### Success Criteria  
- [ ] Detects queue end
- [ ] Fetches YouTube recommendations
- [ ] Auto-adds to AppState
- [ ] UI indicator for radio mode
- [ ] Configurable enable/disable

## External References

### youtui
**Location:** `<PROJECT_ROOT>/youtui`

**What We Use:**
- ✅ ytmapi-rs library (API wrapper)
- ✅ Authentication patterns
- ✅ API endpoint examples

**What We DON'T Use:**
- ❌ Download-and-play approach
- ❌ rodio playback
- ❌ Non-streaming architecture

### Harmony Music
**Purpose:** Reference for streaming patterns

**What To Learn:**
- Stream URL caching strategy
- Gapless playback implementation
- Buffer management
- Mobile-optimized streaming

**Status:** Research needed

### ytmapi-rs Details
```toml
[dependencies]
ytmapi-rs = { path = "../youtui/ytmapi-rs", version = "0.2.0" }

features:
  - rustls-tls (or native-tls)
  - simplified-queries
  - reqwest
```

**Key APIs:**
- `search()` - Search tracks/albums/artists
- `get_watch_playlist()` - Radio recommendations
- `get_song()` - Track metadata
- `get_artist()` - Artist info
- `get_album()` - Album tracks

## Dependencies

### New Dependencies (Phase 4)
```toml
ytmapi-rs = { path = "../youtui/ytmapi-rs" }
rusty_ytdl = "0.7.4"
tokio = { version = "1", features = ["full"] }  # For async ytmapi
```

### Async Integration
**Challenge:** ytmapi-rs is async, MusicBackend is sync

**Solution:** Blocking runtime in backend
```rust
struct YouTubeBackend {
    rt: tokio::runtime::Runtime,
    api: YtMusic,
    // ...
}

impl MusicBackend for YouTubeBackend {
    fn search(&mut self, query: &[Filter]) -> Result<Vec<Song>> {
        self.rt.block_on(async {
            self.api.search(&query).await
        })
    }
}
```

## Implementation Sequence

### Phase 4 Steps
1. Add ytmapi-rs dependency
2. Create YouTubeBackend struct
3. Implement authentication (cookie first)
4. Implement search functionality
5. Implement stream URL extraction
6. Integrate with MPV for playback
7. Implement pre-buffering for gapless
8. Add to Client enum

### Phase 5 Steps
1. Add backend config parsing
2. Update Ctx initialization
3. Backend-specific config sections
4. Runtime backend selection
5. Error handling and fallbacks

### Phase 6 Steps
1. Implement queue-end detection
2. GetWatchPlaylist integration
3. Auto-add recommended tracks
4. UI indicator for radio mode
5. Configuration options

## Technical Challenges

### 1. Async/Sync Boundary
**Issue:** ytmapi-rs async, MusicBackend sync  
**Solution:** tokio::Runtime::block_on()

### 2. Stream URL Expiration
**Issue:** YouTube URLs expire (~1 hour)  
**Solution:** Cache with TTL, refresh on 403

### 3. Gapless Playback
**Issue:** Need seamless track transitions  
**Solution:** Pre-buffer next tracks to MPV queue

### 4. Authentication
**Issue:** YouTube requires auth  
**Solution:** Cookie-based (simple) or OAuth (robust)

## Design Principles

1. **Backend Agnostic:** UI doesn't know if MPD or YouTube
2. **Streaming First:** Modern streaming experience
3. **Feature Parity:** YouTube features + MPD reliability
4. **Config Driven:** User controls backend choice
5. **Maintainable:** Clean separation of concerns

## Next Steps

1. ✅ Clarification reviewed and approved
2. → Research Harmony Music streaming (if needed)
3. → Begin Phase 4 implementation
4. → Implement gapless pre-buffering
5. → Test with real YouTube Music playback

## Questions

1. Should we research Harmony Music before Phase 4 start?
2. Cookie or OAuth authentication first?
3. Pre-buffer count: 2 or 3 tracks?
4. Should radio be Phase 6 or part of Phase 4?
5. ytmapi-rs: local path or publish to crates.io?
