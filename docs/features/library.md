# Feature: Library

## Purpose
Documents the library browsing and management flow for user-owned content (playlists, albums, artists, songs).

## When to Read
- **Symptoms**: Library not loading, empty results, stale data, playlist operations failing
- **Tasks**: Implement YouTube library, add mutation operations, improve cache behavior

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Library Pane                                    │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     ContentView<LibraryContent>                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │ │
│  │  │ Category     │  │ SectionList  │  │  Detail      │              │ │
│  │  │ Selector     │  │ (items)      │  │  Preview     │              │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │ │
│  │        │                   │                                        │ │
│  │        ▼                   ▼                                        │ │
│  │  ┌──────────────┐  ┌──────────────────────────────────┐            │ │
│  │  │ Playlists    │  │ Cached items from LibraryCache   │            │ │
│  │  │ Albums       │  │ (24h TTL, LRU eviction)          │            │ │
│  │  │ Artists      │  │                                  │            │ │
│  │  │ Songs        │  └──────────────────────────────────┘            │ │
│  │  └──────────────┘                                                   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ get_library(category)
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          LibraryCache                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                   │
│  │Playlists │ │ Albums   │ │ Artists  │ │  Songs   │                   │
│  │ LRU(1)   │ │ LRU(1)   │ │ LRU(1)   │ │ LRU(1)   │                   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                   │
│                    TTL: 24 hours                                        │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │ cache miss
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Backend API                                     │
│  MPD: Full implementation (lsinfo, list commands)                        │
│  YouTube: Returns empty vec (TODO)                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## User Flow: Browse Library

### 1. Open Library Pane
```
User presses library hotkey → Navigator::focus_library()
                            → LibraryPane::on_focus()
                            → Request default category (Playlists)
```

### 2. Select Category
```
User selects "Albums" → get_library(LibraryCategory::Albums)
                      → Check LibraryCache
                      → Cache hit: render immediately
                      → Cache miss: fetch from backend, store, render
```

### 3. Browse Item
```
User selects album → Discovery::browse(album_id)
                   → Fetch album tracks
                   → Display in SectionList
```

## User Flow: Playlist Operations

### Create Playlist
```
User action: "Create playlist" with selection
    │
    ▼
┌─────────────────────────────────────────┐
│ create_playlist(name, song_paths)       │
│ 1. Validate name (non-empty, unique)    │
│ 2. Backend::create_playlist()           │
│ 3. cache.clear_category(Playlists)      │
│ 4. UI refresh                           │
└─────────────────────────────────────────┘
```

### Add to Playlist
```
User action: "Add to playlist" on selected items
    │
    ▼
┌─────────────────────────────────────────┐
│ add_to_playlist(playlist_name, items)   │
│ 1. Check for duplicates                 │
│   - None: add directly                  │
│   - Some: show DuplicateStrategy modal  │
│ 2. Backend::add_to_playlist_multiple()  │
│ 3. cache.clear_category(Playlists)      │
│ 4. UI refresh                           │
└─────────────────────────────────────────┘
```

### Duplicate Handling
```rust
pub enum DuplicateStrategy {
    Skip,           // Skip duplicates, add only new
    AddAnyway,      // Add all including duplicates
    Replace,        // Remove existing, add new
}
```

## Key Files

| File | Purpose |
|------|---------|
| `backends/library_cache.rs` | LRU+TTL caching layer |
| `backends/library_category.rs` | Category enum |
| `ui/modals/menu/mod.rs` | Playlist creation/add modals |
| `ui/panes/queue.rs` | Add-to-playlist from queue |
| `ui/browser.rs` | Library browsing UI |

## Backend Implementation Status

| Operation | MPD | YouTube |
|-----------|-----|---------|
| List playlists | ✅ | ❌ Empty |
| List albums | ✅ | ❌ Empty |
| List artists | ✅ | ❌ Empty |
| List songs | ✅ | ❌ Empty |
| Create playlist | ✅ | ❌ |
| Add to playlist | ✅ | ❌ |
| Delete playlist | ✅ | ❌ |
| Like song | ❌ N/A | ❌ |
| Subscribe artist | ❌ N/A | ❌ |

## Cache Behavior

### Hit/Miss Flow
```rust
// On get_library(category):
match cache.get(category) {
    Some(data) if !expired => return data,  // HIT
    _ => {
        let data = backend.fetch_library(category)?;
        cache.put(category, data.clone());  // STORE
        return data;
    }
}
```

### Invalidation Points
- After `create_playlist()` → clear Playlists
- After `add_to_playlist()` → clear Playlists
- After `delete_playlist()` → clear Playlists
- Manual refresh → clear all

## Debug Commands

```bash
# Enable cache debug logging
RUST_LOG=rmpc::backends::library_cache=debug cargo run

# Expected output:
# [DEBUG] Library cache HIT for Playlists
# [DEBUG] Library cache MISS for Albums  
# [DEBUG] Library cache EXPIRED for Artists (age: 24h 5m)
# [DEBUG] Library cache STORED for Songs (42 items)
```

## Extension: YouTube Library

To implement YouTube library support:

1. **Wire up existing queries** in `backends/youtube/`:
   ```rust
   use ytmapi_yrmpc::query::{
       GetLibraryAlbumsQuery,
       GetLibraryArtistsQuery,
       GetLibraryPlaylistsQuery,
       GetLibrarySongsQuery,
   };
   ```

2. **Implement handler** in `server/handlers/search.rs`:
   ```rust
   pub async fn handle_get_library(category: &str) -> ServerResponse {
       let api = get_api().await;
       match category {
           "playlists" => {
               let result = api.get_library_playlists().await?;
               ServerResponse::Library(convert_playlists(result))
           }
           // ... other categories
       }
   }
   ```

3. **Add mutation operations** (like, subscribe, etc.)

## Cross-References

- [Library Sync Architecture](../arch/library-sync.md) - Cache implementation details
- [YouTube Integration](../arch/youtube-integration.md) - Authentication, API patterns
- [Queue](./queue.md) - Add-to-playlist from queue context
