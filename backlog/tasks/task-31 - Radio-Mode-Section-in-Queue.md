---
id: task-31
title: Radio Mode Section in Queue
status: To Do
assignee: []
created_date: '2025-12-27 19:08'
labels:
  - feature
  - ux
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Queue shows three sections: Now Playing, Up Next, and Radio Suggestions. Radio suggestions are auto-generated based on current song. Uses existing SectionList + build_sections pattern.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 QueueContent gains radio_suggestions field
- [ ] #2 build_sections creates Radio Suggestions section
- [ ] #3 Tab navigation works between all 3 sections
- [ ] #4 Suggestions fetched from YouTube Mix API
<!-- AC:END -->
