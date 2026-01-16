# PlayIntent Implementation Learnings

## Rust Enum Ordering Gotcha (2026-01-15)

**Issue**: Rust's `derive(Ord)` on enums orders variants by declaration position, not semantic meaning.

**Context**: `PreloadTier` enum needs urgency-based ordering (Immediate > Gapless > Eager > Background), but natural declaration order is opposite.

**Solution**: Declare enum variants in reverse priority order:
```rust
pub enum PreloadTier {
    Background,  // Lowest priority - declared first
    Eager,
    Gapless,
    Immediate,   // Highest priority - declared last
}
```

**Rationale**: 
- Rust's derived `Ord` compares enum discriminants, which increment from first to last variant
- Last variant gets highest discriminant → highest in comparisons
- Comment preserved to prevent future "fixes" that break semantics

**Test Verification**: `test_preload_tier_ordering` catches this regression.

## Protocol Module Structure

**Pattern**: YouTube backend uses `protocol/` directory (not single `protocol.rs` file)
- `protocol/mod.rs` - Main protocol types, IPC framing
- `protocol/play_intent.rs` - PlayIntent-specific types (this bead)

**Import Pattern**: Domain types use `use crate::domain::Song;` consistently across protocol files.

## Type Design Decisions

**RequestId**: `u64` sufficient (no need for UUID crate)
- Simple atomic counter in daemon
- Lightweight serialization
- Fits IPC frame size constraints

**Shuffle Handling**: Boolean in `PlayIntent::Context` 
- TUI handles actual shuffle logic (Fisher-Yates)
- Daemon just respects intent priorities
- Avoids coupling daemon to specific shuffle algorithm

## Task 1.2: Protocol Enum Updates

**Date**: 2026-01-15

### What Was Done
- Added `PlayWithIntent { intent, request_id }` and `CancelRequest { request_id }` to ServerCommand enum
- Added `PlayResult(Result<(), PlayError>)` to ServerResponse enum  
- Added import: `use play_intent::{PlayIntent, RequestId, PlayError};`
- Added stub handlers in server/mod.rs (return error responses)
- Verified with `cargo build` and `cargo test` - all pass

### Key Insights
- **Enum exhaustiveness checking**: Rust compiler catches missing match arms immediately
- **Stub implementation pattern**: Return error messages for unimplemented commands
- **Comment justification**: Added necessary section header comment for intent-based commands group

### Files Modified
- `rmpc/src/backends/youtube/protocol/mod.rs` (imports + enum variants)
- `rmpc/src/backends/youtube/server/mod.rs` (stub match arms)

### Next Task
Task 1.3 will implement the real handlers for these commands using the PlayIntent architecture.


## Search Pane Migration (yrmpc-ive)

**Date**: 2026-01-15
**File**: `rmpc/src/ui/panes/search_pane_v2.rs`

### Implementation Details

Successfully migrated `search_pane_v2.rs` to use PlayIntent API:

1. **Imports Added**:
   - `use crate::backends::youtube::protocol::play_intent::{PlayIntent, ContextSource}`

2. **Methods Updated**:
   
   **play_song()**:
   - Before: `ctx.queue_store().replace_and_play(vec![song])`
   - After: Uses `PlayIntent::Context` with:
     - `tracks: vec![song]`
     - `offset: 0`
     - `shuffle: false`
     - `source: Some(ContextSource::Search { query })`

   **play_all_songs()**:
   - Before: Used `BackendDispatcher::resolve_and_enqueue()` with multiple parameters
   - After: Uses `PlayIntent::Context` with:
     - `tracks: songs`
     - `offset: start_index` (preserves selected song position)
     - `shuffle: false`
     - `source: Some(ContextSource::Search { query })`

3. **Query Extraction**:
   - Uses existing `get_current_query_string()` method
   - Extracts search text from `InputGroups` inputs
   - Provides analytics context for playback tracking

### Patterns Observed

1. **No Direct Query Field**:
   - SearchPaneV2 doesn't store query directly
   - Uses `InputGroups` to manage search state
   - Helper method extracts query when needed

2. **Offset Preservation**:
   - `play_all_songs()` receives `start_index` parameter
   - Maps directly to `PlayIntent::Context.offset`
   - Maintains user's selection when playing multiple songs

3. **Simplified Code**:
   - Removed 10 lines of queue management code
   - No need for `Enqueue::Song` mapping
   - No need for `BackendDispatcher::resolve_and_enqueue` complexity
   - Declarative intent replaces imperative queue operations

### Verification

- ✅ `cargo build` passes
- ✅ No remaining `replace_and_play()` calls in search_pane_v2.rs
- ✅ No remaining `BackendDispatcher::resolve_and_enqueue()` calls
- ✅ Imports correctly reference `play_intent` module
- ✅ Query extraction works via existing helper method

### Build Time

- Debug build: ~39 seconds (acceptable for dev workflow)

### Commit

```
commit 92ad7a6661226926d343f460d5ea48e8f54ba823
refactor(search): migrate search_pane_v2 to PlayIntent
```

## Album/Playlist Panes Migration (yrmpc-tn6)

