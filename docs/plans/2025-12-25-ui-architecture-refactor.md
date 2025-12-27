# Implementation Plan: UI Architecture Refactor

## Overview

Refactor the UI system from the legacy DirStack-based architecture to a clean TabPane/DetailPane system with proper navigation, content stacking, and vim-style modes.

---

## Phase 1: Core Infrastructure

### 1.1 Rename Filter to Find

**Files:**
- `ui/widgets/filter_state.rs` → `ui/widgets/find_state.rs`
- Update all imports and references

**Changes:**
```rust
// Before
pub struct FilterState { ... }

// After
pub struct FindState { ... }
```

**Effort:** 30 min

---

### 1.2 Create Navigator

**File:** `ui/navigator.rs` (new)

**Contents:**
```rust
pub struct Navigator {
    tab_panes: HashMap<TabId, Box<dyn TabPane>>,
    detail_panes: HashMap<DetailId, Box<dyn DetailPane>>,
    active: PaneId,
    history: Vec<PaneId>,
}

pub enum PaneId {
    Tab(TabId),
    Detail(DetailId),
}

pub enum TabId { Search, Queue, Library }
pub enum DetailId { Artist, Album, Playlist }

impl Navigator {
    pub fn new() -> Self;
    pub fn switch_to(&mut self, pane: PaneId);
    pub fn go_back_pane(&mut self) -> bool;
    pub fn navigate_to_entity(&mut self, entity: EntityRef, ctx: &Ctx);
    pub fn handle_key(&mut self, key: KeyEvent, ctx: &mut Ctx) -> Result<()>;
    pub fn render(&self, frame: &mut Frame, area: Rect, ctx: &Ctx);
}
```

**Effort:** 2-3 hours

---

### 1.3 Define Pane Traits

**File:** `ui/panes/mod.rs`

**Contents:**
```rust
pub enum InputMode {
    Normal,
    Edit,
    Find,
}

pub enum PaneAction {
    Handled,
    NavigateTo(EntityRef),
    BackPane,
    Play(Song),
    PlayAll(Vec<Song>, usize),
    Enqueue(Vec<Song>),
}

pub trait Pane {
    fn id(&self) -> PaneId;
    fn mode(&self) -> InputMode;
    fn render(&self, frame: &mut Frame, area: Rect, ctx: &Ctx);
    fn handle_key(&mut self, key: KeyEvent, ctx: &mut Ctx) -> PaneAction;
}

pub trait TabPane: Pane {
    fn tab_label(&self) -> &str;
    fn hotkey(&self) -> char;
    fn current_stage(&self) -> &str;
    fn can_go_back_stage(&self) -> bool;
    fn go_back_stage(&mut self) -> bool;
}

pub trait DetailPane: Pane {
    fn has_content(&self) -> bool;
    fn stack_depth(&self) -> usize;
    fn push(&mut self, content: EntityContent);
    fn pop(&mut self) -> bool;
    fn clear(&mut self);
}
```

**Effort:** 1 hour

---

## Phase 2: Shared Components

### 2.1 Update InteractiveListView

**File:** `ui/widgets/interactive_list_view.rs`

**Changes:**
- Add `mode: InputMode` field
- Rename filter to find
- Add mode-aware key handling
- Add `handle_esc()` with priority logic
- Add `handle_backspace()` with priority logic

```rust
pub struct InteractiveListView {
    state: ListViewState,
    mode: InputMode,
    find: Option<FindState>,
}

impl InteractiveListView {
    pub fn handle_key(&mut self, key: KeyEvent) -> ListAction {
        match self.mode {
            InputMode::Find => self.handle_find_key(key),
            InputMode::Normal => self.handle_normal_key(key),
            InputMode::Edit => ListAction::Passthrough, // Handled by pane
        }
    }
    
    pub fn handle_esc(&mut self) -> EscResult {
        if self.mode == InputMode::Find {
            self.find = None;
            self.mode = InputMode::Normal;
            return EscResult::Handled;
        }
        
        if self.find.is_some() {
            self.find = None;
            return EscResult::Handled;
        }
        
        EscResult::BackPane
    }
}
```

