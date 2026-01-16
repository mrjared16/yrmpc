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
│ 3) build_from_prepared(prepared) -> MpvInput                          │
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

For `PreloadTier::Immediate`, `wait_for_prefix_result` may return direct URL fallback when:

- deadline timeout occurs, or
- prefix staging fails.

Gapless/Eager/Background tiers wait for normal staged completion.

## Runtime MPV Input Builder

`FfmpegConcatSource::build_from_prepared` in `rmpc/src/backends/youtube/audio/sources/concat.rs` is the authoritative runtime builder:

- `PreparedMedia::StagedPrefix`:
  - if `bytes >= content_length`: play local file directly
  - otherwise: build `lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}` and provide protocol whitelist args
- `PreparedMedia::Direct`: pass URL through
- `PreparedMedia::LocalFile`: pass local path through

`PlaybackService::playlist_append_input` (`rmpc/src/backends/youtube/services/playback_service.rs`) applies runtime args and issues `loadfile ... append`.

## Relay Status

Relay is a **boundary contract** today, not an active runtime server. See `rmpc/src/backends/youtube/media/relay.rs`.

- Defines request/response/range/session contracts.
- Validates staged-prefix inputs via `RelaySessionSpec::try_from_prepared`.
- Encodes single-range-or-full policy and relay-owned reconnect ownership.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/shared/play_queue/mod.rs` | Queue order and playback state transitions |
| `rmpc/src/backends/youtube/server/orchestrator.rs` | Playback bridge and MPV/queue sync |
| `rmpc/src/backends/youtube/audio/planner.rs` | Delivery-mode planning |
| `rmpc/src/backends/youtube/media/mod.rs` | MediaPreparer + PreparedMedia contract |
| `rmpc/src/backends/youtube/media/preparer.rs` | Coalescing, bounded queue, cancellation |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | Runtime MPV input builder |
| `rmpc/src/backends/youtube/services/playback_service.rs` | MPV control and playlist append path |
| `rmpc/src/backends/youtube/media/relay.rs` | Relay transport contract boundary |

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| First track falls back to direct too often | Immediate deadline misses | `media/preparer.rs` logs around fallback_reason |
| Prefetch queue churns and drops work | Bounded queue pressure | `MAX_PENDING_PRELOADS` + queue trim logs |
| Track prep not cancelled when it should be | request_id mapping still present | cancel path in `handle_cancel_request` |
| Playback URL shape unexpected | wrong `PreparedMedia` variant | `build_from_prepared` decision path |
| Relay behavior assumptions mismatch runtime | relay is contract-only | `media/relay.rs` (no runtime server) |

## See Also

- [docs/ARCHITECTURE-no-stutter-playback.md](../ARCHITECTURE-no-stutter-playback.md)
- [docs/features/playback.md](../features/playback.md)
- [docs/adr/ADR-003-part5-decision.md](../adr/ADR-003-part5-decision.md)
