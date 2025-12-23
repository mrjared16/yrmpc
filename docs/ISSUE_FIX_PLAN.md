# Issue Fix Plan: Search Layout + Queue Behavior

> **Purpose**: Detailed implementation guide for fixing 6 issues found during testing.  
> **Created**: 2025-12-11  
> **Status**: ✅ ALL COMPLETE (2025-12-12)

---

## Summary of Issues

| # | Component | Issue | Root Cause | Status |
|---|-----------|-------|------------|--------|
| 1 | SearchPaneV2 | Left column too narrow | Hardcoded 30px width | ✅ Fixed (uses column_widths) |
| 2 | SearchPaneV2 | Missing 3-column layout | Only 2 columns implemented | ✅ Fixed (3-column layout) |
| 3 | QueuePaneV2 | Enter doesn't toggle pause | Unconditional play command | ✅ Fixed (PlayOrToggle) |
| 4 | QueuePaneV2 | Delete requires restart | on_event ignores queue changes | ✅ Fixed (UiEvent::Player) |
| 5 | QueuePaneV2 | Song resumes from last position | No seek(0) on play | ✅ Fixed (added seek(0)) |
| 6 | QueuePaneV2 | Cover image too small | Fixed small constraint | ✅ Fixed (75%/Min(4)) |

---

## Quick Fix: Revert to Legacy SearchPane

Set in `config/rmpc.ron`:
```ron
legacy_panes: (
    queue: false,   // Keep QueuePaneV2
    search: true,   // USE LEGACY SearchPane
)
```

This restores working 3-column layout while Queue fixes are applied.

---

## Issue 1 & 2: SearchPaneV2 Layout

### File
`rmpc/src/ui/panes/search_pane_v2.rs`

### Current Code (lines 450-454)
```rust
// Two-column layout: inputs | results
let chunks = Layout::horizontal([
    Constraint::Length(30),  // Input column - TOO NARROW
    Constraint::Min(0),      // Results column
]).split(area);
```

### Problem
- Only 2 columns (input, results) - missing **preview** column
- Input column hardcoded to 30 chars - not responsive
- Legacy uses `ctx.config.theme.column_widths` (20/38/42 by default)

### Reference: Legacy Layout
`rmpc/src/ui/panes/search/mod.rs` (lines 1358-1366)
```rust
let widths = &ctx.config.theme.column_widths;
let [previous_area, current_area_init, preview_area] = *Layout::horizontal([
    Constraint::Percentage(widths[0]),
    Constraint::Percentage(widths[1]),
    Constraint::Percentage(widths[2]),
]).split(area);
```

### Fix
Add 3-column layout with configurable widths:
```rust
let widths = &ctx.config.theme.column_widths;
let [input_area, results_area, preview_area] = Layout::horizontal([
    Constraint::Percentage(widths[0]),
    Constraint::Percentage(widths[1]),
    Constraint::Percentage(widths[2]),
]).areas::<3>(area);
```

### Verification
- [ ] All 3 columns visible
- [ ] Can type in search input
- [ ] Preview shows selected item details

---

## Issue 3: Enter Doesn't Toggle Pause

### File
`rmpc/src/ui/panes/queue_pane_v2.rs`

### Current Code (lines 81-85)
```rust
fn play_selected(&self, ctx: &mut Ctx) {
    let items = ctx.queue.clone();
    let _ = list_ops::execute_on_selected(&self.list_view, items, QueueItemAction::Play, ctx);
}
```

### Problem
Always sends Play command, never checks if already playing selected song.

### Expected Behavior (Spotify-style)
- Enter on **playing** song → PAUSE
- Enter on **paused** song (same) → RESUME
- Enter on **different** song → PLAY + seek(0)

### Available APIs
- `client.pause_toggle()` at `src/player/client.rs:575`
- `client.seek_current(SeekPosition::Absolute(0.0))` at `src/player/client.rs:148`
- `ctx.status.state` - current playback state (Playing/Paused/Stopped)

