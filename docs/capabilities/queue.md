# Capability: Queue (Required)

> **Layer**: 1 (Required)
> **Trait**: `api::Queue`
> **Flag**: `Capability::Queue`

## Purpose

Manage the playback queue - add, remove, reorder tracks.

## Contract

### Trait Definition

```rust
pub trait Queue {
    fn add(&self, items: &[MediaItem]) -> Result<()>;
    fn add_next(&self, items: &[MediaItem]) -> Result<()>;
    fn remove(&self, indices: &[usize]) -> Result<()>;
    fn clear(&self) -> Result<()>;
    fn move_item(&self, from: usize, to: usize) -> Result<()>;
    fn get_queue(&self) -> Result<Vec<QueueItem>>;
    fn play_at(&self, index: usize) -> Result<()>;
    fn get_current_index(&self) -> Result<Option<usize>>;
}
```

### QueueItem

```rust
pub struct QueueItem {
    pub id: String,
    pub title: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub duration: Option<Duration>,
    pub thumbnail_url: Option<String>,
}
```

### Expected Behavior

| Method | Behavior |
|--------|----------|
| `add(items)` | Append to end of queue |
| `add_next(items)` | Insert after current track |
| `remove(indices)` | Remove tracks at indices |
| `clear()` | Remove all tracks |
| `move_item(from, to)` | Reorder single track |
| `get_queue()` | Return full queue |
| `play_at(index)` | Jump to track at index |

### Ordering Semantics

- Indices are 0-based
- Current track index may change after remove/move
- Queue changes should be reflected immediately in UI

## UI Expectations

- Queue updates within 200ms
- Current track highlighted
- Drag-and-drop reordering (via move_item)

## Cross-References

- [Queue Feature](../features/queue.md) - User flow
- [Playback Capability](./playback.md) - Controls playback of queue items
