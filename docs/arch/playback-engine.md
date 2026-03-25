# Playback Engine Architecture

## Purpose

Defines the current playback pipeline for YouTube mode: planning transport, preparing media, building MPV input, and keeping queue state synchronized with MPV.

## When to Read

- **Symptoms**: playback does not start, first-track delay is too high, prefetch behaves unexpectedly, EOF handling looks wrong
- **Tasks**: update playback flow, adjust transport strategy, debug preparation/cancellation behavior

## Architecture Overview

The engine is a two-layer design:

1. **PlayQueue state layer** (`rmpc/src/shared/play_queue/mod.rs`) tracks order/repeat/shuffle.
2. **Playback bridge layer** (`rmpc/src/backends/youtube/server/orchestrator.rs`) executes playback, prefetch, and MPV sync.

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 1: PlayQueue (state, ordering, repeat/shuffle)                  │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │ queue state + prefetch window
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Layer 2: Orchestrator + MediaPreparer + MPV                           │
│ 1) plan(mode) -> AudioSourcePlan                                      │
│ 2) prepare(track_id, tier) -> PreparedMedia                           │
│ 3) build_runtime_input(track_id, prepared) -> MpvInput                │
│ 4) playlist_append_input / playlist_play_index                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Transport Planning

`AudioSourcePlanner` in `rmpc/src/backends/youtube/audio/planner.rs` is the authoritative mode-to-behavior mapping.

| Mode | Transport | Prepare Action | Prefetch Policy | MPV Reconnect |
|------|-----------|----------------|-----------------|---------------|
| `Combined` | `AudioTransportTarget::Combined` | `StagePrefix` | `StagePrefix` | `false` |
| `Direct` | `AudioTransportTarget::DirectUrl` | `ResolveOnly` | `ResolveOnly` | `true` |
| `Relay` | `AudioTransportTarget::LocalRelay` | `StagePrefix` | `StagePrefix` | `true` |

## Shared Preparation Core

`MediaPreparer` (`rmpc/src/backends/youtube/media/mod.rs`) is the single public contract:

- `prepare(track_id, tier) -> Result<PreparedMedia>`
- `prefetch(track_id, tier)`
- `activate_playback_window(track_ids)`

Current YouTube implementation: `YouTubeMediaPreparerHandle` / `YouTubeMediaPreparer` in `rmpc/src/backends/youtube/media/preparer.rs`.

### Preparation Behavior

- URL resolution and prefix download are coalesced by per-track in-flight jobs.
- Prefix preloads are bounded (`MAX_PENDING_PRELOADS = 8`).
- Priority queue + semaphores enforce tier concurrency:
  - Immediate: 2
  - Gapless: 2
  - Eager: 2
  - Background: 1
- Cancellation is request-aware and window-aware:
  - `Cancel { request_id }` aborts jobs when no remaining request maps to that track.
  - `ActivateWindow` drops stale queued jobs and cancels obsolete in-flight tracks.

### Fallback Semantics

For `PreloadTier::Immediate`, `wait_for_prefix_result` may return:

- **`StreamAndCache`** (normal path): tee-prefix download plays via relay while caching to disk. This is the default for immediate cache-miss relay playback.
- **`DirectFallback`**: if relay setup fails entirely (not just prefix timeout), the coordinator swaps ownership to `TrackOwner::DirectFallback` and hands MPV a plain URL. This is the last-resort fallback.

Gapless/Eager/Background tiers wait for normal staged completion.

## Runtime MPV Input Builder

`PlaybackService::build_runtime_input` in `rmpc/src/backends/youtube/services/playback_service.rs` is the authoritative runtime boundary:

- **LocalRelay Transport**: delegates to `RelayRuntime::register_session` to serve an HTTP endpoint matching the staging plan and streaming local bytes.
- **Combined/Direct Transport**: delegates to `FfmpegConcatSource::build_from_prepared`:
  - `PreparedMedia::StagedPrefix`:
    - if `bytes >= content_length`: play local file directly
    - otherwise: build `lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}` and provide protocol whitelist args
  - `PreparedMedia::StreamAndCache`: relay streams the URL while tee-prefix downloads cache in background (default for immediate cache-miss relay)
  - `PreparedMedia::Direct`: pass URL through (fallback only)
  - `PreparedMedia::LocalFile`: pass local path through

`PlaybackService::playlist_append_input` then applies runtime args and issues `loadfile ... append`.

## Relay Status

Relay is fully implemented as an active local daemon (`RelayRuntime`) in `rmpc/src/backends/youtube/media/relay_runtime.rs`.

- Serves HTTP streaming at a dynamic port bound to `127.0.0.1`.
- Bridges cached prefix content with live HTTP upstream fetching via `reqwest`.
- Employs strict HTTP range checking and enforcing session lifetimes on endpoints.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/shared/play_queue/mod.rs` | Queue order and playback state transitions |
| `rmpc/src/backends/youtube/server/orchestrator.rs` | Playback bridge and MPV/queue sync |
| `rmpc/src/backends/youtube/audio/planner.rs` | Delivery-mode planning |
| `rmpc/src/backends/youtube/media/mod.rs` | MediaPreparer + PreparedMedia contract |
| `rmpc/src/backends/youtube/media/preparer.rs` | Coalescing, bounded queue, cancellation |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | FFmpeg subset input builder |
| `rmpc/src/backends/youtube/services/playback_service.rs` | Routing boundary for MPV transport and control |
| `rmpc/src/backends/youtube/media/relay_runtime.rs` | Local HTTP daemon relay server |

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| First track falls back to direct too often | Immediate deadline misses | `media/preparer.rs` logs around fallback_reason |
| Prefetch queue churns and drops work | Bounded queue pressure | `MAX_PENDING_PRELOADS` + queue trim logs |
| Track prep not cancelled when it should be | request_id mapping still present | cancel path in `handle_cancel_request` |
| Playback URL shape unexpected | wrong `PreparedMedia` variant | `build_from_prepared` decision path |
| Relay behavior assumptions mismatch runtime | Stale session/invalid range | Check `relay_runtime.rs` logs / `RelaySessionState` |

## See Also

- [playback-flow.md](playback-flow.md) — **canonical current playback behavior**
- [audio-streaming.md](audio-streaming.md) — transport/cache deep dive
- [ADR-004](../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) — relay architecture rationale
- [ADR-003 summary](../adr/ADR-003-media-preparer-architecture.md)
