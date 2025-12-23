---
id: task-medium.2
title: PlaylistItemOps Trait
status: To Do
assignee: []
created_date: '2025-12-10 23:44'
updated_date: '2025-12-11 00:10'
labels:
  - architecture
dependencies: []
parent_task_id: task-medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create PlaylistItemOps trait for sidebar playlist items following QueueItemOps pattern. Actions: Open, AddToQueue, Shuffle, Delete. Required for sidebar implementation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Create PlaylistItemOps trait in domain/actions.rs
- [ ] #2 Define PlaylistItemAction enum (Open, AddToQueue, Shuffle, Delete)
- [ ] #3 Implement trait for Playlist type
- [ ] #4 Update docs/ADR-interactive-layout-system.md Part 4
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Follows same Strategy Pattern as QueueItemOps. See docs/ADR-interactive-layout-system.md Part 4 for design rationale.
<!-- SECTION:NOTES:END -->
