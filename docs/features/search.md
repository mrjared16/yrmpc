# Feature: Search

## Purpose
Documents the complete search flow from user query to rendered results, covering UI components, backend integration, and the adapter layer.

## When to Read
- **Symptoms**: Empty results, TopResult missing, wrong content types displayed, autocomplete broken
- **Tasks**: Add new result types, modify search layout, fix parsing issues, extend autocomplete

## Interaction Model

The Search pane follows a Vim-inspired interaction model:
- **Navigation Mode** (default): Navigate results with `j`/`k`. Press `i` to enter Insert mode.
- **Insert Mode**: Type query in the input box. Press `Esc` to return to Navigation mode.
- **Trigger Search**: Press `Enter` (in either mode) to execute the search.
- **Results**: `Enter` on a result plays it (or adds to queue based on config).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          SearchPaneV2                                    │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     ContentView<SearchableContent>                  │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │ │
│  │  │ InputGroups  │  │ Autocomplete │  │  SectionList │              │ │
│  │  │ (query box)  │  │  Dropdown    │  │  (results)   │              │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘              │ │
│  │                                            │                        │ │
│  │                              ┌─────────────┴─────────────┐          │ │
│  │                              ▼                           ▼          │ │
│  │                    ┌──────────────┐            ┌──────────────┐     │ │
│  │                    │ TopResults   │            │ Songs/Albums │     │ │
│  │                    │ Section      │            │ /Artists...  │     │ │
│  │                    └──────────────┘            └──────────────┘     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  Phase: Search (input focused) ←→ BrowseResults (results focused)       │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ Discovery::search()
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          YouTubeBackend                                  │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │ Discovery trait  │───▶│   adapter.rs     │───▶│ Vec<SearchSection>│  │
│  │ search(query)    │    │ convert_search   │    │ [TopResults,     │  │
│  │                  │    │ _results()       │    │  Songs, Albums]  │  │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ ytmapi::search()
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ytmapi-yrmpc                                     │
│  ┌──────────────────┐    ┌──────────────────┐                           │
│  │ parse/search.rs  │───▶│ TopResult        │                           │
│  │                  │    │ SearchResultSong │                           │
│  │                  │    │ SearchResultAlbum│                           │
│  └──────────────────┘    └──────────────────┘                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. User types query in InputGroups
        │
        ▼
2. SearchPaneV2::search() triggered
   └─► ctx.query().id(SEARCH_ID).query(Discovery::search(client, SearchQuery))
        │
        ▼
3. YouTubeBackend executes ytmapi::search()
   └─► HTTP request to YouTube Music API
        │
        ▼
4. ytmapi-yrmpc parses JSON response
   └─► parse/search.rs extracts TopResult, Songs, Albums, Artists, Videos
   └─► TopResult includes browse_id, video_id (yrmpc fork additions)
        │
        ▼
5. adapter.rs::convert_search_results()
   └─► TryFrom<TopResult> for Item (with error filtering)
   └─► Builds Vec<SearchSection> with key, title, items
        │
        ▼
6. QueryResult::SearchResultSectioned returned
        │
        ▼
7. SearchPaneV2::on_query_finished() receives result
   └─► ContentView updates SectionList with sections
        │
        ▼
8. UI renders sections in 1/2/3 column layout based on width
   └─► TopResults first, then Songs, Albums, Artists, Videos, Playlists
```

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/ui/panes/search_pane_v2.rs` | SearchPaneV2 component, layout, input handling |
| `rmpc/src/backends/youtube/adapter.rs` | convert_search_results(), TryFrom impls |
| `ytmapi-yrmpc/src/parse/search.rs` | TopResult, SearchResult* parsing |
| `rmpc/src/shared/api.rs` | Discovery trait definition |
| `rmpc/src/ui/widgets/input_groups.rs` | Query input component |

## TopResult Handling

TopResult is the featured result at the top of search. It requires special handling:

```rust
// adapter.rs: TryFrom<TopResult> for Item
match result.result_type {
    Song | Video  → require video_id   → Item with playback URI
    Artist        → use browse_id      → Item with browse URI (may be empty)
    Album         → require browse_id  → Item with browse URI
    Playlist      → video_id OR browse_id fallback
    Station       → video_id OR browse_id fallback
    Unknown(_)    → try video_id → browse_id → skip
}

// Error handling: skip broken items, don't crash search
results.filter_map(|r| Item::try_from(r).ok())
```

