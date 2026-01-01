# Session Handoff: Architecture Refinement Review
**Date**: 2025-12-28 (Updated 2025-12-29)
**Session Type**: Deep Architectural Critique
**Status**: Plan APPROVED, Ready for Implementation
**Task**: task-37 - Action System Architecture Refinement

---

## Session Summary

This session performed a deep architectural critique of the action system (task-32, 33, 34)
as a "top 0.1% tech lead" focusing on SOLID principles and clean architecture.

**Key Finding**: The action system infrastructure was built but NOT integrated.
Panes still contain all logic and bypass the Intent → Dispatcher → Handler system entirely.

---

## Critical Issues Discovered

### Issue #1: Two ActionKind Enums
```
domain/content.rs:1039   →  Play, Shuffle, Radio, AddToQueue, AddToLibrary, Share
actions/intent.rs:23     →  Play, AddToQueue, RemoveFromQueue, MoveUp, MoveDown, SaveToLibrary, Navigate, ToggleMark
```
**Problem**: Duplicate concepts, confusing imports, unclear which to use.

### Issue #2: Panes Bypass Intent System
```rust
// Current: Panes return direct actions
fn resolve_action(&self, item: DetailItem) -> PaneAction {
    PaneAction::Play(song)  // ← Never uses Intent!
}

// Intended: Panes return Intent
PaneAction::Execute(Intent::play(selection))  // ← Never called!
```
**Problem**: 656 lines of action system code that's never executed.

### Issue #3: PlayHandler Conflates Use Cases
```rust
// One handler does two things:
if current_song.uri == song.uri {
    client.pause_toggle();  // Toggle!
} else {
    client.play_id(id);     // Play!
}
```
**Problem**: SRP violation - should be separate handlers.

### Issue #4: Header in Domain Layer
```rust
// domain/detail_item.rs
pub enum DetailItem {
    Header { title: String },  // UI concern in domain!
    Song(Song),
    Ref(ContentRef),
}
```
**Problem**: Layer violation - Header is purely for list rendering.

### Issue #5: Inconsistent resolve_action Signatures
| Pane | Signature |
|------|-----------|
| Queue | `fn resolve_action(&self, item, ctx) -> PaneAction` |
| Search | `fn resolve_action(&mut self, ctx, item) -> Result<()>` |
| Album | `fn resolve_action(&self, item) -> PaneAction` |

**Problem**: Can't create trait or unify behavior.

### Issue #6: Navigate/ToggleMark in IntentKind
These are UI operations (routing, selection state) not domain actions.

---

## Proposed Refactoring Roadmap

### Phase 1: Fix Layer Violations (Foundation)
1. Create UI-only `ListItem` enum with Header
2. Keep `DetailItem` as domain-only (Song, Ref)
3. Merge/consolidate ActionKind enums
4. Remove Navigate/ToggleMark from IntentKind

### Phase 2: Unify Responsibility (Consistency)
1. Standardize: `fn create_intent(&self, item: MediaItem) -> Option<Intent>`
2. Move ALL validation to handlers
3. Split PlayHandler → PlayHandler + TogglePlaybackHandler

### Phase 3: Wire Intent System (Integration)
1. Change panes to return `PaneAction::Execute(Intent)`
2. Delete duplicated marked-item logic (4 copies → 1)
3. Handlers execute all operations

### Phase 4: Optimize (Polish)
1. Pass `&Intent` not owned
2. Consider `HashMap<IntentKind, Handler>` if priority unused
3. Add lazy caching to Selection

---

## Ideal Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ DOMAIN LAYER (Pure, No Dependencies)                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│  MediaItem (trait): Track, Album, Artist, Playlist                          │
│  IntentKind (enum): Play, Queue, Remove, Save, Expand                       │
│  Selection<T: MediaItem>: items: Vec<T> (no Headers!)                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ APPLICATION LAYER (Use Cases)                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  Intent { kind, selection }                                                  │
│  Handler (trait): fn execute(&self, &Intent, &mut Ctx) -> Outcome            │
│  ActionDispatcher: HashMap<IntentKind, Vec<Handler>>                         │
│  Outcome: Success, Rejected { reason }, Error                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ UI LAYER (Presentation)                                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  ListItem (enum): Media(MediaItem), Header(String), Spacer                   │
│  SelectableList<ListItem>: marked: HashSet<usize>                            │
│  Pane::create_intent() -> Option<Intent> (filters out Headers)               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Files Modified This Session

| File | Changes |
|------|---------|
| `rmpc/src/actions/` (all) | Created in previous session, NOT modified |
| `backlog/tasks/task-32` | Added code review notes |
| `backlog/tasks/task-33` | Added code review notes |
| `backlog/tasks/task-34` | Added code review notes |
| `backlog/tasks/task-37` | NEW - Architecture refinement task |

---

## Uncommitted Changes

All changes from previous session are still uncommitted:
```bash
git status  # Shows M rmpc, ?? many files
```

**Do NOT commit yet** - the action system is not integrated and would add dead code.

---

## Next Steps for New Session

1. **Read this handoff document**
2. **Read task-37** for full refactoring plan
3. **Discuss Phase 1 with user** before implementing:
   - How to handle Header? New ListItem enum or keep in DetailItem?
   - Merge ActionKind or just rename?
   - What about existing code using domain::ActionKind?
4. **Start Phase 1** after clarification

---

## Questions for User (Before Implementing)

### RESOLVED - All Decisions Made

| Question | Decision |
|----------|----------|
| Q1: Header handling | Option A - Create UI-only ListItem enum |
| Q2: ActionKind | Rename to IntentKind |
| Q3: Navigate/ToggleMark | Remove from IntentKind (UI operations) |
| Q3.2: Queue context | Option B - Handler queries ctx for backend IDs |
| Q4: Dispatcher | Hybrid - HashMap + priority, future pre/post phases |
| Scope | Full refactor, all phases, take time |

---

## Next Steps for New Session

1. **Read task-37**: `backlog task 37 --plain`
2. **Start Phase 1.1**: Rename ActionKind → IntentKind
3. **Continue through phases** in order
