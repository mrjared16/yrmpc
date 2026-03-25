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
│    ├─ StreamAndCache { url }  ← relay streams while tee-prefix caches        │
│    ├─ Direct { url }          ← fallback only (relay setup failure)           │
│    └─ LocalFile { path }                                                      │
└─────────────────────┬──────────────────────────────────────────────────────────┘
                      │
                      ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ Authoritative runtime builder (one way to turn prepared media into MPV input) │
│                                                                                │
│  PlaybackService::build_runtime_input(track_id, prepared, plan) -> MpvInput   │
│    ├─ LocalRelay   → RelayRuntime::register_session(track_id, &prepared)       │
│    │                 → http://127.0.0.1:<port>/relay/sessions/{id}/stream      │
│    └─ Direct/Combined → FfmpegConcatSource::build_from_prepared(prepared)      │
│       ├─ StagedPrefix → lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}
│       ├─ Direct       → {url} passthrough                                      │
│       └─ LocalFile    → {path}                                                 │
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
| Prepared media types | `rmpc/src/backends/youtube/media/mod.rs` | `PreparedMedia::{StagedPrefix,StreamAndCache,Direct,LocalFile}` |
| Authoritative runtime builder | `rmpc/src/backends/youtube/services/playback_service.rs` | `PlaybackService::build_runtime_input` |
| Runtime implementations | `rmpc/src/backends/youtube/audio/sources/concat.rs`, `rmpc/src/backends/youtube/media/relay_runtime.rs` | `FfmpegConcatSource`, `RelayRuntime` |
| Authoritative append path | `rmpc/src/backends/youtube/services/playback_service.rs` | `PlaybackService::playlist_append_input` |

## Transport Decisions

- Combined and Relay use the same `MediaPreparer` entry point as Direct, but return staged-prefix artifacts while Direct returns `PreparedMedia::Direct`.
- **StreamAndCache** is the normal immediate cache-miss path: relay streams the URL to MPV while a tee-prefix download caches bytes in the background.
- **DirectFallback** occurs only when relay setup fails entirely (not just prefix timeout). The coordinator swaps ownership to `TrackOwner::DirectFallback` and hands MPV a plain URL.
- During immediate-play startup, `PlaybackCoordinator` owns current-track identity. `PlayQueue.current_id` and transient MPV observations are advisory until playback is confirmed. Stale `TrackChanged(-1)` before playback start must be ignored.
- Reconnect AVOptions are still not applied on `lavf://concat + subfile`. This is a known limitation.
- Relay currently serves a localhost HTTP stream via `RelayRuntime`; the planned throttling bypass keeps that localhost contract but chunks the relay -> YouTube leg while continuing to stream bytes to mpv immediately.

## Relay

Relay already has both a contract layer and a runtime server. `rmpc/src/backends/youtube/media/relay.rs` defines the session/range contract, and `rmpc/src/backends/youtube/media/relay_runtime.rs` serves the localhost relay URL used by `LocalRelay` transport. The planned throttling-bypass work hardens only the upstream fetch behavior; it does not change the player-facing relay contract.

## Evidence

- See [playback-flow.md](arch/playback-flow.md) for current runtime behavior and debugging.
- See [ADR-004](adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) for relay architecture rationale.
