# Architecture Overview

This document provides a high-level overview and routes you to detailed documentation.

## Design Principles

1. **TabPane + DetailPane**: Tabs for browsing, detail panes for deep exploration
2. **Three-Level Navigation**: Mode → Intra-pane → History stack
3. **Content Stacking**: Push detail views onto navigation stack, pop to return
4. **Find not Filter**: Use stacking search, don't filter in place
5. **Vim Modes**: Normal (navigate), Insert (text input), Visual (selection)
6. **Single Path**: One correct way to implement each pattern
7. **Sections as Containers**: Sections hold items, not just headers

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────────────┐
│                              Ui                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                         Navigator                              │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │              TabPane / DetailPane                        │  │  │
│  │  │  ┌─────────────────────────────────────────────────────┐│  │  │
│  │  │  │              ContentView<C>                         ││  │  │
│  │  │  │  ┌─────────────────────────────────────────────────┐││  │  │
│  │  │  │  │              SectionList                        │││  │  │
│  │  │  │  │  ┌─────────────────────────────────────────────┐│││  │  │
│  │  │  │  │  │         SelectableList                          ││││  │  │
│  │  │  │  │  └─────────────────────────────────────────────┘│││  │  │
│  │  │  │  └─────────────────────────────────────────────────┘││  │  │
│  │  │  └─────────────────────────────────────────────────────┘│  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Abstractions

| Abstraction | Purpose |
|-------------|---------|
| `Navigator` | Manages pane stack, routing, back navigation |
| `ContentView<C>` | Generic container for any content type |
| `SectionList` | Facade for section-based item display |
| `Intent` | User action representation (play, enqueue, navigate) |
| `Song` | Core playable item with metadata HashMap for album, artist, etc. |
| `DetailItem` | View model for list display with title, subtitle, thumbnail. |
| `Section` | First-class domain object grouping items by semantic key. |

## Backend Architecture

Refactored (Dec 2025) to enforce Interface Segregation and Backend Agnosticism:

1. **Granular Traits**: `MusicBackend` is split into `api::Playback`, `api::Queue`, `api::Discovery`.
2. **Unified Implementation**: All backends reside in `src/backends/<name>` (e.g., `youtube`, `mpd`).
3. **Playback Engine**: Current YouTube backend controls an external MPV process over JSON IPC; see [playback-engine.md](arch/playback-engine.md) (engine design) and [backends/youtube/](backends/youtube/README.md) (wiring details).
4. **Layer Separation**:
   - `src/domain/`: Defines *what* data is (MediaItem, ContentDetails).
   - `src/backends/api/`: Defines *how* to fetch data.
   - `src/ui/views/`: Defines *how* to render data.

## Section System

Content is organized into typed sections for flexible rendering:

- **SectionKey**: Semantic identifier (Albums, Tracks, Artists, TopResults, etc.)
- **SectionData**: Content variants (Items, Tracks, Stats, Actions, Paginated, Error)
- **Dynamic Rendering**: UI renders sections based on their key and data type.

## PlayIntent Command Pattern

The PlayIntent architecture (ADR-002) provides atomic playback commands for low-latency playback with a shared preparation core:

- **TUI Layer**: `QueueStore.play(PlayIntent)` with optimistic update
- **IPC Layer**: `ServerCommand::PlayWithIntent { intent, request_id }`
- **Daemon Layer**: `handle_play_with_intent()` → `orchestrator::play_position_sync(...)` → `MediaPreparer::prepare`

Key types:
- `PlayIntent`: Context, Next, Append, Radio (seed-only v1)
- `PreloadTier`: Immediate > Gapless > Eager > Background
- `RequestId`: u64 counter for dedup/cancel

Playback URL construction is centralized at runtime in `FfmpegConcatSource::build_from_prepared` (`rmpc/src/backends/youtube/audio/sources/concat.rs`).

## Where to Look

### By Task

| Task | Read These |
|------|------------|
| Fix search/TopResult parsing | [features/search.md](features/search.md), [arch/youtube-integration.md](arch/youtube-integration.md) |
| Fix playback/MPV issues | [features/playback.md](features/playback.md), [arch/playback-engine.md](arch/playback-engine.md) |
| Fix streaming/buffering | [arch/audio-streaming.md](arch/audio-streaming.md) |
| Fix navigation/back button | [arch/ui-navigation.md](arch/ui-navigation.md) |
| Add new pane | [features/navigation.md](features/navigation.md) |
| Fix queue operations | [features/queue.md](features/queue.md) |
| Understand action dispatch | [arch/action-system.md](arch/action-system.md) |
| Modify section display | [arch/section-model.md](arch/section-model.md) |
| Library/playlist operations | [features/library.md](features/library.md), [capabilities/library-cache.md](capabilities/library-cache.md) |
| Implement a new backend | [backends/reference/README.md](backends/reference/README.md), [capabilities/README.md](capabilities/README.md) |
| Understand capability system | [capabilities/README.md](capabilities/README.md) |
| Config/persistence issues | [arch/persistence.md](arch/persistence.md) |
| Background tasks/scheduler | [arch/background-tasks.md](arch/background-tasks.md) |

