---
id: task-19
title: Fix Broken Search Enter Key
status: Done
assignee: []
created_date: '2025-12-13 17:49'
updated_date: '2025-12-14 07:55'
labels:
  - search
  - blocker
  - regression
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
⚠️ URGENT: Search is broken after session 2025-12-13

**Symptom**: Enter key does not trigger search
**Cause**: Vim-style keybinding changes in search_pane_v2.rs

**Debug location**: search_pane_v2.rs lines 273-289 handle_search_phase()

**Expected flow**:
1. Press i → enter insert mode
2. Type query
3. Press Esc → exit insert mode  
4. Press Enter → should call self.search(ctx)

**Actual**: Enter does nothing
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Enter key triggers search when not in insert mode
- [x] #2 Search results populate after Enter
- [x] #3 No regression on other search features
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed in session 2025-12-14.

**Root cause**: Search was actually working - the perceived "broken" behavior was a misunderstanding of vim-style flow.

**Actual issue found**: Performance regression (2+ second delay) due to missing ctx.render() in on_query_finished.

**Fix**: Added auto-render at framework level in ui/mod.rs after on_query_finished completes.
<!-- SECTION:NOTES:END -->
