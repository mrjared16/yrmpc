# Backend Abstraction Work - Session Handout

**Session Date**: 2025-11-21  
**Current Errors**: 79 (down from 159)  
**Phase**: 1C - Finishing Compilation Fixes

## Quick Status

### What's Working ✅
- Backend abstraction structure in place (`player::Client` enum)
- Core delegation methods added (10+ methods)
- Extension trait (`MpdClientExt`) implemented for `player::Client`
- Graceful fallbacks for MPV backend
- Type-safe backend switching

### What's Remaining ⏳
- 79 compilation errors to fix
- Missing 2 methods (`pause_toggle`, `move_in_queue`)
- Field access issues (`.0` on Vec types)
- Closure type mismatches in browser.rs
- Argument count mismatches
- Import errors (sticker types)

### Documentation Created 📚
All documentation is up-to-date and synchronized:
1. **task.md** - Detailed task breakdown with progress tracking
2. **implementation_plan.md** - Complete 6-phase architecture plan
3. **.agent/technical_context.md** - Technical patterns and examples
4. **Memory: current_session_state.md** - Session state and last action
5. **Memory: backend_abstraction_progress.md** - Progress summary
6. **.agent/QUICKSTART.md** - Quick start guide for next agent

## For Next Agent: Start Here 🚀

1. **Read** `.agent/QUICKSTART.md` (2 minutes)
2. **Verify state**: `cargo build --release 2>&1 | grep "error\[E" | wc -l`  
3. **Add methods**: Use Serena to add `pause_toggle` and `move_in_queue`
4. **Fix errors**: Follow task.md checklist systematically
5. **Update docs**: Mark completed items in task.md

## The Big Picture

### Goal (from user)
> "Run rmpc without configuring MPD or installing it at all"

### Solution Architecture
**Adapter Pattern** (not current delegation-only):
- Phase 1 ✅ (in progress): Finish current abstraction → 0 errors
- Phase 2: Extract domain models from MPD types
- Phase 3: Move queue to app layer  
- Phase 4: Implement YouTube Music backend
- Phase 5: Config-driven backend selection
- Phase 6: Radio daemon (infinite queue)

