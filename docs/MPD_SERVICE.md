# MPD Service Architecture

## Overview
`rmpc` must function as both a TUI client AND an MPD-compatible server, enabling external control via `mpc`, rofi, and other MPD clients.

## Why MPD Protocol?

### Benefits
- **Ecosystem**: Leverage existing MPD tooling
- **Scriptability**: Shell scripts can control playback
- **Launcher integration**: Rofi scripts for music selection
- **Status bars**: Polybar, i3status show current track
- **Multiple clients**: Connect from different terminals

### Challenges
- **YouTube backend**: MPD assumes local files, we stream
- **Playlist management**: MPD playlists vs YouTube playlists
- **Metadata**: MPD tags vs YouTube API data

## Architecture

```
┌─────────────────────────────────────────┐
│  External Clients                       │
│  ┌─────┐ ┌──────┐ ┌────────┐           │
│  │ mpc │ │ rofi │ │ ncmpcpp│           │
│  └──┬──┘ └───┬──┘ └───┬────┘           │
└─────┼────────┼────────┼─────────────────┘
      │        │        │
      └────────┴────────┘
               │
         MPD Protocol
         (port 6600)
               │
      ┌────────▼──────────┐
      │  rmpc MPD Server  │
      │  ┌──────────────┐ │
      │  │ Command      │ │
      │  │ Handler      │ │
      │  └──────┬───────┘ │
      │         │         │
      │  ┌──────▼───────┐ │
      │  │ YouTube      │ │
      │  │ Backend      │ │
      │  └──────┬───────┘ │
      │         │         │
      │  ┌──────▼───────┐ │
      │  │ MPV + Cache  │ │
      │  └──────────────┘ │
      └───────────────────┘
               │
         YouTube Music API
```

## Core MPD Commands to Support

### Playback Control
```
play [SONGPOS]        # Play track at position
pause [0|1]           # Toggle or set pause state
stop                  # Stop playback
next                  # Skip to next track
previous              # Go to previous track
seek [TIME]           # Seek to position
```

### Queue Management
```
add <URI>             # Add YouTube URL or search result
clear                 # Clear queue
delete [POS]          # Remove track from queue
move [FROM] [TO]      # Reorder queue
shuffle               # Shuffle queue
```

### Status & Info
```
status                # Playback state, volume, etc.
currentsong           # Current track metadata
playlist              # List queue
listplaylists         # List saved playlists (YouTube local)
```

### Playlist Operations
```
load <NAME>           # Load saved playlist
save <NAME>           # Save current queue as playlist
rm <NAME>             # Delete saved playlist
playlistadd <NAME> <URI>  # Add to playlist
```

## Implementation Plan

### Phase 1: MPD Server Core
**File:** `rmpc/src/mpd_server/mod.rs` (new)

```rust
pub struct MpdServer {
    listener: TcpListener,
    backend: Arc<Mutex<YouTubeBackend>>,
    queue: Arc<Mutex<Queue>>,
}

impl MpdServer {
    pub async fn run(&self) -> Result<()> {
        loop {
            let (stream, addr) = self.listener.accept().await?;
            let backend = Arc::clone(&self.backend);
            let queue = Arc::clone(&self.queue);
            
            tokio::spawn(async move {
                handle_client(stream, backend, queue).await
            });
        }
    }
}
```

### Phase 2: Command Parser
**File:** `rmpc/src/mpd_server/commands.rs` (new)

```rust
enum MpdCommand {
    Play(Option<usize>),
    Pause(Option<bool>),
    Add(String),  // YouTube URL or search query
    Status,
    CurrentSong,
    // ... more commands
}

fn parse_command(line: &str) -> Result<MpdCommand> {
    // Parse MPD protocol
}
```

### Phase 3: YouTube URI Scheme
**Format:** `youtube://CONTENT_TYPE/ID`

```
youtube://video/dQw4w9WgXcQ
youtube://artist/UC3muIvzjhubNpJ4Pn_0kCQw
youtube://album/MPREb_1234567890
youtube://playlist/RDCLAK5uy_123
```

**MPD Integration:**
```bash
# Via mpc
mpc add youtube://video/dQw4w9WgXcQ

# Via rofi script
echo "youtube://artist/$ARTIST_ID" | mpc add
```

### Phase 4: Metadata Mapping
**MPD expects:**
```
file: <path>
Artist: <artist>
Album: <album>
Title: <title>
Time: <duration_seconds>
Genre: <genre>
```

**YouTube provides:**
```rust
Song {
    file: youtube://video/...
    metadata: {
        "artist": ["Artist Name"],
        "album": ["Album Name"],
        "title": ["Track Title"],
        "duration": ["225"],  // seconds
    }
}
```

**Converter:**
```rust
fn to_mpd_response(song: &Song) -> String {
    format!(
        "file: {}\nArtist: {}\nAlbum: {}\nTitle: {}\nTime: {}\n",
        song.file,
        song.metadata.get("artist").and_then(|v| v.first()).unwrap_or("Unknown"),
        song.metadata.get("album").and_then(|v| v.first()).unwrap_or("Unknown"),
        song.metadata.get("title").and_then(|v| v.first()).unwrap_or("Unknown"),
        song.duration.unwrap_or(0),
    )
}
```

