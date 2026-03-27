# UI Navigation Architecture

## Purpose
Defines the navigation model: Navigator, pane stacking, ContentView, and the three-level navigation system.

## When to Read
- **Symptoms**: Back button stuck, pane not pushed, content not updating, wrong pane displayed
- **Tasks**: Add new pane type, modify navigation flow, fix stack corruption

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                 Ui                                       │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                           Navigator                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │                      Pane Stack                              │  │  │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │  │  │
│  │  │  │ TabPane │──│ Detail  │──│ Detail  │  ◄── Top = Active    │  │  │
│  │  │  │ (root)  │  │ Pane 1  │  │ Pane 2  │                      │  │  │
│  │  │  └─────────┘  └─────────┘  └─────────┘                      │  │  │
│  │  │       ▲            ▲            ▲                            │  │  │
│  │  │       │            │            │                            │  │  │
│  │  │    NavigateTo   NavigateTo   Current                         │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  │                                                                    │  │
│  │  Tab Bar: [Search] [Queue] [Library] [Settings]                   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Navigator Ownership & Layout (2026-01)

To prevent state desync and memory waste, the Navigator acts as the sole owner of all pane instances.

- **Single Ownership**: Navigator owns `SearchPaneV2`, `QueuePaneV2`, etc.
- **PaneContainer Role**: When `legacy_panes.enabled=false`, `PaneContainer` is layout-only. It does NOT instantiate panes but receives references (`&Pane`) from Navigator for rendering.
- **Benefits**:
    - Eliminates duplicate pane instances (one in Navigator, one in PaneContainer).
    - Ensures single source of truth for selection/scroll state.
    - Simplifies ownership model.

## Three-Level Navigation

```
Level 1: MODE (Tab switching)
├── Search Tab ←→ Queue Tab ←→ Library Tab ←→ Settings Tab
│
Level 2: INTRA-PANE (Within current pane)
├── Sections ↕ Items (j/k navigation)
├── Columns ↔ (h/l in multi-column)
│
Level 3: HISTORY (Stack push/pop)
├── Push: Enter on item → Detail pane
├── Pop: Backspace/Esc → Previous pane
```

## Pane Types

| Type | Purpose | Example | Implementation |
|------|---------|---------|----------------|
| **TabPane** | Root-level tabs, always in tab bar | SearchPane, QueuePane | Uses `ContentView` or custom layout |
| **DetailPane** | Pushed onto stack, shows entity details | ArtistPane, AlbumPane | Usually `ContentView<BrowsableContent>` |

### V2 Implementations
- **SearchPaneV2**: Uses `ContentView<SearchableContent>` + `SelectableList` (~290 lines) replacing legacy monolithic ~2000 line implementation. Reuses `InputGroups` for filters.
- **QueuePane**: Uses `ContentView<QueueContent>` with layered sections (Now Playing, Up Next).

```rust
// TabPane: Implements both traits
trait TabPane: NavigatorPane {
    fn tab_title(&self) -> &str;
    fn tab_icon(&self) -> &str;
}

// DetailPane: Only NavigatorPane
trait NavigatorPane {
    fn on_key(&mut self, key: KeyEvent) -> PaneAction;
    fn render(&self, frame: &mut Frame, area: Rect);
    // V2: Also handles async events and query completion
    fn on_event(&mut self, event: &AppEvent) -> PaneAction;
    fn on_query_finished(&mut self, id: String, data: LoadResult);
}
```

## ContentView Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ContentView<C>                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                         SectionList                                │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │ Section: "Top Results"                                       │  │  │
│  │  │   └─► SelectableList (items)                              │  │  │
│  │  ├─────────────────────────────────────────────────────────────┤  │  │
│  │  │ Section: "Songs"                                             │  │  │
│  │  │   └─► SelectableList (items)                              │  │  │
│  │  ├─────────────────────────────────────────────────────────────┤  │  │
│  │  │ Section: "Albums"                                            │  │  │
│  │  │   └─► SelectableList (items)                              │  │  │
│  │  └─────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  C = Content type (SearchableContent, BrowsableContent, etc.)           │
└─────────────────────────────────────────────────────────────────────────┘

### Event Bubbling Principle
`ContentView` does not interpret semantic actions. It converts raw key events into abstract `ContentAction`s (Activate, MoveUp, Back) and bubbles them to the parent Pane.
- **ContentView**: "User pressed Enter" → Returns `ContentAction::Activate`
- **Pane**: Decides meaning (e.g., SearchPane → NavigateTo; QueuePane → Play)
```

## Navigation Flow

```
1. User presses Enter on Artist in search results
        │
        ▼
2. SearchPane returns PaneAction::NavigateTo(EntityRef::Artist(id))
        │
        ▼
3. Navigator::request_navigation() owns the async detail fetch
   └─► switches to the destination detail pane immediately
   └─► renders a loading placeholder while detail data is pending
   └─► ignores stale detail responses after cancel/back navigation
   └─► pushes accepted detail content into the navigator-owned detail pane
        │
        ▼
4. User presses Backspace
        │
        ▼
5. Active pane returns PaneAction::BackPane
        │
        ▼
6. Navigator pops pane_stack
   └─► Previous pane (SearchPane) becomes active
