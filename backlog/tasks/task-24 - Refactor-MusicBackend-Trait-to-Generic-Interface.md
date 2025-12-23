---
id: task-24
title: Refactor MusicBackend Trait to Generic Interface
status: In Progress
assignee: []
created_date: '2025-12-21 18:42'
updated_date: '2025-12-22 19:40'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Complete backend architecture refactor following SOLID principles.

**See**: [ADR-backend-refactor.md](docs/ADR-backend-refactor.md) for full plan.

**Goals**:
1. Interface Segregation: Split MusicBackend into Playable + Queueable + Searchable
2. Backend Agnosticism: No MPD/MPV types leak into core interfaces
3. Symmetry: MPD and YouTube have parallel structures
4. Extensibility: New backends can be added without modifying existing code

**Key Changes**:
- Create `src/traits/` with focused trait definitions
- Create `src/backends/` to unify all backend implementations
- Abstract MPV behind `MediaEngine` trait (replaceable)
- Move MPD from `src/mpd/` into `src/backends/mpd/`
- Remove stub implementations from YouTube backend
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Generic player trait defined with clean naming
- [ ] #2 YouTube backend implements generic trait only
- [ ] #3 MPD-specific methods moved to separate trait
- [ ] #4 No stub implementations in YouTube backend
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Phase 1: Foundation (No Breaking Changes)
1.1 Create src/traits/ directory structure
1.2 Create src/backends/ directory structure
1.3 Define Playable, Queueable, Searchable traits
1.4 Define composite MusicBackend trait
1.5 Define extension traits (PlaylistPersistence, etc.)

Phase 2: Migrate Shared Utilities
2.1 Create MediaEngine trait abstraction
2.2 Move MPV code to backends/shared/mpv/
2.3 Implement MediaEngine for MpvIpc

Phase 3: Migrate YouTube Backend
3.1 Move youtube/ to backends/youtube/
3.2 Restructure daemon code into daemon/ subdirectory
3.3 Update PlaybackService to use MediaEngine trait
3.4 Implement new traits for YouTubeBackend

Phase 4: Migrate MPD Backend
4.1 Move mpd/ to backends/mpd/
4.2 Move mpd_backend.rs into backends/mpd/
4.3 Implement new traits for MpdBackend
4.4 Create MPD extension implementations

Phase 5: Update Core
5.1 Create backend factory function
5.2 Update core to use new traits
5.3 Remove old player module

Phase 6: Cleanup
6.1 Remove deprecated methods
6.2 Remove stub implementations
6.3 Update documentation
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Session 2025-12-22: Phase 1 Complete

**File reorganization done:**
- All backends now under src/backends/
- MPD protocol in backends/mpd/protocol/
- YouTube in backends/youtube/
- MPV in backends/mpv/
- Build compiles successfully

**Backward compatibility preserved via re-exports.**

**Phase 2+ (trait split) deferred to future session.**

Session 2025-12-23: Completed Phase 1 naming cleanup. Renamed PlayerController to BackendDispatcher with backward compatibility. Build fixed. Tests currently broken due to previous Song struct changes.
<!-- SECTION:NOTES:END -->
