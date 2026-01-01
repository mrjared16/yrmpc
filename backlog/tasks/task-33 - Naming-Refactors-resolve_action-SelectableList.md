---
id: task-33
title: 'Naming Refactors (resolve_action, SelectableList)'
status: Done
assignee:
  - '@agent'
created_date: '2025-12-28 07:50'
updated_date: '2025-12-28 15:49'
labels:
  - refactor
dependencies:
  - task-32
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rename components for clarity:

1. interpret_activation → resolve_action (5 panes) - may be deleted if action system replaces it
2. InteractiveListView → SelectableList (codebase-wide)

Files:
- src/ui/widgets/interactive_list_view.rs - Rename struct
- All files importing it - Update imports
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 interpret_activation renamed to resolve_action in all panes
- [x] #2 InteractiveListView renamed to SelectableList
- [ ] #3 All imports updated
- [ ] #4 All tests pass
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Renamed interpret_activation to resolve_action and InteractiveListView to SelectableList

InteractiveListView→SelectableList, interpret_activation→resolve_action, strategies/→handlers/, strategy.rs→handler.rs, router.rs→dispatcher.rs

## Code Review (2025-12-28)
- SelectableList rename complete
- resolve_action rename complete
- BUT: resolve_action has 3 different signatures across panes
- Need to standardize: fn create_intent(&self, item) -> Option<Intent>
<!-- SECTION:NOTES:END -->
