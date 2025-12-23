---
id: task-medium.3
title: Adapt SearchPane to InteractiveListView
status: Done
assignee: []
created_date: '2025-12-11 00:09'
updated_date: '2025-12-11 13:29'
labels:
  - architecture
  - ui
  - search
dependencies: []
parent_task_id: task-medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
SearchPane still uses internal hardcoded column_widths (20/38/42) and does NOT use the new InteractiveListView component.

**Current state:**
- SearchPane reads column_widths from ctx.config.theme (hardcoded in theme)
- SearchPane has its own navigation logic (not reusing InteractiveListView)
- Inconsistent with QueuePaneV2 which uses InteractiveListView

**Decision context (from ADR):**
SearchPane is a 'Compound Pane' with shared state between filter/results/preview. Full decomposition would require message passing between panes.

**Two options:**
1. Partial: Use InteractiveListView for results list only
2. Full: Decompose into SearchFilters + SearchResults + SearchPreview panes

**Reference docs:**
- docs/ADR-interactive-layout-system.md Part 1 (original layout inconsistency)
- docs/ADR-interactive-layout-system.md Part 3 (InteractiveListView design)
- rmpc/src/ui/panes/search/mod.rs lines 1358-1363 (column_widths usage)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Evaluate: partial vs full decomposition approach
- [x] #2 If partial: Replace songs_dir navigation with InteractiveListView
- [ ] #3 If full: Create SearchFilters, SearchResults, SearchPreview panes
- [ ] #4 Remove column_widths hardcode from search/mod.rs
- [ ] #5 Update docs/ADR-interactive-layout-system.md with final approach
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
SUPERSEDED by SearchPaneV2 (task-14).

Approach taken: Full new implementation using BrowseStack + InteractiveListView rather than adapting existing SearchPane. Legacy remains available via config toggle.
<!-- SECTION:NOTES:END -->
