---
id: task-21
title: YouTube Client Reconnection
status: To Do
assignee: []
created_date: '2025-12-17 03:40'
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
