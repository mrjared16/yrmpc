---
id: task-2
title: Queue View Revamp
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-09 21:36'
labels:
  - ui
  - queue
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-QUEUE-2: Apply Rich List UI (ItemListWidget) to QueuePane.

**Context:**
- Queue currently uses legacy table/list rendering
- Rich List UI implemented in ui/widgets/item_list.rs
- Spec: docs/ui-ux-provised.md section 2.2 (R-QUEUE-2)

**Implementation hints:**
- Replace queue rendering with ItemListWidget
- Enable rich mode via ItemListConfig { mode: ListRenderMode::Rich }
- Display thumbnails per row (2-line layout)
- Reference: ui/panes/search/mod.rs for example usage
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 QueuePane uses ItemListWidget for rendering
- [ ] #2 Thumbnails displayed per queue row
- [ ] #3 Rich mode toggle works in queue
<!-- AC:END -->
