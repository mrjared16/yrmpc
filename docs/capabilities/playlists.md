# Capability: Playlists (Optional)

> **Layer**: 2 (Optional Common)
> **Trait**: `api::optional::Playlists`
> **Flags**: `Capability::Playlists`, `Capability::PlaylistCreate`, `Capability::PlaylistEdit`

## Purpose

CRUD operations on user playlists.

## When to Implement

Implement if your service supports user playlists. Skip if your backend only does playback (e.g., radio-only services).

## Contract

### Trait Definition

```rust
pub trait Playlists {
    fn list_playlists(&self) -> Result<Vec<Playlist>>;
    fn get_playlist(&self, id: &str) -> Result<Playlist>;
    fn create_playlist(&self, name: &str) -> Result<Playlist>;
    fn delete_playlist(&self, id: &str) -> Result<()>;
    fn rename_playlist(&self, id: &str, name: &str) -> Result<()>;
    fn add_tracks(&self, playlist_id: &str, track_ids: &[&str]) -> Result<()>;
    fn remove_tracks(&self, playlist_id: &str, indices: &[usize]) -> Result<()>;
    fn reorder_tracks(&self, playlist_id: &str, from: usize, to: usize) -> Result<()>;
}
```

### Capability Flags

| Flag | Meaning |
|------|---------|
| `Playlists` | Can list and view playlists |
| `PlaylistCreate` | Can create new playlists |
| `PlaylistEdit` | Can modify existing playlists |

Some services allow viewing but not editing (e.g., shared playlists).

## UI Fallback

When `Playlists` capability is absent:
- Hide playlist menu
- Hide "Add to Playlist" option
- Hide playlist tab in library

## Cross-References

- [Library Feature](../features/library.md) - User flow
- [Capability System](./README.md) - Required vs optional
