---
id: task-8
title: Metadata Consistency Fix
status: To Do
assignee: []
created_date: '2025-12-09 21:21'
labels:
  - bug
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix case mismatch: Song.album() uses 'Album' but YouTube uses 'album'. See docs/backlog-metadata-consistency.md for full research.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Song.album() checks both 'album' and 'Album' keys
- [ ] #2 Queue view shows album metadata correctly
<!-- AC:END -->
