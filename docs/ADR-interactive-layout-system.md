# Interactive Layout System Design

## Overview

This document describes the layout system redesign for yrmpc, addressing inconsistencies between views and enabling future features like a toggleable saved playlists sidebar.

---

## Part 1: rmpc's Original Layout System

### Architecture

rmpc uses a **config-driven layout system** defined in `rmpc/src/config/tabs.rs`:

```
rmpc.ron config
     ↓
TabsFile → Tab → SizedPaneOrSplit → Pane
                        ↓
              Split { direction, panes[] }
                        ↓
            SubPaneFile { size, pane }
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| `TabsFile` | Top-level tabs configuration | tabs.rs:242 |
| `PaneOrSplitFile` | Either a single pane or a split | tabs.rs:291 |
| `SizedSubPane` | Pane with size (percent or length) | tabs.rs:380 |
| `PercentOrLength` | Size as "35%" or "3" (fixed lines) | theme/mod.rs |

### Example Configuration

```ron
tabs: [
    (
        name: "Queue",
        pane: Split(
            direction: Horizontal,
            panes: [
                (size: "40%", pane: Split(
                    direction: Vertical,
                    panes: [
                        (size: "3", pane: Pane(Lyrics)),
                        (size: "100%", pane: Pane(AlbumArt)),
                    ],
                )),
                (size: "60%", pane: Pane(Queue)),
            ],
        ),
    ),
]
```

### Strengths
- Fully configurable via `.ron` files
- Recursive splits allow any layout
- Supports percentage and fixed sizes
- Supports `Component` for reusable layouts

### Problem: Inconsistent Internal Layouts

While the **tab-level** layout is configurable, some panes have **internal hardcoded layouts**:

| Pane | Internal Layout | Problem |
|------|-----------------|---------|
| SearchPane | `column_widths: [20, 38, 42]` | Hardcoded in theme |
| QueuePane | N/A (relies on Split) | Different approach |

This creates visual inconsistency when switching tabs.

---

## Part 2: Why Queue Needed Revamping

### The Problems

1. **Legacy QueuePane was 1400+ lines**
   - Complex, hard to maintain
   - Mixed concerns (rendering + actions + state)

2. **No code reuse between Queue Tab and Queue Modal**
   - Same functionality implemented twice
   - Bugs fixed in one place, not the other

3. **Actions embedded in view**
   - `play_selected()`, `delete_selected()` in QueueView
   - Can't reuse view for different actions (playlist, search)

4. **Hardcoded proportions**
   - 35/65 split in Player mode
   - Should come from config like other layouts

### The Solution: Separation of Concerns

```
Before:
┌─────────────────────────────────────┐
│ QueueView                           │
│ - Navigation (select_next, etc.)    │
│ - Rendering                         │
│ - Actions (play_selected, delete)   │  ← WRONG PLACE
└─────────────────────────────────────┘

After:
┌─────────────────────────────────────┐
│ InteractiveListView<T>              │
│ - Navigation (select_next, etc.)    │
│ - Rendering with highlight callback │
│ - NO ACTIONS                        │
└─────────────────────────────────────┘
           ↑             ↑
    ┌──────┴───┐  ┌──────┴───┐
    │QueuePane │  │QueueModal│
    │ -Actions │  │ -Actions │  ← RIGHT PLACE
    └──────────┘  └──────────┘
```

**Key Insight: The Pane/Modal knows the context (Queue vs Playlist vs Search), so it should handle actions.**

---

## Part 3: InteractiveListView Design

### Component Purpose

A **generic, reusable list component** for any items implementing `ListItemDisplay`.

### API

```rust
pub struct InteractiveListView {
    pub list_state: ListState,
}

impl InteractiveListView {
    // Navigation
    pub fn select_previous(&mut self, len: usize);
    pub fn select_next(&mut self, len: usize);
    pub fn select_first(&mut self, len: usize);
    pub fn select_last(&mut self, len: usize);
    pub fn selected(&self) -> Option<usize>;
    pub fn sync_to(&mut self, index: Option<usize>);

