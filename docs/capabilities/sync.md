# Capability: Sync (Optional)

> **Layer**: 2 (Optional Common)
> **Trait**: `api::optional::Sync`
> **Flag**: `Capability::Sync`

## Purpose

Two-way synchronization between local state and cloud service.

**THIS IS OPTIONAL.** Many use cases don't need sync:
- MPD: Local files, no cloud
- Offline mode: User disabled sync
- Privacy: User prefers local-only

## When to Implement

Implement if:
- Your service has cloud state (playlists, likes, history)
- Users expect changes to sync across devices
- You want real-time updates from other clients

Skip if:
- Backend is local-only (MPD, local files)
- You only need read access
- Sync complexity isn't worth it

## Contract

### Trait Definition

```rust
pub trait Sync {
    fn sync_now(&self) -> Result<SyncResult>;
    fn enable_auto_sync(&self, interval: Duration) -> Result<()>;
    fn disable_auto_sync(&self) -> Result<()>;
    fn get_sync_status(&self) -> Result<SyncStatus>;
}

pub struct SyncResult {
    pub pushed: usize,   // Changes sent to cloud
    pub pulled: usize,   // Changes received from cloud
    pub conflicts: Vec<SyncConflict>,
}

pub enum SyncStatus {
    Idle,
    Syncing,
    Error(String),
    Disabled,
}
```

### Conflict Resolution

When local and cloud conflict:
1. **Last-write-wins**: Most recent change wins
2. **Cloud-wins**: Prefer cloud state
3. **Local-wins**: Prefer local state
4. **Ask user**: Show conflict dialog

Default: Cloud-wins (matches mobile app behavior)

## UI Fallback

When `Sync` capability is absent or disabled:
- Queue/library changes are local-only
- No sync status indicator
- No "Sync Now" button

## Configuration

```ron
youtube: (
    sync_enabled: true,      // Can be disabled
    sync_interval: "5m",     // Auto-sync interval
    sync_on_startup: true,   // Sync when app starts
),
```

## Cross-References

- [Library Cache](./library-cache.md) - Caching without sync
- [YouTube Backend](../backends/youtube/README.md) - Sync implementation
