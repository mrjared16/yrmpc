# Project Status

**Last Updated**: 2025-12-17
**Status**: ✅ Core Playable - Hybrid Queue Architecture Complete

---

## Current State

| Feature | Status | Notes |
|---------|--------|-------|
| Auto-Advance | ✅ Complete | Rolling prefetch window enables seamless playback |
| Repeat Mode | ✅ Complete | Off, One (loop track), All (loop queue) |
| Shuffle Mode | ✅ Complete | History-based random selection |
| MPV Event Loop | ✅ Complete | observe_property for playlist-pos, pause, end-file |
| Queue Update Fix (task-18) | ✅ Complete | Result-type driven updates |
| Search Enter Key (task-19) | ✅ Complete | YouTube Music-like behavior |
| **CPU Idle Fix (task-6)** | ✅ Complete | **0% CPU when idle (was 146%)** |
| Build | ✅ Passing | Only pre-existing warnings |
| Manual Testing | 🔄 Pending | Needs verification |

---

## Recent Completions (2025-12-17 Session)

### High CPU Idle Fix (task-6)

**Root Cause Identified via Per-Thread Profiling:**
- `idle` thread: 77.7% CPU
- `request` thread: 68.4% CPU
- Total: ~146% CPU

**Problem:** The `idle` and `request` threads in `core/client.rs` were designed for MPD's blocking idle protocol. For YouTube backend, `YouTubeClient::read_response()` returned `Ok(vec![])` immediately without blocking, causing both threads to spin in a tight loop.

**Fix Applied:**
1. `src/player/youtube/client.rs:175-191` - Changed `read_response()` to sleep for 1 second and return `MpdError::TimedOut`
2. `src/player/mpv_ipc.rs:232-265` - Changed `read_event()` to return `Option<MpvEvent>` instead of spinning

**Result:** 0.0% CPU when idle (verified with per-thread profiling)

---

## Recent Completions (2025-12-16 Session)

| Feature | Description |
|---------|-------------|
| **MPV Event Loop** | Background thread observes MPV properties, reacts to changes |
| **Rolling Prefetch Window** | MPV playlist holds 2-3 resolved URLs for auto-advance |
| **Repeat Mode** | RepeatMode enum: Off, One, All - fully wired through protocol |
| **Shuffle Mode** | History-based shuffle, "previous" navigates back through history |
| **Status with Options** | StatusData now includes repeat/shuffle state for UI |

### Architecture Changes

| Old | New | Reason |
|-----|-----|--------|
| `loadfile replace` | `playlist_clear + append × 3` | Enables auto-advance |
| No MPV events | `observe_property` + event loop | React instead of poll |
| Eager URL resolve | Lazy on play | Eliminates 6s delay on add |
| Stub repeat/shuffle | Full implementation | User-requested features |

---

## Architecture Decisions

| ADR | Description |
|-----|-------------|
| [ADR-query-result-state-updates](ADR-query-result-state-updates.md) | Result type determines state updates |
| [ADR-rich-list-ui](ADR-rich-list-ui.md) | Rich list rendering |
| [ADR-interactive-layout-system](ADR-interactive-layout-system.md) | Interactive layouts |

---

## Known Issues

| Issue | Priority | Status |
|-------|----------|--------|
| Manual testing needed | P0 | 🔄 Next step |
| ~~High CPU on client (task-6)~~ | ~~P1~~ | ✅ Fixed 2025-12-17 |
| Test infrastructure broken | P3 | Pre-existing, not from our changes |

---

## Manual Test Plan (Hybrid Queue)

### Prerequisites
```bash
# Start fresh daemon
pkill -f "rmpc.*daemon" || true
./restart_daemon.sh

# Run client with debug logging
RUST_LOG=debug ./rmpc/target/debug/rmpc --config config/rmpc.ron 2>&1 | tee debug.log
```

### Test 1: Auto-Advance
1. Clear queue (if any songs present)
2. Search for an artist with multiple short songs
3. Add 3+ songs to queue
4. Play the first song
5. **Expected**: After song 1 finishes, song 2 starts automatically
6. **Check log**: "MPV event: TrackChanged"