    // Rendering
    pub fn render<T, F>(
        &mut self,
        frame: &mut Frame,
        area: Rect,
        ctx: &Ctx,
        items: &[T],           // Any slice of items
        title: Option<&str>,   // Optional block title
        highlight_fn: F,       // Which item is "playing"
    )
    where
        T: ListItemDisplay,
        F: Fn(usize, &T) -> bool;
}
```

### Usage Example

```rust
// In QueuePaneV2
fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) {
    let current_id = ctx.find_current_song_in_queue().map(|(_, s)| s.id);
    
    self.list_view.render(
        frame,
        area,
        ctx,
        &ctx.queue,               // Items to display
        Some("Queue"),            // Title
        |_idx, song| current_id.is_some_and(|id| id == song.id),  // Highlight
    );
}

// In SidebarPane (future)
fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) {
    self.list_view.render(
        frame,
        area,
        ctx,
        &ctx.playlists,           // Different items!
        Some("Playlists"),
        |_, _| false,             // No highlight
    );
}
```

### Why This Design Works

| Aspect | Design Decision | Benefit |
|--------|-----------------|---------|
| Generic `&[T]` | Any item type | Reuse for Queue, Playlist, Search |
| Highlight callback | Pane decides highlighting | Queue: current playing. Playlist: none |
| No actions | Pane handles actions | Context-aware action dispatch |
| `ListItemDisplay` trait | Rendering abstracted | Any displayable item works |

---

## Part 4: ItemOps Traits for Context-Specific Actions

### Pattern

Each item type can implement context-specific action traits:

```rust
// For queue songs
pub trait QueueItemOps {
    fn queue_actions(&self) -> Vec<QueueItemAction>;
    fn execute_queue_action(&self, action: QueueItemAction, ctx: &mut Ctx) -> Result<()>;
}

// For playlist items (future)
pub trait PlaylistItemOps {
    fn playlist_actions(&self) -> Vec<PlaylistItemAction>;
    fn execute_playlist_action(&self, action: PlaylistItemAction, ctx: &mut Ctx) -> Result<()>;
}
```

### Action Types

```rust
pub enum QueueItemAction {
    Play,
    Delete,
    MoveUp,
    MoveDown,
}

pub enum PlaylistItemAction {
    Open,
    AddToQueue,
    Shuffle,
    Delete,
}
```

### Usage in Pane

```rust
// QueuePane handles queue actions
fn handle_action(&mut self, event: &mut KeyEvent, ctx: &mut Ctx) {
    if let Some(song) = self.selected_song(ctx).cloned() {
        match action {
            QueueActions::Play => song.execute_queue_action(QueueItemAction::Play, ctx),
            QueueActions::Delete => song.execute_queue_action(QueueItemAction::Delete, ctx),
        }
    }
}