### By Symptom

| Symptom | Likely Cause | Read |
|---------|--------------|------|
| Empty search results | ytmapi parsing | [arch/youtube-integration.md](arch/youtube-integration.md) |
| Playback doesn't start | URL extraction | [arch/playback-engine.md](arch/playback-engine.md) |
| Wrong item displayed | Adapter conversion | [arch/youtube-integration.md](arch/youtube-integration.md) |
| Navigation stuck | Stack corruption | [arch/ui-navigation.md](arch/ui-navigation.md) |
| Action not handled | Missing handler | [arch/action-system.md](arch/action-system.md) |
| Queue out of sync | State mismatch | [features/queue.md](features/queue.md) |
| Library empty/stale | Cache or backend | [capabilities/library-cache.md](capabilities/library-cache.md), [features/library.md](features/library.md) |
| Config not loading | Persistence | [arch/persistence.md](arch/persistence.md) |
| Prefetch not working | Background tasks | [arch/background-tasks.md](arch/background-tasks.md) |
| Audio cuts out mid-track | Streaming issue | [arch/audio-streaming.md](arch/audio-streaming.md) |

## Documentation Index

### Zone 1: Architecture (Backend-Agnostic Primitives)
- [arch/action-system.md](arch/action-system.md) - Intent dispatch, handlers
- [arch/ui-navigation.md](arch/ui-navigation.md) - Navigator, panes, stacking
- [arch/section-model.md](arch/section-model.md) - SectionList, UI vs domain
- [arch/persistence.md](arch/persistence.md) - Config, serialization, state storage
- [arch/background-tasks.md](arch/background-tasks.md) - Scheduler, prefetch, threading
- [arch/audio-streaming.md](arch/audio-streaming.md) - Progressive streaming, caching (ADR-001)

### Zone 2: Capabilities (Backend Contracts)
- [capabilities/README.md](capabilities/README.md) - **Start here** - Required vs optional capabilities
- [capabilities/playback.md](capabilities/playback.md) - Layer 1: Play/pause/seek (required)
- [capabilities/queue.md](capabilities/queue.md) - Layer 1: Queue operations (required)
- [capabilities/discovery.md](capabilities/discovery.md) - Layer 1: Search/browse (required)
- [capabilities/playlists.md](capabilities/playlists.md) - Layer 2: Playlist CRUD (optional)
- [capabilities/sync.md](capabilities/sync.md) - Layer 2: 2-way cloud sync (optional)
- [capabilities/library-cache.md](capabilities/library-cache.md) - Layer 2: Caching pattern (optional)
- [capabilities/lyrics.md](capabilities/lyrics.md) - Layer 2: Lyrics fetching (optional)

### Zone 3: Features (End-to-end Flows)
- [features/search.md](features/search.md) - Query to results flow
- [features/playback.md](features/playback.md) - Selection to audio flow
- [features/queue.md](features/queue.md) - Queue management flow
- [features/navigation.md](features/navigation.md) - Pane navigation flow
- [features/library.md](features/library.md) - Library browsing and management

### Backends (Implementation-Specific)
- [backends/reference/README.md](backends/reference/README.md) - **Contributor guide** - How to add a backend
- [backends/youtube/README.md](backends/youtube/README.md) - YouTube Music implementation
- [arch/youtube-integration.md](arch/youtube-integration.md) - ytmapi adapter, quirks
- [arch/playback-engine.md](arch/playback-engine.md) - MPV, audio cache, extraction

### Reference
- [VISION.md](VISION.md) - Project goals

## Layer Boundaries

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│     UI      │────▶│   Domain    │◀────│   Backend   │
│  (panes)    │     │ (MediaItem) │     │ (ytmapi)    │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   ▲                   ▲
      │                   │                   │
      │ Uses              │ Shared            │ Produces
      │                   │                   │
      └───────────────────┴───────────────────┘
```

**Unified Type System**: `MediaItem` is the shared vocabulary. Backends convert their internal types (e.g., `ytmapi::Video`) directly into `MediaItem` before returning them. The "Lossy Adapter Chain" has been eliminated; domain types flow directly through the IPC protocol.

## Quick Start for Contributors

1. Read [VISION.md](VISION.md) for project goals
2. Find your task in "Where to Look" above
3. Read the linked feature/primitive docs
4. Follow existing patterns in similar code
