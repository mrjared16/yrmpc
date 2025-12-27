---
id: task-3
title: Queue Manipulation
status: Done
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-27 10:28'
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
- [x] #1 d/x removes selected item from queue
- [x] #2 Reorder via keyboard shortcuts
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Session 2025-12-27 Update:

- Fixed execute_queue_move bug in navigator.rs (was using ID as position)
- J/K (Shift+j/k) now properly moves items up/down in queue
- Delete (d key) was already working via QueuePaneV2

AC #1 (delete) was already implemented in QueuePaneV2.
AC #2 (reorder) now works with Navigator fix.

Remaining: Need to verify d/x both work for delete.

Verified 2025-12-27: Fully implemented in queue_pane_v2.rs via QueueListBehavior. d/x delete and J/K reorder working.
<!-- SECTION:NOTES:END -->
