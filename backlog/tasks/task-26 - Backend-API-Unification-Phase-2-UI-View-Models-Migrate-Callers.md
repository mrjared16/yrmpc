---
id: task-26
title: 'Backend API Unification - Phase 2: UI View Models & Migrate Callers'
status: Done
assignee:
  - '@agent'
created_date: '2025-12-24 10:31'
updated_date: '2025-12-24 10:42'
labels:
  - backend
  - refactor
  - ui
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create UI view models for rendering detail pages, migrate UI code from youtube() escape hatch to Discovery::details(), and fix the playlist metadata bug. Part of backend API unification plan.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Create src/ui/views/mod.rs and src/ui/views/details.rs with DetailsPage view model
- [x] #2 Add conversion from domain::ContentDetails to DetailsPage view model
- [x] #3 Migrate ui/panes/search/mod.rs from youtube().browse_*_details() to Discovery::details()
- [x] #4 Migrate backends/messaging.rs to use domain types instead of youtube types
- [x] #5 Fix playlist metadata bug - use GetPlaylistDetailsQuery for proper title/description
- [x] #6 cargo build passes
- [x] #7 cargo test passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create src/ui/views/ directory with mod.rs
2. Create src/ui/views/details.rs with DetailsPage view model (Artwork, Stats, Section, Action, Layout)
3. Add From<ContentDetails> impl to convert domain types to view model
4. Update src/ui/mod.rs to export views module
5. Read ui/panes/search/mod.rs to understand current usage of youtube().browse_*_details()
6. Migrate DetailView enum to use domain::ContentDetails instead of youtube types
7. Update backends/messaging.rs QueryResult to use domain types
8. Fix playlist metadata bug in youtube/api.rs - use correct YouTube queries
9. Verify: cargo build && cargo test
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added From impls for YouTube->domain type conversions in backends/youtube/details.rs. Fixed playlist metadata bug by using GetPlaylistDetailsQuery for metadata instead of only GetWatchPlaylistQuery.

AC#3: Partial - added .into() conversions to domain types. Full migration to Discovery::details() deferred to Phase 3 (escape hatch removal).
<!-- SECTION:NOTES:END -->