### Test 2: Repeat One
1. With a song playing, toggle Repeat (should show "Repeat" active in status bar)
2. If single mode available, enable Single (Repeat One = repeat + single)
3. Wait for song to finish
4. **Expected**: Same song starts again from beginning
5. **Check log**: "Repeat One: replaying current track"

### Test 3: Repeat All
1. Ensure only Repeat is on (not Single)
2. Skip to last song in queue
3. Wait for it to finish
4. **Expected**: Playback loops back to first song
5. **Check log**: "Repeat All: looping back to start"

### Test 4: Shuffle Mode
1. Add 5+ songs to queue
2. Toggle Shuffle (Random) on
3. Press Next multiple times
4. **Expected**: Songs play in random order, not sequential
5. Press Previous
6. **Expected**: Goes back to previously played song (history navigation)

### Test 5: UI Status Sync
1. Toggle Repeat on/off
2. **Expected**: Status bar shows Repeat icon state correctly
3. Toggle Shuffle on/off
4. **Expected**: Status bar shows Random icon state correctly

---

## Backlog (Prioritized)

### P0 - Immediate
- [ ] Manual test hybrid queue features (above)

### P1 - High Priority
- [ ] Queue Manipulation UI (remove, reorder with keyboard)
- [ ] High CPU on client fix (task-6)

### P2 - Medium Priority
- [ ] Gapless playback optimization
- [ ] Now Playing view

### P3 - Low Priority
- [ ] Fix test infrastructure
- [ ] Grid view implementation

---

## Quick Commands

```bash
# Build
cd rmpc && cargo build --release

# Run with debug
RUST_LOG=debug ./rmpc/target/release/rmpc --config config/rmpc.ron

# Check daemon logs
tail -f ~/.local/share/rmpc/daemon.log

# Kill stuck daemon
pkill -f "rmpc.*daemon"
```

---

## Session Handoff

**Latest Session**: `.agent/session-2025-12-16-hybrid-queue.md` (MUST READ)

### What Was Implemented (2025-12-16)

**Problem**: YouTube backend couldn't auto-advance, repeat, or shuffle - songs stopped after each track.

**Solution**: Hybrid Queue Architecture
1. **MPV Event Loop** - Background thread observes MPV properties
2. **Rolling Prefetch** - MPV playlist has 2-3 URLs (not 1), enabling auto-advance
3. **RepeatMode enum** - Off, One, All with proper `handle_track_ended()` logic
4. **Shuffle with History** - Random selection + history stack for "previous"

### Key Files Modified (2025-12-16)

| File | Changes |
|------|---------|
| `rmpc/src/player/mpv_ipc.rs` | MpvEvent enum, observe_property, read_event |
| `rmpc/src/player/youtube/services/queue_service.rs` | RepeatMode, shuffle history |
| `rmpc/src/player/youtube/services/playback_service.rs` | start_event_loop |
| `rmpc/src/player/youtube/protocol.rs` | SetRepeat, SetShuffle, StatusData fields |
| `rmpc/src/player/youtube/server.rs` | handle_track_ended, rolling prefetch |
| `rmpc/src/player/youtube/client.rs` | repeat(), random() implementation |

### Immediate Next Steps

1. **Manual Test**: Run app, test keybindings (z=repeat, v=single, x=shuffle)
2. **Verify**: Auto-advance works, repeat modes work, shuffle works
3. **If bugs found**: Check logs for "TrackChanged", "Repeat", "end-file"
4. **Commit**: If working, commit with message about hybrid queue architecture

### Testing Commands
```bash
# Rebuild and restart
cd /home/phucdnt/workspace/projects/yrmpc/rmpc && cargo build
cd /home/phucdnt/workspace/projects/yrmpc && ./restart_daemon.sh

# Run with debug
RUST_LOG=debug ./rmpc/target/debug/rmpc --config config/rmpc.ron 2>&1 | tee debug.log
```

### Serena Memory
New memory created: `hybrid_queue_architecture` - read this for architecture details
