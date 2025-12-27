---
id: task-27
title: Type-Safe Hybrid ContentDetails Refactor
status: Done
assignee:
  - '@agent'
created_date: '2025-12-24 11:26'
updated_date: '2025-12-24 14:07'
labels:
  - backend
  - refactor
  - architecture
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Refactor ContentDetails from YouTube-biased fixed structs to Type-Safe Hybrid architecture with Extensions system. This addresses the design critique that current domain types are YouTube-specific and don't gracefully handle backends with different capabilities (MPD, future Spotify). See docs/plans/2024-12-24-backend-api-unification.md Part 2-3 for full design.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Create src/domain/content.rs with new ContentDetails enum (AlbumContent, ArtistContent, PlaylistContent)
- [x] #2 Add Extensions container with SectionKey enum and SectionData variants
- [x] #3 Add ExtensionsBuilder for ergonomic construction
- [x] #4 Update YouTube backend to build Extensions with stats, related content
- [x] #5 Update MPD backend to return minimal Extensions (actions only)
- [x] #6 Update Discovery::details() return type to new ContentDetails
- [x] #7 Update UI to render Extensions dynamically
- [x] #8 Deprecate old domain/details.rs types
- [x] #9 cargo build passes
- [x] #10 cargo test passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create src/domain/content.rs with core types
2. Add Extensions, Section, SectionKey, SectionData
3. Add ExtensionsBuilder with fluent API
4. Update YouTube Discovery::details() to build Extensions
5. Update MPD Discovery::details() to return minimal
6. Update messaging.rs QueryResult variants
7. Update UI views to render Extensions
8. Mark old domain/details.rs as deprecated
9. Verify build and tests
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Type-Safe Hybrid architecture with Extensions system. All 662 tests pass. Commit: 166d0ac
<!-- SECTION:NOTES:END -->
