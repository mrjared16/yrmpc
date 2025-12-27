---
id: task-16
title: Fix Search Layout and Queue Behavior Issues
status: Done
assignee: []
created_date: '2025-12-11 14:28'
updated_date: '2025-12-27 10:30'
labels:
  - ui
  - queue
  - search
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix 6 issues found during testing: SearchPane layout too narrow/missing preview, Queue enter toggle, delete refresh, seek position, cover size. See docs/ISSUE_FIX_PLAN.md for detailed implementation guide.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 #1 SearchPane: Restore 3-column layout with configurable widths (docs/ISSUE_FIX_PLAN.md Issue 1-2)
- [ ] #2 #2 Queue: Enter on playing song toggles pause (uses client.pause_toggle())
- [ ] #3 #3 Queue: Enter on different song plays from start (uses seek_current(SeekPosition::Absolute(0.0)))
- [ ] #4 #4 Queue: Delete immediately updates list (on_event handles UiEvent::Player)
- [ ] #5 #5 Queue: Cover image uses larger constraints (Percentage vs fixed)
- [ ] #6 #6 All tests pass: cargo check && manual testing
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: search_pane_v2.rs implements 3-column layout with configurable widths from ctx.config.theme.column_widths.
<!-- SECTION:NOTES:END -->