```

## Redraw Ownership Contract

In Navigator mode, **Navigator owns synchronous key-driven redraw scheduling**.

- `NavigatorPane::handle_key()` should return semantic `PaneAction`s.
- Pane-local synchronous state changes should:
  - mutate local pane state,
  - consume the key,
  - return `PaneAction::Handled`.
- `Navigator::handle_key()` schedules `ctx.render()` when a consumed key returns `PaneAction::Handled`.
- Navigator-owned panes should not call `ctx.render()` directly for normal synchronous key handling.

This prevents panes from silently mutating selection/filter state without producing an immediate redraw.

## Interactive Components

The navigation system relies on a unified interactive component library designed for SOLID compliance and OCP (Open-Closed Principle).

### Core Components
- **SelectableList**: The primary list widget supporting multi-select, paging, and "skip unfocusable" behavior.
- **ListViewState**: Manages scroll position, scrolloff, and O(1) paging logic efficiently.
- **FilterState**: Handles in-list filtering with Vim-style navigation (`/` to search, `n`/`N` to jump between matches in Normal mode).

### Selection Pattern
To avoid lifetime and borrow checker conflicts common in Rust UI state management, the selection system uses **Indices** rather than references.
- **Decision**: Store indices (`Vec<usize>` from `marked_indices()`) for selected items instead of holding references to data.
- **Benefit**: Decouples selection state from the data source, allowing mutable operations (delete, move) without invalidating selection references.

### Shared Behaviors
- **QueueListBehavior Trait**: Abstracts queue operations (play, delete, move) to share logic between `QueuePaneV2` (full pane) and `QueueModal` (popup).
- **ItemOps Trait**: Standardizes common item operations across different content types.
- **BrowseStack**: Enables "Dir-like" hierarchical navigation within a single pane, used by `SearchPaneV2` for drill-down interactions without pushing new panes to the global stack.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/ui/panes/navigator.rs` | Navigator, pane stack, handle_pane_action |
| `rmpc/src/ui/panes/navigator_types.rs` | PaneAction, EntityRef enums |
| `rmpc/src/ui/widgets/content_view.rs` | ContentView<C> generic container |
| `rmpc/src/ui/widgets/section_list.rs` | SectionList facade |
| `rmpc/src/ui/panes/mod.rs` | Pane trait definitions |

## Adding New Pane

1. Create pane struct in `rmpc/src/ui/panes/my_pane.rs`
2. Implement `NavigatorPane` trait (and `TabPane` if root-level)
3. Add variant to `EntityRef` if it's a detail pane
4. Add match arm in `Navigator::create_detail_pane()`
5. Return `PaneAction::NavigateTo(EntityRef::MyEntity(id))` from parent pane

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Back button stuck | Stack empty or corrupted | `navigator.rs` |
| Pane not pushed | NavigateTo not returned | Source pane's `on_key()` |
| Wrong pane shows | EntityRef mismatch | `create_detail_pane()` |
| Content not updating | ContentView not refreshed | Pane's query handling |
| Tab not visible | TabPane trait not implemented | Pane definition |

## See Also

- [docs/arch/action-system.md](action-system.md) - PaneAction handling
- [docs/arch/section-model.md](section-model.md) - SectionList internals
- [docs/features/search.md](../features/search.md) - SearchPane example

---

## Architectural Decisions (Distilled from ADRs)

### 1. Concrete Pane Fields, Not Dynamic HashMap (from ADR-navigator-design)
- **Decision**: Navigator owns concrete pane fields (`search_pane: SearchPaneV2`, `queue_pane: QueuePaneV2`) instead of `HashMap<PaneId, Box<dyn NavigatorPane>>`.
- **Rationale**: 
  - Stable pane set (~6 panes) doesn't change at runtime
  - Compile-time type safety catches missing pane handlers
  - Match exhaustiveness ensures all panes are handled
  - Zero vtable overhead at 60fps rendering
- **Trade-off**: Less runtime flexibility for more safety and performance.

### 2. Hybrid Rich List Architecture (from ADR-rich-list-ui)
- **Decision**: Simple public trait (`ListItemDisplay`) + internal Element tree for complex rendering.
- **Mechanism**:
  - `ListItemDisplay` trait: Items implement simple `render()` method
  - `Element` enum: Internal/private, can change without breaking API
  - Compact mode: Skips Element tree for fast path (plain text)
- **Rationale**: Simple public API for implementers, internal flexibility for evolution. Headers use distinct styling (bold yellow).

### 3. Layered SOLID Architecture (from ADR-unified-view-architecture)
- **Decision**: Five-layer hierarchy with single responsibility per layer:
  ```
  Navigator → Pane → ContentView → SectionList → SelectableList
  ```
- **Responsibilities**:
  - **Navigator**: Stack management, tab switching, pane lifecycle
  - **Pane**: Semantic action interpretation, query orchestration
  - **ContentView**: Layout, event bubbling (no semantics)
  - **SectionList**: Section grouping, header injection
  - **SelectableList**: Item navigation, selection state
- **Rationale**: SRP per layer, OCP for new panes. Each layer handles its own keys.

### 4. External Navigation Pattern (from ADR-unified-view-architecture)
- **Decision**: Navigation is always "external" - parent controls child's focus, not internal drilling.
- **Mechanism**: `ContentView` returns `ContentAction::Activate`, parent Pane decides target.
- **Move operations**: Use J/K directly (no modal confirmation).
- **InputContentView**: Composes Input widget + List for search-with-results pattern.
