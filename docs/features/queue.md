# Feature: Queue

## Purpose
Documents queue management flow: adding, removing, reordering tracks, and sync between UI and playback.

## When to Read
- **Symptoms**: Queue out of sync, wrong track plays, duplicate entries, reorder not working
- **Tasks**: Modify queue behavior, fix sync issues, add bulk operations

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            QueuePane (UI)                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  ContentView<QueueContent>                                        │   │
│  │    └─► SectionList showing queue items                           │   │
│  │    └─► Visual selection for bulk operations                      │   │
│  │    └─► Current track highlighting                                │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ PaneAction / Intent
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            QueueStore                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Single source of truth for queue state                          │   │
│  │                                                                   │   │
│  │  items: Vec<Song>             ◄── Ordered track list              │   │
│  │  current_index: Option<usize> ◄── Now playing position            │   │
│  │  // history tracking via playback state                          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ notifies
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PlaybackService                                  │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Subscribes to QueueStore changes                                 │   │
│  │  Triggers extraction/playback for current track                  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Add to Queue
```
1. User selects song(s) in SearchPane
   └─► PaneAction::Enqueue(songs) or Intent::AddToQueue
        │
        ▼
2. Navigator routes to QueueStore
   └─► QueueStore::add(songs, position)
   └─► position: End (play last) or Next (play next)
        │
        ▼
3. QueueStore updates internal state
   └─► Notifies subscribers (UI, PlaybackService)
        │
        ▼
4. QueuePane refreshes display
   └─► New items appear in list
```

### Play from Queue
```
1. User presses Enter on queue item
   └─► QueuePane returns PaneAction::Play(song)
        │
        ▼
2. QueueStore::set_current(index)
   └─► Updates current_index
   └─► Adds previous to history
        │
        ▼
3. PlaybackService receives notification
   └─► Extracts URL for new current track
   └─► Sends to MPV
```

### Reorder
```
1. User presses Shift+J/K on queue item
   └─► Intent::MoveUp or Intent::MoveDown
        │
        ▼
2. QueueStore::move(from, to)
   └─► Swaps items in Vec
   └─► Adjusts current_index if affected
        │
        ▼
3. UI refreshes with new order
```

## Interaction Model

### Playback Control
- **Enter on Playing Song**: Toggles pause (`client.pause_toggle()`).
- **Enter on Other Song**: Plays immediately from start (`seek_current(SeekPosition::Absolute(0.0))`).
- **Delete**: Immediately removes item and updates list via `UiEvent::Player`.

### Layout & Rendering
- **Cover Images**: Rendered using percentage-based constraints to maintain responsiveness across different pane sizes.
- **SectionList**: Uses `render()` pipeline (not simple) to support dynamic status indicators and icons.

## Key Operations

| Operation | Intent/Action | QueueStore Method |
|-----------|---------------|-------------------|
| Add to end | `AddToQueue` | `add(songs, End)` |
| Play next | `AddToQueue` + Next | `add(songs, Next)` |
| Remove | `RemoveFromQueue` | `remove(indices)` |
| Move up | `MoveUp` | `move(idx, idx-1)` |
| Move down | `MoveDown` | `move(idx, idx+1)` |
| Clear | `ClearQueue` | `clear()` |
| Shuffle | `Shuffle` | `shuffle()` |

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/player/queue_store.rs` | QueueStore state management |
| `rmpc/src/ui/panes/queue_pane.rs` | QueuePane UI |
| `rmpc/src/actions/handlers/queue.rs` | Queue action handlers |
| `rmpc/src/domain/queue_item.rs` | QueueItem struct |

## Sync Model

```
┌─────────────────┐         ┌─────────────────┐
│   QueueStore    │◄───────▶│   QueuePane     │
│ (source of truth│  notify │   (display)     │
└────────┬────────┘         └─────────────────┘
         │
         │ notify
         ▼
┌─────────────────┐
│PlaybackService  │
│ (controls MPV)  │
└─────────────────┘

Rule: UI never directly modifies queue.
      Always goes through QueueStore.
      QueueStore notifies all subscribers.
```

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Queue shows wrong items | UI not subscribed to updates | `queue_pane.rs` |
| Wrong track plays | current_index desync | `queue_store.rs` |
| Reorder not working | Move handler missing | `handlers/queue.rs` |
| Duplicates appear | Add without dedup | `queue_store.rs` add() |
| Items disappear | Incorrect remove logic | `queue_store.rs` remove() |

## See Also

- [docs/features/playback.md](playback.md) - Playback integration
- [docs/arch/action-system.md](../arch/action-system.md) - Queue actions
- [docs/arch/section-model.md](../arch/section-model.md) - Queue sections

---

## Architectural Decisions (Distilled from ADR-queue-trait-redesign)

### 1. Three-Layer Queue Trait Architecture
- **Decision**: Queue operations follow the same three-layer pattern as other backend traits:
  1. **Layer 1 (Universal)**: Basic queue operations all backends support (add, remove, clear, get_queue)
  2. **Layer 2 (Optional)**: Advanced features some backends support (shuffle, save as playlist)
  3. **Layer 3 (Backend-specific)**: Unique features (MPD's consume mode, YouTube's radio mode)
- **Rationale**: Same interface works identically for MPD and YouTube backends. UI code doesn't branch on backend type.

### 2. ToggleMode Enum for Repeat/Consume States
- **Decision**: Use `ToggleMode` enum with three states: `Off`, `On`, `Oneshot`.
- **Rationale**: Both MPD's "single" mode and "consume" mode have three states. A boolean would lose the Oneshot semantics (play once then stop vs repeat forever).
- **Impact**: UI can display accurate state icons. Backend translates to protocol-specific commands.

### 3. Crossfade and Gapless in Playback Trait
- **Decision**: Audio effects (crossfade, gapless playback) belong in `api::Playback`, not `api::Queue`.
- **Rationale**: These affect HOW audio plays, not WHAT is queued. Separation allows backends to support gapless even without queue support.

### 4. Playlists are Optional (Layer 2)
- **Decision**: Playlist operations (save, load, delete) are Layer 2 optional operations under `api::optional::Playlists`.
- **Rationale**: Not all backends may support full playlist management. YouTube supports playlists, MPD supports stored playlists - but capability varies.
- **Usage**: UI checks `backend.supports(Capability::Playlists)` before showing playlist operations.

### 5. Unified Capability Enum
- **Decision**: Single `Capability` enum covers all optional features across all backends.
- **Usage**: `backend.supports(Capability::Shuffle)` returns bool. UI hides unavailable features.
- **Rationale**: Declarative feature detection. No string-based capability checks.