### Why This Matters
- Current approach: MPV "fakes" MPD responses (doesn't scale)
- Better approach: Backends adapt to domain types
- End result: YouTube Music + mpv = no MPD needed!

## Files Modified This Session

| File | Lines | What Changed |
|------|-------|--------------|
| `rmpc/src/config/mod.rs` | 1-8 | Fixed typo (Huse → use) |
| `rmpc/src/player/client.rs` | 355-550 | Added 10+ delegation methods |
| `rmpc/src/shared/mpd_client_ext.rs` | 869-984 | Implemented trait for player::Client |
| `rmpc/src/core/work.rs` | 49-57 | Fixed closure type (mpd::Client → player::Client) |
| `rmpc/src/ui/browser.rs` | 17-18 | Updated imports (added player::Client) |

## Error Breakdown (79 total)

| Type | Count | Difficulty | ETA |
|------|-------|-----------|-----|
| Missing methods | 4 | Easy | 15 min |
| Field access (`.0`) | 6 | Easy | 20 min |
| Closure types | 4 | Medium | 30 min |
| Argument counts | 20 | Medium | 45 min |
| Type mismatches | 14 | Medium | 45 min  |
| Import errors | 3 | Easy | 10 min |
| **Total** | **79** | | **~3 hours** |

## Architecture Context

### Current Implementation
```rust
// Delegation pattern
pub enum Client<'name> {
    Mpd(MpdBackend<'name>),
    Mpv(MpvBackend),
}

impl Client {
    pub fn method(&mut self) -> Result<T> {
        match self {
            Client::Mpd(b) => b.client.method().map_err(Into::into),
            Client::Mpv(b) => b.method(),  // or Ok(default)
        }
    }
}
```

### Target Implementation (Phase 2+)
```rust
// Adapter pattern
trait MusicBackend {
    fn status(&mut self) -> Result<domain::Status>;  // Domain type!
    fn search(&mut self, q: &str) -> Result<Vec<domain::Song>>;
    // Only universal operations
}

impl MusicBackend for YouTubeBackend {
    fn status(&mut self) -> Result<domain::Status> {
        // Adapt mpv status to domain::Status
        let mpv_time = self.mpv.get_property("time-pos")?;
        Ok(domain::Status {
            elapsed: Duration::from_secs(mpv_time as u64),
            // ... convert all fields
        })
    }
}
```

## Key Insights from Principal Engineer Review

1. **Current abstraction is technically correct** but over-engineered
2. **MPV shouldn't fake MPD concepts** (stickers, partitions)
3. **YouTube Music needs different abstraction** (search, radio, likes)
4. **Queue should be app-managed**, not backend-managed
5. **Adapter pattern is better** for multi-backend support

## References to youtui Codebase

User wants to use `youtui`'s approach:
```
youtui/src/app/server/api/
├── mpv.rs        # mpv IPC wrapper (use this!)
├── ytmusic.rs    # YouTube Music API (use this!)
└── mod.rs        # Adapter to common types
```

Key learning: They use async mpv + ytmusicapi-rs, with in-memory queue.

## Critical Success Factors

### ✅ Do This
- Use Serena tools (`mcp0_find_symbol`, `mcp0_search_for_pattern`)
- Update docs after each sub-task
- Follow patterns in `technical_context.md`
- Stay focused on task.md checklist
- Test incrementally (`cargo build` after each change)

### ❌ Don't Do This
- Add features not in plan
- Fix errors without understanding root cause
- Abstract more MPD-specific concepts
- Forget to update documentation
- Try to solve everything at once

## Build Commands Reference

```bash
# Full build with log
cargo build --release 2>&1 | tee build.log

# Error count
cargo build --release 2>&1 | grep "error\[E" | wc -l

# Error summary
cargo build --release 2>&1 | grep "error\[E" | sort | uniq -c | sort -rn

# Specific error type
cargo build --release 2>&1 | grep "E0599"  # Method not found

# After 0 errors
cargo clippy -- -D warnings
cargo test
```

## Communication with User

If user asks about progress:
> "We're at 79 errors (down from 159, 50% done with Phase 1). Currently adding missing delegation 
> methods and fixing type mismatches. After Phase 1 (0 errors), we'll refactor to adapter pattern 
> to enable YouTube Music backend without MPD. Full plan is in implementation_plan.md."

If user hits limits:
> "All context is documented. Next agent can start from QUICKSTART.md. Last action: [X]. 
> Next action: [Y]. All progress tracked in task.md."

## Session Timeline

| Time | Action | Result |
|------|--------|--------|
| T+0 | Fixed config typo | 140 → 133 errors |
| T+30min | Added core delegation methods | 133 → 119 errors |
| T+60min | Implemented extension trait | 119 → 79 errors |
| T+90min | **Documentation phase** | All docs created |
| T+120min | **Ready to resume execution** | ← YOU ARE HERE |

## Next 3 Actions (In Order)

1. **Add missing methods** (15 min)
   - `pause_toggle()` to player::Client
   - `move_in_queue(from, to)` to player::Client
   - Expected: 79 → 75 errors

2. **Fix field access** (20 min)
   - Find `.0` on Vec types
   - Check if wrapper type or direct Vec
   - Fix accordingly
   - Expected: 75 → 69 errors

3. **Fix closure types** (30 min)
   - Update browser.rs trait signatures
   - Change `Client<'_>` → `player::Client<'_>`
   - Expected: 69 → 65 errors

Continue until 0 errors, following task.md.

## Verification Before Handoff

- [x] task.md updated with current state
- [x] implementation_plan.md documents full architecture
- [x] technical_context.md has all patterns
- [x] current_session_state.md reflects last action
- [x] QUICKSTART.md ready for next agent
- [x] This handout summarizes everything

**Status**: ✅ **Ready for continuation**

---

**For the next coding agent**: Start with `.agent/QUICKSTART.md` 🚀

## Looking Ahead: UI Adaptation (Phase 3) 🎨

**Context**: The user provided images of a Web Client and wants the TUI to match its UI/UX.
**Goal**: "Ultrathink" UI - minimal, visual, "Zen Mode".

### Architecture & Components (See `implementation_plan.md`)
1. **Shared Widgets**: `Card`, `Grid`, `Hero` (reusable components).
2. **Search Pane**: State-driven `SearchPane` with `AutocompleteList` and `ResultGrid`.
3. **Home Pane**: Vertical scroll with `SectionHeader` and `HorizontalScrollCardList`.
4. **Artist Pane**: Split view with `HeroHeader` and `DiscographyGrid`.
5. **Player**: `ZenMode` layout with large `AlbumArt` and minimal controls.

**Next Agent Action**: 
1. Finish compilation fixes (Phase 1).
2. Start Phase 3 by implementing the **Shared Widgets** first.
3. Follow the detailed component specs in `implementation_plan.md`.
