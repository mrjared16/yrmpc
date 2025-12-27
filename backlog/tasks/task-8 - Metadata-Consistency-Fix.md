---
id: task-8
title: Metadata Consistency Fix
status: Done
assignee: []
created_date: '2025-12-09 21:21'
updated_date: '2025-12-27 10:28'
labels:
  - bug
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Fix case mismatch: Song.album() uses "Album" but YouTube uses "album".

**Context:**
- Album metadata displays correctly in search but not in queue
- Research completed: docs/backlog-metadata-consistency.md
- Root cause: Song.album() case sensitivity

**Implementation hints:**
- File: rmpc/src/domain/song.rs, method album()
- Make case-insensitive: check both "album" and "Album" keys
- Test with YouTube search results in queue view
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Song.album() checks both 'album' and 'Album' keys
- [ ] #2 Queue view shows album metadata correctly
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: domain/song.rs uses unified HashMap<String, Vec<String>> with standard getters.
<!-- SECTION:NOTES:END -->
