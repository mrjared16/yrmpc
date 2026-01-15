# Queue State Synchronization Architecture

## Problem Statement

Current queue state management has critical issues:
1. **Inconsistent events**: "queue", "playlist", "options" events scattered
2. **Missing MPV sync**: ItemsRemoved/Cleared don't update MPV playlist
3. **Optimistic update race**: TUI and daemon state can diverge
4. **No conflict resolution**: No version tracking or reconciliation

## Proposed Solution: Versioned Queue State

### Core Concept

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SINGLE SOURCE OF TRUTH                            │
│                    (Daemon QueueService)                             │
│                                                                      │
│  QueueState {                                                        │
│      version: u64,           // Increments on every mutation         │
│      items: Vec<QueueItem>,  // The actual queue                     │
│      current_index: Option<usize>,                                   │
│      repeat_mode: RepeatMode,                                        │
│      shuffle_enabled: bool,                                          │
│      shuffle_order: Vec<usize>,                                      │
│  }                                                                   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ Broadcast on change
┌─────────────────────────────────────────────────────────────────────┐
│                    UNIFIED EVENT                                     │
│                    QueueStateChanged { version, diff }               │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────┐
            │     TUI       │               │     MPV       │
            │  QueueStore   │               │   Playlist    │
            │               │               │               │
            │ Apply diff    │               │ Apply diff    │
            │ if version >  │               │ if version >  │
            │ local version │               │ local version │
            └───────────────┘               └───────────────┘
```

### State Mutation Flow

```
1. TUI sends command (optimistic update optional)
                    │
                    ▼
2. Daemon validates and applies to QueueService
                    │
                    ▼
3. QueueService increments version, computes diff
                    │
                    ▼
4. QueueStateChanged event broadcast with:
   - new_version
   - diff (added/removed/moved items)
   - full_state (for full sync requests)
                    │
                    ▼
5. All listeners (TUI, MPV, MPRIS) apply diff
   - If listener.version < new_version: apply
   - If listener.version >= new_version: ignore (already up to date)
```

### Event Consolidation

**Before (chaos):**
| Event      | Sent By                    |
|------------|----------------------------|
| "queue"    | play_intent.rs             |
| "playlist" | queue.rs, queue_events.rs  |
| "options"  | options.rs                 |
| "player"   | playback.rs                |

**After (unified):**
| Event                | Payload                           |
|----------------------|-----------------------------------|
| `QueueStateChanged`  | version, items diff, modes        |
| `PlaybackStateChanged` | position, duration, playing, etc. |

### Optimistic Updates (Optional)

For responsive UI:

```rust
// TUI: Apply optimistic update
queue_store.apply_optimistic(AddSong { song, position });

// TUI: Send command to daemon
send_command(AddSong { ... });

// Later: Receive QueueStateChanged
if event.version > local_version {
    // Daemon state wins - replace optimistic
    queue_store.apply_authoritative(event.state);
}
```

### Conflict Resolution

| Scenario | Resolution |
|----------|------------|
| TUI adds song, daemon already added same | Daemon version wins, TUI dedupes |
| TUI removes song, daemon already removed | No-op, versions match |
| TUI and daemon have different order | Daemon version wins |
| TUI has stale version | Full state sync requested |

### Implementation Plan

1. **Add version to QueueService** (beads-xxxx)
   - Atomic u64 version counter
   - Increment on every mutation

2. **Create QueueStateChanged event** (beads-xxxx)
   - Replace "queue"/"playlist"/"options" events
   - Include version and diff

3. **Update all handlers to use new event** (beads-xxxx)
   - play_intent.rs, queue.rs, options.rs
   - queue_events.rs for internal MPV sync

4. **Update TUI QueueStore** (beads-xxxx)
   - Track local version
   - Apply diffs only if version > local

5. **Add full sync mechanism** (beads-xxxx)
   - GetQueueState command returns full state + version
   - Used on TUI startup and version mismatch

### Files to Modify

| File | Change |
|------|--------|
| `services/queue_service.rs` | Add version tracking, diff computation |
| `protocol/mod.rs` | Add QueueStateChanged event type |
| `server/handlers/*.rs` | Replace event sends with QueueStateChanged |
| `ui/stores/queue_store.rs` | Add version-aware state application |
| `server/handlers/queue_events.rs` | Fix MPV sync for all event types |

### Backward Compatibility

During transition:
- Keep old event names working
- Add new QueueStateChanged in parallel
- TUI can listen to both
- Deprecate old events after migration complete
