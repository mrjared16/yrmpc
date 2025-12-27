<role>
You are picking up implementation work on a TUI music player's unified view architecture refactor. The previous agent completed critical bug fixes and Phase 1-2 of the migration plan. You are continuing with Phases 3-5 to complete the Navigator-based architecture and remove legacy code.
</role>

<context>
The yrmpc project (YouTube Music TUI in Rust) is undergoing a major refactor from a legacy PaneContainer-based UI to a new Navigator-based architecture following an ADR (docs/ADR-unified-view-architecture.md). The new architecture uses layered SOLID components: InteractiveListView → SectionList → ContentView → Panes → Navigator. The previous agent fixed two critical bugs (vim n/N navigation, queue move position calculation), simplified the legacy config flag to a single `legacy_panes.enabled` boolean (defaults to false = new architecture), and documented the navigate_to() flow. The V2 panes (SearchPaneV2, QueuePaneV2) implement BOTH legacy Pane trait AND new NavigatorPane trait for coexistence during migration.
</context>

<current_state>
**Completed:**
- Bug Fix 1: Added n/N key support in Normal mode when filter is active (interactive_list_view.rs ~line 530)
- Bug Fix 2: Fixed execute_queue_move to properly lookup position from ctx.queue instead of using ID as position (navigator.rs lines 380-431)
- Phase 1: Simplified LegacyPanes config to single `enabled: bool` field (defaults false), wired Navigator creation in actor.rs
- Phase 2: Verified QueueContent exists and ID mapping is done at pane level

**In Progress:**
- Phase 3: navigate_to() updated with documentation explaining the async flow. The method is complete but the async fetch is handled by source panes (SearchPaneV2) not Navigator itself.

**Pending:**
- Phase 4: Remove legacy `impl Pane for SearchPaneV2` and `impl Pane for QueuePaneV2` (dual trait implementations)
- Phase 5: Delete deprecated code (~5000 lines): NavStack, legacy search/mod.rs, legacy queue.rs, PaneContainer routing

**Build Status:** `cargo check` passes successfully
</current_state>

<key_files>
**Config:**
- `rmpc/src/config/mod.rs` - LegacyPanes struct now has single `enabled: bool` field (lines 99-117)

**Navigator System:**
- `rmpc/src/ui/panes/navigator.rs` (497 lines) - Main controller with handle_key, execute_* methods, navigate_to
- `rmpc/src/ui/panes/navigator_types.rs` (426 lines) - NavigatorPane, TabPane, DetailPane traits, PaneAction/ListAction/SectionAction enums

**V2 Panes (have dual trait implementations to remove):**
- `rmpc/src/ui/panes/search_pane_v2.rs` (952 lines) - impl Pane (lines 612-763), impl NavigatorPane (lines 772-907)
- `rmpc/src/ui/panes/queue_pane_v2.rs` (498 lines) - impl Pane, impl NavigatorPane

**Legacy Code (candidates for deletion in Phase 5):**
- `rmpc/src/ui/panes/search/mod.rs` (2016 lines) - Legacy SearchPane
- `rmpc/src/ui/panes/queue.rs` (1449 lines) - Legacy QueuePane
- `rmpc/src/ui/widgets/nav_stack.rs` (237 lines) - Deprecated by ContentView

**Widgets (ADR implementation - keep):**
- `rmpc/src/ui/widgets/content_view.rs` (375 lines) - Unified stack component
- `rmpc/src/ui/widgets/section_list.rs` (607 lines) - Section structure with handle_key
- `rmpc/src/ui/widgets/interactive_list_view.rs` (894 lines) - Core list with Find mode

**Routing:**
- `rmpc/src/actor.rs` - Ui struct creates Navigator when `!ctx.config.legacy_panes.enabled` (line 103), handle_key routes through Navigator (lines 285-292)
- `rmpc/src/ui/panes/mod.rs` - PaneContainer uses `use_legacy` variable for pane routing
</key_files>

<next_steps>
1. **Complete Phase 3 verification**: Run the app with `legacy_panes.enabled: false` (default) and test:
   - Search → drill into Artist/Album/Playlist
   - Verify content displays in detail panes
   - Test n/N find navigation in Normal mode
   - Test Shift+J/K queue move operations

2. **Phase 4 - Remove dual trait implementations**:
   - In `search_pane_v2.rs`: Delete `impl Pane for SearchPaneV2` block (lines 612-763)
   - In `queue_pane_v2.rs`: Delete `impl Pane for QueuePaneV2` block
   - Update any code that depends on V2 panes implementing legacy Pane trait
   - Run `cargo check` to find compile errors and fix them

3. **Phase 5 - Delete deprecated code** (do this carefully, one file at a time):
   - Delete `rmpc/src/ui/widgets/nav_stack.rs` (237 lines)
   - Remove NavStack from `widgets/mod.rs` exports
   - Identify which legacy panes can be safely deleted (search/mod.rs, queue.rs)
   - Remove corresponding entries from PaneContainer and panes/mod.rs
   - Run `cargo check` after each deletion

4. **Final verification**:
   - Run `cargo test` to ensure no regressions
   - Test with `legacy_panes.enabled: true` to verify fallback still works
   - Update docs/ARCHITECTURE.md to mark migration complete

**Reference Documents:**
- ADR: `docs/ADR-unified-view-architecture.md` - The target architecture design
- Architecture: `docs/ARCHITECTURE.md` - Component hierarchy and data flow
- Session notes: `.agent/session-2025-12-27-git-recovery.md` - Previous recovery session
</next_steps>

<verification_commands>
```bash
# Build check
cd <PROJECT_ROOT>/rmpc && cargo check

# Run tests
cargo test

# Start the app (requires daemon running)
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```
</verification_commands>