// SidebarPane handles playlist actions (future)
fn handle_action(&mut self, event: &mut KeyEvent, ctx: &mut Ctx) {
    if let Some(playlist) = self.selected_playlist(ctx) {
        match action {
            SidebarActions::Open => playlist.execute_playlist_action(PlaylistItemAction::Open, ctx),
            SidebarActions::AddToQueue => playlist.execute_playlist_action(PlaylistItemAction::AddToQueue, ctx),
        }
    }
}
```

---

## Part 5: Future - Toggleable Sidebar

### Design: Modal-Based Sidebar

Use existing **Modal infrastructure** for the sidebar, similar to QueueModal:

```
┌────────────────────────────────────────────────────────────┐
│ [Main Content Area]                                        │
│                                                            │
│   (When 'g' pressed, sidebar modal appears on left)        │
│                                                            │
│ ┌──────────────┐                                          │
│ │ [Sidebar]    │← Left-anchored modal (20% width)         │
│ │ • Home       │                                          │
│ │ • Search     │                                          │
│ │ ─────────    │                                          │
│ │ 📁 Liked     │                                          │
│ │ 📁 Playlist1 │                                          │
│ └──────────────┘                                          │
└────────────────────────────────────────────────────────────┘
```

### Implementation Steps

1. **Create `SavedPlaylistsModal`**
   ```rust
   pub struct SavedPlaylistsModal {
       id: Id,
       list_view: InteractiveListView,  // Reuse!
   }
   ```

2. **Add keybind for toggle**
   ```rust
   pub enum GlobalAction {
       ToggleSidebar,  // 'g' key
   }
   ```

3. **Implement Modal trait**
   ```rust
   impl Modal for SavedPlaylistsModal {
       fn render(&mut self, frame: &mut Frame, ctx: &mut Ctx) {
           let area = frame.area().left_anchored(20);  // New helper
           
           self.list_view.render(
               frame, area, ctx,
               &ctx.playlists,
               Some("Library"),
               |_, _| false,
           );
       }
   }
   ```

4. **Handle actions with `PlaylistItemOps`**
   ```rust
   fn handle_key(&mut self, key: &mut KeyEvent, ctx: &mut Ctx) {
       if let Some(action) = key.as_common_action(ctx) {
           match action {
               CommonAction::Confirm => {
                   if let Some(playlist) = self.selected_playlist(ctx) {
                       playlist.execute_playlist_action(PlaylistItemAction::Open, ctx);
                       self.hide(ctx)?;
                   }
               }
           }
       }
   }
   ```

### Configuration (Future Enhancement)

```ron
sidebar: (
    enabled: true,
    toggle_key: "g",
    width: 20,  // Percentage
    position: Left,
    sections: [
        (type: "tabs"),
        (type: "divider"),
        (type: "playlists"),
    ],
)
```

---

## Part 6: Coordination Layer (Lessons Learned)

### The Problem

`QueuePaneV2` and `QueueModal` displayed the same domain (queue items) but had different action implementations. Example: pressing Enter on the currently playing song would toggle pause in one view but start fresh playback in the other.

### Root Cause

The ADR (Part 3-4) correctly separated:
- **InteractiveListView** — Navigation + Rendering (shared ✓)
- **QueueItemOps** — Domain actions (shared ✓)
- **Pane/Modal** — Context-aware action dispatch

But it missed the **coordination layer** between View and Pane:

```
InteractiveListView (navigation/render)  ← Shared
            ↑
    [ MISSING LAYER ]                    ← Bug source
            ↑
QueuePane / QueueModal (actions)         ← Each reimplemented glue code
            ↓
QueueItemOps (domain logic)              ← Shared
```

### The Pattern: BrowserPane as Reference

`BrowserPane<T>` in `browser.rs` provides 300+ lines of shared action handling:
- All browser-based panes (Library, Playlists, Directories, Artist, Albums, TagBrowser) use it
- Common actions (navigate, select, filter, enqueue, delete) are implemented ONCE
- Each pane just implements domain-specific hooks

**Queue views lacked this equivalent trait**, leading to duplicated "glue code" like:
```rust
// Repeated in BOTH QueuePaneV2 and QueueModal
fn play_selected(&self, ctx: &mut Ctx) {
    if let Some(idx) = self.list_view.selected() {
        if let Some(song) = ctx.queue.get(idx).cloned() {
            song.execute_queue_action(PlayOrToggle, ctx);
        }
    }
}
```

### The Solution: list_ops.rs

`ui/list_ops.rs` is the coordination layer for queue views:

```rust
// Shared helpers - USE THESE instead of reimplementing
pub fn execute_on_selected(view, items, action, ctx) -> Result<bool>
pub fn execute_on_marked_or_selected(view, items, action, ctx) -> Result<usize>
pub fn execute_move(view, items, direction, ctx) -> bool
```

### Mandate for New Queue Views

> **RULE**: When creating a view that operates on `ctx.queue`, you MUST use `list_ops` helpers for all actions. Do NOT implement your own "get selected → call action" pattern.

Example for a new QueueSidebar:
```rust
// ✓ CORRECT - uses shared helper
fn handle_delete(&mut self, ctx: &mut Ctx) {
    let items = ctx.queue.clone();
    list_ops::execute_on_marked_or_selected(
        &mut self.list_view,
        items,
        QueueItemAction::Delete,
        ctx,
    );
}

