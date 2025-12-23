# ADR: Query Result-Driven State Updates

**Status**: Accepted
**Date**: 2025-12-14
**Context**: task-18 Queue Update Event Notification

---

## Context

The YouTube backend doesn't have MPD's IdleEvent mechanism for notifying the UI when state changes. When a user adds a song to the queue, the UI doesn't update until manual refresh.

Previous attempts to solve this:
1. **Blocking idle on shared socket** - Caused 30s freeze on all operations
2. **Event channels** - Over-engineered for the problem
3. **Optimistic updates** - Song IDs missing from local updates, breaks playback

## Decision

**Match on query result TYPE, not query ID, to determine state updates.**

When a query returns `QueryResult::Queue(...)`, the event loop automatically updates `ctx.queue`. This is backend-agnostic and requires no new infrastructure.

### Before

```rust
// event_loop.rs - Only specific ID triggers update
match (id, target, result) {
    ("global_queue_update", None, MpdQueryResult::Queue(queue)) => {
        ctx.queue = queue.unwrap_or_default();
    }
    // Other IDs returning Queue are ignored!
}
```

### After

```rust
// event_loop.rs - Result type determines state update
match (id, target, result) {
    (_, _, MpdQueryResult::Queue(queue)) => {
        ctx.queue = queue.unwrap_or_default();
        render_wanted = true;
        ui.on_event(UiEvent::QueueChanged, &mut ctx)?;
    }
    (_, _, MpdQueryResult::Status { data, .. }) => {
        ctx.status = data;
        // ...
    }
    // Pattern extends to other state types
}
```

## Rationale

### Why Result-Type Matching?

1. **Self-documenting**: If a query returns `Queue`, it obviously wants queue updated
2. **Backend-agnostic**: Works for MPD, YouTube, or any future backend
3. **DRY**: No duplicate refresh logic scattered across panes
4. **Impossible to forget**: Return the right type, get the right behavior

### Why Not Event Channels?

Event channels require:
- New channel infrastructure
- Wiring between server and event loop
- Handling of async event delivery
- More code, more complexity

Result-type matching requires:
- ~15 lines of code change
- No new infrastructure
- Works with existing query system

### Why Not Optimistic Updates?

Optimistic updates (update UI before server confirms):
- Songs added locally lack server-assigned IDs
- Queue positions become inconsistent
- Playback breaks (needs ID to play specific song)

Result-type updates:
- Server processes command, returns authoritative state
- UI receives correct data with IDs
- Consistent and reliable

## Consequences

### Positive

- Queue updates immediately after add/delete
- Pattern extends to Status, Volume, Playlists
- No backend-specific workarounds needed
- Minimal code change

### Negative

- All queries returning `Queue` will update `ctx.queue` (intended behavior)
- Naming still uses `MpdQueryResult` (addressed in Phase 2)

### Neutral

- Existing `"global_queue_update"` pattern still works
- MPD backend unchanged

## Implementation

### Phase 1: Fix Queue Updates

```rust
// search_pane_v2.rs - Return updated queue
ctx.query()
    .id("enqueue_v2")
    .query(move |client| {
        client.add_song(&song, None)?;
        let queue = client.playlist_info()?;
        Ok(MpdQueryResult::Queue(Some(queue)))
    });
```

```rust
// event_loop.rs - Handle any Queue result
(_, _, MpdQueryResult::Queue(queue)) => {
    ctx.queue = queue.unwrap_or_default();
    render_wanted = true;
    log::debug!(len = ctx.queue.len(); "Queue updated");
    if let Err(err) = ui.on_event(UiEvent::QueueChanged, &mut ctx) {
        status_error!(error:? = err; "...");
    }
}
```

### Phase 2: Rename Types

```bash
# Remove MPD coupling from shared types
sed -i 's/MpdQueryResult/QueryResult/g' $(find rmpc/src -name "*.rs")
```

## Related

- [task-18: Queue Update Event Notification](../backlog/tasks/task-18%20-%20Queue-Update-Event-Notification.md)
- [VISION.md](VISION.md) - Project goals
