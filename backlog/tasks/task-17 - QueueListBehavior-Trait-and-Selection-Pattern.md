---
id: task-17
title: QueueListBehavior Trait and Selection Pattern
status: Done
assignee: []
created_date: '2025-12-11 23:20'
updated_date: '2025-12-11 23:35'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement QueueListBehavior trait and Selection pattern in list_ops.rs. KEY DESIGN: Selection uses INDICES (not references) to avoid lifetime/borrow conflicts. Provides shared queue action logic (play, delete, move) between QueuePaneV2 and QueueModal, plus unified single/bulk operation interface.
<!-- SECTION:DESCRIPTION:END -->
