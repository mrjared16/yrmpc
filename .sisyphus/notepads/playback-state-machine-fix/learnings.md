# Learnings

- Added `InternalEvent::{TrackChanged(i32), IdleChanged(bool)}` in `rmpc/src/backends/youtube/protocol.rs`.
- `PlaybackService::start_event_loop` now takes both `event_tx: Sender<String>` (Idle/"player") and `internal_event_tx: Sender<InternalEvent>` (orchestrator events).
- MPV event loop keeps existing "player" event sends for TUI refresh and additionally emits internal events for orchestrator.
- For log messages that must literally include braces, escape format braces: "{{" / "}}".
- Added `PlaybackState::PendingAdvance { since: Instant, from_position: usize }` and a minimal timeout helper to support event-driven EOF transitions.
- `PlaybackStateTracker::transition` treats `PendingAdvance { .. }` in the `from` parameter as a variant match (ignores payload), avoiding brittle `Instant` equality requirements.
- Added unit tests: `test_pending_advance_transition` and `test_pending_advance_timeout`.
