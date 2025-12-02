# LLM Agent Guidelines - yrmpc Project

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Last Updated**: 2024-12-02

---

## CRITICAL: Read This First

### Current Bug Status
| Bug | Status | Test |
|-----|--------|------|
| Bug #1: Enter on song does nothing | ❌ BROKEN | `npm test` - "FEATURE: play song" fails |
| Bug #2: HTTP 400 on artist/playlist | ❌ BROKEN | `npm test` - "FEATURE: view artist/playlist" fails |

**When bugs are fixed**: `npm test` should show 6/6 passed (currently 3/6)

### Root Causes (ALREADY IDENTIFIED - Don't Re-investigate)

**Bug #1**: `enqueue_multiple` is a NO-OP for YouTube backend
- File: `rmpc/src/shared/mpd_client_ext.rs` lines 769-775
- Fix: Implement actual play logic in the `Client::YouTube` match arm

**Bug #2**: ID prefix not stripped before API call
- File: `rmpc/src/player/youtube_backend.rs` - `browse_artist()`, `browse_playlist()`
- IDs come as `"artist:UC..."` but ytmapi-rs expects `"UC..."`
- Fix: `let raw_id = id.strip_prefix("artist:").unwrap_or(id);`

---

## CRITICAL: What NOT To Do

### 1. DO NOT Re-investigate Bugs
The root causes are documented above. Don't waste time re-reading code to find what's already known.

### 2. DO NOT Run The TUI Directly
```bash
# WRONG - You cannot interact with TUI from shell
./rmpc/target/release/rmpc

# WRONG - tmux send-keys doesn't work with raw terminal mode
tmux send-keys "i" "lofi" "Enter"
```

### 3. DO NOT Write Tests That Always Pass
```typescript
// WRONG - passes even when bug exists (no positive assertion)
const log = readLogFile();
expect(log.includes('error')).toBe(false);  // No error ≠ success!

// CORRECT - requires positive evidence of action
expect(log.includes('loadfile')).toBe(true);  // Must see the action happen
expect(log.includes('error')).toBe(false);    // AND no errors
```

### 4. DO NOT Assume Features Work
**Current state (verified by failing tests)**:
- ❌ Enter on song: Nothing happens, no audio
- ❌ Enter on artist/playlist: HTTP 400 error, blank page

---

## How To Test This Project

### E2E Tests (Primary - Use This)
```bash
npm test
```
- **Current**: 3 passed, 3 failed (feature tests fail due to bugs)
- **After fixes**: Should be 6/6 passed
- Uses `RMPC_LOG_FILE` env var to capture app logs
- Tests check for **positive evidence** of actions in logs

### E2E Test Infrastructure Details
```typescript
// Log capture mechanism
const LOG_FILE = '/tmp/rmpc-e2e-test.log';
terminal.write(`RMPC_LOG_FILE=${LOG_FILE} RUST_LOG=debug ${RMPC_BIN}\r`);

// Read logs after action
const log = fs.readFileSync(LOG_FILE, 'utf-8');
expect(log.includes('loadfile')).toBe(true);  // Verify action happened
```

**tui-test Limitations**:
- No regex support in `getByText()` - use string matching
- Keyboard input may not reliably trigger actual functionality
- Tests run in parallel - use unique log files if needed

### Rust Integration Tests
```bash
cd rmpc && cargo test --test youtube_backend_tests
```

### For Verifying Audio System
```bash
python3 tests/verify_audio.py  # Returns: 0=playing, 1=idle, 2=paused
```

### Manual Testing (For TUI interaction)
```bash
./rmpc/target/release/rmpc --config ./config/rmpc.ron
```

---

## Project Structure

```
yrmpc/
├── rmpc/                    # Main Rust codebase (submodule)
│   ├── src/
│   │   ├── player/
│   │   │   ├── youtube_backend.rs  # YouTube API + MPV control
│   │   │   └── mpv_ipc.rs          # MPV IPC communication
│   │   └── ui/panes/search/        # Search UI pane
│   └── tests/                      # Rust integration tests
├── tests/
│   ├── e2e/                        # TypeScript UI tests (LIMITED)
│   ├── verify_audio.py             # MPV state checker
│   └── integration_test.sh         # Broken - don't use
├── config/rmpc.ron                 # App configuration
└── docs/                           # Documentation
```

