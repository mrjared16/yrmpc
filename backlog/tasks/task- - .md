---
id: ''
title: ''
status: ''
assignee: []
created_date: ''
updated_date: '2025-12-29 05:10'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Deep architectural refinement of the action system based on code review session.
The current implementation has infrastructure built but not integrated, with several
SOLID violations and layer mixing issues.

## Critical Issues to Fix

### 1. Two ActionKind Enums (Duplicate Responsibility)
- `domain/content.rs:1039` - ActionKind for UI action buttons
- `actions/intent.rs:23` - ActionKind for intent system
**Fix**: Merge or rename to avoid confusion

### 2. Panes Bypass Intent System (Dead Code)
- `resolve_action` in panes still returns `PaneAction::Play(song)` directly
- Intent system (`PaneAction::Execute(Intent)`) is not wired
**Fix**: Phase 3 of refactoring roadmap

### 3. PlayHandler Conflates Two Use Cases (SRP Violation)
- "Play new content" vs "Toggle current playback"
- Should be separate handlers or separate IntentKinds
**Fix**: Split into PlayHandler and TogglePlaybackHandler

### 4. Header in Domain Layer (Layer Violation)
- `DetailItem::Header` is a presentation concern
- Pollutes all components touching DetailItem
**Fix**: Move Header to UI-only ListItem enum

### 5. Inconsistent resolve_action Signatures
- Queue: `fn resolve_action(&self, item, ctx) -> PaneAction`
- Search: `fn resolve_action(&mut self, ctx, item) -> Result<()>`
- Album: `fn resolve_action(&self, item) -> PaneAction`
**Fix**: Standardize to `fn create_intent(&self, item) -> Option<Intent>`

### 6. Navigate/ToggleMark in IntentKind (Wrong Layer)
- These are UI operations, not domain actions
**Fix**: Keep as PaneAction variants, remove from IntentKind

## Refactoring Phases

### Phase 1: Fix Layer Violations
- [ ] Move Header to UI layer (create ListItem enum)
- [ ] Merge/rename ActionKind (one source of truth)
- [ ] Remove Navigate/ToggleMark from IntentKind

### Phase 2: Unify Responsibility
- [ ] Standardize resolve_action → create_intent signature
- [ ] Move validation entirely to handlers
- [ ] Split PlayHandler into Play + TogglePlayback

### Phase 3: Wire Intent System
- [ ] Panes return PaneAction::Execute(Intent)
- [ ] Delete duplicated marked-item logic from panes
- [ ] Handler handles all play/queue operations

### Phase 4: Optimize
- [ ] Pass &Intent instead of owned Intent
- [ ] Consider HashMap<IntentKind, Handler> dispatcher
- [ ] Add caching to Selection queries
<!-- SECTION:DESCRIPTION:END -->

# Task: Action System Architecture Refinement

## Status: To Do
## Priority: High
## Labels: architecture, refactor, SOLID

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single ActionKind/IntentKind definition
- [ ] #2 Header only exists in UI layer
- [ ] #3 All panes use create_intent with consistent signature
- [ ] #4 PlayHandler only handles "play new content"
- [ ] #5 Intent system actually executes actions
- [ ] #6 User sees feedback when action fails
- [ ] #7 Single IntentKind definition (no duplicate ActionKind)
- [ ] #8 Header only exists in UI layer (ListItem enum)
- [ ] #9 All panes use create_intent() with consistent signature
- [ ] #10 PlayHandler only handles play new content
- [ ] #11 Intent system actually executes actions (not bypassed)
- [ ] #12 User sees feedback when action fails
- [ ] #13 HashMap dispatcher with priority chains
- [ ] #14 Pass &Intent instead of owned
- [ ] #15 All 711+ tests pass
<!-- AC:END -->



## Notes

This task emerged from a deep architectural critique session.
See handoff document: .agent/handoffs/2025-12-28-architecture-refinement.md
