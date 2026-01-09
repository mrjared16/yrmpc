# Section Model Architecture

## Purpose
Defines how content is organized into sections and the separation between domain and UI layers.

## When to Read
- **Symptoms**: Headers duplicated, wrong section order, items in wrong section, type mismatch
- **Tasks**: Add new section type, modify section layout, fix domain-to-UI conversion

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Domain Layer                                   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Section { key: SectionKey, title: String, data: SectionData }    │   │
│  │                                                                   │   │
│  │  SectionKey: Stats | Albums | Tracks | Artists | Videos | ...    │   │
│  │  SectionData: Items(Vec<DetailItem>) | Tracks(...) | Stats(...)   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ SectionView::from(Section)
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            UI Adapter                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  SectionView { key, title, items: Vec<DetailItem>, layout }       │   │
│  │                                                                   │   │
│  │  Converts domain Section → UI-ready SectionView                  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             │ SectionList wraps
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                             UI Layer                                     │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  SectionList { sections: Vec<SectionView> }                       │   │
│  │                                                                   │   │
│  │  flatten_sections() → Vec<ListItem>                              │   │
│  │    ├─► ListItem::Header("Albums")                                │   │
│  │    ├─► ListItem::Content(DetailItem::Album(...))                 │   │
│  │    ├─► ListItem::Content(DetailItem::Album(...))                 │   │
│  │    ├─► ListItem::Header("Tracks")                                │   │
│  │    └─► ListItem::Content(DetailItem::Song(...))                  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Types

```rust
// Domain: What the data IS
struct Section {
    key: SectionKey,             // Semantic identifier
    title: String,               // Display title
    data: SectionData,           // Actual content
}

enum SectionKey {
    Stats, Albums, Tracks, Artists, Videos,
    Playlists, TopResults, RelatedArtists, // ...
}

enum SectionData {
    Items(Vec<DetailItem>),    // Generic items
    Tracks(Vec<Song>),         // Playable tracks
    Stats(ArtistStats),        // Subscriber count, etc
    Actions(Vec<Action>),      // Actionable buttons
    Paginated { items, next }, // Infinite scroll
    Error(String),             // Error state
}

// UI: How to DISPLAY it
enum ListItem {
    Header(String),            // Section header (UI-only)
    Content(DetailItem),       // Actual content
    Spacer,                    // Visual spacing
}

// Domain: Individual item
enum DetailItem {
    Song(Song),
    Album(AlbumRef),
    Artist(ArtistRef),
    Playlist(PlaylistRef),
    Video(VideoRef),
    // ...
}
```

## Critical Rule: Headers in UI Only

```
WRONG: DetailItem::Header("Albums")     ← Headers don't belong in domain
RIGHT: ListItem::Header("Albums")       ← Headers are UI-only

Domain layer deals with WHAT (songs, albums, artists)
UI layer deals with HOW TO DISPLAY (headers, spacing, layout)
```

## Data Flow

```
1. Backend returns domain data
   └─► Vec<Section> with SectionData
        │
        ▼
2. Pane converts to SectionViews
   └─► SectionView::from(section) for each
        │
        ▼
3. SectionList wraps SectionViews
   └─► SectionList { sections: Vec<SectionView> }
        │
        ▼
4. Rendering calls flatten_sections()
   └─► Inserts ListItem::Header at section boundaries
   └─► Returns flat Vec<ListItem> for rendering
        │
        ▼
5. SelectableList renders items
   └─► Skips Header for selection (non-selectable)
   └─► Renders Content items normally
```

## Architectural Decisions

### 1. Section as First-Class Domain Object
**Context**: Previously, sections were encoded as `Header` markers within a flat list of items (e.g., `[Header("Albums"), Album1, Album2, Header("Tracks"), Track1]`).
**Problem**: This caused "Nested Headers" bugs where re-grouping logic would accidentally wrap headers inside other headers. It also forced every UI component to implement complex parsing logic to reconstruct the structure.
**Decision**: `Section` is now a concrete container type in the Domain layer (`struct Section { key, title, items }`).
**Benefits**:
- **Impossible Invalid States**: A section cannot contain another section header.
- **Backend Fidelity**: Preserves the structural intent from APIs (like YouTube Music shelves).
- **Simplified UI**: The UI simply iterates over sections rather than parsing flat lists.

