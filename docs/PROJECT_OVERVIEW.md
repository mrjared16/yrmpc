# Project Overview: yrmpc

## What This Is
Terminal-based YouTube Music client with keyboard-driven interface.

## Tech Stack
- **Language**: Rust
- **UI**: TUI via `ratatui`
- **Playback**: MPV (headless audio)
- **API**: YouTube Music via `ytmapi-rs`
- **Auth**: Cookie-based (Netscape format)

## Current State ✅

**Working:**
- Search all types (songs, artists, albums, playlists)
- Playback with queue management
- MPRIS integration
- Daemon mode (systemd)
- Autocomplete suggestions

**Next Priorities:**
- Rich UI (thumbnail + 2-line layout)
- API filtering (fetch only needed sections)

## Project Structure

```
yrmpc/
├── rmpc/                   # Main app (submodule)
│   ├── src/
│   │   ├── domain/search/  # Type-safe SearchItem
│   │   ├── player/youtube/ # Backend (api, server, client)
│   │   └── ui/panes/       # UI components
│   └── tests/
├── youtui/                 # ytmapi-rs (local patches)
└── config/rmpc.ron         # Configuration
```

## Key Features

### Search
- Type-safe SearchItem enum (Song, Video, Artist, Album, Playlist, Header)
- Configurable section order via `config.search.sections`
- TopResult parsing with fallback

### Playback
- MPV streaming (no downloads)
- Queue management
- MPRIS metadata
- Daemon architecture for external control

## Performance
- Search: <1s
- Playback start: <2s
- Track switching: <100ms (pre-buffered)
