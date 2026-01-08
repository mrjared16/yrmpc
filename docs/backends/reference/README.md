# Implementing a New Backend

> **Goal**: Add Spotify, Tidal, Last.fm, or any streaming service to yrmpc
> **Time**: ~1-2 days for basic playback, ~1 week for full features

## Quick Start Checklist

```
[ ] 1. Create backend module: rmpc/src/backends/myservice/
[ ] 2. Implement required traits (Playback, Queue, Discovery, Volume)
[ ] 3. Declare capabilities in capabilities() method
[ ] 4. Register in BackendDispatcher
[ ] 5. Add configuration options
[ ] 6. Test with `cargo run -- --backend myservice`
[ ] 7. (Optional) Implement additional capabilities
```

## Required Traits (Layer 1)

Every backend MUST implement these four traits:

### `api::Playback`
```rust
pub trait Playback {
    fn play(&self) -> Result<()>;
    fn pause(&self) -> Result<()>;
    fn stop(&self) -> Result<()>;
    fn seek(&self, position: Duration) -> Result<()>;
    fn get_status(&self) -> Result<PlaybackStatus>;
}
```
**Location**: `rmpc/src/backends/api/playback.rs`

### `api::Queue`
```rust
pub trait Queue {
    fn add(&self, items: &[MediaItem]) -> Result<()>;
    fn remove(&self, indices: &[usize]) -> Result<()>;
    fn clear(&self) -> Result<()>;
    fn get_queue(&self) -> Result<Vec<QueueItem>>;
    fn play_at(&self, index: usize) -> Result<()>;
}
```
**Location**: `rmpc/src/backends/api/queue.rs`

### `api::Discovery`
```rust
pub trait Discovery {
    fn search(&self, query: &str) -> Result<SearchResults>;
    fn browse(&self, id: &str) -> Result<BrowseResults>;
    fn get_recommendations(&self) -> Result<Vec<MediaItem>>;
}
```
**Location**: `rmpc/src/backends/api/discovery.rs`

### `api::Volume`
```rust
pub trait Volume {
    fn get_volume(&self) -> Result<u8>;
    fn set_volume(&self, level: u8) -> Result<()>;
}
```
**Location**: `rmpc/src/backends/api/volume.rs`

## Optional Traits (Layer 2)

Implement these if your service supports them:

| Trait | When to Implement |
|-------|-------------------|
| `api::optional::Playlists` | Service has user playlists |
| `api::optional::Lyrics` | Service provides lyrics |
| `api::optional::Radio` | Service has radio/stations |
| `api::optional::UserPreferences` | Service has like/dislike |
| `api::optional::Sync` | You want 2-way cloud sync |

**Location**: `rmpc/src/backends/api/optional/`

## Declaring Capabilities

```rust
use crate::backends::api::Capability;

impl Backend for MyServiceBackend {
    fn capabilities(&self) -> &'static [Capability] {
        &[
            // Required (all backends have these)
            Capability::Playback,
            Capability::Queue,
            Capability::Discovery,
            Capability::Volume,
            // Optional (only if you implement them)
            Capability::Playlists,
            Capability::PlaylistCreate,
        ]
    }
}
```

The TUI checks these flags to show/hide features. If you don't declare `Capability::Playlists`, the playlist menu won't appear.

## Suggested File Structure

```
rmpc/src/backends/myservice/
├── mod.rs              # Backend struct, trait implementations
├── api.rs              # HTTP client, API calls
├── adapter.rs          # Convert API types → domain types
├── config.rs           # Configuration (api keys, endpoints)
└── auth.rs             # (Optional) OAuth, tokens
```

## Registration

### 1. Add to BackendType enum

```rust
// rmpc/src/backends/mod.rs
pub enum BackendType {
    Mpd,
    Youtube,
    MyService,  // Add your backend
}
```

### 2. Register in dispatcher

```rust
// rmpc/src/backends/dispatcher.rs
impl BackendDispatcher {
    pub fn new(backend_type: BackendType, config: &Config) -> Result<Self> {
        match backend_type {
            BackendType::MyService => {
                Box::new(MyServiceBackend::new(config)?)
            }
            // ...
        }
    }
}
```

### 3. Add configuration

```rust
// rmpc/src/config/mod.rs
pub struct Config {
    pub backend: BackendType,
    pub myservice: Option<MyServiceConfig>,
    // ...
}
```

## Testing Your Backend

```bash
# Run with your backend
cargo run -- --backend myservice --config path/to/config.ron

# Run specific tests
cargo test backends::myservice

# Enable debug logging
RUST_LOG=rmpc::backends::myservice=debug cargo run
```

## Type Conversions (Adapter Pattern)

Your API returns service-specific types. Convert them to domain types:

```rust
// adapter.rs
impl TryFrom<SpotifyTrack> for MediaItem {
    type Error = AdapterError;
    
    fn try_from(track: SpotifyTrack) -> Result<Self, Self::Error> {
        Ok(MediaItem::Song(Song {
            id: track.id,
            title: track.name,
            artist: track.artists.first().map(|a| a.name.clone()),
            album: track.album.map(|a| a.name),
            duration: Duration::from_millis(track.duration_ms),
            // ...
        }))
    }
}
```

## Common Patterns

### Async to Sync Bridge
yrmpc's TUI is synchronous. Use channels for async APIs:

```rust
// Spawn async runtime in background thread
let (tx, rx) = crossbeam::channel::bounded(1);
std::thread::spawn(move || {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let result = api.search(&query).await;
        tx.send(result).unwrap();
    });
});
let result = rx.recv()?;
```

### Error Handling
Map API errors to backend errors:

```rust
impl From<reqwest::Error> for BackendError {
    fn from(e: reqwest::Error) -> Self {
        if e.is_timeout() {
            BackendError::Timeout
        } else if e.is_connect() {
            BackendError::ConnectionFailed
        } else {
            BackendError::ApiError(e.to_string())
        }
    }
}
```

## Cross-References

- [Capability System](../../capabilities/README.md) - Required vs optional
- [YouTube Backend](../youtube/README.md) - Reference implementation
- [Architecture](../../ARCHITECTURE.md) - System overview
