# Task-53 & Task-39 Fix - Thumbnail and Icon Loss

**Date**: 2026-01-01
**Status**: FIXED - Awaiting user verification
**Related Tasks**: Task-53 (thumbnails), Task-39 (icons)

## Problem Summary

Search results in SearchPaneV2 showed:
- `thumbnail_url=None` for all items (Task-53)
- `type=None` for all items, causing wrong icons (Task-39)

## Root Cause Found

**Location**: `rmpc/src/backends/client.rs` lines 66-93

**Function**: `item_to_song(&Item) -> Song`

This "backward compatibility" converter was called by:
```
BackendDispatcher::search() → api::Discovery::search() → item_to_song()
```

**The Bug**: The function only copied `title` and `artist`, completely ignoring:
- `item.thumbnail`
- `item.content_type`

## The Fix Applied

```rust
// Added to item_to_song() at lines 72-85:
if let Some(ref thumb) = item.thumbnail {
    metadata.insert("thumbnail".to_string(), vec![thumb.clone()]);
}
let type_str = match item.content_type {
    api::ContentType::Track => "song",
    api::ContentType::Album => "album",
    api::ContentType::Artist => "artist",
    api::ContentType::Playlist => "playlist",
    api::ContentType::Directory => "directory",
    api::ContentType::Header => "header",
};
metadata.insert("type".to_string(), vec![type_str.to_string()]);
```

## Files Modified

1. **`rmpc/src/backends/client.rs`**:
   - Fixed `item_to_song()` (lines 66-93)
   - Added 3 tests (lines 1575-1638)

2. **`rmpc/src/backends/youtube/client.rs`**:
   - Added INFO-level diagnostics at lines 473, 479-481

3. **`rmpc/src/ui/panes/search_pane_v2.rs`**:
   - Added diagnostic at line 1130-1135 (NavigatorPane::on_query_finished)

## Key Insight: Why This Was Hard to Find

The actual code path was NOT `YouTubeProxy::search()` (MusicBackend trait).

It was:
```
SearchPaneV2::search()
  → ctx.query(|client| client.search(&filter))
  → BackendDispatcher::search()  [client.rs:611]
  → api::Discovery::search()     [returns SearchResults { items: Vec<Item> }]
  → item_to_song(&item)          [THE BUG - lossy conversion]
  → Vec<Song>
  → QueryResult::SearchResult { data }
  → on_query_finished()
  → DetailItem::from(Song)
  → UI rendering
```

There were TWO `on_query_finished` implementations:
- Line 910: Pane trait (legacy)
- Line 1120: NavigatorPane trait (actually used!)

## Tests Added

All pass:
```
cargo test --lib preserves_thumbnail
# 6 tests pass
```

Tests:
- `item_to_song_preserves_thumbnail`
- `item_to_song_preserves_content_type_as_artist`
- `item_to_song_preserves_content_type_as_album`

## Architectural Analysis Started

Identified "Lossy Adapter Chain" anti-pattern:
- Data flows through 6 conversion layers
- One incomplete adapter silently drops fields
- No compile-time protection

This is a broader architectural issue - see next section.

## Next Steps

1. **User needs to verify**: Run TUI, search, confirm thumbnails appear
2. **Architectural review**: Complete the streaming-architecture-review
3. **Similar bugs to check**:
   - `SongData::to_song()` in protocol.rs:201
   - `Item::from(&Song)` in api/content.rs:167
   - Other `*_to_song()` functions

## Commands to Verify

```bash
cd <PROJECT_ROOT>
./rmpc/target/debug/rmpc --config config/rmpc.ron
# Search for "kim long"
# Should see: thumbnails, correct icons (🎤 for artists, 💿 for albums)
```

## Uncommitted Changes

Check with:
```bash
git diff --stat
```

Consider committing:
```bash
git add rmpc/src/backends/client.rs rmpc/src/backends/youtube/client.rs rmpc/src/ui/panes/search_pane_v2.rs
git commit -m "fix(search): preserve thumbnails and content_type in item_to_song()

Fixes Task-53 (thumbnails not displaying) and Task-39 (all items render as songs).

Root cause: item_to_song() in backends/client.rs was a backward-compat
converter that only copied title/artist, ignoring thumbnail and content_type.

Added tests to prevent regression."
```
