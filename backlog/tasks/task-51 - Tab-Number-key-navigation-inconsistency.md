---
id: task-51
title: Tab/Number key navigation inconsistency
status: To Do
assignee: []
created_date: '2025-12-31 15:47'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
BEHAVIOR: Press 1/2/3 switches pane but tab bar highlight stays. Press Tab changes highlight but pane stays. ROOT CAUSE: Navigator handles number keys internally with stop_propagation(), never updates ctx.active_tab. Tab key bypasses Navigator, updates ctx.active_tab but Navigator ignores TabChanged events.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Number keys update both Navigator pane AND tab bar highlight
- [ ] #2 Tab key update both Navigator pane AND tab bar highlight
<!-- AC:END -->