### 2. The Domain-UI Adapter Pattern
**Context**: We needed a consistent way to transform domain data into renderable UI components without polluting the domain with `ratatui` dependencies.
**Decision**: Implement `From<Section> for SectionView`.
**Mechanism**:
- **Domain (`Section`)**: Defines *what* the content is (data, semantic key).
- **UI (`SectionView`)**: Defines *how* it is displayed (layout, rendering state).
- **Adapter**: A pure transformation layer that maps semantic keys (`SectionKey::Stats`) to visual layouts (`Layout::StatsGrid`).

### 3. Separation of Ordering Responsibilities
**Context**: Backends return data in a "natural" order (e.g., relevance), but users define custom orders in `config.ron`.
**Decision**: 3-Layer Responsibility Chain:
1.  **Backend**: Returns `Vec<Section>` in the API's natural order.
2.  **Domain**: Stores this natural order faithfully.
3.  **UI**: Applies `config.section_order` only at the presentation layer (`apply_config_order()`).
**Why**: This ensures that search relevance is not destroyed by the domain model, while still giving users control over the final display.

### 4. SelectableList is Pure Navigation (from ADR-interactive-layout-system)
- **Decision**: `SelectableList` (formerly InteractiveListView) handles ONLY navigation and rendering. NO action interpretation.
- **Rationale**: Actions belong in the Pane or Modal, not the View. The same key (Enter) means different things in different contexts (Search: navigate, Queue: play).
- **Impact**: Views are reusable across contexts. Panes own the semantic meaning of keypresses.

### 5. Coordination Layer for List Operations
- **Decision**: Introduce `list_ops.rs` as coordination layer between panes and views.
- **Rationale**: Prevents glue code duplication. Common patterns (bulk select, move, delete) are shared.
- **Pattern**: `QueueListBehavior` trait abstracts queue operations for both `QueuePaneV2` (full pane) and `QueueModal` (popup).

### 6. Selection via Indices, Not References (from ADR-interactive-layout-system)
- **Decision**: Store selection as indices (`Vec<usize>` from `marked_indices()`) instead of holding references to items.
- **Rationale**: Avoids lifetime/borrow checker conflicts. Mutable operations (delete, move) don't invalidate selection.
- **Benefit**: Same key works for single-item and bulk operations. Context-aware action dispatch.

### 7. SectionKey Enum for Type Safety (from ADR-section-as-container)
- **Decision**: Use `SectionKey` enum for section identifiers with known variants.
- **Rationale**: Compile-time exhaustiveness checking ensures all section types are handled. New section types require explicit variant addition.
- **Trade-off**: Less runtime flexibility, but catches missing handlers at compile time. Add new variant to `SectionKey` in `domain/content.rs`.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/domain/content.rs` | Section, SectionKey, SectionData |
| `rmpc/src/domain/detail_item.rs` | DetailItem enum |
| `rmpc/src/ui/widgets/section_list.rs` | SectionList facade |
| `rmpc/src/ui/widgets/list_item.rs` | ListItem enum |
| `rmpc/src/ui/widgets/detail_stack.rs` | SectionView, build_sections |

## Adding New Section Type

1. Add variant to `SectionKey` in `domain/content.rs`
2. Add handling in `SectionData` if needed
3. Update `SectionView::from()` to handle new key
4. Add rendering case in `flatten_sections()` if special layout needed

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Duplicate headers | Header in both domain and UI | Check DetailItem usage |
| Wrong section order | SectionKey ordering | `section_list.rs` sort logic |
| Missing section | SectionView not created | `detail_stack.rs` build_sections |
| Type mismatch | Wrong DetailItem variant | `domain/detail_item.rs` |
| Items not rendering | ListItem::Content not wrapped | flatten_sections() |

## See Also

- [docs/arch/ui-navigation.md](ui-navigation.md) - ContentView uses SectionList
- [docs/features/search.md](../features/search.md) - Search sections example
- [docs/arch/youtube-integration.md](youtube-integration.md) - Section source
