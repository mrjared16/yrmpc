---
id: task-low.2
title: Remove Legacy QueueView
status: To Do
assignee: []
created_date: '2025-12-10 23:44'
updated_date: '2025-12-11 13:30'
labels:
  - cleanup
dependencies:
  - task-high.2
  - task-high.3
parent_task_id: task-low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The old queue_view.rs is now superseded by interactive_list_view.rs. QueuePaneV2 and QueueModal use InteractiveListView. Remove or deprecate queue_view.rs to avoid confusion.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Verify QueuePaneV2 and QueueModal no longer import queue_view
- [ ] #2 Delete rmpc/src/ui/widgets/queue_view.rs
- [ ] #3 Remove pub mod queue_view from widgets/mod.rs
- [ ] #4 Cargo build succeeds
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
queue_view.rs is superseded by interactive_list_view.rs. QueuePaneV2 and QueueModal now use InteractiveListView. Cleanup after confirming queue functionality works.

UPDATE (2025-12-11): Dependency task-high.2 now complete. LegacyPanes config allows toggling. Can proceed with cleanup once runtime verified.
<!-- SECTION:NOTES:END -->
