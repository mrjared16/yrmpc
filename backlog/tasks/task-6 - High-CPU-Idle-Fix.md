---
id: task-6
title: High CPU Idle Fix
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-09 21:36'
labels:
  - performance
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Profile and fix high CPU usage when idle.

**Context:**
- Daemon uses CPU even when not playing
- Should be near 0% when idle

**Implementation hints:**
- Profile with: cargo flamegraph --bin rmpc
- Check event loop in core/ for tight loops
- Check MPV polling frequency in player/youtube/services/playback_service.rs
- Add sleep/await if polling too frequently
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Identify cause via profiling
- [ ] #2 Reduce idle CPU to near 0%
<!-- AC:END -->
