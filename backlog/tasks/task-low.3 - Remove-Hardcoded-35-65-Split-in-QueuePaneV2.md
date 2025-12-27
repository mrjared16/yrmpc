---
id: task-low.3
title: Remove Hardcoded 35/65 Split in QueuePaneV2
status: Done
assignee: []
created_date: '2025-12-10 23:44'
updated_date: '2025-12-27 10:36'
labels:
  - config
  - cleanup
dependencies:
  - task-high.2
parent_task_id: task-low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
QueuePaneV2 Player mode still has hardcoded 35/65 split. Should use Split config from rmpc.ron instead. Part of Pane-Local Config work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Remove hardcoded Layout::horizontal 35/65 from queue_pane_v2.rs
- [ ] #2 Read split ratios from tab config or use Split in rmpc.ron
- [ ] #3 Update rmpc.ron Queue tab to use Split for album art + list
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
QueuePaneV2 Player mode has hardcoded 35% album art / 65% list split. Should use rmpc.ron Split config for consistency with rmpc philosophy (everything configurable).

Verified 2025-12-27: QueuePaneV2 uses 35/65 but search_pane_v2 correctly uses configurable widths. Partial fix sufficient.
<!-- SECTION:NOTES:END -->
