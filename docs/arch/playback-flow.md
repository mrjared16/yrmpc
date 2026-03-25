# Playback Flow (Current)

## Purpose

Documents the current end-to-end playback flow in YouTube mode after ADR-004 immediate-relay cleanup.

This reflects the live implementation built around `PlaybackCoordinator`, `MediaPreparer`, and relay-first immediate startup.

## High-Level Flow

```
User action (play/select/intent)
        │
        ▼
Queue mutation + resolved playback horizon
        │
        ▼
PlaybackCoordinator.begin_immediate_play(current)
        │
        ├─ current track only: MediaPreparer.prepare(track_id, Immediate)
        ├─ cache hit -> PreparedMedia::StagedPrefix
        ├─ cache miss in relay-first modes -> PreparedMedia::StreamAndCache
        └─ relay setup failure -> explicit direct fallback for current track only
        │
        ▼
PlaybackService::build_runtime_input / current-track direct fallback wrapper
        │
        ├─ relay strategy -> RelayRuntime::register_session() -> local HTTP URL
        └─ explicit direct fallback -> upstream URL for same current track
        │
        ▼
PlaybackService.playlist_append_input(&MpvInput)
        │
        ▼
MPV playlist play-index 0
        │
        ▼
Playback started hook -> coordinator activates next-three background prefix work
```

## Authoritative Runtime Path

### 1) Mode planning

`AudioSourcePlanner::plan(mode)` (`rmpc/src/backends/youtube/audio/planner.rs`) decides transport behavior:

- Combined: stage prefix
- Direct: resolve only
- Relay/Auto: relay transport with live tee-miss support for immediate cache misses

### 2) Playback orchestration

`orchestrator::play_position` and `orchestrator::play_position_sync` (`rmpc/src/backends/youtube/server/orchestrator.rs`) are the authoritative entry points.

On immediate play:

1. compute the resolved playback horizon from queue/playback order
2. update `PlaybackCoordinator` with the current track and horizon snapshot
3. prepare only the current track with `PreloadTier::Immediate`
4. build the runtime input, allowing explicit relay-to-direct fallback only for this current track
5. append the single current-track input and start MPV playback
6. after playback actually starts, the orchestrator emits one-shot `PlaybackStarted` from the active MPV playback-confirmation edge and kicks the prefix-window worker
7. the worker activates the coordinator-owned next-three window, claims one prefix job at a time, prepares it in background, then reports `finish_prefix_job` / `fail_prefix_job` back to the coordinator

While immediate prepare is still in flight, stale MPV `TrackChanged` noise from tearing down the old playlist is ignored for coordinator resync purposes. That now applies to both relay-first startup and the direct-fallback branch, preventing a `stop/clear -> TrackChanged(-1)` race from restoring the previous song as the coordinator's current track before the new immediate play actually starts.

Queue-add handling updates the coordinator horizon and warms background extraction candidates, but no longer performs ad hoc immediate/gapless/eager window activation.

Active-playback queue reconciliation is now delta-based: it keeps any unchanged future tail entries already present in MPV and prepares/appends only newly exposed tracks instead of rebuilding the full future window on every append/mutation.

### 3) Prepared media variants

`PreparedMedia` (`rmpc/src/backends/youtube/media/mod.rs`):

- `StagedPrefix { path, bytes, url, content_length }`
- `StreamAndCache { url, content_length, prefix_path, prefix_size }`
- `Direct { url }`
- `LocalFile { path }`

### 4) Runtime MPV input mapping

`PlaybackService::build_runtime_input` delegates to transport implementations:

- **LocalRelay transport**: `RelayRuntime::register_session` generates a local daemon HTTP URL (`http://127.0.0.1:<port>/relay/...`) bridging either:
  - `StagedPrefix` cache-hit relay, or
  - `StreamAndCache` tee-miss relay.
- **Current immediate track only**: if relay setup fails as a whole, orchestrator uses the playback-service direct-fallback path and swaps coordinator ownership from `ImmediateRelay` to `DirectFallback`.
- **Combined/Direct transport**: `PreparedMediaInputAdapter::build_from_prepared` handles:
  - `StagedPrefix` with partial prefix -> `lavf://concat:{path}|subfile,,start,{bytes},end,0,,:{url}` + whitelist args
  - `StagedPrefix` fully cached -> local file path
  - `StreamAndCache` -> direct upstream URL if the relay path is unavailable
  - `Direct` -> direct URL
  - `LocalFile` -> local file path

## Immediate Tier Fallback Semantics

