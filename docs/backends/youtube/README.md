# YouTube Music Backend

> **Status**: Primary implementation (flagship)
> **Capabilities**: Playback, Queue, Discovery, Volume, Playlists, Sync (optional)

## Overview

The YouTube backend connects yrmpc to YouTube Music via the `ytmapi-yrmpc` library. It uses a daemon-client architecture for reliable streaming.

> **Current canonical playback docs:**
> - [../../arch/playback-flow.md](../../arch/playback-flow.md) — current runtime behavior
> - [../../arch/audio-streaming.md](../../arch/audio-streaming.md) — transport/cache deep dive
> - [../../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](../../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) — architectural rationale

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TUI (Client)                             │
│  Sends requests via IPC (JSON over Unix socket/stdio)           │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      YouTube Daemon                             │
│  ┌──────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ Server       │  │ MediaPreparer  │  │ MPV (playback)     │  │
│  │ (handlers)   │  │ + AudioCache   │  │                    │  │
│  └──────────────┘  └────────────────┘  └────────────────────┘  │
│         │                │                      │               │
│         └────────────────┴──► RelayRuntime ─────┘              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ytmapi-yrmpc                                  │
│  Rust bindings for YouTube Music internal API                   │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Client | `backends/youtube/client.rs` | IPC with daemon |
| Server | `backends/youtube/server/` | Request handlers |
| Play Intent Handler | `backends/youtube/server/handlers/play_intent.rs` | Handles PlayIntent commands (ADR-002) |
| Orchestrator | `backends/youtube/server/orchestrator.rs` | Playback bridge, EOF/track-change FSM |
| Adapter | `backends/youtube/adapter.rs` | Type conversions |
| URL Resolver | `backends/youtube/url_resolver.rs` | Video ID → stream URL (ytx/yt-dlp) |
| MediaPreparer | `backends/youtube/media/preparer.rs` | Coalesced prep: URL resolve + prefix + tier |
| AudioCache | `backends/youtube/audio/cache.rs` | 200KB prefix download/LRU cache |
| RelayRuntime | `backends/youtube/media/relay_runtime.rs` | Local HTTP daemon for LocalRelay transport |
| ConcatSource | `backends/youtube/audio/sources/concat.rs` | Builds `lavf://concat` MPV input |
| Playback Service | `backends/youtube/services/playback_service.rs` | MPV playlist control + transport boundary |
| Queue Service | `backends/youtube/services/queue_service.rs` | Queue state |
| Internal Events | `backends/youtube/services/internal_event.rs` | Typed MPV event routing |

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

Extractor options (ytx vs yt-dlp) are handled by the URL Resolver. Audio streaming uses `AudioCache` for 200KB prefix download + LRU eviction, `FfmpegConcatSource`/`RelayRuntime` for byte-perfect playback via MPV, and `MediaPreparer` for tier-based coalesced preparation.

### Current playback contract (2026-03)

- **Immediate play is relay-first.** A cache miss normally returns `PreparedMedia::StreamAndCache`, so playback begins through the local relay while the prefix is tee-written into cache.
- **Direct URL is fallback only.** Direct playback is used only if relay setup fails as a whole for the current track.
- **Coordinator owns in-flight current-track identity.** During immediate startup, `PlaybackCoordinator` is authoritative; `PlayQueue.current_id` and transient MPV `TrackChanged(-1)` observations are advisory until playback is confirmed.
- **Queue mutation is delta-based.** Active-playback reconciliation preserves unchanged future MPV tail entries and only prepares/appends newly exposed tracks.
- **Prefix cache promotion is reusable.** Tee-completed relay prefixes are promoted into `AudioCache`, and gapless/eager prefix downloads reuse the original resolved stream URL instead of forcing a second extraction.

See [arch/audio-streaming.md](../../arch/audio-streaming.md) for the full streaming architecture.

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
- [Playback Flow](../../arch/playback-flow.md) - Current runtime behavior
