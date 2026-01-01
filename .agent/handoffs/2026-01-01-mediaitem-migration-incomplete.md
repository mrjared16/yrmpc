# MediaItem Architecture Migration - INCOMPLETE

**Date**: 2026-01-01
**Status**: INCOMPLETE - User correctly identified critical flaw
**Task**: Task-55 (MediaItem Architecture - Eliminate Lossy Adapter Chain)

## Critical Flaw Identified by User

> "did you fully migration, no obsolete code? dont make the same old mistakes that leave deprecated code wiring to the codebase that make it as most impossible to debug"

**The Problem**: I created new types (MediaItem, BackendExtension) but did NOT migrate actual code paths to use them. This creates the worst of both worlds:
- Two parallel type systems exist
- Old buggy code paths still active
- New types are unused
- Debugging becomes impossible

## Current State

### Git Commits Made (4 commits, NOT SQUASHED)
```
0ed2310 feat: add From conversions for MediaItem interop (Phase 3)
9a98c54 feat: add MediaItem enum with typed variants (Phase 2)
3487a24 refactor: unify ContentType enums (Phase 1)
b8a6de4 wip: fix lossy adapter chain in item_to_song() + regression tests
```

### What Was Done
1. ✅ Fixed `item_to_song()` to copy thumbnail and content_type (Task-53/39 root cause)
2. ✅ Unified ContentType enums (Header added to domain, api re-exports)
3. ✅ Created `domain/media_item.rs` with MediaItem enum
4. ✅ Added From conversions for Item ↔ MediaItem ↔ Song
5. ✅ 11 tests pass for new types

### What Was NOT Done (CRITICAL)
1. ❌ BackendDispatcher::search() still returns Vec<Song>, not Vec<MediaItem>
2. ❌ item_to_song() still exists and is still used
3. ❌ UI still consumes Song/DetailItem, not MediaItem
4. ❌ Old stringly-typed code paths still active
5. ❌ No code removed, only code added

## The Actual Code Flow (Still Using Old Types)

```
SearchPaneV2::search()
  → ctx.query(|client| client.search(&filter))
  → BackendDispatcher::search()
  → api::Discovery::search()     [returns SearchResults { items: Vec<Item> }]
  → item_to_song(&item)          [STILL USED - converts to Song with HashMap]
  → Vec<Song>
  → QueryResult::SearchResult { data }
  → on_query_finished()
  → DetailItem::from(Song)       [STILL USED]
  → UI rendering
```

MediaItem is created but NEVER enters this flow.

## Options Presented to User

1. **Full migration now** - Replace Song with MediaItem everywhere (big, risky)
2. **Targeted migration** - Replace only item_to_song() path, verify, expand
3. **Rollback** - Remove MediaItem, just keep the item_to_song() fix

User has not yet chosen.

## Files Created/Modified

### New Files
- `rmpc/src/domain/media_item.rs` - MediaItem enum, BackendExtension, Displayable trait

### Modified Files
- `rmpc/src/domain/mod.rs` - Added media_item module export
- `rmpc/src/domain/content.rs` - Added Header variant to ContentType
- `rmpc/src/backends/api/content.rs` - Re-export ContentType from domain
- `rmpc/src/backends/client.rs` - Fixed item_to_song() + added tests
- `rmpc/src/domain/detail_item.rs` - Added Header case to match statements
- `rmpc/src/ui/panes/search_pane_v2.rs` - Added Header to kind_to_string()

## To Continue

### If User Chooses Option 2 (Targeted Migration)

1. Modify `BackendDispatcher::search()` to return `Vec<MediaItem>` instead of mapping through `item_to_song()`
2. Update `search_pane_v2.rs` `on_query_finished()` to handle `Vec<MediaItem>`
3. Remove `item_to_song()` function entirely
4. Verify thumbnails/icons work in TUI
5. Expand to other code paths

### If User Chooses Option 3 (Rollback)

1. `git reset --hard b8a6de4` (keep only the item_to_song fix)
2. Remove media_item.rs
3. Remove ContentType unification (or keep it, it's useful)

### Commands to Verify

```bash
# Run tests
cargo test --lib media_item
cargo test --lib preserves

# Build
cargo build

# Test TUI
./rmpc/target/debug/rmpc --config config/rmpc.ron
# Search, verify thumbnails and icons
```

## Key Insight

The "Lossy Adapter Chain" anti-pattern isn't fixed by ADDING new types - it's fixed by REPLACING the lossy conversions. Adding MediaItem alongside Song just creates a second chain without removing the first.

## Backlog Task Status

Task-55 AC status:
- [x] AC1: Unify ContentType enums
- [x] AC2: Create MediaItem enum
- [x] AC3: Create BackendExtension enum
- [ ] AC4: Migrate BackendDispatcher
- [ ] AC5: Migrate UI layers
- [ ] AC6: Deprecate Song for non-MPD
- [ ] AC7: All tests pass
- [ ] AC8: No runtime regressions
