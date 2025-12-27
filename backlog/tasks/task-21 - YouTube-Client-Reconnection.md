---
id: task-21
title: YouTube Client Reconnection
status: Done
assignee: []
created_date: '2025-12-17 03:40'
updated_date: '2025-12-27 10:35'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
YouTubeClient::reconnect() is not implemented. When daemon connection drops (Broken pipe), client cannot recover.

File: rmpc/src/player/youtube/client.rs:197-199

Context: Discovered while investigating task-20. The search logic IS correct, but daemon connection drops causing Broken pipe errors.

See: .agent/session-2025-12-17-cpu-fix.md for full context
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Reconnect restores connection after Broken pipe
- [ ] #2 No manual daemon restart required
- [ ] #3 Reconnection is logged for debugging
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: YouTubeProxy::reconnect() implemented in youtube/client.rs with socket reconnection and buffer recreation.
<!-- SECTION:NOTES:END -->
