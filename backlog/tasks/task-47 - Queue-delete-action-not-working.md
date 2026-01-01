---
id: task-47
title: Queue delete action not working
status: In Progress
assignee: []
created_date: '2025-12-30 07:19'
updated_date: '2026-01-01 04:38'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Cannot delete items from queue
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIXED: Queue delete now shows explicit error instead of silently failing.

**Root Cause**: indices_to_ids() used .filter_map() silently dropping None IDs.

**Fix**: Changed return type to Result<Vec<u32>> in queue_pane_v2.rs:202-211:
- Explicitly bail with anyhow::bail! if song has no ID
- Error message: 'Selected items not found in queue'
- Updated all call sites (lines 224-233) to handle errors with status_error! macro

**Tests**: indices_to_ids_errors_on_missing_ids() proves error handling
<!-- SECTION:NOTES:END -->
