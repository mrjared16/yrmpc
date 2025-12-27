---
id: task-22
title: Keybinding Discoverability in UI
status: Done
assignee: []
created_date: '2025-12-21 17:51'
updated_date: '2025-12-27 10:35'
labels: []
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Current keybindings for repeat/shuffle/single modes (z/x/v) are not discoverable in the UI. Users have no way to know these keys exist without reading config files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Header shows keybinding hints for modes
- [ ] #2 Help modal accessible via ~ key
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified 2025-12-27: KeybindsModal in ui/modals/keybinds.rs shows Global, Navigation, Queue keybinds with descriptions.
<!-- SECTION:NOTES:END -->
