---
id: task-2
title: Queue View Revamp
status: Done
assignee:
  - '@agent'
created_date: '2025-12-09 21:20'
updated_date: '2025-12-11 13:30'
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
- [x] #1 QueuePane uses ItemListWidget for rendering
- [x] #2 Thumbnails displayed per queue row
- [x] #3 Rich mode toggle works in queue
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Completed QueuePaneV2 using InteractiveListView and ItemListWidget. Created generic InteractiveListView component for reuse. QueueModal also refactored. Documentation in docs/ADR-interactive-layout-system.md

CORRECTION (2025-12-11): Marked Done prematurely. QueuePaneV2 code exists but NOT wired to config. Actual completion requires task-high.2 (Wire QueuePaneV2 to Config System).

COMPLETED (2025-12-11): task-high.2 now Done. QueuePaneV2 wired via LegacyPanes config system. Build passes, queue interactions work.
<!-- SECTION:NOTES:END -->
