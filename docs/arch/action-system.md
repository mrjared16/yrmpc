# Action System Architecture

## Purpose
Defines how user actions flow through the system: from key press to Intent to handler execution.

## When to Read
- **Symptoms**: Action not triggered, wrong handler called, selection not passed correctly
- **Tasks**: Add new action type, modify handler priority, debug action dispatch

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              User Input                                  │
│                           (key press / click)                            │
└────────────────────────────────────┬────────────────────────────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Pane (TabPane/DetailPane)                      │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  handle_key() / on_action()                                       │   │
│  │     └─► resolve_action() -> Option<Intent>                        │   │
│  │     └─► Return PaneAction::Execute(Intent)                        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬────────────────────────────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              Navigator                                   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  handle_pane_action()                                             │   │
│  │     └─► Match PaneAction variant                                  │   │
│  │     └─► PaneAction::Execute(intent) → action_executor.execute()   │   │
│  │     └─► PaneAction::Navigate/Back → Handle internally (UI only)   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬────────────────────────────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PaneActionExecutor                               │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  execute_intent(intent)                                           │   │
│  │     └─► ActionDispatcher::dispatch(&intent)                       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬────────────────────────────────────┘
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          ActionDispatcher                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  dispatch(&intent)                                               │   │
│  │     └─► Match intent.action (IntentKind)                          │   │
│  │     └─► Find appropriate ActionHandler list (priority based)      │   │
│  │     └─► handler.execute(&intent, ctx)                             │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. User presses key (e.g., Enter on a song)
        │
        ▼
2. Pane::handle_key() matches keybinding
   └─► Gets current selection from InteractiveListView
   └─► Calls resolve_action() to build Intent
   └─► Returns PaneAction::Execute(intent)
        │
        ▼
3. Navigator::handle_pane_action() receives PaneAction
   └─► Matches PaneAction::Execute(intent)
   └─► Calls action_executor.execute_intent(intent)
        │
        ▼
4. ActionDispatcher::dispatch(&intent)
   └─► Matches intent.action to registered handlers
   └─► PlayHandler::execute(&intent)
        │
        ▼
5. Handler performs action
   └─► Resolves song URL, sends to MPV
   └─► Returns Outcome (Handled/Rejected)
```

## Key Types

```rust
// Intent: What the user wants to do (Domain Level)
// NOTE: Excludes UI actions like Navigation or Selection toggling
struct Intent {
    action: IntentKind,      // WHAT action
    selection: Selection,     // ON WHAT items
}

// IntentKind: Pure domain actions
enum IntentKind {
    Play,                    // Play new content
    TogglePlayback,          // Pause/resume (separate from Play)
    AddToQueue,              // Add to end of queue
    RemoveFromQueue,         // Remove from queue
    MoveUp, MoveDown,        // Reorder queue
    SaveToLibrary,           // Save to YouTube library
}

// Selection: What items are selected
enum Selection {
    Single(Item),            // One item
    Multiple(Vec<Item>),     // Visual selection
    Range(start, end),       // Range selection
}

// PaneAction: UI + Domain bridge
enum PaneAction {
    Handled,                 // Pane handled it internally
    BackPane,                // UI Action: Pop navigation stack
    NavigateTo(EntityRef),   // UI Action: Push detail pane
    Execute(Intent),         // Domain Action: Execute via dispatcher
    // Legacy variants removed/deprecated
}
```

## Architectural Decisions

### 1. Separation of Concerns (UI vs Domain)
- **Decision**: Split `IntentKind` (Domain) from `PaneAction` (UI).
- **Rationale**: Navigation, marking items, and focus changes are UI-state concerns handled by the Navigator or Pane. Playing, Queuing, and Saving are Domain concerns handled by the Action System.
- **Impact**: `Navigate` and `ToggleMark` were removed from `IntentKind`.

### 2. Layer Isolation
- **Decision**: Introduce `ListItem` enum in UI layer.
- **Rationale**: Domain objects like `DetailItem` should not know about UI concepts like "Headers" or "Dividers".
- **Impact**: `Header` variant moved from Domain to UI layer.

### 3. Handler Single Responsibility Principle (SRP)
- **Decision**: Split `PlayHandler` into `PlayHandler` and `TogglePlaybackHandler`.
- **Rationale**: "Playing a new song" and "Pausing the current song" are distinct operations with different requirements (selection vs global state).
- **Impact**: Clearer logic, easier testing.

### 4. Zero-Copy Dispatching
- **Decision**: Pass `&Intent` to handlers instead of moving ownership.
- **Rationale**: Allow multiple handlers to inspect the same intent (middleware/observer pattern) without cloning.
- **Impact**: `ActionHandler::execute` takes `&Intent`.

### 5. Standardization
- **Decision**: Unified `create_intent()` signature across panes.
- **Rationale**: All panes should produce Intents in a consistent way from their selection state.
- **Refactor**: Renamed `interpret_activation` → `resolve_action` → `create_intent`.
- **Refactor**: Renamed `InteractiveListView` → `SelectableList`.

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/actions/intent.rs` | Intent, IntentKind, Selection types |
| `rmpc/src/actions/dispatcher.rs` | ActionDispatcher::dispatch() |
| `rmpc/src/actions/handler.rs` | ActionHandler trait |
| `rmpc/src/actions/handlers/*.rs` | Individual handlers (play, queue, save) |
| `rmpc/src/ui/panes/action_executor.rs` | PaneActionExecutor |
| `rmpc/src/ui/panes/navigator.rs` | handle_pane_action() switch |

## Adding New Action

1. Add variant to `IntentKind` in `actions/intent.rs`
2. Create handler in `actions/handlers/my_action.rs`
3. Implement `ActionHandler` trait
4. Register handler in `ActionDispatcher::new()`
5. Add keybinding in pane's `on_key()` to emit the intent via `create_intent()`

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Action not triggered | Keybinding not matched | Pane's `on_key()` |
| Wrong handler called | IntentKind mismatch | `dispatcher.rs` |
| Selection empty | ContentView selection not passed | Pane's `create_intent()` |
| Handler not found | Handler not registered | `ActionDispatcher::new()` |

## See Also

- [docs/arch/ui-navigation.md](ui-navigation.md) - Navigator, pane handling
- [docs/features/playback.md](../features/playback.md) - Play action flow
- [docs/features/queue.md](../features/queue.md) - Queue action flow
