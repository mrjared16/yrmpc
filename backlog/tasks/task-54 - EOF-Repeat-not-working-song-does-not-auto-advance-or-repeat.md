---
id: task-54
title: EOF/Repeat not working - song does not auto-advance or repeat
status: In Progress
assignee: []
created_date: '2025-12-31 16:15'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
BEHAVIOR: When song ends (EOF), does not auto-advance to next in queue or repeat when repeat mode on. ROOT CAUSE: Needs investigation - EOF event handling in playback service, queue advance logic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Song auto-advances to next when current ends
- [ ] #2 Song repeats when repeat-one mode enabled
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
INVESTIGATION: Code analysis shows EOF handling is architecturally correct. Flow: MPV->MpvIpc->PlaybackService->YouTubeServer->Orchestrator. All repeat modes and queue advance logic exist in orchestrator.rs handle_eof(). Likely a runtime issue (MPV connection, event timing, or state mismatch). Requires runtime debugging with logs - check if 'Track ended with reason: eof' appears in logs when song finishes.
<!-- SECTION:NOTES:END -->
