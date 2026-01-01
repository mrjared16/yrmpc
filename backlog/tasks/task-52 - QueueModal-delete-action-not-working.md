---
id: task-52
title: QueueModal delete action not working
status: In Progress
assignee: []
created_date: '2025-12-31 15:47'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
BEHAVIOR: Pressing d in QueueModal does nothing - song not deleted. ROOT CAUSE: QueueModal only checks CommonAction::Delete, but d key is mapped to QueueActions::Delete. Modal ignores queue-specific actions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pressing d in QueueModal deletes selected song
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tests written that document keybinding mapping. Fix: Add as_queue_action(ctx) check in handle_key() for QueueActions::Delete.
<!-- SECTION:NOTES:END -->
