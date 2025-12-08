# Rich List UI - Architecture Decision Record

> **Status**: ✅ Implemented  
> **Date**: 2025-12-08

---

## Context

The current list rendering uses ratatui's `List` widget which only supports text. To match Spotify/YouTube Music UX, we need thumbnails + 2-line layouts.

---

## Decision: Hybrid Architecture

**Simple public API + Internal element tree**

```
PUBLIC                        INTERNAL
ListItemDisplay trait   →    Element tree → render_element()
(data extraction)            (flexible composition)
```

---

## Implementation Status

### ✅ Completed
- `ListItemDisplay` trait (`domain/display.rs`)
- `Element` enum (`ui/widgets/element.rs`)
- `ItemListWidget` (`ui/widgets/item_list.rs`)
- `ListDisplayConfig` (`config/theme/mod.rs`)
- Headers with distinct styling (bold yellow, separator lines)
- Responsive fallback to compact mode (< 60 cols)

### 🐛 Known Issues
- **Thumbnail rendering**: Displays corner only, needs proper scaling fix

### 📁 Key Files
| File | Purpose |
|------|---------|
| `domain/display.rs` | ListItemDisplay trait |
| `ui/widgets/element.rs` | Element enum |
| `ui/widgets/item_list.rs` | ItemListWidget |
| `config/theme/mod.rs` | ListDisplayConfig |
| `domain/song.rs` | ListItemDisplay impl for Song |

---

## Alternatives Considered

### Option A: SOLID 2-Layer (Rejected)
```
ListItemDisplay trait → ItemListWidget (hardcoded layout)
```
- ✅ Simple, fast to ship
- ❌ Layout hardcoded in widget
- ❌ Each new view = new widget

### Option B: Full RenderElement (Rejected for MVP)
```
Renderable trait → Element tree (config-driven)
```
- ✅ Maximum flexibility
- ❌ Complex public API
- ❌ Over-engineering for MVP

### Option C: Hybrid (Chosen)
```
ListItemDisplay trait → Element tree (internal) → render_element()
```
- ✅ Simple public API
- ✅ Internal flexibility
- ✅ Same effort as Option A
- ✅ Evolution path to Option B

---

## Key Decisions with Reasoning

| Decision | Reasoning |
|----------|-----------|
| **`ListItemDisplay` is simple trait** | Easy for domain types to implement; reduces cognitive load |
| **`Element` is internal/private** | Can change without breaking API; allows iteration |
| **Widget builds element tree** | Encapsulates layout; single place to modify |
| **Generic `render_element()`** | Reusable for Grid, Carousel; DRY principle |
| **Compact mode skips tree** | Fast path for default behavior; no overhead |

---

## Constraints (TUI Limitations)

| Constraint | Impact |
|------------|--------|
| ratatui `List` = text-only | Cannot embed images in ListItem |
| Images need explicit Rect | Must manually calculate positions |
| No z-index/overlay | Can't layer images on top of text |
| 60fps full re-render | Element tree traversal must be fast |

---

## Evolution Path

| Phase | Capability | Effort |
|-------|------------|--------|
| **MVP** ✅ | Internal Element, hardcoded layout | 2-3 days |
| **Phase 2** | Config-driven Element builders | +2 days |
| **Phase 3** | Grid/Carousel views | +1 day each |

---

## References

- React.js influence: Unified element abstraction
- Existing rmpc `PropertyKindOrText`: Already has composition pattern
- Spotify desktop: Rich list with thumbnails

