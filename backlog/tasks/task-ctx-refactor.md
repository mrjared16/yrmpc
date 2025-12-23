# Task: Refactor Ctx God Object

**Status:** Backlog  
**Priority:** Medium  
**Effort:** High  
**Blocked By:** Upstream merge completion

## Problem

`Ctx` violates Single Responsibility Principle with 25+ fields mixing:
- UI state (active_tab, queue_panel_visible)
- Backend communication (channels, scheduler)
- Domain data (status, queue, stickers)
- Caching (image_cache, lrc_index)
- Configuration (config, debug flags)

## Research Needed

Study how Solid.js handles state management:
- Fine-grained reactivity
- Signal-based updates
- Separation of concerns

## Proposed Solution (TBD after research)

Split Ctx into smaller, focused components:
- `UiState` - UI-specific state
- `BackendClient` - Communication layer
- `AppCache` - Caching layer
- `Configuration` - Config access

## Why Deferred

Need to merge plugin system to upstream first. Refactoring Ctx now would make merge conflicts unbearable.

## Next Steps

1. Merge plugin system to upstream
2. Research Solid.js state management
3. Design new architecture
4. Implement incrementally
