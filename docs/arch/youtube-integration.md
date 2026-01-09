# YouTube Integration Architecture

## Purpose
Defines how rmpc integrates with YouTube Music via ytmapi-yrmpc, including the adapter boundary, resilience patterns, and upstream sync workflow.

## When to Read
- **Symptoms**: Empty search results, missing IDs, "Unknown" type in logs, TopResult parsing errors
- **Tasks**: Fix YouTube API breakage, add new content types, sync upstream changes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              rmpc                                        │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                       YouTubeBackend                                │ │
│  │  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────┐  │ │
│  │  │   API Methods    │───▶│    adapter.rs    │───▶│  api::Item   │  │ │
│  │  │  search()        │    │  TryFrom impls   │    │  (stable)    │  │ │
│  │  │  get_artist()    │    │  convert_*()     │    │              │  │ │
│  │  └────────┬─────────┘    └──────────────────┘    └──────────────┘  │ │
│  │           │                                                         │ │
│  └───────────┼─────────────────────────────────────────────────────────┘ │
│              │ uses                                                      │
└──────────────┼───────────────────────────────────────────────────────────┘
               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ytmapi-yrmpc (submodule)                         │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  parse/search.rs │    │  nav_consts.rs   │    │  auth/browser.rs │   │
│  │  TopResult       │    │  JSON pointers   │    │  Cookie parsing  │   │
│  │  SearchResult*   │    │  SECTION_LIST    │    │  SAPISID hash    │   │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘   │
│                                                                          │
│  Fork of: nick42d/youtui                                                 │
│  Sync via: ./scripts/git-remotes.sh sync                                 │
└──────────────────────────────────────────────────────────────────────────┘
```

**Layer Boundaries:**
- `ytmapi-yrmpc`: External API parsing (unstable, follows YouTube changes)
- `adapter.rs`: ONLY boundary between ytmapi types and rmpc domain
- `api::Item`: Internal stable types consumed by UI

## Data Flow (Search)

```
User Query
    │
    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. YouTubeBackend::search(query)                                         │
│    └─► ytmapi::SearchQuery::new(query)                                   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. ytmapi-yrmpc parses YouTube JSON response                             │
│    └─► parse/search.rs extracts TopResult, Songs, Albums, Artists...     │
│    └─► TopResult { result_type, browse_id, video_id, thumbnails, ... }   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. adapter.rs converts to rmpc types                                     │
│    └─► convert_search_results() builds Vec<SearchSection>                │
│    └─► TryFrom<TopResult> for Item (with TopResultError handling)        │
│    └─► filter_map(|r| Item::try_from(r).ok()) ◄── Skip broken items      │
└────────────────────────────────────────────┬────────────────────────────┘
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. UI receives Vec<SearchSection>                                        │
│    └─► SearchPane renders sections: TopResults, Songs, Albums, Artists   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `ytmapi-yrmpc/src/parse/search.rs` | Parse YouTube JSON → TopResult, SearchResult* structs |
| `ytmapi-yrmpc/src/nav_consts.rs` | JSON pointer paths (SECTION_LIST, TITLE, etc.) |
| `rmpc/src/backends/youtube/adapter.rs` | TryFrom impls, convert_search_results() |
| `ytmapi-yrmpc/src/auth/browser.rs` | Cookie parsing, SAPISID extraction |
| `ytmapi-yrmpc/scripts/git-remotes.sh` | Upstream sync management |

## TopResult Conversion Logic

```rust
// adapter.rs: TryFrom<TopResult> for Item
match result.result_type {
    Song | Video  → require video_id
    Artist        → use browse_id (may be empty - see invariants below)
    Album         → require browse_id
    Playlist      → try video_id, fallback browse_id
    Station       → try video_id, fallback browse_id
    _             → try video_id → browse_id → error
}
```

