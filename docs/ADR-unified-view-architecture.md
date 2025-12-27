# ADR: Unified View Architecture

**Date:** 2025-12-26  
**Status:** Accepted  
**Decision:** Layered SOLID architecture with InputContentView composition

---

## Context

The codebase had three different paths for displaying lists:
1. DetailPanes → ContentView → SectionList → InteractiveListView ✅
2. SearchPane → NavStack → InteractiveListView ❌ (different!)
3. QueuePane → InteractiveListView directly ❌ (bypasses layers!)

This caused:
- Duplicate key handling logic
- Inconsistent user experience
- Bug fixes needed in multiple places
- Violation of DRY principle

---

## Decision

### Core Principle: Layered Single Responsibility

Each layer has ONE responsibility, handles its own keys, delegates rest downward:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LAYERED ARCHITECTURE                                 │
│                    Each layer = Single Responsibility                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LAYER 4: NAVIGATOR                                                         │
│  ═════════════════                                                          │
│  Responsibility: Pane routing, action execution, modal, history            │
│  Owns: All panes, single modal, history stack                              │
│  Keys: 1/2/3 (tab switch), global shortcuts                                │
│  Executes: All PaneActions against backend                                 │
│                                                                             │
│  LAYER 3: PANES                                                             │
│  ═════════════                                                              │
│  Responsibility: Map keys to actions (ONLY THIS)                           │
│  Types:                                                                     │
│    - InputContentView<I, C>: Input + List (SearchPane)                     │
│    - ContentView<C>: List only (QueuePane, DetailPanes)                    │
│  Keys: Pane-specific (d/J/K for queue, phase switch for search)            │
│                                                                             │
│  LAYER 2: ContentView<C>                                                    │
│  ═══════════════════════                                                    │
│  Responsibility: Stack management (push/pop levels)                        │
│  Owns: Vec<ContentLevel<C>>                                                │
│  Keys: None - stack ops come from action translation                       │
│  Delegates: All key handling to SectionList                                │
│                                                                             │
│  LAYER 1: SectionList                                                       │
│  ═══════════════════                                                        │
│  Responsibility: Section structure (headers, section navigation)           │
│  Owns: Vec<SectionView>, flat_items, InteractiveListView                  │
│  Keys: Tab/Shift-Tab (section jump)                                        │
│  Delegates: Item navigation to InteractiveListView                         │
│                                                                             │
│  LAYER 0: InteractiveListView                                               │
│  ═════════════════════════════                                              │
│  Responsibility: List state (selection, scroll, marks, find)              │
│  Owns: selected, marks, scroll_offset, find_state                         │
│  Keys: j/k/G/gg/Ctrl-d/u, Space, /, n/N, Esc                               │
│  Modes: Normal, Find                                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

### 1. All Actions Follow Same Pattern

```
User Intent → Action → Backend → State Update → Re-render
```

Examples:
- Press 'd' → Delete(ids) → Backend removes → Queue updates → Re-render
- Press J → MoveDown(ids) → Backend moves → Queue updates → Re-render
- Press Enter → Play(song) → Backend plays → Status updates → Re-render

**Pane's ONLY job is mapping keys to actions. No business logic in panes.**

### 2. Move Uses J/K Directly (No Special Mode)

```
Shift+K (capital K): Move selected item(s) UP one position
Shift+J (capital J): Move selected item(s) DOWN one position
```

No target mode, no 'm' key sequence. Immediate action like Delete.

### 3. InputContentView for Input + List Composition

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  InputContentView<I, C>                                                     │
│  ═══════════════════════                                                    │
│                                                                             │
│  Composes:                                                                  │
│    - Input zone (I: provides input UI)                                      │
│    - Content zone (ContentView<C>)                                          │
│                                                                             │
│  Focus management:                                                          │
│    - Arrow keys switch between Input and Content                            │
│    - Each zone handles its own keys when focused                            │
│                                                                             │
│  Usage:                                                                     │
│    SearchPane = InputContentView<SearchInputGroups, SearchResultsContent>   │
│    LibraryPane = InputContentView<FilterInput, PlaylistContent> (future)    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4. Preview Zone Handled by Pane

Preview is passive (never focused), varies by pane, and optional.
Pane handles preview rendering, not InputContentView.

```
SearchPane.render():
  split area into [input_list_area, preview_area]
  self.input_content.render(input_list_area)
  self.render_preview(preview_area)  // pane-specific
```

### 5. External Navigation (No Internal Drilling)

SearchPane manages only its phases:
- Input phase (typing search query)
- Results phase (browsing results)