**Effort:** 2 hours

---

### 2.2 Create SectionList Component

**File:** `ui/widgets/section_list.rs` (new)

**Contents:**
```rust
pub struct SectionList {
    sections: Vec<SectionView>,
    list_view: InteractiveListView,
}

impl SectionList {
    pub fn new(sections: Vec<SectionView>) -> Self;
    pub fn render(&self, frame: &mut Frame, area: Rect, ctx: &Ctx);
    pub fn handle_key(&mut self, key: KeyEvent) -> SectionAction;
    pub fn selected_item(&self) -> Option<&DetailItem>;
}

pub enum SectionAction {
    Handled,
    Select(DetailItem),
    Mark(Vec<usize>),
    BackPane,
    // ...
}
```

**Effort:** 2 hours

---

## Phase 3: TabPanes

### 3.1 SearchPane

**File:** `ui/panes/search.rs` (rewrite)

**Structure:**
```rust
pub struct SearchPane {
    stage: SearchStage,
    input: TextInput,
    results: Option<SectionList>,
    mode: InputMode,
}

enum SearchStage {
    Input,
    Results,
}

impl TabPane for SearchPane {
    fn tab_label(&self) -> &str { "Search" }
    fn hotkey(&self) -> char { '1' }
    fn current_stage(&self) -> &str { 
        match self.stage {
            SearchStage::Input => "Input",
            SearchStage::Results => "Results",
        }
    }
    fn can_go_back_stage(&self) -> bool { 
        self.stage == SearchStage::Results 
    }
    fn go_back_stage(&mut self) -> bool {
        if self.stage == SearchStage::Results {
            self.stage = SearchStage::Input;
            true
        } else {
            false
        }
    }
}
```

**Effort:** 4-6 hours (most complex pane)

---

### 3.2 QueuePane

**File:** `ui/panes/queue.rs` (rewrite)

**Structure:**
```rust
pub struct QueuePane {
    list_view: InteractiveListView,
    // Reads queue from ctx.queue (live)
}

impl TabPane for QueuePane {
    fn tab_label(&self) -> &str { "Queue" }
    fn hotkey(&self) -> char { '2' }
    fn current_stage(&self) -> &str { "List" }
    fn can_go_back_stage(&self) -> bool { false }
    fn go_back_stage(&mut self) -> bool { false }
}
```

**Effort:** 2-3 hours

---

### 3.3 LibraryPane

**File:** `ui/panes/library.rs` (new)

**Structure:**
```rust
pub struct LibraryPane {
    playlists: Vec<SavedPlaylist>,
    list_view: InteractiveListView,
}

impl TabPane for LibraryPane {
    fn tab_label(&self) -> &str { "Library" }
    fn hotkey(&self) -> char { '3' }
    fn current_stage(&self) -> &str { "List" }
    fn can_go_back_stage(&self) -> bool { false }
    fn go_back_stage(&mut self) -> bool { false }
}
```

**Effort:** 2 hours

---

## Phase 4: DetailPanes

### 4.1 ArtistPane

**File:** `ui/panes/artist.rs` (new)

**Structure:**
```rust
pub struct ArtistPane {
    stack: Vec<ArtistLevel>,
}

struct ArtistLevel {
    content: ArtistContent,
    section_list: SectionList,
}

impl DetailPane for ArtistPane {
    fn has_content(&self) -> bool { !self.stack.is_empty() }
    fn stack_depth(&self) -> usize { self.stack.len() }
    
    fn push(&mut self, content: EntityContent) {
        if let EntityContent::Artist(artist) = content {
            let sections = build_artist_sections(&artist);
            self.stack.push(ArtistLevel {
                content: artist,
                section_list: SectionList::new(sections),
            });
        }
    }
    
    fn pop(&mut self) -> bool {
        if self.stack.len() > 1 {
            self.stack.pop();
            true
        } else {
            false
        }
    }
    
    fn clear(&mut self) {
        self.stack.clear();
    }
}
```

