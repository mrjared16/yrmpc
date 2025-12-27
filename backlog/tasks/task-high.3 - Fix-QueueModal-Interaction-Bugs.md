---
id: task-high.3
title: Fix QueueModal Interaction Bugs
status: To Do
assignee: []
created_date: '2025-12-11 00:09'
updated_date: '2025-12-27 10:36'
labels:
  - bug
  - queue
  - modal
dependencies: []
parent_task_id: task-high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
User reported queue modal interactions not working properly. Modal may have runtime bugs not caught at compile time.

**Symptoms reported:**
- Cannot interact with queue items in modal
- Delete in pane didnt work

**Files to check:**
- rmpc/src/ui/modals/queue_modal.rs
- rmpc/src/ui/widgets/interactive_list_view.rs

**Reference:**
- docs/ADR-interactive-layout-system.md Part 3 (InteractiveListView design)
- QueueModal uses InteractiveListView.render() with highlight callback
- Actions handled inline: play_selected(), delete_selected()

**Debug approach:**
1. Add logging to handle_key()
2. Verify key events propagate correctly
3. Check if QueueItemOps.execute_queue_action() is called
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Identify root cause of modal interaction failure
- [ ] #2 Fix key event handling in QueueModal.handle_key()
- [ ] #3 Verify delete_selected() calls QueueItemOps correctly
- [ ] #4 Runtime test: j/k navigation in modal works
- [ ] #5 Runtime test: Enter (play) and d (delete) work in modal
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: QueueModal logic superseded by Navigator architecture. QueuePaneV2 is primary interaction point now. May be obsolete.
<!-- SECTION:NOTES:END -->