When user drills into Artist/Album/Playlist:
- Return `PaneAction::NavigateTo(EntityRef)`
- Navigator handles navigation to appropriate DetailPane
- No internal NavStack in SearchPane

---

## Action Types (Each Layer Focused)

```rust
// Layer 0: InteractiveListView
enum ListAction {
    Handled,
    Activate(usize),       // Enter pressed
    Mark(Vec<usize>),      // Space pressed
    MoveUp(Vec<usize>),    // Shift+K pressed
    MoveDown(Vec<usize>),  // Shift+J pressed
    Delete(Vec<usize>),    // 'd' pressed
    Back,                  // Esc with nothing to clear
    Passthrough,           // Key not handled
}

// Layer 1: SectionList  
enum SectionAction {
    Handled,
    Activate(DetailItem),
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),
    MoveDown(Vec<DetailItem>),
    Delete(Vec<DetailItem>),
    Back,
    Passthrough,
}

// Layer 2: ContentView
enum ContentAction {
    Handled,
    Activate(DetailItem),  // Pane interprets: play? navigate? drill?
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),
    MoveDown(Vec<DetailItem>),
    Delete(Vec<DetailItem>),
    Back,
}

// Layer 3: Pane → Navigator
enum PaneAction {
    Handled,
    // Playback
    Play(Song),
    PlayAll { songs: Vec<Song>, start: usize },
    Enqueue(Vec<Song>),
    // Navigation  
    NavigateTo(EntityRef),
    BackPane,
    // Modal
    ShowModal(ModalKind),
    // Queue operations
    QueueDelete(Vec<u32>),
    QueueMoveUp(Vec<u32>),
    QueueMoveDown(Vec<u32>),
    // Search
    Search(String),
}
```

---

## SOLID Compliance

| Principle | How Satisfied |
|-----------|---------------|
| **SRP** | Each layer has ONE reason to change |
| **OCP** | Add new pane = new struct, lower layers unchanged |
| **LSP** | All ContentViewable types work with ContentView |
| **ISP** | Each layer only knows its own concern |
| **DIP** | Layers depend on traits, communicate via Action enums |

---

## Component Naming

| Component | Name | Rationale |
|-----------|------|-----------|
| Input + List composition | `InputContentView` | Parallel to ContentView |
| Input groups wrapper | `InputGroups` | Keep existing name |
| List state management | `InteractiveListView` | Keep existing name |
| Section wrapper | `SectionList` | Keep existing name |
| Stack wrapper | `ContentView` | Keep existing name |

---

## Migration Plan

### Phase 1: Extend InteractiveListView
- Add `ListAction::MoveUp`, `MoveDown`, `Delete`
- Handle Shift+J, Shift+K, 'd' keys
- Update action bubbling through layers

### Phase 2: Create InputContentView
- New component: `ui/widgets/input_content_view.rs`
- Composes InputGroups + ContentView
- Focus management between zones

### Phase 3: Migrate SearchPane
- Use InputContentView instead of NavStack
- Remove internal drilling (use Navigator)
- Keep preview rendering in pane

### Phase 4: Migrate QueuePane
- Create QueueContent implementing ContentViewable
- Use ContentView<QueueContent>
- Map J/K/d to queue actions

### Phase 5: Cleanup
- Remove NavStack
- Remove duplicate key handling code
- Update documentation

---

## Files to Create/Modify

### New Files
- `ui/widgets/input_content_view.rs` - InputContentView component

### Modified Files
- `ui/widgets/interactive_list_view.rs` - Add MoveUp/MoveDown/Delete actions
- `ui/widgets/section_list.rs` - Bubble new actions
- `ui/widgets/content_view.rs` - Bubble new actions
- `ui/panes/navigator_types.rs` - Add queue actions to PaneAction
- `ui/panes/navigator.rs` - Execute queue actions
- `ui/panes/search_pane_v2.rs` - Use InputContentView
- `ui/panes/queue_pane_v2.rs` - Use ContentView<QueueContent>
- `domain/content.rs` - Add QueueContent

---

## Anti-Patterns to Avoid

1. **No Capabilities struct** - Violates OCP (must modify to add capability)
2. **No pane-specific logic in lower layers** - Keep layers pure
3. **No special modes for simple actions** - Move/Delete are immediate, not modal
4. **No internal drilling in TabPanes** - Use Navigator for cross-pane navigation

---

## References

- Original discussion: Session 2025-12-26
- Previous architecture: `docs/ARCHITECTURE.md`
- Handoff: `.agent/LLM-HANDOFF-COMPLETE.md`
