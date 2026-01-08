# Persistence Architecture

> **Scope**: State storage, serialization, and configuration patterns
> **Status**: Config-only persistence; no runtime state persistence

## Overview

yrmpc uses a **stateless runtime model** with configuration-only persistence:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Persistent (Disk)                                │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ ~/.config/rmpc/config.ron   (RON format, user-editable)            │ │
│  │ ~/.config/rmpc/theme.ron    (optional, merged with config)         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ serde + ron
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        Runtime (Memory)                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │ Config       │  │ LibraryCache │  │ UI State     │                  │
│  │ (immutable)  │  │ (LRU+TTL)    │  │ (transient)  │                  │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ serde_json
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        IPC (Daemon ↔ TUI)                                │
│  JSON messages over Unix socket / stdio                                  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Configuration System

### File Format: RON

Uses [RON (Rusty Object Notation)](https://github.com/ron-rs/ron) for human-readable config.

**Location**: `~/.config/rmpc/config.ron` (or `--config` flag)

```ron
(
    address: "127.0.0.1:6600",
    backend: Youtube,
    youtube: (
        extractor: Ytx,
        prefetch_count: 3,
        stream_timeout: "30s",
    ),
    tabs: [
        ( name: "Queue" ),
        ( name: "Search" ),
    ],
)
```

### Config Loading Flow

```
main.rs
    │
    ├─ args.config_path()          → Resolve path from CLI or default
    │
    ├─ ConfigFile::read(&path)     → Read file, parse RON
    │    └─ serde_path_to_error     → Detailed parse error locations
    │
    ├─ ConfigFile::into_config()   → Merge with theme file, resolve paths
    │    ├─ Load theme.ron (optional)
    │    ├─ Resolve relative paths
    │    └─ Apply defaults
    │
    └─ Config (immutable for runtime)
```

### Key Files

| File | Purpose |
|------|---------|
| `config/mod.rs` | Main ConfigFile struct, loading logic |
| `config/cli.rs` | CLI argument parsing, config path resolution |
| `config/tabs.rs` | Tab configuration structures |
| `config/theme/` | Theme-related configuration |
| `config/keys/` | Keybinding configuration |

### Config Hot-Reload

**Location**: `core/config_watcher.rs`

Watches config file for changes and sends reload events:

```rust
// Watches config directory
let watcher = notify::recommended_watcher(|res| {
    if let Ok(event) = res {
        // Re-read and apply config
        let config = ConfigFile::read(&config_path)?;
        send_event(AppEvent::ConfigReloaded(config));
    }
});
```

## Serialization Patterns

### Domain Types → Serde

All domain types derive `Serialize` + `Deserialize` for IPC:

```rust
// domain/media_item.rs
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum MediaItem {
    Song(Song),
    Album(Album),
    Artist(Artist),
    Playlist(Playlist),
}

// Backward compatibility via alias
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Song {
    #[serde(alias = "file")]  // Old field name
    pub uri: String,
    // ...
}
```

### IPC Protocol (Daemon ↔ TUI)

**Location**: `backends/youtube/protocol.rs`

Length-prefixed JSON over Unix socket:

```rust
// Write message
pub fn write_message<W: Write, T: Serialize>(writer: &mut W, msg: &T) -> Result<()> {
    let json = serde_json::to_vec(msg)?;
    writer.write_all(&(json.len() as u32).to_le_bytes())?;
    writer.write_all(&json)?;
    Ok(())
}

// Read message
pub fn read_message<R: Read, T: Deserialize>(reader: &mut R) -> Result<T> {
    let mut len_buf = [0u8; 4];
    reader.read_exact(&mut len_buf)?;
    let len = u32::from_le_bytes(len_buf) as usize;
    let mut buf = vec![0u8; len];
    reader.read_exact(&mut buf)?;
    serde_json::from_slice(&buf)
}
```

### MPV Integration

Uses `serde_json` for MPV IPC commands:

```rust
// backends/youtube/mpv/ipc.rs
#[derive(Debug, Serialize, Deserialize)]
struct MpvCommand {
    command: Vec<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    request_id: Option<u64>,
}
```

## What Is NOT Persisted

| State | Why Not Persisted |
|-------|-------------------|
| Queue position | Ephemeral player state |
| Playback progress | MPV manages internally |
| Library cache | Re-fetched from API (24h TTL) |
| Search history | Not implemented |
| Recently played | Not implemented |
| UI scroll position | Transient |

## Extension Points

### Adding State Persistence

To persist runtime state (e.g., recently played):

1. **Define state struct** with Serialize/Deserialize:
   ```rust
   #[derive(Serialize, Deserialize)]
   struct AppState {
       recently_played: Vec<String>,
       last_queue: Vec<Song>,
   }
   ```

2. **Choose storage location**:
   ```rust
   let state_path = dirs::data_dir()
       .map(|d| d.join("rmpc/state.json"))
       .unwrap_or_else(|| PathBuf::from("~/.local/share/rmpc/state.json"));
   ```

3. **Save on shutdown**, load on startup:
   ```rust
   fn save_state(state: &AppState) -> Result<()> {
       let json = serde_json::to_string_pretty(state)?;
       fs::write(&state_path, json)?;
       Ok(())
   }
   ```

### Database Persistence

For structured data (ratings, play counts), consider:
- SQLite via `rusqlite` or `sqlx`
- Embedded key-value store (sled, rocksdb)

Not currently implemented; config files suffice for current needs.

## Debug Commands

```bash
# Validate config syntax
cargo run -- config --print

# Show resolved config path
cargo run -- config --path

# Enable config parsing debug
RUST_LOG=rmpc::config=debug cargo run

# Watch config file events
RUST_LOG=rmpc::core::config_watcher=debug cargo run
```

## Cross-References

- [Library Sync](./library-sync.md) - In-memory caching (not persisted)
- [YouTube Integration](./youtube-integration.md) - Auth token storage (in config)
