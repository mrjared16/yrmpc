# Tracking Locations for ADR-003 Migration

**CRITICAL**: Update ALL these locations when completing work to avoid stale information.

## 1. Plan File (Primary Source of Truth)
- **File**: `.sisyphus/plans/adr-003-media-preparer-migration.md`
- **Format**: Markdown checkboxes `- [ ]` / `- [x]`
- **Count**: 41 total checkboxes
- **Update**: Mark `[x]` when task acceptance criteria met

## 2. Beads (Issue Tracking)
- **Tool**: `bd` CLI
- **Commands**: 
  - `bd update <id> --status=in_progress` (claim)
  - `bd close <id>` (complete)
- **Epic**: `yrmpc-q8xi`
- **Beads**: 19 tasks (2 cancelled: 9h3q, 1f5c)

## 3. Todo List (Session Tracking)
- **Tool**: `todowrite` 
- **Location**: In-memory, tracked per session
- **Items**: 8 high-level phase todos
- **Update**: Mark status=completed when phase done

## 4. Notepad (Knowledge Base)
- **Directory**: `.sisyphus/notepads/adr-003-media-preparer-migration/`
- **Files**:
  - `learnings.md` - patterns, conventions discovered
  - `decisions.md` - architectural choices made
  - `issues.md` - problems encountered
  - `verification.md` - test results, validations
- **Update**: Append findings after each task

## Update Protocol (DO ALL 4)

When completing a task:
1. ✓ Mark checkbox in plan file
2. ✓ Close bead: `bd close <id>`
3. ✓ Update todo if phase complete
4. ✓ Document learnings in notepad
