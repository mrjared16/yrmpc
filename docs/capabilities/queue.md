# Capability: Queue (Required)

> **Layer**: 1 (Required)
> **Trait**: `api::Queue`
> **Flag**: `Capability::Queue`
> **Implementation**: `PlayQueue` (Pure State Machine)

## Purpose

Manage the playback queue - add, remove, reorder tracks. Backed by a pure state machine to ensure consistency between UI and Audio.

## Contract

### Trait Definition

```rust
pub trait Queue {
    // Core Operations
    fn add(&self, items: &[MediaItem]) -> Result<()>;
    fn add_next(&self, items: &[MediaItem]) -> Result<()>;
    fn remove(&self, ids: &[String]) -> Result<()>;
    fn clear(&self) -> Result<()>;
    fn move_item(&self, from_id: &str, to_id: &str) -> Result<()>;
    
    // State Access
    fn get_queue(&self) -> Result<Vec<QueueItem>>;
    fn play_id(&self, id: &str) -> Result<()>;
    fn get_current_id(&self) -> Result<Option<String>>;
    
    // Modes
    fn set_shuffle(&self, shuffle: bool) -> Result<()>;
    fn set_repeat(&self, mode: RepeatMode) -> Result<()>;
}
```

### QueueItem

```rust
pub struct QueueItem {
    pub id: String,          // Stable ID
    pub song: Song,          // Full metadata
    pub is_current: bool,    // Convenience flag
}
```

### Expected Behavior

| Method | Behavior |
|--------|----------|
| `add(items)` | Appends to end of `play_order` (and `original_order`) |
| `add_next(items)` | Inserts after current track in `play_order` |
| `remove(ids)` | Removes tracks by ID from both orders |
| `clear()` | Clears all tracks |
| `move_item(from, to)` | Reorders `play_order`. `original_order` preserved if shuffle is ON. |
| `play_id(id)` | Sets `current_id` to specified ID |
| `set_shuffle(true)` | Randomizes `play_order` (keeps `current_id` playing) |

### Ordering Semantics

- **ID-Based**: All operations use `String` IDs, not indices. Indices are unstable in async environments.
- **Two-Layer Shuffle**:
  - **Shuffle Off**: `play_order` == `original_order`.
  - **Shuffle On**: `play_order` is a shuffled view. `original_order` is preserved.
- **Immediate Feedback**: The UI reflects the `PlayQueue` state immediately, even if the backend is still processing side effects (Optimistic UI).

## UI Expectations

- **Reactivity**: Subscribe to `QueueEvent`s (ItemsAdded, OrderChanged, etc.) to update the UI.
- **Optimism**: Trust the `PlayQueue` state.
- **Visuals**:
  - Highlight `current_id`.
  - Show shuffle/repeat status icons.

## Cross-References

- [Queue Feature](../features/queue.md) - User flow
- [PlayQueue Architecture](../arch/play-queue.md) - Internal design
- [Playback Capability](./playback.md) - Controls playback
