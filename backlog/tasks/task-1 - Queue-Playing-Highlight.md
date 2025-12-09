---
id: task-1
title: Queue Playing Highlight
status: To Do
assignee: []
created_date: '2025-12-09 21:20'
updated_date: '2025-12-09 21:36'
labels:
  - ui
  - queue
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
R-QUEUE-1: Show which song is currently playing in queue with bold + ▶ icon.

**Context:**
- Queue shows tracks to play next (rmpc/src/ui/panes/queue.rs)
- Spec: docs/ui-ux-provised.md section 2.2 (R-QUEUE-1)
- Rich List UI already implemented (docs/ADR-rich-list-ui.md)

**Implementation hints:**
- Add is_playing() method to ListItemDisplay trait (domain/display.rs)
- Queue pane should track current playing song via status
- Render with bold style + "▶" prefix when is_playing() returns true
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Add is_playing() to ListItemDisplay trait
- [ ] #2 Queue view renders playing track with bold + ▶ icon
- [ ] #3 Currently playing track visually distinct
<!-- AC:END -->
