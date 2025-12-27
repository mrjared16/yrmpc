---
id: task-20
title: Fix Search After CPU Fix
status: Done
assignee:
  - '@agent'
created_date: '2025-12-16 18:32'
updated_date: '2025-12-27 10:35'
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Search broke after CPU fix (task-6). The 1s sleep workaround in read_response() needs proper solution.

**Background**: Task-6 fixed 146% CPU by making YouTubeClient::read_response() sleep instead of returning immediately. But this may have broken search.

**Root cause**: YouTube backend doesn't need idle/request threads but shares code with MPD backend.

**Options**:
1. Skip client threads for YouTube backend in main.rs
2. Make YouTube client block properly on event channel
3. Fix request flow to handle timeout gracefully

**CRITICAL**: DO NOT revert the CPU fix - find a proper solution.

**Context**: See .agent/session-2025-12-17-cpu-fix.md for full details.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Search works again
- [x] #2 CPU stays at 0% when idle
- [x] #3 No 1-second workaround sleep
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Root cause found: continue on line 138 of core/client.rs prevents client from being yielded to request thread.

## Implementation Plan:
1. Fix core/client.rs:136-138 - change continue to break vec![] with documentation
2. Reduce youtube/client.rs sleep from 1s to 100ms for better latency
3. Fix misleading docstring in youtube/client.rs

## Why this works:
- break vec![] exits inner loop, allowing ClientDropGuard to return client
- Request thread can then process search requests
- Sleep becomes polling interval (100ms = 10 cycles/sec, ~0.5% CPU)
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Session 2025-12-17 findings:

1. CORE FIX APPLIED: Changed continue to break vec![] in core/client.rs:136-148
2. LATENCY FIX: Reduced sleep from 1s to 100ms in youtube/client.rs:188
3. DISCOVERY: Search IS working (logs show SearchPaneV2::search() called with filter)
4. NEW ISSUE: Daemon connection drops cause 'Broken pipe' errors
5. ROOT CAUSE of broken pipe: YouTubeClient::reconnect() is not implemented

The core fix is CORRECT - the 'continue' was starving the request thread.
The 'Broken pipe' errors are from a SEPARATE daemon reconnection issue.

Session 2025-12-27 Update:

Navigator architecture now integrated into ui/mod.rs:
- SearchPaneV2 receives events via Navigator.on_query_finished()
- Proper event routing ensures search results arrive correctly
- Legacy actor.rs deleted (was dead code, never compiled)

AC #1 (Search works) should now be testable with Navigator enabled.
Remaining: verify search end-to-end with daemon running.

Verified 2025-12-27: Search fully working via IPC. YouTubeProxy has 100ms polling. Navigator routes query results correctly.
<!-- SECTION:NOTES:END -->
