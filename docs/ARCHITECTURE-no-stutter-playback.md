# Playback Architecture (no-stutter update)

## Overview

The playback path is transport-neutral end-to-end. A single authoritative preparation core decides how media is staged, and a single authoritative runtime builder turns prepared artifacts into MPV inputs. Combined and Relay share the same preparation core. Direct remains both an explicit mode and an automatic fallback.

## Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ User action / queue sync                                                       │
│  ├─ async path: orchestrator::play_position(media_preparer)                   │
│  └─ sync path:  orchestrator::play_position_sync(...)                         │
└─────────────────────┬──────────────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ Authoritative preparation core                                                │
│                                                                                │
│  AudioSourcePlanner.plan(mode)                                                │
│    ├─ Combined → StagePrefix, reconnect off                                   │
│    ├─ Direct   → ResolveOnly, reconnect on                                    │
│    └─ Relay    → StagePrefix, reconnect on                                    │
│                                                                                │
│  MediaPreparer                                                                 │
│    ├─ prepare(track_id, tier) -> PreparedMedia                                │
│    └─ prefetch(track_id, tier)                                                │
│                                                                                │
│  PreparedMedia                                                                 │
│    ├─ StagedPrefix { path, bytes, url, content_length }                       │
│    ├─ Direct { url }                                                          │
│    └─ LocalFile { path }                                                      │
└─────────────────────┬──────────────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ Authoritative runtime builder (one way to turn prepared media into MPV input) │
│                                                                                │
│  FfmpegConcatSource::build_from_prepared(prepared) -> MpvInput                │
│    ├─ StagedPrefix → lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}
│    ├─ Direct       → {url} passthrough                                        │
│    └─ LocalFile    → {path}                                                   │
│                                                                                │
│  PlaybackService::playlist_append_input(&MpvInput)                            │
│    └─ apply_mpv_args(...) → loadfile {url} append                             │
└────────────────────────────────────────────────────────────────────────────────┘
```

## Key Contracts

| Concept | Location | Current shape |
|---|---|---|
| Planner (mode → plan) | `rmpc/src/backends/youtube/audio/planner.rs` | `AudioTransportTarget::{DirectUrl, Combined, LocalRelay}` |
| Shared preparer trait | `rmpc/src/backends/youtube/media/mod.rs` | `MediaPreparer::prepare/prefetch` |
| Prepared media types | `rmpc/src/backends/youtube/media/mod.rs` | `PreparedMedia::{StagedPrefix,Direct,LocalFile}` |
| Authoritative runtime builder | `rmpc/src/backends/youtube/audio/sources/concat.rs` | `FfmpegConcatSource::build_from_prepared` |
| Authoritative append path | `rmpc/src/backends/youtube/services/playback_service.rs` | `PlaybackService::playlist_append_input` |

## Transport Decisions

- Combined and Relay use the same `MediaPreparer` entry point as Direct, but return staged-prefix artifacts while Direct returns `PreparedMedia::Direct`.
- Direct fallback occurs automatically when immediate tier preparation times out or fails in `media/preparer.rs`; the planner also supports `ResolveOnly` for explicit Direct mode.
- Reconnect AVOptions are still not applied on `lavf://concat + subfile`. This is a known limitation.

## Relay

Relay is defined as a code-adjacent boundary-only contract: `rmpc/src/backends/youtube/media/relay.rs`. There is no runtime Relay server.

## Evidence

- `/.sisyphus/evidence/task-9-combined-play.log` — combined runtime builder evidence.
- `/.sisyphus/evidence/task-9-direct-fallback.log` — direct fallback evidence.
- `/.sisyphus/evidence/task-10-matrix.log` — final verification matrix.
- `/.sisyphus/evidence/task-10-eof-regression.log` — deterministic EOF repro evidence.