// ✗ WRONG - reimplements glue code
fn handle_delete(&mut self, ctx: &mut Ctx) {
    if let Some(idx) = self.list_view.selected() {
        if let Some(song) = ctx.queue.get(idx).cloned() { // duplicated pattern!
            song.execute_queue_action(Delete, ctx);
        }
    }
}
```

### Applying to Other Domains

If you create multiple views for the same domain (e.g., PlaylistPane + PlaylistModal), follow the same pattern:
1. Create domain actions trait (e.g., `PlaylistItemOps`)
2. Create coordination helpers (e.g., `playlist_ops.rs`) or extend `list_ops`
3. All views use the helpers, NOT custom glue code

---

## Part 7: QueueListBehavior Trait and Selection Pattern

### Problem

Queue views (QueuePaneV2, QueueModal) share the same domain but had:
1. **Duplicated glue code** for play/delete/move actions
2. **No unified bulk operation pattern** for vim-style visual mode

### Solution 1: QueueListBehavior Trait

A behavior trait for views that interact with `ctx.queue`:

```rust
// In list_ops.rs
pub trait QueueListBehavior {
    fn list_view(&self) -> &InteractiveListView;
    fn list_view_mut(&mut self) -> &mut InteractiveListView;
    
    // Default implementations
    fn play_selected(&mut self, ctx: &mut Ctx) { ... }
    fn delete_selected(&mut self, ctx: &mut Ctx) { ... }
    fn move_selected(&mut self, direction: MoveDirection, ctx: &mut Ctx) { ... }
    
    // Hook for customization
    fn on_after_delete(&mut self, ctx: &mut Ctx, old_idx: Option<usize>, count: usize) { ... }
}
```

Implementors only need 2 accessor methods:
```rust
impl QueueListBehavior for QueuePaneV2 {
    fn list_view(&self) -> &InteractiveListView { &self.list_view }
    fn list_view_mut(&mut self) -> &mut InteractiveListView { &mut self.list_view }
}
```

### Solution 2: Selection Pattern for Bulk Operations

Separate **what is selected** from **what to do with it**.

> **Design Decision:** Use **indices** instead of references to avoid lifetime/borrow conflicts when passing selection to async commands.

```rust
pub enum Selection {
    Single(usize),
    Multiple(Vec<usize>),
}

pub fn get_selection(view: &InteractiveListView) -> Option<Selection> {
    if view.has_marked() {
        let indices: Vec<_> = view.marked_indices().collect();
        if indices.is_empty() { None } else { Some(Selection::Multiple(indices)) }
    } else {
        view.selected().map(Selection::Single)
    }
}
```

**Usage in panes:**
```rust
fn add_to_queue(&mut self, ctx: &mut Ctx) {
    let Some(selection) = list_ops::get_selection(&self.view) else { return };
    
    match selection {
        Selection::Single(i) => {
            let song = self.items[i].clone();
            ctx.command(move |c| c.add(&song.file));
        }
        Selection::Multiple(indices) => {
            let songs: Vec<_> = indices.iter()
                .filter_map(|i| self.items.get(*i).cloned())
                .collect();
            ctx.command(move |c| c.add_batch(songs));
        }
    }
}
```

**Benefits:**
- Same key ("a") works for single and bulk
- Bulk logic can be optimized (batch command vs N commands)
- No lifetime issues when passing to closures
- Selection resolution is generic, action is domain-specific

---

## Summary

### Key Decisions

| Decision | Reasoning |
|----------|-----------|
| **InteractiveListView is generic** | Reuse across Queue, Search, Sidebar |
| **Actions in Pane/Modal, not View** | Context-aware action dispatch |
| **Highlight via callback** | Different views have different highlighting needs |
| **Modal-based sidebar** | Reuses existing infrastructure, toggleable |
| **ItemOps traits** | Type-safe, extensible action system |
| **list_ops coordination layer** | Prevents glue code duplication |
| **QueueListBehavior trait** | Shared queue action logic |
| **Selection<T> pattern** | Unified single/bulk operation interface |

### File Locations

| File | Purpose |
|------|---------|
| `ui/widgets/interactive_list_view.rs` | Generic list component |
| `ui/panes/queue_pane_v2.rs` | Queue tab (uses InteractiveListView) |
| `ui/modals/queue_modal.rs` | Queue sidebar (uses InteractiveListView) |
| `ui/list_ops.rs` | **Coordination layer, QueueListBehavior, Selection** |
| `domain/actions.rs` | QueueItemOps, ItemContext |
| `config/tabs.rs` | Layout configuration system |
