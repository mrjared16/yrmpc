---
id: task-5
title: Back Navigation
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-09 21:36'
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