## Streaming & Caching Strategy

### Pre-Buffering (10s Cache)
```rust
struct TrackCache {
    video_id: String,
    buffer: Vec<u8>,  // First 10s of audio
    loaded: bool,
}

impl Queue {
    async fn prefetch_next(&mut self) -> Result<()> {
        if let Some(next_track) = self.peek_next() {
            let url = extract_stream_url(&next_track.video_id).await?;
            
            // Download first 10s to buffer
            let buffer = download_partial(url, 10 * BITRATE / 8).await?;
            
            self.cache.insert(next_track.video_id.clone(), TrackCache {
                video_id: next_track.video_id.clone(),
                buffer,
                loaded: true,
            });
        }
        Ok(())
    }
}
```

### Gapless Playback
```rust
// When current track reaches 90% played:
if current_position > 0.9 * total_duration {
    // Start MPV on next track (paused)
    mpv.load_file_async(next_url, LoadFileMode::AppendPlay)?;
    
    // Use cached 10s for instant start
    if let Some(cache) = self.cache.get(&next_video_id) {
        mpv.write_buffer(&cache.buffer)?;
    }
}
```

### No Full Downloads
```rust
// WRONG - Don't do this:
// download_full_video(video_id).await?;

// CORRECT - Stream only:
let stream_url = rusty_ytdl::Video::new(video_id)?
    .get_download_url()
    .await?;

// MPV streams directly from URL
mpv.command("loadfile", &[stream_url, "append-play"])?;
```

## Rofi Integration Example

### `~/.local/bin/rofi-music`
```bash
#!/bin/bash
# Search YouTube Music and add to queue

query=$(rofi -dmenu -p "Search Music")
[ -z "$query" ] && exit

# Search via mpc (rmpc implements search)
mpc searchadd any "$query"
mpc play
```

### Usage
```bash
# Bind to keyboard shortcut (i3/sway)
bindsym $mod+m exec rofi-music
```

## Status Bar Integration (Polybar)

### `~/.config/polybar/config`
```ini
[module/mpd]
type = internal/mpd
host = 127.0.0.1
port = 6600

format-online = <label-song> <icon-prev> <icon-play> <icon-next>
label-song = %artist% - %title%
```

## MPD Client Compatibility

### Tested Clients
- ✅ `mpc` - Command-line client
- ⚠️ `ncmpcpp` - TUI client (partial, playlist features vary)
- ✅ Rofi scripts - Launcher integration
- ✅ Polybar - Status display
- ⚠️ Cantata - GUI client (may have quirks with YouTube URIs)

### Limitations
- **Local file browsing**: N/A (YouTube streaming only)
- **Album art**: Thumbnails via metadata (not filesystem)
- **Exact seeking**: Limited by stream chunks
- **Outputs**: Single MPV instance (no multi-room)

## Performance Optimizations

### Latency Reduction
```rust
// 1. Pre-resolve URLs when adding to queue
async fn add_to_queue(video_id: &str) -> Result<()> {
    let url = extract_stream_url(video_id).await?;
    queue.push(Track {
        video_id: video_id.to_string(),
        stream_url: Some(url),  // Cached!
    });
}

// 2. Use HTTP/2 connection pooling for API
let client = Client::builder()
    .http2_prior_knowledge()
    .pool_max_idle_per_host(10)
    .build()?;

// 3. Parallel prefetch
tokio::spawn(async {
    queue.prefetch_next().await
});
```

### Memory Management
```rust
// Limit cache size (10s * 128kbps = ~160KB per track)
const MAX_CACHE_TRACKS: usize = 5;

if cache.len() > MAX_CACHE_TRACKS {
    cache.remove(&oldest_track_id);
}
```

## Testing MPD Service

### Manual Test
```bash
# Terminal 1: Start rmpc with MPD server
./target/release/rmpc --mpd-port 6600

# Terminal 2: Connect via mpc
export MPD_HOST=localhost
export MPD_PORT=6600

mpc add youtube://video/dQw4w9WgXcQ
mpc play
mpc status
```

### Automated Test
```rust
#[tokio::test]
async fn test_mpd_protocol() {
    let server = MpdServer::new("127.0.0.1:6600").await?;
    tokio::spawn(async move { server.run().await });
    
    let mut stream = TcpStream::connect("127.0.0.1:6600").await?;
    
    // Send MPD command
    stream.write_all(b"status\n").await?;
    
    // Read response
    let mut buf = vec![0u8; 1024];
    let n = stream.read(&mut buf).await?;
    
    let response = String::from_utf8_lossy(&buf[..n]);
    assert!(response.contains("OK MPD"));
}
```

## Next Steps

1. **Implement MPD server** (`rmpc/src/mpd_server/`)
2. **Add pre-buffering** to `YouTubeBackend`
3. **Test gapless playback** with MPV
4. **Create rofi scripts** for workflow
5. **Document MPD commands** in user guide
