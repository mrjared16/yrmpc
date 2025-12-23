---
id: task-low.1
title: Pane-Local Config for Column Widths
status: To Do
assignee: []
created_date: '2025-12-10 23:44'
updated_date: '2025-12-11 00:10'
labels:
  - config
  - architecture
dependencies: []
parent_task_id: task-low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add optional pane_config to TabFile allowing per-pane column widths configuration. Fixes magic numbers (20/38/42) in Search pane. Makes layout configurable via rmpc.ron. See docs/ADR-interactive-layout-system.md Part 1.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add PaneConfig struct to tabs.rs
- [ ] #2 Add pane_config field to TabFile
- [ ] #3 Pass pane_config through to pane render context
- [ ] #4 Update SearchPane to read column_widths from pane_config
- [ ] #5 Update docs/ADR-interactive-layout-system.md
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Design in docs/ADR-interactive-layout-system.md. Alternative to full pane decomposition. Allows per-pane config without decomposing compound panes like Search.
<!-- SECTION:NOTES:END -->
