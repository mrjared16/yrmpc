# Documentation Index

## Quick Start (LLM Agents)

| Order | File | Purpose |
|-------|------|---------|
| 1 | `AGENTS.md` (root) | Quick reference, beads workflow |
| 2 | `docs/ARCHITECTURE.md` | High-level overview + routing tables |
| 3 | `docs/capabilities/README.md` | Required vs optional capabilities |
| 4 | Feature/primitive doc from routing table | Deep dive for your task |

## 3-Zone Documentation Structure

### Zone 1: Architecture (Backend-Agnostic Primitives)
| File | Content |
|------|---------|
| [arch/action-system.md](arch/action-system.md) | Intent dispatch, handlers, priorities |
| [arch/ui-navigation.md](arch/ui-navigation.md) | Navigator, panes, content stacking |
| [arch/section-model.md](arch/section-model.md) | SectionList, UI vs domain separation |
| [arch/persistence.md](arch/persistence.md) | Config, serialization, state storage |
| [arch/background-tasks.md](arch/background-tasks.md) | Scheduler, prefetch, threading |
| [arch/play-queue.md](arch/play-queue.md) | **NEW**: PlayQueue state machine (L1) & Bridge (L2) |

### Zone 2: Capabilities (Backend Contracts)
| File | Content |
|------|---------|
| [capabilities/README.md](capabilities/README.md) | **Start here** - Required vs optional matrix |
| [capabilities/playback.md](capabilities/playback.md) | Layer 1 (required): Play/pause/seek |
| [capabilities/queue.md](capabilities/queue.md) | Layer 1 (required): Queue operations |
| [capabilities/discovery.md](capabilities/discovery.md) | Layer 1 (required): Search/browse |
| [capabilities/playlists.md](capabilities/playlists.md) | Layer 2 (optional): Playlist CRUD |
| [capabilities/sync.md](capabilities/sync.md) | Layer 2 (optional): 2-way cloud sync |
| [capabilities/library-cache.md](capabilities/library-cache.md) | Layer 2 (optional): Caching pattern |
| [capabilities/lyrics.md](capabilities/lyrics.md) | Layer 2 (optional): Lyrics fetching |

### Zone 3: Features (End-to-end Flows)
| File | Content |
|------|---------|
| [features/search.md](features/search.md) | Query → API → Adapter → UI flow |
| [features/playback.md](features/playback.md) | Selection → Extraction → MPV flow |
| [features/queue.md](features/queue.md) | Queue management, sync |
| [features/navigation.md](features/navigation.md) | Pane navigation, adding panes |
| [features/library.md](features/library.md) | Library browsing, playlist management |

### Backends (Implementation-Specific)
| File | Content |
|------|---------|
| [backends/reference/README.md](backends/reference/README.md) | **Contributor guide** - How to add a backend |
| [backends/youtube/README.md](backends/youtube/README.md) | YouTube Music implementation |
| [arch/youtube-integration.md](arch/youtube-integration.md) | ytmapi adapter, API quirks |
| [arch/playback-engine.md](arch/playback-engine.md) | MPV, audio cache, URL extraction |

### Reference
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [VISION.md](VISION.md) - Project goals and roadmap
- [USER_GUIDE.md](USER_GUIDE.md) - End-user documentation
- [YOUTUBE_API.md](YOUTUBE_API.md) - YouTube Music API reference

### Architecture Decision Records
- [ADR-001: Audio Streaming Architecture](adr/ADR-001-audio-streaming-architecture.md)
- [ADR-002: PlayIntent Architecture](adr/ADR-002-playintent-architecture-2026-01-15.md)

## By Task

| Task | Read These |
|------|------------|
| Implement new backend | [backends/reference/](backends/reference/README.md), [capabilities/](capabilities/README.md) |
| Fix search/TopResult | [features/search.md](features/search.md), [arch/youtube-integration.md](arch/youtube-integration.md) |
| Fix playback | [features/playback.md](features/playback.md), [arch/playback-engine.md](arch/playback-engine.md) |
| Fix queue sync | [features/queue.md](features/queue.md), [arch/play-queue.md](arch/play-queue.md) |
| Fix navigation | [arch/ui-navigation.md](arch/ui-navigation.md) |
| Add new content type | [arch/youtube-integration.md](arch/youtube-integration.md) |
| Understand actions | [arch/action-system.md](arch/action-system.md) |
| Library/playlists | [features/library.md](features/library.md), [capabilities/playlists.md](capabilities/playlists.md) |

## Key Directories

```
yrmpc/
├── AGENTS.md               # ⭐ Start here
├── docs/
│   ├── ARCHITECTURE.md     # Routing overview
│   ├── arch/               # Zone 1: Backend-agnostic primitives
│   ├── capabilities/       # Zone 2: Backend contracts (NEW)
│   ├── features/           # Zone 3: Feature flows
│   ├── backends/           # Implementation-specific (NEW)
│   │   ├── reference/      # Contributor template
│   │   └── youtube/        # YouTube implementation
├── rmpc/                   # Main application (submodule)
│   └── src/
│       ├── backends/youtube/  # YouTube integration
│       ├── ui/panes/          # UI components
│       └── shared/api.rs      # Domain types
└── ytmapi-yrmpc/           # YouTube API client (submodule)
```

Last updated: 2025-01-11