**Pattern: Accessing ContentView nested data**
```rust
// Get ID from current content level for ContextSource
let album_id = self.view.current()
    .map(|level| level.content.id.clone())
    .unwrap_or_default();
```

**Migration steps for detail panes:**
1. Add imports: `use crate::backends::youtube::protocol::play_intent::{ContextSource, PlayIntent};`
2. Change `resolve_action(&self, item: DetailItem)` to `resolve_action(&self, item: DetailItem, ctx: &Ctx)`
3. Update `handle_key` to pass `ctx` to `resolve_action`
4. Replace `PaneAction::Play(song)` with direct `ctx.queue_store().play(PlayIntent::Context {...})`
5. Replace `PaneAction::PlayAll {...}` with direct `ctx.queue_store().play(PlayIntent::Context {...})`
6. Return `PaneAction::Handled` after calling queue_store.play()

**Key insight:** Detail panes now call queue_store directly instead of returning PaneAction::Play/PlayAll. This decouples pane logic from Navigator's action routing.

**Testing:** Verified with `cargo build` (45s debug build).

## 2026-01-15: Context Menu Action Migration (yrmpc-val)

### What We Did
Migrated "Add to Queue" actions from legacy `queue_store().add()` to `PlayIntent::Append`.

**Files Changed:**
- `rmpc/src/actions/handlers/queue.rs`: QueueHandler now uses `PlayIntent::Append`
- `rmpc/src/ui/panes/search_pane_v2.rs`: Updated `add_to_queue()` method

### Key Implementation Points

1. **QueueHandler Migration**
   - Added import: `use crate::backends::youtube::protocol::play_intent::PlayIntent;`
   - Changed `ctx.queue_store().add(songs)` to `ctx.queue_store().play(PlayIntent::Append { tracks: songs })`

2. **SearchPaneV2 Migration**
   - Play=true case: Uses `PlayIntent::Context` (replace queue and play immediately)
   - Play=false case: Uses `PlayIntent::Append` (add to queue without playing)
   - This maintains the existing semantic: "play" parameter controls immediate playback vs queue append

### Architecture Understanding

**queue_store.play() is the unified API:**
- `PlayIntent::Context` - Replace queue and play (offset, shuffle, source context)
- `PlayIntent::Append` - Add to end of queue without playing
- `PlayIntent::Next` - Insert after current song (not used in this bead)

**Legacy methods still exist but should not be used:**
- `queue_store().add()` - deprecated, use `PlayIntent::Append`
- `queue_store().add_and_play()` - deprecated, use `PlayIntent::Context`

### Where Actions Flow

1. **User presses 'a' key** (Add to Queue)
   → `ContentAction::Enqueue` in detail panes
   → `PaneAction::Enqueue` in navigator.rs
   → `Intent::add_to_queue()` via PaneActionExecutor
   → `QueueHandler::execute()` handles `IntentKind::AddToQueue`
   → `queue_store().play(PlayIntent::Append { tracks })`

2. **Context menu "Add to Queue"** (not implemented yet)
   → Would follow same flow through Intent system

### What Works Now

- ✅ All detail panes (album, artist, playlist) support 'a' key → Add to Queue
- ✅ Search pane "Add to Queue" action
- ✅ Build passes with no errors
- ✅ PlayIntent migration is transparent to UI layer

### What's NOT Done (Future Work)

- [ ] "Play Next" action (would use `PlayIntent::Next`)
- [ ] Actual context menu UI (if it exists)
- [ ] Any other legacy calls to `add()` or `add_and_play()`

### Testing Notes

**Manual verification needed:**
1. Open album detail, press 'a' on a song → should add to queue
2. Search for a song, use "Add all to queue" action → should append all
3. Verify no blocking/delays (PlayIntent should be non-blocking)

**Cargo build status:** ✅ Passes (warnings are pre-existing)

### Commit
```
refactor(queue): migrate Add to Queue actions to PlayIntent::Append

- Update QueueHandler to use PlayIntent::Append instead of queue_store().add()
- Update search_pane_v2 add_to_queue() to use PlayIntent patterns
- Works from all panes (album, artist, playlist, search)

Part of PlayIntent migration (yrmpc-val)
```
Commit hash: `8882ace`
## Radio Playback Implementation (2026-01-15)

### Action System Pattern
- New intents require 4 changes:
  1. Add variant to `IntentKind` enum (`actions/intent.rs`)
  2. Add helper method to `Intent` struct (same file)
  3. Create handler in `actions/handlers/<name>.rs`
  4. Register in dispatcher (`ui/panes/navigator.rs`)

### Handler Pattern
- Use `log::info!()` not `tracing::info!()`
- Song fields are methods: `song.title()` not `song.title`
- Return `HandleResult::Skip` for unhandled actions
- Return `HandleResult::NotApplicable(reason)` for validation failures

### PlayIntent::Radio Usage
- Defined in `backends/youtube/protocol/play_intent.rs`
- Takes `seed: Song` and `mix_type: MixType`
- MixType variants: SongRadio, ArtistRadio, GenreRadio
- Call via `ctx.queue_store().play(PlayIntent::Radio { seed, mix_type })`

### v1 Scope
- Seed-only radio (no auto-extend)
- Uses MixType::SongRadio
- Auto-extend is v2 feature (logged in info message)
