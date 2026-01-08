# Capability: Discovery (Required)

> **Layer**: 1 (Required)
> **Trait**: `api::Discovery`
> **Flag**: `Capability::Discovery`

## Purpose

Search and browse content - find music to play.

## Contract

### Trait Definition

```rust
pub trait Discovery {
    fn search(&self, query: &str) -> Result<SearchResults>;
    fn browse(&self, id: &str, browse_type: BrowseType) -> Result<BrowseResults>;
    fn get_recommendations(&self) -> Result<Vec<MediaItem>>;
}
```

### SearchResults

```rust
pub struct SearchResults {
    pub top_result: Option<MediaItem>,
    pub songs: Vec<Song>,
    pub albums: Vec<Album>,
    pub artists: Vec<Artist>,
    pub playlists: Vec<Playlist>,
}
```

### BrowseType

```rust
pub enum BrowseType {
    Artist,
    Album,
    Playlist,
    Radio,
}
```

### Expected Behavior

| Method | Behavior |
|--------|----------|
| `search(query)` | Return mixed results for query |
| `browse(id, type)` | Return contents of artist/album/playlist |
| `get_recommendations()` | Return personalized suggestions |

### Error Handling

| Error | Recovery |
|-------|----------|
| No results | Return empty results, not error |
| Rate limited | Retry with backoff |
| Network error | Show error, allow retry |

## UI Expectations

- Search results within 500ms
- Pagination for large result sets
- Type filtering (songs, albums, etc.)

## Cross-References

- [Search Feature](../features/search.md) - User flow
- [Playback Capability](./playback.md) - Play search results
