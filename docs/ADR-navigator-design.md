# ADR: Navigator Pane Structure

**Date**: 2025-12-27
**Status**: Accepted
**Decision**: Keep concrete pane fields in Navigator struct

---

## Context

The Navigator struct owns all panes as concrete typed fields:

```rust
pub struct Navigator {
    search_pane: SearchPaneV2,
    queue_pane: QueuePaneV2,
    library_pane: LibraryTabPane,
    artist_pane: ArtistDetailPane,
    album_pane: AlbumDetailPane,
    playlist_pane: PlaylistDetailPane,
    active: PaneId,
    history: Vec<PaneId>,
}
```

This was flagged as an Open/Closed Principle (OCP) violation because adding a new pane requires modifying:
1. The Navigator struct (add field)
2. The PaneId enum (add variant)
3. Match statements in Navigator methods

An alternative pattern would use dynamic registration:

```rust
pub struct Navigator {
    panes: HashMap<PaneId, Box<dyn NavigatorPane>>,
    active: PaneId,
}
```

---

## Decision

**Keep the concrete pane fields pattern.**

---

## Rationale

### Trade-off Analysis

| Aspect | Current (Concrete) | Alternative (Dynamic) |
|--------|-------------------|----------------------|
| **Adding Panes** | Modify 3 places | Just call `register()` |
| **Type Safety** | Full compile-time | Runtime downcast needed |
| **Performance** | Zero-cost | vtable on every call |
| **Debugging** | See exact types | `Box<dyn>` hides types |
| **Complexity** | Simple, explicit | More abstract |
| **IDE Support** | Full autocomplete | Limited for dyn traits |

### Why Concrete Wins for This Project

1. **Stable Pane Set**: We have 6 panes and are unlikely to add many more frequently. The OCP overhead is minimal.

2. **Compile-Time Safety**: Refactoring panes often involves signature changes. Compile errors catch issues immediately. With `Box<dyn>`, errors manifest at runtime.

3. **TUI Performance**: The render loop runs at ~60fps. Vtable indirection on every render/handle_key is measurable overhead for no benefit.

4. **Debugging Experience**: When debugging, seeing `SearchPaneV2` in stack traces is clearer than `Box<dyn NavigatorPane>`.

5. **Match Exhaustiveness**: Rust's match exhaustiveness checking ensures all panes are handled. With dynamic registration, you can forget to handle a pane.

### When Dynamic Would Be Better

- Plugin architecture where third parties add panes
- 20+ panes where match statements become unwieldy
- Runtime pane discovery/loading

None of these apply to yrmpc.

---

## Consequences

### Positive

- Compile-time verification of pane handling
- Zero-cost abstraction
- Clear, traceable code

### Negative

- Adding a pane requires touching Navigator (acceptable given infrequent additions)
- Code reviewers must verify all match arms are updated

---

## Guidelines for Adding Panes

When adding a new pane:

1. Add field to `Navigator` struct in `navigator.rs`
2. Add variant to `PaneId` enum in `navigator_types.rs`
3. Update `active_pane()` and `active_pane_mut()` match blocks
4. Add initialization in `Navigator::new()`
5. Update any pane-iterating methods

The compiler will flag missing match arms, making this safe.

---

## References

- SOLID Principles discussion in architecture review
- Rust dynamic dispatch documentation
- Similar decisions in ratatui ecosystem apps
