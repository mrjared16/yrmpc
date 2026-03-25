# Welcome to yrmpc

**yrmpc** is a YouTube Music TUI client written in Rust, built on [rmpc](https://github.com/mierak/rmpc) and an MPV audio backend.

## Getting Started

```bash
# Build and run in dev mode
cd rmpc && cargo build
./restart_daemon_debug.sh          # Start the backend daemon
./rmpc/target/debug/rmpc --config ./config/rmpc.ron  # Start the TUI
```

> See [AGENTS.md](../AGENTS.md) for build commands, cargo rules, and when to restart the daemon.

---

## System Overview

```text
   User
     │ keypress / intent
     ▼
 ┌─────────────┐      ┌──────────────────────────────────────┐
 │     TUI     │─IPC─►│            Daemon (server)           │
 │  Navigator  │      │  Orchestrator + MediaPreparer + MPV  │
 └─────────────┘      └──────────────────────────────────────┘
        │                                  │
        ▼                                  ▼
  Queue (L1: PlayQueue)          YouTube API + AudioCache
  Bridge (L2: event handlers)   Audio prefetch + URL resolution
```

**Two logical layers for playback:**
1. **PlayQueue (L1)** — pure state machine in `rmpc/src/shared/play_queue/`. No I/O.
2. **Bridge (L2)** — orchestrates MPV, MediaPreparer, and prefetch based on PlayQueue events.

---

## Documentation Map

### Start Here (Onboarding Path)

| Step | File | What You Learn |
|------|------|----------------|
| 1 | [VISION.md](VISION.md) | Project goals and UX principles |
| 2 | [ARCHITECTURE.md](ARCHITECTURE.md) | System overview + routing table |
| 3 | [arch/playback-flow.md](arch/playback-flow.md) | **Canonical current playback behavior** |
| 4 | [adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) | Why the current playback architecture exists |

> **Breaking internal contract (2026-03 playback refactor):** during immediate startup, `PlaybackCoordinator` owns current-track identity. `PlayQueue.current_id` and transient MPV queue observations are advisory until playback is confirmed. Stale `TrackChanged(-1)` before playback start must be ignored and must not restore the previous track.

### Architecture (Backend-Agnostic)

| File | Content |
|------|---------|
| [arch/playback-flow.md](arch/playback-flow.md) | **Canonical playback flow**: coordinator ownership, immediate relay startup, delta queue reconciliation |
| [arch/audio-streaming.md](arch/audio-streaming.md) | Transport/cache deep dive: AudioCache, concat, relay transport |
| [arch/playback-engine.md](arch/playback-engine.md) | Older playback pipeline background; use `playback-flow.md` for current runtime behavior |
| [arch/play-queue.md](arch/play-queue.md) | PlayQueue state machine and Bridge event handlers |
| [arch/action-system.md](arch/action-system.md) | Intent dispatch, handlers, priorities |
| [arch/ui-navigation.md](arch/ui-navigation.md) | Navigator, panes, content stacking |
| [arch/section-model.md](arch/section-model.md) | SectionList, UI vs domain separation |
| [arch/persistence.md](arch/persistence.md) | Config, serialization, state storage |
| [arch/background-tasks.md](arch/background-tasks.md) | Scheduler, prefetch, threading |
| [arch/youtube-integration.md](arch/youtube-integration.md) | ytmapi adapter, API quirks |

### Features (End-to-End Flows)

| File | Content |
|------|---------|
| [features/playback.md](features/playback.md) | Selection → URL extraction → MPV playback |
| [features/queue.md](features/queue.md) | Queue management, EOF handling, shuffle |
| [features/search.md](features/search.md) | Query → API → Adapter → UI rendering |
| [features/navigation.md](features/navigation.md) | Pane navigation, adding new panes |
| [features/library.md](features/library.md) | Library browsing and playlist management |

### Capabilities (Backend Contracts)

> These define what each backend *must* and *may* implement.

| File | Content |
|------|---------|
| [capabilities/README.md](capabilities/README.md) | Required vs optional matrix |
| [capabilities/playback.md](capabilities/playback.md) | Play/pause/seek (L1: required) |
| [capabilities/queue.md](capabilities/queue.md) | Queue operations (L1: required) |
| [capabilities/discovery.md](capabilities/discovery.md) | Search/browse (L1: required) |
| [capabilities/playlists.md](capabilities/playlists.md) | Playlist CRUD (L2: optional) |
| [capabilities/sync.md](capabilities/sync.md) | 2-way cloud sync (L2: optional) |
| [capabilities/library-cache.md](capabilities/library-cache.md) | Caching pattern (L2: optional) |
| [capabilities/lyrics.md](capabilities/lyrics.md) | Lyrics fetching (L2: optional) |

### Backends (Implementation-Specific)

| File | Content |
|------|---------|
| [backends/youtube/README.md](backends/youtube/README.md) | YouTube Music implementation details |
| [backends/reference/README.md](backends/reference/README.md) | How to add a new backend |

### Architecture Decision Records

| ADR | Title |
|-----|-------|
| [ADR-001](adr/ADR-001-audio-streaming-architecture.md) | Audio streaming: concat+subfile over EDL |
| [ADR-002](adr/ADR-002-playintent-architecture-2026-01-15.md) | PlayIntent command architecture |
| [ADR-003](adr/ADR-003-part5-decision.md) | MediaPreparer architecture (see all parts in `adr/`) |
| [ADR-004](adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) | Immediate relay cleanup + single-coordinator ownership (**implemented**) |

---

## Find By Task

| Task | Read These |
|------|------------|
| Fix playback / MPV issues | [arch/playback-flow.md](arch/playback-flow.md), [adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) |
| Fix streaming / buffering / audio gap | [arch/audio-streaming.md](arch/audio-streaming.md), [arch/playback-flow.md](arch/playback-flow.md) |
| Redesign immediate play / relay / queue coordination | [adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md), [arch/playback-flow.md](arch/playback-flow.md) |
| Fix queue sync / shuffle | [arch/playback-flow.md](arch/playback-flow.md), [arch/play-queue.md](arch/play-queue.md) |
| Fix search / TopResult parsing | [features/search.md](features/search.md), [arch/youtube-integration.md](arch/youtube-integration.md) |
| Fix navigation / back button | [arch/ui-navigation.md](arch/ui-navigation.md) |
| Understand action dispatch | [arch/action-system.md](arch/action-system.md) |
| Library / playlists | [features/library.md](features/library.md), [capabilities/playlists.md](capabilities/playlists.md) |
| Implement a new backend | [backends/reference/README.md](backends/reference/README.md), [capabilities/README.md](capabilities/README.md) |

## Find By Symptom

| Symptom | Likely Cause | Read |
|---------|--------------|------|
| Playback doesn't start | immediate ownership / relay startup / staging issue | [arch/playback-flow.md](arch/playback-flow.md) |
| Audio cuts mid-track | RelayRuntime or upstream error | [arch/audio-streaming.md](arch/audio-streaming.md) |
| Stutter at track junction | Prefix cache miss or concat URL | [arch/audio-streaming.md](arch/audio-streaming.md) |
| Queue out of sync | L1/L2 desync or stale in-flight current-track observation | [arch/playback-flow.md](arch/playback-flow.md), [arch/play-queue.md](arch/play-queue.md) |
| Empty search results | ytmapi parsing issue | [arch/youtube-integration.md](arch/youtube-integration.md) |
| Navigation stuck | Stack corruption | [arch/ui-navigation.md](arch/ui-navigation.md) |
| Action not handled | Missing handler | [arch/action-system.md](arch/action-system.md) |
| Config not loading | Persistence / RON parsing | [arch/persistence.md](arch/persistence.md) |

---

## Key Source Locations

```
yrmpc/
├── AGENTS.md                       ⭐ Start here — build, dev workflow
├── MEMORY.md                       Lessons learned / patterns
├── docs/                           All documentation (here)
├── rmpc/src/
│   ├── backends/youtube/
│   │   ├── server/orchestrator.rs  Core playback orchestration
│   │   ├── server/playback_prepare.rs  Shared blocking-prepare helpers
│   │   ├── server/test_support.rs  Shared test doubles (RecordingMediaPreparer, MPV guard)
│   │   ├── media/preparer.rs       MediaPreparer (YouTubeMediaPreparer)
│   │   ├── media/relay_runtime.rs  Local HTTP relay daemon
│   │   ├── audio/cache.rs          AudioCache (prefix download/LRU)
│   │   ├── audio/sources/concat.rs FfmpegConcatSource
│   │   ├── audio/planner.rs        Transport mode planning
│   │   └── services/playback_service.rs  MPV IPC + transport boundary
│   ├── shared/play_queue/          PlayQueue pure state machine (L1)
│   └── ui/panes/navigator.rs       UI routing
└── config/rmpc.ron                 Dev config
```

*Last updated: 2026-03-25*
