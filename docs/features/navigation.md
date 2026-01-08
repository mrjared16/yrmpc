# Feature: Navigation

## Purpose
Documents pane navigation flow: tab switching, detail pane pushing, back navigation, and adding new panes.

## When to Read
- **Symptoms**: Back button stuck, pane not opening, wrong pane displayed, tab not visible
- **Tasks**: Add new pane type, modify navigation flow, fix stack issues

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Navigator                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Tab Bar                                                           │  │
│  │  [Search] [Queue] [Library] [Settings]                            │  │
│  │      ▲                                                             │  │
│  │      │ Tab selection (1-4 keys)                                   │  │
│  └──────┼────────────────────────────────────────────────────────────┘  │
│         │                                                                │
│  ┌──────┴────────────────────────────────────────────────────────────┐  │
│  │  Pane Stack (per tab)                                              │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                            │  │
│  │  │ TabPane │─▶│ Detail  │─▶│ Detail  │  ◄── Top = Active          │  │
│  │  │ (root)  │  │ Pane 1  │  │ Pane 2  │                            │  │
│  │  └─────────┘  └─────────┘  └─────────┘                            │  │
│  │       ▲            ▲            ▲                                  │  │
│  │       │            │            │                                  │  │
│  │    Always       Push on      Push on                               │  │
│  │    present      Enter        Enter                                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Navigation Levels

| Level | Action | Keys | Example |
|-------|--------|------|---------|
| **Mode** | Switch tabs | `1-4`, `Tab` | Search → Queue |
| **Intra-pane** | Navigate within | `j/k`, `h/l` | Move through items |
| **History** | Push/pop panes | `Enter`, `Backspace` | Open artist → back |

## Data Flow

### Push Detail Pane
```
1. User presses Enter on Artist in search results
        │
        ▼
2. SearchPane::on_key() returns PaneAction::NavigateTo(EntityRef::Artist(id))
        │
        ▼
3. Navigator::handle_pane_action()
   └─► Matches NavigateTo variant
   └─► Calls create_detail_pane(entity_ref)
        │
        ▼
4. Navigator::create_detail_pane(EntityRef::Artist(id))
   └─► Creates ArtistDetailPane::new(id)
   └─► Pushes onto pane_stack
        │
        ▼
5. ArtistDetailPane becomes active
   └─► Fetches artist data
   └─► Renders albums, tracks, related
```

### Pop (Back)
```
1. User presses Backspace
        │
        ▼
2. Active pane returns PaneAction::BackPane
        │
        ▼
3. Navigator::handle_pane_action()
   └─► Matches BackPane
   └─► Pops current pane from stack
   └─► Previous pane becomes active
```

## Adding New Pane

### Step 1: Create Pane Struct
```rust
// rmpc/src/ui/panes/my_pane.rs
pub struct MyDetailPane {
    id: MyEntityId,
    content: ContentView<MyContent>,
}
```

### Step 2: Implement NavigatorPane
```rust
impl NavigatorPane for MyDetailPane {
    fn on_key(&mut self, key: KeyEvent) -> PaneAction { ... }
    fn render(&self, frame: &mut Frame, area: Rect) { ... }
    fn title(&self) -> &str { "My Pane" }
}
```

### Step 3: Add EntityRef Variant
```rust
// navigator_types.rs
enum EntityRef {
    Artist(ArtistId),
    Album(AlbumId),
    MyEntity(MyEntityId),  // ◄── Add here
}
```

### Step 4: Handle in create_detail_pane
```rust
// navigator.rs
fn create_detail_pane(&self, entity: EntityRef) -> Box<dyn NavigatorPane> {
    match entity {
        EntityRef::Artist(id) => Box::new(ArtistDetailPane::new(id)),
        EntityRef::MyEntity(id) => Box::new(MyDetailPane::new(id)),  // ◄── Add
    }
}
```

### Step 5: Trigger from Parent Pane
```rust
// In parent pane's on_key()
KeyCode::Enter => {
    if let Some(item) = self.selected_item() {
        return PaneAction::NavigateTo(EntityRef::MyEntity(item.id));
    }
}
```

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/ui/panes/navigator.rs` | Navigator, pane stack, routing |
| `rmpc/src/ui/panes/navigator_types.rs` | PaneAction, EntityRef enums |
| `rmpc/src/ui/panes/mod.rs` | NavigatorPane, TabPane traits |
| `rmpc/src/ui/panes/*_pane.rs` | Individual pane implementations |

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Back button stuck | Stack empty or single pane | `navigator.rs` |
| Pane not opening | EntityRef not matched | `create_detail_pane()` |
| Wrong pane shows | EntityRef variant wrong | Check NavigateTo call |
| Tab not visible | TabPane not implemented | Pane struct |
| Content not loading | Query not triggered | Pane's init/on_mount |

## See Also

- [docs/arch/ui-navigation.md](../arch/ui-navigation.md) - Navigation primitives
- [docs/arch/action-system.md](../arch/action-system.md) - PaneAction handling
- [docs/features/search.md](search.md) - SearchPane as example