**ID Invariants per Type:**
| Type | Required ID | If Missing |
|------|-------------|------------|
| Song/Video | video_id | Skipped |
| Artist | browse_id (optional) | Show, disable browse |
| Album | browse_id | Skipped |
| Playlist/Station | Either ID | Skipped if both missing |

**Common TopResult Issues:**
- Missing browse_id → Artist shows but can't navigate (expected for some artists)
- Missing video_id → Song/Video won't play
- Unknown type → Logs warning, skips item

## Layout System

The search pane uses a responsive 3-column layout that adapts to terminal width and user configuration.

### Configurable Columns
Column widths are defined in `ctx.config.theme.column_widths` (e.g., `[20, 30, 50]`), allowing users to customize the ratio between:
1. **Categories** (Left): Filters/facets
2. **Results** (Center): Main search results
3. **Preview** (Right): Selected item details

### Layout Logic
```rust
SearchLayout::compute(phase, area_width):
    // 1. Input Phase: Full width input
    if phase == Search:
        return full_width_input
    
    // 2. Responsive Width Check
    if width >= NARROW_THRESHOLD (100):
        // 3. User Configured Ratios
        return apply_ratios(three_column_layout, config.column_widths)
    else:
        return two_column (input | results)
```

## Rendering Pipeline

Search results are rendered via the `SectionList` component, which requires a specific rendering path to support rich metadata (icons, playing state).

### Type Distinction & Icons
Correct rendering relies on the `render()` method (not `render_simple()`) and the `highlight` callback:

1. **Type Resolution**: `Item` -> `DetailItem::from()` -> `type_icon()`
   - Distinguishes Songs, Albums, Artists, Playlists, etc.
   - Fallback to generic icons if type metadata is lost.

2. **Visual States**:
   - **Headers**: Rendered as dividers, not selectable items.
   - **Playing State**: Checks `ctx.find_current_song_in_queue()` to show playing indicator.
   - **Thumbnails**: `HighlightedItem` proxies `thumbnail_url()` to the display layer.

### Rendering Flow
```
SectionList::render()
  └─► Iterates sections
       ├─► Header: Renders title (non-selectable)
       └─► Items: Renders via HighlightedItem
             ├─► Checks active state (paused/playing)
             ├─► Resolves type icon
             └─► Fetches/Displays thumbnail
```

## Concurrency & Performance

Search operations interact with the YouTube backend, which uses a polling-based concurrency model to manage request latency without blocking the UI.

### Polling Strategy
- **Interval**: 100ms polling cycle in `YouTubeProxy` (down from 1s).
- **Yielding**: The client yield loop uses `break vec![]` (not `continue`) to ensure the client is returned to the request thread immediately.
- **Responsiveness**: Ensures UI remains responsive (0% idle CPU) while waiting for HTTP responses.

## Debugging Checklist

| Symptom | Likely Layer | File | Action |
|---------|--------------|------|--------|
| Empty results | ytmapi parsing | `parse/search.rs` | Check JSON root path |
| TopResult missing ID | ytmapi parsing | `parse/search.rs` | Check browse_id/video_id extraction |
| Wrong item type | adapter | `adapter.rs` | Check TryFrom match arm |
| Autocomplete broken | UI | `search_pane_v2.rs` | Check AutocompleteDropdown |
| Layout wrong | UI | `search_pane_v2.rs` | Check SearchLayout::compute() |
| Section missing | adapter | `adapter.rs` | Check convert_search_results() |

## Extending Search

### Add New Result Type
1. Add variant to `TopResultType` in `ytmapi-yrmpc/src/parse/search.rs`
2. Add TryFrom match arm in `adapter.rs`
3. Add section in `convert_search_results()` if separate section needed
4. Add regression test with sample JSON

### Modify Layout
1. Edit `SearchLayout::compute()` in `search_pane_v2.rs`
2. Adjust `MIN_COLUMN_WIDTH` or `NARROW_THRESHOLD` constants
3. Test with various terminal widths

## See Also

- [docs/arch/youtube-integration.md](../arch/youtube-integration.md) - Adapter layer, resilience patterns
- [docs/arch/section-model.md](../arch/section-model.md) - SectionList architecture
- [docs/arch/ui-navigation.md](../arch/ui-navigation.md) - ContentView, pane navigation
- [docs/CODEBASE_MAP.md](../CODEBASE_MAP.md) - File structure reference
