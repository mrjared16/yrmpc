---
id: task-9
title: Play vs Add Queue Action
status: Done
assignee: []
created_date: '2025-12-09 21:21'
updated_date: '2025-12-27 10:28'
labels:
  - ui
  - queue
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-SEARCH-3: Enter=play (replace queue), Shift+Enter=add to queue.

**Context:**
- Search results should support different actions
- Spec: docs/ui-ux-provised.md section 2.1 (R-SEARCH-3)

**Implementation hints:**
- File: ui/panes/search/mod.rs, handle_input() method
- Enter: Clear queue + add + play: queue.clear(); queue.add(song); play(0)
- Shift+Enter: Just add: queue.add(song)
- Reference existing Enter handler logic
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Enter on search item plays immediately
- [ ] #2 Shift+Enter adds to queue without playing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: search_pane_v2.rs distinguishes add_to_queue (enqueue) vs play_song (clear+play). ListAction::Activate vs Enqueue.
<!-- SECTION:NOTES:END -->