### Fix
```rust
fn play_selected(&self, ctx: &mut Ctx) {
    use crate::mpd::commands::SeekPosition;
    use crate::mpd::commands::State;
    
    let selected_song = self.selected_song(ctx);
    let current = ctx.find_current_song_in_queue();
    
    // Check if selected song is currently playing/paused
    let is_same_song = current.as_ref()
        .and_then(|(_, s)| s.id)
        .zip(selected_song.and_then(|s| s.id))
        .map(|(cur, sel)| cur == sel)
        .unwrap_or(false);
    
    if is_same_song {
        // Same song - toggle pause
        ctx.command(|client| Ok(client.pause_toggle()?));
    } else if let Some(song) = selected_song {
        // Different song - play and seek to start
        let items = ctx.queue.clone();
        let _ = list_ops::execute_on_selected(&self.list_view, items, QueueItemAction::Play, ctx);
        
        // Seek to start to avoid resume-from-last-position
        ctx.command(|client| Ok(client.seek_current(SeekPosition::Absolute(0.0))?));
    }
}
```

### Verification
- [ ] Enter on playing song → pauses
- [ ] Enter on paused song → resumes
- [ ] Enter on different song → plays from 0:00

---

## Issue 4: Delete Requires Restart

### File
`rmpc/src/ui/panes/queue_pane_v2.rs`

### Current Code (lines 193-199)
```rust
fn on_event(&mut self, _event: &mut UiEvent, _is_visible: bool, ctx: &Ctx) -> Result<()> {
    if let Some((idx, _)) = ctx.find_current_song_in_queue() {
        self.list_view.sync_to(Some(idx));
    }
    Ok(())
}
```

### Problem
Ignores `_event` parameter - doesn't check for queue changes.

### Reference: UiEvent::Player
`src/ui/mod.rs:1219` - `IdleEvent::Player => UiEvent::Player`

### Fix
```rust
fn on_event(&mut self, event: &mut UiEvent, _is_visible: bool, ctx: &Ctx) -> Result<()> {
    if let UiEvent::Player = event {
        // Queue may have changed - validate selection
        let len = ctx.queue.len();
        if let Some(idx) = self.list_view.selected() {
            if idx >= len {
                self.list_view.select(if len > 0 { Some(len - 1) } else { None });
            }
        }
    }
    
    // Sync to current playing song
    if let Some((idx, _)) = ctx.find_current_song_in_queue() {
        self.list_view.sync_to(Some(idx));
    }
    Ok(())
}
```

### Verification
- [ ] Delete song → list updates immediately
- [ ] Selection adjusts if deleted item was selected

---

## Issue 5: Song Resumes From Last Position

**Already fixed in Issue 3** - `seek_current(SeekPosition::Absolute(0.0))` added.

---

## Issue 6: Cover Image Too Small

### File
`rmpc/src/ui/panes/queue_pane_v2.rs`

### Current Code (lines 319-323)
```rust
let [img_area, info_area] = Layout::vertical([
    Constraint::Min(10),    // PROBLEM: Only 10 rows minimum
    Constraint::Length(4),
]).areas::<2>(inner);
```

### Problem
`Constraint::Min(10)` is too small for album art. The left panel is also only 35% (line 170-173).

### Fix Option A: Larger left panel
```rust
// Line 170-173
let [art_area, list_area] = Layout::horizontal([
    Constraint::Percentage(40),  // Was 35
    Constraint::Percentage(60),  // Was 65
]).areas::<2>(area);
```

### Fix Option B: Better vertical split
```rust
// Lines 319-323
let [img_area, info_area] = Layout::vertical([
    Constraint::Percentage(75),  // Most space for image
    Constraint::Min(4),          // Minimum for info
]).areas::<2>(inner);
```

### Verification
- [ ] Cover image larger and more visible
- [ ] Song info still readable below cover

---

## Implementation Order

1. **Config change** - Set `search: true` for legacy SearchPane
2. **Fix 3** - play_selected toggle logic
3. **Fix 4** - on_event queue sync
4. **Fix 6** - Cover image sizing
5. **Test** - Build and verify all fixes
6. **Later** - Full SearchPaneV2 3-column rewrite

---

## Related Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| `rmpc/src/ui/panes/queue_pane_v2.rs` | 81-85, 193-199, 319-323 | Queue fixes |
| `rmpc/src/ui/panes/search_pane_v2.rs` | 450-454 | Search layout |
| `rmpc/src/ui/panes/search/mod.rs` | 1358-1366 | Reference 3-column layout |
| `rmpc/src/player/client.rs` | 148, 575 | seek_current, pause_toggle APIs |
| `rmpc/src/mpd/commands/mod.rs` | 42-47 | SeekPosition enum |
| `config/rmpc.ron` | legacy_panes section | Config toggle |
