# YouTube Music Backend

> **Status**: Primary implementation (flagship)
> **Capabilities**: Playback, Queue, Discovery, Volume, Playlists, Sync (optional)

## Overview

The YouTube backend connects yrmpc to YouTube Music via the `ytmapi-yrmpc` library. It uses a daemon-client architecture for reliable streaming.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TUI (Client)                             │
│  Sends requests via IPC (JSON over Unix socket/stdio)          │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      YouTube Daemon                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Server      │  │ URL Resolver│  │ MPV Player  │             │
│  │ (handlers)  │  │ (ytx/yt-dlp)│  │ (playback)  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ytmapi-yrmpc                                 │
│  Rust bindings for YouTube Music internal API                   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Client | `backends/youtube/client.rs` | IPC with daemon |
| Server | `backends/youtube/server/` | Request handlers |
| Play Intent Handler | `backends/youtube/server/handlers/play_intent.rs` | Handles PlayIntent commands (ADR-002) |
| Orchestrator | `backends/youtube/server/orchestrator.rs` | EOF/track-change state machine |
| Adapter | `backends/youtube/adapter.rs` | Type conversions |
| URL Resolver | `backends/youtube/url_resolver.rs` | Video ID → stream URL |
| Playback Service | `backends/youtube/services/playback_service.rs` | MPV control |
| Queue Service | `backends/youtube/services/queue_service.rs` | Queue state |
| Internal Events | `backends/youtube/services/internal_event.rs` | Typed MPV event routing |
| ProgressiveAudioFile | `backends/youtube/streaming_audio_file.rs` | Progressive download with range requests |
| AudioFileManager | `backends/youtube/audio_file_manager.rs` | File lifecycle and cache management |

## Resilience Architecture (2024-01)

YouTube Music API changes frequently. The backend uses a hybrid resilience strategy:

1.  **Extraction Layer**:
    -   Located in `rmpc/src/backends/youtube/extract/`.
    -   Defines centralized **fallback paths** for critical fields (video_id, browse_id).
    -   Re-parses data from raw JSON if strict typing fails.

2.  **Failure Handling**:
    -   **Unknown Variants**: Never hard-fail on new enum types (e.g., new `TopResultType`).
    -   **Optional Fields**: Avoid `?` operator on unstable fields; use `Option` and fallback.
    -   **Concise Logging**: Log only failures, with context keys, avoiding hot paths.

3.  **Golden Fixtures**:
    -   Real API responses captured and stored as tests.
    -   Used to detect regressions when API shapes change.

## Data Flow (Metadata)

How metadata (e.g., Album name) propagates from YouTube to the Queue:

1.  **ytmusicapi**: Returns JSON with album info.
2.  **Adapter**: Converts to `SongItem`. `album` field is mapped from response.
3.  **Domain**: `Song` struct stores album in `metadata["album"]` HashMap.
4.  **Protocol**: `PlayableData` preserves album field.
5.  **Queue**: `QueuePane` renders using `ListItemDisplay` trait, which accesses metadata (case-insensitive "album"/"Album" fallback).

## Capabilities Implemented

| Capability | Status | Notes |
|------------|--------|-------|
| Playback | ✅ | Via MPV |
| Queue | ✅ | Local queue + MPV sync |
| Discovery | ✅ | Search, browse, recommendations |
| Volume | ✅ | MPV volume control |
| Playlists | ✅ | Cloud playlists |
| PlaylistCreate | ✅ | Create new playlists |
| PlaylistEdit | ✅ | Add/remove tracks |
| Sync | ✅ Optional | 2-way with YouTube Music |
| Lyrics | 🔶 Planned | - |
| Radio | 🔶 Planned | - |

## Authentication

See [auth.md](./auth.md) for details on:
- Cookie-based authentication (browser export)
- OAuth flow (future)
- SAPISID token handling

## Stream Resolution

Extractor options (ytx vs yt-dlp), URL caching, and prefetch strategy are handled by the URL Resolver component. Audio streaming uses `ProgressiveAudioFile` for progressive download with `AudioFileManager` coordinating file lifecycle and cache eviction.

See [arch/audio-streaming.md](../../arch/audio-streaming.md) for detailed streaming architecture.

## YouTube-Specific Quirks

Known issues and workarounds:
- **TopResult parsing**: Null artist IDs require fallback extraction
- **Rate limiting**: Respect API limits, implement backoff
- **API response variations**: Different formats for same endpoints

## Configuration

```ron
youtube: (
    extractor: Ytx,           // or YtDlp
    prefetch_count: 3,        // URLs to prefetch ahead
    stream_timeout: "30s",    // Max wait for stream URL
    sync_enabled: true,       // Optional 2-way sync
),
```

## Cross-References

- [Capability System](../../capabilities/README.md) - What we implement
- [Contributor Guide](../reference/README.md) - How backends work
- [Playback Feature](../../features/playback.md) - User flow
