# Handoff: ContentView Bubbling Refactor

**Date**: 2025-12-27
**Session**: Architecture Fix - Issues 1-3
**Backlog Task**: task-29
**Status**: Issues 1+2 COMPLETE, Issue 3 PENDING

---

## What Was Accomplished

### Issue 1: ContentView Stops Interpreting ✅
- Removed local `ContentAction` enum from `content_view.rs` (lines 73-109)
- Re-exported `ContentAction` from `navigator_types.rs` for backwards compatibility
- Changed `handle_key()` to bubble `ContentAction::Activate(item)` instead of translating to `Play`/`NavigateTo`

### Issue 2: Move/Delete Actions Bubble ✅
- `SectionAction::MoveUp/MoveDown/Delete` now bubble as `ContentAction::MoveUp/MoveDown/Delete`
- Previously these were dropped with `ContentAction::Handled`

### Files Modified (UNCOMMITTED)

**In parent repo (yrmpc/):**
- `.agent/handoffs/2025-12-27-contentview-bubbling.md` - This handoff
- `backlog/tasks/task-29 - UI-Architecture-Fix-ContentView-Bubbling.md` - Task tracking
- `docs/plans/2025-12-27-architecture-critique.md` - Architecture analysis
- `docs/plans/2025-12-27-ui-architecture-fix.md` - Execution plan

**In rmpc/ submodule:**
| File | Change |
|------|--------|
| `src/ui/widgets/content_view.rs` | Removed local ContentAction enum, re-export from navigator_types, bubble all actions |
| `src/ui/panes/album_detail.rs` | Added `interpret_activation()` method, expanded imports |
| `src/ui/panes/artist_detail.rs` | Added `interpret_activation()` method, expanded imports |
| `src/ui/panes/playlist_detail.rs` | Added `interpret_activation()` method, expanded imports |
| `src/ui/panes/search_pane_v2.rs` | Added `interpret_activation()`, `action_for_item()`, `play_all_songs()` methods |
| `src/ui/widgets/input_content_view.rs` | Changed `ContentAction::BackPane/BackStage` to `ContentAction::Back` |
| `src/ui/panes/navigator.rs` | Previous session changes (block move optimization) |

---

## Key Pattern Established

Each pane now has an `interpret_activation()` method:

```rust
fn interpret_activation(&self, item: DetailItem) -> PaneAction {
    match item {
        DetailItem::Song(song) => {
            // Check for marked items first
            if let Some(level) = self.view.current() {
                if level.section_list.has_marked() {
                    // Play all marked songs
                    return PaneAction::PlayAll { songs, start_index };
                }
            }
            PaneAction::Play(song)
        }
        DetailItem::Ref(content_ref) => {
            // Navigate to entity detail
            PaneAction::NavigateTo(EntityRef { ... })
        }
        DetailItem::Header { .. } => PaneAction::Handled,
    }
}
```

---

## Issue 3: QueuePane Uses ContentView (PENDING)

### Current State
QueuePane bypasses ContentView and SectionList, using InteractiveListView directly:
```rust
// queue_pane_v2.rs:61
pub struct QueuePaneV2 {
    list_view: InteractiveListView,  // DIRECT - skips layers
}
```

### Target State
```rust
pub struct QueuePaneV2 {
    content_view: ContentView<QueueContent>,  // Uses unified stack
}
```

### Required Steps
1. Create `QueueContent` type in `domain/content.rs` implementing `ContentViewable`
2. `to_content_details()` should return sections: "Now Playing", "Up Next"
3. Refactor `QueuePaneV2` to use `ContentView<QueueContent>`
4. Update queue refresh logic in `navigator.rs`

### Why This Matters
- Enables section headers in queue view
- Enables Tab navigation between sections
- Bug fixes to SectionList apply to Queue
- Content stacking (drill into song → show lyrics)

---

## Verification Commands

```bash
# Compile check
cd /home/phucdnt/workspace/projects/yrmpc/rmpc && cargo check

# Run tests (708 should pass)
cargo test --lib

# View uncommitted changes
git status --short
git diff --stat
```

---

## Backlog Status

Task task-29 is "In Progress":
- AC 1-3: ✅ Checked
- AC 4: ⬜ Pending (QueuePane refactor)

```bash
backlog task 29 --plain
```

---

## To Commit (When User Approves)

```bash
cd /home/phucdnt/workspace/projects/yrmpc/rmpc
git add -A
git commit -m "refactor: ContentView bubbles actions, panes interpret

- Remove local ContentAction from content_view.rs
- Re-export ContentAction from navigator_types.rs
- content_view.rs handle_key now bubbles all actions
- Add interpret_activation() to detail panes
- Update search_pane_v2 with action interpretation
- Fix input_content_view to use ContentAction::Back

Issue 3 (QueuePane ContentView) deferred to next session."
```

---

## Next Session Instructions

1. Read this handoff
2. Check task-29: `backlog task 29 --plain`
3. If Issues 1+2 not committed, ask user to approve commit
4. Continue with Issue 3: QueuePane refactor
5. Reference the plan: `docs/plans/2025-12-27-ui-architecture-fix.md`
