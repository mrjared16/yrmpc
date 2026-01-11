# Feature: Queue

## Purpose
Documents queue management flow: adding, removing, reordering tracks, and sync between UI and playback.

## When to Read
- **Symptoms**: Queue out of sync, wrong track plays, duplicate entries, reorder not working
- **Tasks**: Modify queue behavior, fix sync issues, add bulk operations

## Architecture Overview

The system uses a **Two-Layer Architecture** to ensure the TUI and Audio never desync.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            QueuePane (UI)                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Displays PlayQueue snapshot                                     │   │
│  │  Sends Commands (Add, Remove, Move)                              │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ Command (e.g., QueueCommand::Add)
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 1: PlayQueue (State)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Pure State Machine                                              │   │
│  │  Updates internal state immediately (Optimistic)                 │   │
│  │  Emits Events                                                    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ Event (e.g., QueueEvent::ItemsAdded)
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 2: Playback Bridge                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Handles side effects                                            │   │
│  │  • Resolve URLs                                                  │   │
│  │  • Prefetch audio                                                │   │
│  │  • Update MPV playlist                                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Add to Queue
```
1. User selects song(s) in SearchPane
   └─► Dispatch QueueCommand::Add(songs)
        │
        ▼
2. PlayQueue (Layer 1)
   └─► Appends to original_order and play_order
   └─► Emits QueueEvent::ItemsAdded
   └─► Updates UI State (New items appear instantly)
        │
        ▼
3. Playback Bridge (Layer 2)
   └─► Receives ItemsAdded event
   └─► Triggers URL Resolver (async)
   └─► Triggers Audio Prefetcher (download in background)
```

### Shuffle Toggle
```
1. User presses 'z' (Toggle Shuffle)
   └─► Dispatch QueueCommand::SetShuffle(true)
        │
        ▼
2. PlayQueue (Layer 1)
   └─► Generates new random play_order
   └─► Preserves current_id at front (or in place)
   └─► Emits QueueEvent::OrderChanged
   └─► Updates UI (Order changes instantly)
        │
        ▼
3. Playback Bridge (Layer 2)
   └─► Receives OrderChanged event
   └─► Calculates diff for MPV
   └─► Sends atomic `loadfile ... append` commands to MPV
   └─► Audio continues playing uninterrupted
```

### Play from Queue
```
1. User presses Enter on queue item
   └─► Dispatch QueueCommand::PlayId(id)
        │
        ▼
2. PlayQueue (Layer 1)
   └─► Updates current_id
   └─► Emits QueueEvent::CurrentChanged
        │
        ▼
3. Playback Bridge (Layer 2)
   └─► Receives CurrentChanged
   └─► Sends `play` command to MPV
   └─► MPV loads new track
```

## Interaction Model

### ID-Based Reliability
Unlike previous versions, all operations use **IDs (Strings)**, not indices.
- **Reorder**: `move(id, target_id)`
- **Remove**: `remove(id)`
- **Play**: `play(id)`

This prevents "race conditions" where an index becomes stale while an async operation completes.

### Optimistic UI
The UI reflects the state of `PlayQueue` immediately. It does not wait for MPV to confirm.
- If you delete a track, it vanishes from the UI instantly.
- If MPV fails to skip the deleted track, the Bridge handles the correction, but the user feels instant responsiveness.

## Key Operations

| Operation | Command | Effect |
|-----------|---------|--------|
| Add to end | `Add(songs)` | Appends to queue |
| Play next | `AddNext(songs)` | Inserts after current |
| Remove | `Remove(ids)` | Removes from all orders |
| Move | `Move(id, target)` | Reorders `play_order` |
| Shuffle | `SetShuffle(bool)` | Toggles random order |
| Repeat | `SetRepeat(mode)` | Cycles Off/One/All |

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/shared/play_queue.rs` | **Layer 1**: State Machine |
| `rmpc/src/backends/youtube/bridge/` | **Layer 2**: Handlers |
| `rmpc/src/ui/panes/queue_pane.rs` | UI Implementation |

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| UI shows items but no audio | Bridge didn't receive/handle event | `bridge/handlers.rs` |
| "Ghost" tracks play | MPV playlist out of sync with PlayQueue | `bridge/mpv.rs` |
| Shuffle resets on track change | Repeat mode logic error | `play_queue.rs` |
| Items vanish on shuffle | `original_order` not preserved | `play_queue.rs` |

## See Also

- [docs/arch/play-queue.md](../arch/play-queue.md) - Deep dive into architecture
- [docs/capabilities/queue.md](../capabilities/queue.md) - API contract
