---
id: task-25
title: 'Backend API Unification - Phase 1: Add View Model & details()'
status: Done
assignee:
  - '@agent'
created_date: '2025-12-24 10:01'
updated_date: '2025-12-24 10:29'
labels:
  - backend
  - refactor
  - api
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add composable DetailsPage view model and Discovery::details() method to enable backend-agnostic detail views. This is the first phase of the backend API unification plan documented in docs/plans/2024-12-24-backend-api-unification.md
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add details() method to Discovery trait in discovery.rs
- [x] #2 Implement Discovery::details() for YouTubeProxy
- [x] #3 Implement Discovery::details() for MpdBackend (sparse but valid)
- [x] #4 Add details() dispatch in BackendDispatcher
- [x] #5 cargo build passes
- [x] #6 cargo test passes
- [x] #7 Create src/domain/details.rs with ArtistRef, AlbumRef, PlaylistRef, AlbumDetails, ArtistDetails, PlaylistDetails, ContentDetails (proper layer separation)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
CORRECTED PLAN (proper layer separation):

1. Delete incorrectly placed src/backends/api/view.rs (UI concerns don't belong in backend)

2. Create src/domain/details.rs with domain types:
   - ArtistRef, AlbumRef, PlaylistRef (navigation references)
   - AlbumDetails, ArtistDetails, PlaylistDetails (full details)

3. Update src/domain/mod.rs to export details module

4. Add ContentDetails enum to src/backends/api/discovery.rs:
   - ContentDetails::Album(AlbumDetails)
   - ContentDetails::Artist(ArtistDetails)
   - ContentDetails::Playlist(PlaylistDetails)

5. Add details() method to Discovery trait

6. Update YouTube protocol.rs to_details() to return domain types

7. Implement Discovery::details() for YouTubeProxy

8. Implement Discovery::details() for MpdBackend (sparse/stub)

9. Add details() dispatch in BackendDispatcher

10. Update imports in messaging.rs and ui/panes/search/mod.rs

11. Verify: cargo build && cargo test
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Implemented Phase 1 of Backend API Unification with proper layer separation:

### Domain Layer (src/domain/details.rs)
- Created domain types: ArtistRef, AlbumRef, PlaylistRef
- Created detail types: AlbumDetails, ArtistDetails, PlaylistDetails
- Created ContentDetails enum to wrap the detail types
- All types are backend-agnostic and use domain::Song for tracks

### Backend API Layer (src/backends/api/discovery.rs)
- Added details() method to Discovery trait
- Returns ContentDetails enum
- Re-exported ContentDetails from api module

### Backend Implementations
- YouTubeProxy: Implemented details() using existing browse_*_details methods with conversion to domain types
- MpdBackend: Implemented sparse details() that returns basic info from directory/playlist listings
- BackendDispatcher: Added dispatch for details() method

### Key Design Decision
Originally planned to put view model (DetailsPage, Layout, Action) in backends/api/view.rs.
Corrected to proper layer separation:
- Domain types (what the data IS) in src/domain/
- Backend API (how to fetch) in src/backends/api/
- View models (how to render) will go in src/ui/views/ in Phase 2

### Verification
- cargo build: ✅ passes (21 warnings, pre-existing)
- cargo test --lib: ✅ 653 tests pass
<!-- SECTION:NOTES:END -->
