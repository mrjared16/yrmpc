# Capability: Playback (Required)

> **Layer**: 1 (Required)
> **Trait**: `api::Playback`
> **Flag**: `Capability::Playback`

## Purpose

Control audio playback - play, pause, stop, seek.

## Contract

### Trait Definition

```rust
pub trait Playback {
    fn play(&self) -> Result<()>;
    fn pause(&self) -> Result<()>;
    fn stop(&self) -> Result<()>;
    fn seek(&self, position: Duration) -> Result<()>;
    fn get_status(&self) -> Result<PlaybackStatus>;
}
```

### PlaybackStatus

```rust
pub struct PlaybackStatus {
    pub state: PlayState,        // Playing, Paused, Stopped
    pub position: Duration,      // Current position
    pub duration: Option<Duration>, // Track duration (if known)
    pub current_track: Option<QueueItem>,
}

pub enum PlayState {
    Playing,
    Paused,
    Stopped,
}
```

### Expected Behavior

| Method | Behavior |
|--------|----------|
| `play()` | Resume if paused, start if stopped |
| `pause()` | Pause playback, retain position |
| `stop()` | Stop playback, reset position |
| `seek(pos)` | Jump to position, continue playing/paused |
| `get_status()` | Return current state |

### Error Handling

| Error | Recovery |
|-------|----------|
| No track loaded | Return `NoTrackError` |
| Stream unavailable | Show error, skip to next |
| Seek out of bounds | Clamp to valid range |

## UI Expectations

The TUI assumes:
- Status updates within 100ms of action
- Position updates at ~1s intervals during playback
- Immediate response to play/pause/stop

## Implementation Notes

### YouTube Backend
Uses MPV for playback via IPC. Status polled via MPV properties.

### MPD Backend
Uses MPD protocol commands directly.

## Cross-References

- [Playback Feature](../features/playback.md) - User flow
- [Queue Capability](./queue.md) - Track source