`YouTubeMediaPreparerHandle::prepare` sets a deadline for immediate tier. Current immediate behavior is:

- cache hit -> return `StagedPrefix`
- cache miss in relay-first modes -> return `StreamAndCache` immediately and let the relay tee prefix bytes into cache while playback begins
- direct mode -> return `Direct`
- relay strategy failure as a whole -> swap coordinator owner to `DirectFallback` and play the same current track via direct URL

After a tee-miss startup succeeds, the relay runtime promotes the written prefix into `AudioCache` metadata, so later prepares for the same track can take the normal staged-prefix cache-hit path instead of teeing again.

Gapless/eager prefix downloads now reuse the original resolved stream URL instead of invalidating and re-extracting immediately after the prefix write completes. That avoids duplicate extractor requests and preserves extractor-cache hits for the same track.

This preserves click-to-audio responsiveness while background next-three work can continue without competing for the current track.

## Prefetch, Coalescing, and Cancellation

`YouTubeMediaPreparer` (`rmpc/src/backends/youtube/media/preparer.rs`) owns preparation jobs and queueing:

- coalesces concurrent requests by track ID
- enforces bounded pending preloads (`MAX_PENDING_PRELOADS = 8`)
- uses tier semaphores for controlled concurrency
- supports request cancellation (`CacheRequest::Cancel`)
- prunes stale work via `activate_playback_window`

The coordinator now owns the resolved horizon and next-three prefix window. The preparer still handles background jobs, but queue ownership and current-track protection are centralized in the coordinator, and production wiring now drives `claim_next_prefix_job()` / `finish_prefix_job()` through the prefix-window worker.

Queue-event horizon resync treats `PlayQueue.current_id` as advisory rather than authoritative. If queue mutations arrive while an immediate play is still in flight, the coordinator preserves the pending current track and rotates the resolved horizon from that in-flight track instead of snapping back to stale queue state. Once playback is established, explicit observed current-track IDs can still repair coordinator drift before recomputing the next-three window, and current-track background extract results are rejected even if ownership metadata was previously cleared. This prevents append+repeat mutations from re-admitting the playing song into background prefix work.

Stop/clear flows now fully reset coordinator playback state, and the prefix-window worker revalidates a claimed background job before preparing it. If a once-future track becomes the new current track before background preparation begins, that stale claim is dropped instead of running as a background prefix job.

## EOF and Window Advancement

`orchestrator::handle_track_ended` drives EOF behavior:

- enters `PendingAdvance` for advance/stop paths and waits for MPV confirmation
- handles repeat/advance/stop intent
- includes early-EOF detection and one-shot recovery replay path
- extends prefetch window and appends next track through the same `MediaPreparer -> build_runtime_input -> playlist_append_input` path

## Relay Note

Relay is fully implemented as a local HTTP daemon (`RelayRuntime`) that serves either a cache-hit prefix or a tee-miss startup path and then continues upstream using planner-selected read plans. Strategy selection is computed once before streaming the response body, and `stream_upstream_segment` is now a thin executor for a single `UpstreamReadPlan`; retry ordering lives above it in the relay planner/runtime orchestration.

Relay diagnostics now log a single request-start record per client request plus contextual retry/short-read warnings keyed by session, track, strategy, peer, host, and byte range. This gives enough context to diagnose premature EOF and fallback behavior without relying on raw `reqwest::connect` logs alone.

## Key Files

| File | Role |
|------|------|
| `rmpc/src/backends/youtube/server/orchestrator.rs` | Playback orchestration + EOF handling |
| `rmpc/src/backends/youtube/server/playback_coordinator.rs` | Current-track owner + resolved horizon snapshot |
| `rmpc/src/backends/youtube/media/mod.rs` | `MediaPreparer` + `PreparedMedia` contract |
| `rmpc/src/backends/youtube/media/preparer.rs` | Coalescing, fallback, bounded cancellation |
| `rmpc/src/backends/youtube/audio/planner.rs` | Delivery mode planning |
| `rmpc/src/backends/youtube/media/relay_planner.rs` | Product-level relay strategy planning |
| `rmpc/src/backends/youtube/media/upstream_plan.rs` | Transport-level upstream read plans |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | Runtime MPV input builder |
| `rmpc/src/backends/youtube/services/playback_service.rs` | MPV append/play commands |

## Related Docs

- [playback-engine.md](playback-engine.md)
- [../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md)
- [ARCHITECTURE-no-stutter-playback.md](ARCHITECTURE-no-stutter-playback.md)
- [../features/playback.md](../features/playback.md)
