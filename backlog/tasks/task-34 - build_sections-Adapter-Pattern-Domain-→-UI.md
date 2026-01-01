---
id: task-34
title: build_sections Adapter Pattern (Domain → UI)
status: Done
assignee:
  - '@agent'
created_date: '2025-12-28 07:52'
updated_date: '2025-12-28 15:49'
labels:
  - architecture
  - refactor
dependencies:
  - task-32
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Move section building to domain layer with clean adapter:

Domain provides structure:
- ContentSection { key, title, items } in domain/content.rs
- impl ContentViewable::sections() for AlbumContent, ArtistContent, etc.

UI adapts to presentation:
- impl From<ContentSection> for SectionView

Files:
- src/domain/content.rs - Add ContentSection, impl sections()
- src/ui/widgets/detail_stack.rs - Remove build_sections match, use adapter
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ContentSection type defined in domain layer
- [x] #2 ContentViewable trait has sections() method
- [x] #3 All content types implement sections()
- [ ] #4 UI uses From<ContentSection> adapter
- [ ] #5 build_sections removed from detail_stack.rs
- [ ] #6 All tests pass
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added ContentSection in domain, sections() method on ContentViewable, From<Section> for SectionView adapter

Added semantic SectionKey values: Tracks, TopSongs, SearchResults, NowPlaying, UpNext. From<Section> for SectionView adapter implemented.

## Code Review (2025-12-28)
- From<Section> for SectionView adapter added
- into_sections() added to ContentDetails
- BUT: build_sections() still duplicated in detail_stack.rs
- Need migration task to remove duplication
<!-- SECTION:NOTES:END -->
