# UI Architecture Fix Plan

**Date**: 2025-12-27
**Status**: ✅ COMPLETE (Phases 1-3)
**Scope**: Fix 5 architectural issues in UI layer
**Backlog**: task-29 (Done)

---

## Progress

| Phase | Issue | Status |
|-------|-------|--------|
| 1 | Add Move/Delete to ContentAction | ✅ COMPLETE |
| 2 | ContentView bubbles, doesn't interpret | ✅ COMPLETE |
| 3 | QueuePane uses ContentView | ✅ COMPLETE |
| 4 | Abstract backend errors | ⏳ DEFERRED |
| 5 | Queue race conditions | ⏳ DEFERRED |

**Last Updated**: 2025-12-27 22:50
**708 tests pass**

---

## Execution Order

```
Issue 2 (0.5 day) → Issue 1 (1 day) → Issue 3 (2 days) → Issue 4 (defer) → Issue 5 (defer)
```

---

## Phase 1: Issue 2 - Add Move/Delete to ContentAction

**Problem**: Move/Delete actions get dropped at ContentView layer.

**Files to modify**:
- `rmpc/src/ui/panes/navigator_types.rs` - Add variants to ContentAction
- `rmpc/src/ui/widgets/content_view.rs` - Bubble instead of drop

**Changes**:
```rust
// navigator_types.rs - ADD to ContentAction enum
pub enum ContentAction {
    Handled,
    Activate(DetailItem),
    Mark(Vec<DetailItem>),
    MoveUp(Vec<DetailItem>),    // ADD
    MoveDown(Vec<DetailItem>),  // ADD
    Delete(Vec<DetailItem>),    // ADD
    Back,
    Passthrough,
}

// content_view.rs - BUBBLE instead of drop
SectionAction::MoveUp(items) => ContentAction::MoveUp(items),
SectionAction::MoveDown(items) => ContentAction::MoveDown(items),
SectionAction::Delete(items) => ContentAction::Delete(items),
```

---

## Phase 2: Issue 1 - ContentView Bubbles, Doesn't Interpret

**Problem**: ContentView decides "play vs navigate" instead of pane.

**Files to modify**:
- `rmpc/src/ui/widgets/content_view.rs` - Remove translate_activate, bubble Activate
- `rmpc/src/ui/panes/search_pane_v2.rs` - Add interpret_activation
- `rmpc/src/ui/panes/queue_pane_v2.rs` - Add interpret_activation
- `rmpc/src/ui/panes/artist_detail.rs` - Add interpret_activation
- `rmpc/src/ui/panes/album_detail.rs` - Add interpret_activation
- `rmpc/src/ui/panes/playlist_detail.rs` - Add interpret_activation

**Changes**:
```rust
// content_view.rs - BEFORE
SectionAction::Activate(item) => self.translate_activate(&item),

// content_view.rs - AFTER
SectionAction::Activate(item) => ContentAction::Activate(item),

// Each pane - ADD method
fn interpret_activation(&self, item: DetailItem) -> PaneAction {
    match item {
        DetailItem::Song(s) => PaneAction::Play(s),
        DetailItem::Artist(a) => PaneAction::NavigateTo(EntityRef::artist(a)),
        // ...
    }
}
```

---

## Phase 3: Issue 3 - QueuePane Uses ContentView

**Problem**: QueuePane bypasses ContentView and SectionList layers.

**Files to modify**:
- `rmpc/src/domain/content.rs` - Add QueueContent
- `rmpc/src/ui/panes/queue_pane_v2.rs` - Use ContentView<QueueContent>
- `rmpc/src/ui/panes/navigator.rs` - Update queue refresh logic
- `rmpc/src/ui/panes/navigator_types.rs` - Add queue-specific PaneActions if needed

**Changes**:
```rust
// domain/content.rs - ADD
pub struct QueueContent {
    songs: Vec<Song>,
    current_index: Option<usize>,
}

impl ContentViewable for QueueContent {
    fn to_content_details(&self) -> ContentDetails {
        ContentDetails::with_sections(vec![
            Section::new("Now Playing", vec![/* current */]),
            Section::new("Up Next", vec![/* remaining */]),
        ])
    }
}

// queue_pane_v2.rs - REFACTOR
pub struct QueuePaneV2 {
    content_view: ContentView<QueueContent>,  // Was: list_view: InteractiveListView
}
```

---

## Phase 4: Issue 4 - Abstract Backend Errors (DEFER)

**Trigger**: When multi-backend support is needed.

**Files to modify**:
- `rmpc/src/backends/api.rs` - Add BackendError enum
- `rmpc/src/backends/mpd/backend.rs` - Impl From<MpdError>
- `rmpc/src/backends/youtube/backend.rs` - Map errors
- `rmpc/src/ui/mod.rs` - Use BackendError
- `rmpc/src/backends/api/content.rs` - Rename capabilities

---

## Phase 5: Issue 5 - Queue Race Conditions (DEFER)

**Trigger**: When undo/redo or multi-client sync is implemented.

**Approach**: Optimistic UI with reconciliation or queue versioning.

---

## Success Metrics

| Metric | Before | After Phase 1-3 |
|--------|--------|-----------------|
| ContentAction variants | 6 | 9 (add Move/Delete) |
| Panes using ContentView | 4/6 | 6/6 |
| Queue has sections | No | Yes |
| J/K/d work in Queue via layers | No | Yes |

---

## Verification

After each phase:
1. `cargo build` - must compile
2. `cargo test` - tests pass
3. Manual test: Navigate queue, press J/K/d, verify actions work
