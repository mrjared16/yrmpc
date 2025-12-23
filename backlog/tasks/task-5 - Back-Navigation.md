---
id: task-5
title: Back Navigation
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-11 13:30'
labels:
  - ui
  - navigation
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-DETAIL-2: Backspace/Esc returns to previous view.

**Context:**
- Navigation stack needed for browse history
- Spec: docs/ui-ux-provised.md section 2.4 (R-DETAIL-2)

**Implementation hints:**
- Add navigation_stack: Vec<View> to app state
- Push new view when browsing into detail
- Pop on Backspace/Esc keypress
- Reference: ui/panes/mod.rs for pane switching logic
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Backspace navigates back in browse history
- [ ] #2 Esc works as alternative back key
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
UPDATE (2025-12-11): BrowseStack component now implemented (task-15) which provides enter/leave navigation stack. SearchPaneV2 uses it. This task partially covered by BrowseStack architecture.
<!-- SECTION:NOTES:END -->
