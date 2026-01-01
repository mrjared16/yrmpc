---
id: task-48
title: 'Find mode: Cannot type ''n'' character'
status: In Progress
assignee: []
created_date: '2025-12-31 15:07'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When in Find mode (after pressing '/'), typing 'n' jumps to next match instead of adding 'n' to the search pattern. Users cannot search for patterns containing 'n' (e.g., 'song', 'cannot'). Root cause: KeyCode::Char('n') is matched before KeyCode::Char(ch) in Find mode handler.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Typing 'n' in Find mode adds 'n' to filter pattern
- [x] #2 n/N only jump to next/prev match in Normal mode after pattern confirmed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed: Removed 'n'/'N' handlers from Find mode block so all characters go to filter_push_char(). Added TDD tests that verify typing 'n' and 'N' adds to filter.
<!-- SECTION:NOTES:END -->
