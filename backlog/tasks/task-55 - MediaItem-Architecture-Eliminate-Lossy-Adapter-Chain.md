---
id: task-55
title: MediaItem Architecture - Eliminate Lossy Adapter Chain
status: In Progress
assignee:
  - '@agent'
created_date: '2025-12-31 21:33'
updated_date: '2025-12-31 22:00'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Refactor the type system to eliminate the Lossy Adapter Chain anti-pattern. Replace Song/Item duplication with unified MediaItem enum. See architecture review from 2026-01-01.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Unify ContentType enums (api vs domain)
- [x] #2 Create MediaItem enum with Track/Artist/Album/Playlist/Header variants
- [x] #3 Create BackendExtension enum for typed backend-specific data
- [ ] #4 Migrate BackendDispatcher to use MediaItem
- [ ] #5 Migrate UI layers to use MediaItem
- [ ] #6 Deprecate Song for non-MPD backends
- [ ] #7 All existing tests pass
- [ ] #8 No runtime regressions in search/queue/playback
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Phase 1: Unify ContentType (can run in parallel)
- Agent A: Merge api::ContentType + domain::ContentType into single enum
- Agent B: Update all imports and usages

Phase 2: Create MediaItem enum (sequential)
- Define MediaItem enum with variants
- Define BackendExtension enum
- Implement Displayable trait

Phase 3: Migration (can run in parallel)
- Agent A: Migrate BackendDispatcher
- Agent B: Migrate UI (DetailItem, search_pane_v2)
- Agent C: Migrate queue handling

Phase 4: Cleanup
- Deprecate Song for YouTube
- Update tests
- Documentation
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Phase 1 complete: ContentType unified into domain::ContentType with Header variant added. api::ContentType now re-exports from domain.

Phase 2-3 complete: MediaItem enum created with Track/Artist/Album/Playlist/Header variants. BackendExtension enum for YouTube/MPD. Bidirectional From conversions for Song and Item. 7 tests pass.
<!-- SECTION:NOTES:END -->
