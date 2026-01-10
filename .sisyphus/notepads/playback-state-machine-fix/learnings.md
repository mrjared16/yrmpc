# Learnings

- Added `InternalEvent::{TrackChanged(i32), IdleChanged(bool)}` in `rmpc/src/backends/youtube/protocol.rs`.
- `PlaybackService::start_event_loop` now takes both `event_tx: Sender<String>` (Idle/"player") and `internal_event_tx: Sender<InternalEvent>` (orchestrator events).
- MPV event loop keeps existing `"player"` event sends for TUI refresh and additionally emits internal events for orchestrator.
- For log messages that must literally include braces, escape format braces: `"{{"` / `"}}"`.
