# Feature: Playback

## Purpose

Documents the real playback feature path from user action to MPV output in the current YouTube backend implementation.

## When to Read

- **Symptoms**: playback does not start, wrong queue item plays, first-track delay is high, EOF behavior is wrong
- **Tasks**: modify playback behavior, debug queue/MPV sync, adjust tiering or prefetch behavior

## End-to-End Flow

```
UI action / PlayIntent
      │
      ▼
server/handlers/play_intent.rs
      │
      ▼
orchestrator::play_position_sync / play_position
      │
      ├─ build prefetch window (current + lookahead)
      ├─ media_preparer.activate_playback_window(...)
      ├─ media_preparer.prepare(track_id, tier)
      ├─ playback.build_runtime_input(track_id, prepared)
      └─ playback.playlist_append_input(...)
      │
      ▼
playback.playlist_play_index(0)
      │
      ▼
MPV audio output
```

## Playback Intents

`PlayIntent` (`rmpc/src/backends/youtube/protocol/play_intent.rs`) controls how queue/playback starts:

- **Context**: replace queue and play at offset
- **Next**: insert tracks after current item
- **Append**: add tracks to queue tail
- **Radio**: create seed-based queue start

`handle_play_with_intent` (`rmpc/src/backends/youtube/server/handlers/play_intent.rs`) derives preload priorities and routes playback start through orchestrator entry points.

## Tiered Preparation Behavior

`PreloadTier` ordering: `Immediate > Gapless > Eager > Background`.

- Immediate: user is waiting; may fallback to direct URL if staged prefix misses deadline
- Gapless: next-track preparation for smooth transition
- Eager/Background: deeper queue warming

The implementation uses `MediaPreparer` (`rmpc/src/backends/youtube/media/mod.rs`) as the single contract.

## PreparedMedia to MPV

`PreparedMedia` variants:

- `StagedPrefix { path, bytes, url, content_length }` — cached prefix + remainder via concat
- `StreamAndCache { url }` — relay streams URL while tee-prefix downloads cache (normal immediate cache-miss path)
- `Direct { url }` — fallback only, when relay setup fails entirely
- `LocalFile { path }` — local file playback

`PlaybackService::build_runtime_input` (`rmpc/src/backends/youtube/services/playback_service.rs`) maps them to final MPV input based on transport:

- **LocalRelay Transport**: registers `PreparedMedia` with `RelayRuntime` for local HTTP streaming. `StreamAndCache` streams the URL while caching.
- **Combined/Direct Transport**: uses `FfmpegConcatSource` to map:
  - staged partial prefix -> `lavf://concat...|subfile...`
  - staged full prefix -> local file
  - direct -> direct URL (fallback only)

### Coordinator Ownership During Startup

During immediate-play startup, `PlaybackCoordinator` owns current-track identity. `PlayQueue.current_id` and transient MPV observations are advisory until playback is confirmed. Stale `TrackChanged(-1)` before playback start must be ignored and must not restore the previous track. This applies to both relay-first and direct-fallback startup paths.

## Queue and EOF Synchronization

`orchestrator::handle_track_ended` and `handle_track_changed` keep queue state aligned with MPV:

- captures advance intent at EOF (`Advance`, `Repeat`, `Stop`)
- uses pending-advance confirmation flow
- extends prefetch window during in-window auto-advance
- includes early-EOF recovery replay for suspicious truncation cases

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/backends/youtube/server/handlers/play_intent.rs` | Intent validation + dispatch |
| `rmpc/src/backends/youtube/server/orchestrator.rs` | Core playback orchestration and EOF handling |
| `rmpc/src/backends/youtube/media/mod.rs` | `MediaPreparer` + `PreparedMedia` contract |
| `rmpc/src/backends/youtube/media/preparer.rs` | Coalescing, cancellation, fallback behavior |
| `rmpc/src/backends/youtube/audio/planner.rs` | Delivery-mode planning |
| `rmpc/src/backends/youtube/audio/sources/concat.rs` | FFmpeg subset input builder |
| `rmpc/src/backends/youtube/services/playback_service.rs` | Routing boundary for MPV transport and control |
| `rmpc/src/backends/youtube/media/relay_runtime.rs` | Local HTTP daemon relay server |

## Debugging Checklist

| Symptom | Likely Cause | Check |
|---------|--------------|-------|
| Playback start is slow | immediate tier fallback or extractor latency | `media/preparer.rs` fallback logs |
| Next track gaps | gapless tier not prepared in time | prefetch window + tier mapping in orchestrator |
| Wrong track advanced | prefetch window/position sync issue | `handle_within_window_advance` |
| Repeated EOF mid-track | upstream instability | early-EOF recovery path in orchestrator |
| MPV command works but queue UI diverges | pending-advance sync issue | state transitions in `PlaybackStateTracker` |

## See Also

- [../arch/playback-flow.md](../arch/playback-flow.md) — **canonical current playback behavior**
- [../arch/audio-streaming.md](../arch/audio-streaming.md) — transport/cache deep dive
- [../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md](../adr/ADR-004-immediate-relay-path-cleanup-2026-03-24.md) — relay architecture rationale
