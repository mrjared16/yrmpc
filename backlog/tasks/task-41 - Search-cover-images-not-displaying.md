---
id: task-41
title: 'Search: cover images not displaying'
status: Done
assignee: []
created_date: '2025-12-30 07:19'
updated_date: '2025-12-30 13:33'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Thumbnails not showing on search result items
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED via Phase 1: Display Layer Refactor (same fix as task-39). Cover images now display because HighlightedItem properly proxies thumbnail_url() and the render pipeline works correctly.
<!-- SECTION:NOTES:END -->