**ID Field Invariants** (CRITICAL for debugging):
| Type | browse_id | video_id | Behavior if Missing |
|------|-----------|----------|---------------------|
| Song/Video | ignored | **required** | Item skipped |
| Artist | optional | ignored | Non-browsable (show but can't navigate) |
| Album | **required** | ignored | Item skipped |
| Playlist | fallback | primary | Needs at least one |
| Station | fallback | primary | Needs at least one |

**Contract**: Missing/empty `browse_id` for Artist is EXPECTED from YouTube API. 
Treat as non-browsable: display item but disable navigation action.

**ID Fields** (added by yrmpc fork, not in upstream):
- `TopResult.browse_id`: For Artist/Album/Playlist navigation
- `TopResult.video_id`: For Song/Video playback

## Resilience Patterns

| Pattern | Implementation | Purpose |
|---------|----------------|---------|
| **Unknown Variant** | `TopResultType::Unknown(String)` | Handle new YouTube content types gracefully |
| **Error Filtering** | `filter_map(\|r\| try_from(r).ok())` | Skip broken items, don't crash search |
| **Fallback IDs** | Match arms try video_id → browse_id | Handle inconsistent YouTube responses |
| **Context-Aware Mapping** | Match on result_type for subtitle | Artist shows subscribers, Song shows artist |

## Debugging Checklist

| Symptom | Likely Layer | File | Action |
|---------|--------------|------|--------|
| Empty search results | ytmapi parsing | `parse/search.rs` | Check root JSON path |
| Missing video_id/browse_id | ytmapi parsing | `parse/search.rs`, `nav_consts.rs` | Check ID extraction paths |
| "Unknown" type logged | ytmapi parsing | `parse/search.rs` | Add new TopResultType variant |
| Conversion error | adapter | `adapter.rs` | Check TryFrom match arm |
| Auth failures | ytmapi auth | `auth/browser.rs` | Check cookie/SAPISID parsing |

**Debug Workflow:**
1. Enable debug logging: `RUST_LOG=rmpc::backends::youtube=debug cargo run`
2. Reproduce issue, capture raw YouTube JSON from logs
3. Compare JSON paths against `nav_consts.rs` constants
4. To create fixture: copy JSON blob to `ytmapi-yrmpc/tests/fixtures/`
5. Fix parsing in ytmapi-yrmpc, add test with fixture
6. Build rmpc, verify fix

**See also**: [YOUTUBE_API.md](../YOUTUBE_API.md) for browseId path formats and ID conventions.

## Upstream Sync Workflow

```bash
cd ytmapi-yrmpc
./scripts/git-remotes.sh sync
# Resolves conflicts:
#   Keep OURS: Cargo.toml, browser.rs, search.rs, nav_consts.rs
#   Take THEIRS: lib.rs, artist.rs (unless we modified)
git push origin main
cd .. && git add ytmapi-yrmpc && git commit -m "chore: sync ytmapi upstream"
```

**Files to preserve during merge** (contain yrmpc-specific changes):
- `Cargo.toml` - standalone workspace fixes
- `src/auth/browser.rs` - HashMap SAPISID extraction
- `src/parse/search.rs` - TopResult browse_id/video_id fields
- `src/nav_consts.rs` - constants for our search.rs additions

## Library Operations (Not Yet Implemented)

**Status**: Query types exist in ytmapi-yrmpc but are not wired up in rmpc.

### Available Query Types

```rust
// In ytmapi-yrmpc - imported but unused in rmpc
use ytmapi_yrmpc::query::{
    GetLibraryAlbumsQuery,
    GetLibraryArtistsQuery,
    GetLibraryPlaylistsQuery,
    GetLibrarySongsQuery,
};
```

### Current Implementation Gap

| Operation | ytmapi-yrmpc | rmpc Backend | Status |
|-----------|--------------|--------------|--------|
| Get library playlists | `GetLibraryPlaylistsQuery` | Returns `vec![]` | TODO |
| Get library albums | `GetLibraryAlbumsQuery` | Returns `vec![]` | TODO |
| Get library artists | `GetLibraryArtistsQuery` | Returns `vec![]` | TODO |
| Get library songs | `GetLibrarySongsQuery` | Returns `vec![]` | TODO |
| Like song | Not in ytmapi-yrmpc | N/A | Needs upstream |
| Subscribe artist | Not in ytmapi-yrmpc | N/A | Needs upstream |

### Handler Location

```rust
// rmpc/src/backends/youtube/server/handlers/search.rs
pub fn handle_get_library(_category: &str) -> ServerResponse {
    // TODO: Implement library browsing
    ServerResponse::Library(vec![])
}
```

### Implementation Path

1. Wire existing queries in `handle_get_library()`:
   ```rust
   match category {
       "playlists" => api.json_query(GetLibraryPlaylistsQuery).await,
       "albums" => api.json_query(GetLibraryAlbumsQuery).await,
       // ...
   }
   ```

2. Add adapter conversions in `adapter.rs`:
   ```rust
   impl TryFrom<LibraryPlaylist> for Playlist { ... }
   impl TryFrom<LibraryAlbum> for Album { ... }
   ```

3. For write operations (like, subscribe), check if ytmapi-yrmpc supports them or contribute upstream

**See also**: [Library Sync](./library-sync.md) for caching layer, [Library Feature](../features/library.md) for user flow

## Adding New Content Types

1. Add variant to `TopResultType` enum in `ytmapi-yrmpc/src/parse/search.rs`
2. Update parsing logic in same file to populate new variant
3. Add match arm in `adapter.rs` TryFrom<TopResult>
4. Add section handling in `convert_search_results()` if needed
5. Add regression test with sample JSON

## See Also

- [docs/features/search.md](../features/search.md) - Full search flow including UI
- [docs/arch/playback-engine.md](playback-engine.md) - URL extraction, MPV integration
- [docs/ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture overview
- [ytmapi-yrmpc README](../../ytmapi-yrmpc/README.md) - Submodule documentation
