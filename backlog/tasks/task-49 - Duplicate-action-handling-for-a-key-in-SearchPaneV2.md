---
id: task-49
title: Duplicate action handling for 'a' key in SearchPaneV2
status: Done
assignee: []
created_date: '2025-12-31 15:14'
updated_date: '2025-12-31 15:28'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When pressing 'a' to add song to queue in search results, add_to_queue() is called twice. First via ContentAction::Enqueue flow, then again via CommonAction::AddOptions check that runs AFTER ContentView returns. Root cause: Redundant action dispatch path - both ContentAction and CommonAction handle the same key.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pressing 'a' adds song to queue exactly once
- [x] #2 No duplicate entries appear in queue
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fixed: Removed redundant CommonAction::AddOptions handler from search_pane_v2.rs. ContentAction::Enqueue already handles 'a' key correctly.
<!-- SECTION:NOTES:END -->
