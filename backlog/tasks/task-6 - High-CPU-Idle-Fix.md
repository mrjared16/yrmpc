---
id: task-6
title: High CPU Idle Fix
status: Done
assignee:
  - '@agent'
created_date: '2025-12-09 21:20'
updated_date: '2025-12-16 18:26'
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
- [x] #1 Identify cause via profiling
- [x] #2 Reduce idle CPU to near 0%
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root Cause

Per-thread CPU profiling revealed:
- `idle` thread: 77.7% CPU
- `request` thread: 68.4% CPU
- Total: ~146% CPU

The `idle` and `request` threads in `core/client.rs` were designed for MPD's blocking idle protocol. For YouTube backend, `YouTubeClient::read_response()` returned `Ok(vec![])` immediately without blocking, causing both threads to spin in a tight loop passing the client back and forth.

## Fix Applied

**File: src/player/youtube/client.rs:175-191**

Changed `read_response()` to:
1. Sleep for 1 second (blocking)
2. Return `MpdError::TimedOut` so the idle thread handles it gracefully

**Also fixed: src/player/mpv_ipc.rs:232-265**

Changed `read_event()` to return `Option<MpvEvent>` instead of spinning on timeout.

## Result

- Before: ~146% CPU when idle
- After: 0.0% CPU when idle
<!-- SECTION:NOTES:END -->