---

## Bug Fixes Required

### Bug #1: Enter on Song Does Nothing
**Root Cause**: `enqueue_multiple` returns `Ok(())` without doing anything for YouTube backend

**File**: `rmpc/src/shared/mpd_client_ext.rs`
**Lines**: 769-775
**Current Code**:
```rust
crate::player::Client::YouTube(_) => {
    log::debug!("enqueue_multiple not fully supported in MPV/YouTube backend");
    Ok(())  // ← THIS IS THE PROBLEM - does nothing!
}
```

**Fix Strategy**:
1. Get the YouTube backend from `Client::YouTube(backend)`
2. For each song, call `backend.play_id(song_id)` or similar
3. Look at how `play_id` works in `youtube_backend.rs` for reference

**Call Chain** (for context):
```
UI: CommonAction::Confirm → resolve_and_enqueue() → enqueue_multiple() → NO-OP
```

### Bug #2: HTTP 400 on Artist/Playlist Browse
**Root Cause**: IDs have prefixes that ytmapi-rs doesn't expect

**File**: `rmpc/src/player/youtube_backend.rs`
**Functions**: `browse_artist()`, `browse_playlist()`

**ID Format Issue**:
- Stored as: `"artist:UC..."`, `"playlist:PL..."`
- API expects: `"UC..."`, `"PL..."`

**Fix** (add at start of each function):
```rust
// In browse_artist():
let raw_id = artist_id.strip_prefix("artist:").unwrap_or(artist_id);

// In browse_playlist():
let raw_id = playlist_id.strip_prefix("playlist:").unwrap_or(playlist_id);
```

**Verification**: After fix, `npm test` should pass "FEATURE: view artist/playlist"

---

## Audio Architecture

```
User Input → yrmpc TUI → YouTubeBackend → MpvIpc → MPV Process → Audio
                              ↓
                    YouTube Music API (ytmapi-rs)
                              ↓
                    Stream URL (rusty_ytdl)
```

**To verify MPV state programmatically**:
```python
# tests/verify_audio.py queries MPV via IPC socket
# Returns: 0=playing, 1=idle, 2=paused, 3=socket unavailable
python3 tests/verify_audio.py
```

---

## Before Starting Any Task

1. ✅ Read this file completely
2. ✅ Do NOT try to run or interact with the TUI
3. ✅ Use Rust tests to verify backend functionality
4. ✅ Check `docs/PROJECT_STATUS.md` for current state
5. ✅ Ask user to manually test TUI changes

---

## Tools To Use

### For Code Navigation
- `Grep` - Search for patterns
- `Read` - Read file contents
- `serena___find_symbol` - Find Rust symbols

### For Code Changes
- `Edit` - Modify existing files
- `Create` - Create new files

### For Running Tests
```bash
# Rust tests (RELIABLE)
cd rmpc && cargo test

# Python audio check (RELIABLE)
python3 tests/verify_audio.py

# E2E tests (UI ONLY - don't trust for functionality)
npm test
```

---

## Key Files

| File | Purpose | Bug |
|------|---------|-----|
| `rmpc/src/shared/mpd_client_ext.rs` | `enqueue_multiple` - NO-OP for YouTube | Bug #1 |
| `rmpc/src/player/youtube_backend.rs` | `browse_artist/playlist` - ID prefix issue | Bug #2 |
| `rmpc/src/player/youtube_backend.rs` | `play_id` - Reference for Bug #1 fix | - |
| `rmpc/src/ui/panes/search/mod.rs` | Search UI, Enter key handling | - |
| `tests/e2e/rmpc-tui-test.spec.ts` | E2E tests with log assertions | - |

---

## Lessons Learned (Don't Repeat These Mistakes)

1. **Tests must require positive evidence** - checking for absence of errors is not enough
2. **Use `RMPC_LOG_FILE` env var** - not stderr redirect - to capture logs
3. **tui-test has limitations** - keyboard input may not trigger actual backend calls
4. **Root causes are documented** - don't re-investigate, just implement the fixes
5. **Run `npm test` after each fix** - tests will flip from fail to pass when fixed
