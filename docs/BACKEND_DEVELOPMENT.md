# Backend Development Guide

> For LLMs and contributors: How to work with the backend layer

## Quick Start

**Want to debug YouTube features?** Start here.

### Running System

1. **Start daemon:**
   ```bash
   ./restart_daemon_debug.sh
   ```
   This spawns `rmpcd` which:
   - Creates YouTubeServer
   - Spawns MPV process
   - Listens on `/tmp/yrmpc-yt.sock`

2. **Start TUI:**
   ```bash
   ./rmpc/target/debug/rmpc --config config/rmpc.ron
   ```
   This creates YouTubeProxy which connects to the daemon.

### Architecture Overview

```
┌─────────────────────────────────────────┐
│ Daemon (rmpcd)                        │
│   YouTubeServer                         │
│     ├─ ApiService (YouTube API)        │
│     ├─ PlaybackService (MPV manager)   │
│     └─ QueueService (metadata)         │
│                                         │
│   Spawns: MPV process                   │
│   Listens: /tmp/yrmpc-yt.sock        │
└─────────────────────────────────────────┘
                ▲
                │ Unix Socket IPC
                │
┌─────────────────────────────────────────┐
│ TUI (rmpc)                            │
│   BackendDispatcher                     │
│     └─ YouTubeProxy (IPC client)       │
│                                         │
│   Commands: play, search, queue, etc.   │
└─────────────────────────────────────────┘
```

## File Organization

### backends/
```
backends/
├── mod.rs              # Public API, re-exports
├── client.rs           # BackendDispatcher (main entry)
├── traits.rs           # MusicBackend trait
├── interaction.rs      # BackendActions (high-level ops)
├── messaging.rs        # IPC message types
│
├── controllers/        # Controller API (new, preferred)
│
├── mpd/                # MPD backend
│   ├── backend.rs      # MpdBackend
│   └── protocol/       # MPD protocol client
│
└── youtube/            # YouTube backend
    ├── client.rs       # YouTubeProxy (TUI-side)
    ├── server/         # YouTubeServer (daemon-side)
    ├── services/       # Api, Playback, Queue services
    ├── mpv/            # MPV IPC wrapper
    └── extractor/      # Stream URL extraction
```

## Common Tasks

### Adding a New YouTube Feature

Example: Add "Like Song" functionality

1. **Add IPC command** (`protocol.rs`):
   ```rust
   pub enum ServerCommand {
       LikeSong { video_id: String },
   }
   ```

2. **Add handler** (`server/handlers/...`):
   ```rust
   ServerCommand::LikeSong { video_id } => {
       api_service.like_video(&video_id).await?;
       ServerResponse::Ok
   }
   ```

3. **Add method to YouTubeProxy** (`client.rs`):
   ```rust
   pub fn like_song(&mut self, video_id: &str) -> Result<()> {
       self.request_ok(ServerCommand::LikeSong {
           video_id: video_id.to_string()
       })
   }
   ```

4. **Use from UI**:
   ```rust
   ctx.command(|backend| {
       backend.like_song(video_id)?;
       Ok(())
   });
   ```

### Debugging YouTube Issues

**Common issues:**

1. **"Daemon not running"**
   - Check: `ps aux | grep rmpcd`
   - Fix: Run `./restart_daemon_debug.sh`

2. **"No audio playing"**
   - Check: `ps aux | grep mpv`
   - Check: `/tmp/rmpcd-debug.log`
   - MPV socket: `/tmp/yrmpc-yt.mpv.sock`

3. **"Search returns nothing"**
   - Check cookies: `~/.config/rmpc/cookie.txt`
   - Check daemon logs for 401/403 errors

### Naming Conventions

| Type | Naming | Example |
|------|--------|---------|
| Backend entry | `{Name}Backend` (MPD) or `{Name}Proxy` (YouTube) | `MpdBackend`, `YouTubeProxy` |
| High-level ops | `BackendActions` trait | `enqueue_multiple()` |
| Controllers | `{Feature}Controller` | `PlaybackController` |
| Services | `{Feature}Service` | `ApiService`, `PlaybackService` |
| Messages | `{Action}Command` / `{Type}Response` | `ServerCommand`, `QueryResult` |

### Type Hierarchy

```
MusicBackend trait
    ├─ Implemented by: MpdBackend
    └─ Implemented by: YouTubeProxy

BackendDispatcher enum
    ├─ Mpd(MpdBackend)
    └─ YouTube(YouTubeProxy)

BackendActions trait
    └─ Implemented by: BackendDispatcher
```

## Testing

```bash
# Build
cargo build

# Run tests
cargo test

# Run daemon with debug logs
RUST_LOG=debug ./restart_daemon_debug.sh

# Run TUI with logs
RUST_LOG=debug ./rmpc/target/debug/rmpc --config config/rmpc.ron
```

## Common Pitfalls

### ❌ Don't use deprecated names
```rust
use backends::PlayerController;  // Old - removed
use backends::MpdClientExt;      // Old - removed
```

### ✅ Use current names
```rust
use backends::BackendDispatcher;  // Current
use backends::BackendActions;     // Current
```

### ❌ Don't access backend directly from UI
```rust
let backend = ctx.get_backend(); // Doesn't exist
```

### ✅ Use ctx.command() or ctx.query()
```rust
ctx.command(|backend| {
    backend.play()?;
    Ok(())
});
```

## Further Reading

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [ADR-backend-refactor.md](ADR-backend-refactor.md) - Refactoring history
- [YOUTUBE_API.md](YOUTUBE_API.md) - YouTube Music API details
