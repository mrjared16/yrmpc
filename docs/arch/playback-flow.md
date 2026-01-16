# Playback Flow (Current)

## Purpose

Documents the current end-to-end playback flow in YouTube mode after the no-stutter architecture update.

This reflects the live implementation built around `MediaPreparer` and `FfmpegConcatSource`.

## High-Level Flow

```
User action (play/select/intent)
        │
        ▼
Queue mutation + prefetch window selection
        │
        ▼
MediaPreparer.prepare(track_id, tier)
        │
        ├─ resolve URL (coalesced per track)
        ├─ stage prefix when the transport plan requires local staging
        ├─ fallback to direct for Immediate deadline/failure
        └─ return PreparedMedia
        │
        ▼
FfmpegConcatSource::build_from_prepared(prepared)
        │
        ▼
PlaybackService.playlist_append_input(&MpvInput)
        │
        ▼
MPV playlist play-index 0
```

## Authoritative Runtime Path

### 1) Mode planning

`AudioSourcePlanner::plan(mode)` (`rmpc/src/backends/youtube/audio/planner.rs`) decides transport behavior:

- Combined: stage prefix
- Direct: resolve only
- Relay: stage prefix (contract boundary today)

### 2) Playback orchestration

`orchestrator::play_position` and `orchestrator::play_position_sync` (`rmpc/src/backends/youtube/server/orchestrator.rs`) are the authoritative entry points.

For each index in the prefetch window:

1. map window position to tier (`Immediate`, `Gapless`, `Eager`)
2. call `media_preparer.prepare(video_id, tier)`
3. call `FfmpegConcatSource::build_from_prepared(&prepared)`
4. append via `playback.playlist_append_input(&input)`

After preloading the initial window, the orchestrator starts playback with `playlist_play_index(0)`.

### 3) Prepared media variants

`PreparedMedia` (`rmpc/src/backends/youtube/media/mod.rs`):

- `StagedPrefix { path, bytes, url, content_length }`
- `Direct { url }`
- `LocalFile { path }`

### 4) Runtime MPV input mapping

`FfmpegConcatSource::build_from_prepared` (`rmpc/src/backends/youtube/audio/sources/concat.rs`):

- `StagedPrefix` with partial prefix -> `lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}` + whitelist args
- `StagedPrefix` fully cached -> local file path
- `Direct` -> direct URL
- `LocalFile` -> local file path

## Immediate Tier Fallback Semantics

`YouTubeMediaPreparerHandle::prepare` sets a deadline for immediate tier. In `wait_for_prefix_result` (`rmpc/src/backends/youtube/media/preparer.rs`), immediate requests can fall back to direct stream URL when:

- prefix staging misses the deadline, or
- prefix staging fails.

This preserves click-to-audio responsiveness while background work can continue.

## Prefetch, Coalescing, and Cancellation

`YouTubeMediaPreparer` (`rmpc/src/backends/youtube/media/preparer.rs`) owns preparation jobs and queueing:

- coalesces concurrent requests by track ID
- enforces bounded pending preloads (`MAX_PENDING_PRELOADS = 8`)
- uses tier semaphores for controlled concurrency
- supports request cancellation (`CacheRequest::Cancel`)
- prunes stale work via `activate_playback_window`

The orchestrator refreshes active playback windows as playback advances, so outdated requests are cancelled rather than consuming bandwidth.

## EOF and Window Advancement

`orchestrator::handle_track_ended` drives EOF behavior:

- enters `PendingAdvance` for advance/stop paths and waits for MPV confirmation
- handles repeat/advance/stop intent
- includes early-EOF detection and one-shot recovery replay path
- extends prefetch window and appends next track through the same `MediaPreparer -> build_from_prepared -> playlist_append_input` path

## Relay Note

Relay is currently specified as a boundary contract in `rmpc/src/backends/youtube/media/relay.rs` (session/range/reconnect ownership). There is no runtime relay server in this path today.

## Key Files

| File | Role |
|------|------|
| `rmpc/src/backends/youtube/server/orchestrator.rs` | Playback orchestration + EOF handling |
| `rmpc/src/backends/youtube/media/mod.rs` | `MediaPreparer` + `PreparedMedia` contract |
| `rmpc/src/backends/youtube/media/preparer.rs` | Coalescing, fallback, bounded cancellation |
| `rmpc/src/backends/youtube/audio/planner.rs` | Delivery mode planning |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | Runtime MPV input builder |
| `rmpc/src/backends/youtube/services/playback_service.rs` | MPV append/play commands |

## Related Docs

- [playback-engine.md](playback-engine.md)
- [../ARCHITECTURE-no-stutter-playback.md](../ARCHITECTURE-no-stutter-playback.md)
- [../features/playback.md](../features/playback.md)
