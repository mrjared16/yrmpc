# Capability: Library Cache (Optional)

> **Layer**: 2 (Optional Common)
> **Trait**: None (infrastructure pattern)
> **Flag**: `Capability::LibraryCache`

## Purpose

Provides cached access to user library data (playlists, albums, artists, songs) to reduce API calls and improve UI responsiveness.

**This capability is OPTIONAL.** Backends without caching work fine - they fetch fresh data on each request.

## When to Implement

Implement library caching when:
- Your service has rate limits
- Library data changes infrequently
- You want faster UI rendering

Skip caching when:
- Data changes frequently (live playlists)
- Your API is very fast
- You need real-time accuracy

## Contract

### Expected Behavior

| Aspect | Requirement |
|--------|-------------|
| **Cache hit** | Return cached data immediately |
| **Cache miss** | Fetch from backend, store, return |
| **Expiration** | Honor TTL (default: 24h) |
| **Invalidation** | Clear after write operations |

### UI Expectations

| Scenario | TUI Behavior |
|----------|--------------|
| Cache available | Show cached data, optionally refresh in background |
| No cache | Show loading, fetch from backend |
| Cache disabled | Always fetch fresh |

## Implementation Pattern

```rust
pub struct LibraryCache {
    playlists: LruCache<(), CacheEntry>,
    albums: LruCache<(), CacheEntry>,
    artists: LruCache<(), CacheEntry>,
    songs: LruCache<(), CacheEntry>,
    ttl: Duration,
}

impl LibraryCache {
    pub fn get(&mut self, category: LibraryCategory) -> Option<Vec<LibraryItem>> {
        let cache = self.cache_for(category);
        cache.get(&()).and_then(|entry| {
            if entry.is_expired(self.ttl) {
                cache.pop(&());
                None
            } else {
                Some(entry.data.clone())
            }
        })
    }
    
    pub fn put(&mut self, category: LibraryCategory, data: Vec<LibraryItem>) {
        self.cache_for(category).put((), CacheEntry::new(data));
    }
    
    pub fn invalidate(&mut self, category: LibraryCategory) {
        self.cache_for(category).clear();
    }
}
```

## Categories

```rust
pub enum LibraryCategory {
    Playlists,
    Albums,
    Artists,
    Songs,
}
```

## Cache Invalidation

Invalidate cache after write operations:

```rust
// After creating playlist
cache.invalidate(LibraryCategory::Playlists);

// After liking a song
cache.invalidate(LibraryCategory::Songs);
```

## Configuration

```ron
library: (
    cache_enabled: true,    // Set false to disable
    cache_ttl: "24h",       // Time-to-live
),
```

## Backend Examples

| Backend | Cache Strategy |
|---------|----------------|
| YouTube | 24h TTL, invalidate on mutations |
| MPD | Short TTL (local DB updates frequently) |
| Spotify | 1h TTL (playlists change often) |
| Tidal | 24h TTL |

## Cross-References

- [Library Feature](../features/library.md) - User flow for library browsing
- [Capability System](./README.md) - Required vs optional capabilities