**Effort:** 2-3 hours

---

### 4.2 AlbumPane

**File:** `ui/panes/album.rs` (new)

**Structure:** Same pattern as ArtistPane with `Stack<AlbumContent>`

**Effort:** 1-2 hours (similar to ArtistPane)

---

### 4.3 PlaylistPane

**File:** `ui/panes/playlist.rs` (new)

**Structure:** Same pattern as ArtistPane with `Stack<PlaylistContent>`

**Effort:** 1-2 hours (similar to ArtistPane)

---

## Phase 5: Integration

### 5.1 Wire Navigator to App

**File:** `ui/mod.rs`

**Changes:**
- Replace current pane management with Navigator
- Update render loop
- Update key handling

**Effort:** 2-3 hours

---

### 5.2 Update Backend Integration

**Files:** Various

**Changes:**
- Ensure entity fetching returns proper content types
- Wire navigation actions to backend calls

**Effort:** 2 hours

---

## Phase 6: Cleanup

### 6.1 Remove Legacy Code

**Files to delete/modify:**
- `ui/widgets/nav_stack.rs` - delete
- `ui/widgets/detail_stack.rs` - delete
- `ui/dirstack/` - keep for MPD panes, but don't use for new panes
- `search_pane_v2.rs` - replace with new SearchPane

**Effort:** 1-2 hours

---

### 6.2 Rename filter_state to find_state

**Files:**
- `ui/widgets/filter_state.rs` → `ui/widgets/find_state.rs`
- Update all imports

**Effort:** 30 min

---

## Phase 7: Testing

### 7.1 Navigation Testing

- Test pane history (Esc navigation)
- Test content stacking (Backspace in DetailPanes)
- Test stage transitions (Backspace in SearchPane)
- Test mode transitions (Esc in Edit/Find modes)
- Test hotkey switching (1/2/3)

**Effort:** 2-3 hours

---

### 7.2 Find Testing

- Test find mode entry (/)
- Test find query updates
- Test Enter (confirm, keep highlights)
- Test Esc in Find mode (cancel, clear)
- Test Esc in Normal with active find (clear)
- Test n/N navigation

**Effort:** 1-2 hours

---

## Summary

| Phase | Description | Effort |
|-------|-------------|--------|
| 1 | Core Infrastructure | 4-5 hours |
| 2 | Shared Components | 4 hours |
| 3 | TabPanes | 8-11 hours |
| 4 | DetailPanes | 5-7 hours |
| 5 | Integration | 4-5 hours |
| 6 | Cleanup | 2-3 hours |
| 7 | Testing | 3-5 hours |
| **Total** | | **30-40 hours** |

---

## Implementation Order

Recommended order to minimize broken states:

1. **Phase 1.3**: Define Pane traits (establishes contracts)
2. **Phase 2.1**: Update InteractiveListView (mode support)
3. **Phase 2.2**: Create SectionList (shared component)
4. **Phase 4.1**: Create ArtistPane (simplest DetailPane)
5. **Phase 3.2**: Create QueuePane (simplest TabPane)
6. **Phase 1.2**: Create Navigator (can now instantiate panes)
7. **Phase 5.1**: Wire Navigator to App (system works end-to-end)
8. **Phase 3.1**: Create SearchPane (complex, benefits from working system)
9. **Phase 4.2-4.3**: Create AlbumPane, PlaylistPane
10. **Phase 3.3**: Create LibraryPane
11. **Phase 1.1, 6.2**: Rename filter to find
12. **Phase 6.1**: Remove legacy code
13. **Phase 7**: Testing

---

## Risk Mitigation

1. **Keep legacy code working** during refactor
   - New panes coexist with old
   - Switch over incrementally

2. **Feature flag** for new architecture
   - `--use-new-ui` or config option
   - Easy rollback if issues

3. **Test each pane in isolation** before integration
   - Unit tests for key handling
   - Manual testing of navigation

4. **Preserve vim bindings** exactly
   - j/k, G/gg, Ctrl-d/u must work
   - Find (/) must match vim behavior
