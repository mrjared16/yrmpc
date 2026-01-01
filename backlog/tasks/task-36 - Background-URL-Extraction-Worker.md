---
id: task-36
title: Background URL Extraction Worker
status: In Progress
assignee: []
created_date: '2025-12-28 07:56'
updated_date: '2025-12-31 05:43'
labels:
  - performance
  - feature
dependencies: []
priority: medium
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Pre-extract URLs when songs added to queue.

Current: URLs extracted on-demand when playback starts
Proposed: Background worker pre-extracts when songs added

ExtractionWorker:
- Receives QueueEvent::SongsAdded
- Calls url_resolver.prefetch() in background
- Errors logged, not propagated (best-effort)

Files:
- src/backends/youtube/extraction_worker.rs - New file
- src/backends/youtube/server/mod.rs - Spawn worker at startup
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ExtractionWorker struct implemented
- [ ] #2 Worker listens for queue add events
- [ ] #3 URLs pre-extracted in background thread
- [ ] #4 Errors logged but dont block
- [ ] #5 Worker spawned at daemon startup
- [ ] #6 All tests pass
<!-- AC:END -->
