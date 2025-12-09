---
id: task-3
title: Queue Manipulation
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-09 21:32'
labels:
  - ui
  - queue
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-QUEUE-3: Remove and reorder queue items via keyboard.

**Context:**
- Queue pane shows tracks to play next (see rmpc/src/ui/panes/queue.rs)
- Uses vim-style keybindings (j/k navigation already works)
- Spec: docs/ui-ux-provised.md section 2.2 Queue View

**Implementation hints:**
- Delete: handle d/x in handle_input(), call queue.remove(id)
- Reorder: Ctrl+j/k or J/K to move item up/down via queue.move_song(from, to)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 d/x removes selected item from queue
- [ ] #2 Reorder via keyboard shortcuts
<!-- AC:END -->
