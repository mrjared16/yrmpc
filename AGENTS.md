# LLM Agent Guidelines - yrmpc Project

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Last Updated**: 2025-12-06  
**Current Phase**: Search UI Implementation

---

## 🎯 CRITICAL: Current Mission

**Your ONLY job**: Fix Search Integration Bug (REGRESSION)

### The Bug (Search Broke After Refactoring)
```
Before refactoring: Search worked
  - "/" opened search panel
  - Typing showed suggestions in side panel
  - Enter on result showed details

After service layer refactoring: BROKEN
  - No suggestions panel appears
  - Enter shows no results
  - Integration between UI → Protocol → Services broken
```

**Root Cause**: Service layer refactoring broke wiring between TUI and backend

### What's Already Done ✅
- ✅ Daemon architecture (systemd service)
- ✅ YouTube API integration (ytmapi-rs)
- ✅ Backend services (ApiService, PlaybackService, QueueService)
- ✅ Cookie authentication
- ✅ MPV streaming pipeline
- ✅ **Search UI exists** (it worked before!)

### What's Broken ❌ (REGRESSION)
- ❌ Search suggestions panel doesn't appear
- ❌ Enter on search result shows nothing
- ❌ Integration bug: UI → Protocol → ApiService wiring broken
- ❌ Likely caused by service layer refactoring

**Status**: This is a REGRESSION - search worked before the refactoring

---

## 📖 Documentation Index

### Must Read First (5 min)
1. **This file** - Mission brief
2. [`docs/DAEMON_SETUP.md`](#) - How daemon works (don't modify it)
3. [`docs/SEARCH_IMPLEMENTATION_GUIDE.md`](#) - Your task

### Reference Docs
- `docs/ARCHITECTURE.md` - System overview
- `docs/PROJECT_STATUS.md` - What works/broken
- `walkthrough.md` - Recent session work

### Code Navigation
- Search Backend: `rmpc/src/player/youtube/services/api_service.rs`
- Search UI: `rmpc/src/ui/panes/search/` (needs implementation)
- Protocol: `rmpc/src/player/youtube/protocol.rs`

---

## 🚫 DO NOT Touch

### 1. Daemon Architecture (DONE)
```
Files to avoid:
- rmpc/src/lib.rs
- rmpc/src/bin/rmpcd.rs  
- rmpc/src/player/youtube/daemon.rs
- rmpc/src/player/youtube/client.rs
- setup/*
```

**Why**: Systemd service works. Modifying breaks deployment.

### 2. Service Layer (WORKS)
```
Don't refactor:
- rmpc/src/player/youtube/services/*.rs
- rmpc/src/player/youtube/server.rs
```

**Why**: Backend logic is correct. Focus on UI.

### 3. MPV Integration (STABLE)
```
Leave alone:
- rmpc/src/player/youtube_backend.rs
- rmpc/src/player/mpv_ipc.rs
```

**Why**: Streaming works once search is fixed.

---

## ✅ DO Focus On

### Your Implementation Path

**Step 1**: Implement API Call (30 min)
```rust
// File: rmpc/src/player/youtube/services/api_service.rs
pub fn get_suggestions(&self, query: &str) -> Result<Vec<String>> {
    // TODO: Call self.api.search(query) 
    // Return actual suggestions, not empty vec
}
```

**Step 2**: Create Search Panel (1 hour)
```
// Location: rmpc/src/ui/panes/search/
- Create suggestions_panel.rs
- Wire keyboard "/" to trigger search
- Display results in TUI list
```

**Step 3**: Test End-to-End (15 min)
```bash
# Install daemon (one time)
./setup/rmpcd-install

# Run client
./rmpc --config config/rmpc.ron

# Press "/" and type artist name
# Should see: suggestions dropdown
```

---

## 🏗️ Architecture Quick Reference

### Data Flow
```
User "/" key
  ↓
UI KeyEvent
  ↓
Search Panel
  ↓
Protocol::Search command
  ↓
UnixSocket → rmpcd
  ↓
ApiService::get_suggestions()
  ↓
ytmapi-rs API
  ↓
Results ← Protocol::SearchResult
  ↓
UI renders list
```

### Key Components

**Backend** (daemon process)
- `YouTubeServer` - IPC handler
- `ApiService` - YouTube API wrapper
- `PlaybackService` - MPV control
- `QueueService` - Playlist management

**Frontend** (rmpc client)
- `YouTubeClient` - Socket communication
- UI Panes - Ratatui widgets
- KeyEvent handlers - User input

**Protocol** (shared)
- `Command` enum - Client requests
- `Response` enum - Server responses
- Serde serialization over Unix socket

---

## 🧪 How To Test

### Quick Test Loop
```bash
# 1. Build
cargo build --release

# 2. Restart daemon (picks up changes)
systemctl --user restart rmpcd

# 3. Run client
./rmpc --config config/rmpc.ron

# 4. Test search
# Press "/", type "lofi", see suggestions
```

### Verify Daemon Works
```bash
# Check service
systemctl --user status rmpcd

# View logs
journalctl --user -u rmpcd -f

# Check socket
ls -la /tmp/yrmpc-yt.sock
```

### Debug API Calls
```bash
# Run daemon with debug logging
systemctl --user stop rmpcd
RUST_LOG=debug rmpcd

# In another terminal, run rmpc
# Watch API calls in daemon output
```

---

## 📁 File Reference

### Must Read
| File | Purpose | Your Focus |
|------|---------|------------|
| `rmpc/src/player/youtube/services/api_service.rs` | Stub to implement | ⭐ FIX THIS |
| `rmpc/src/ui/panes/search/mod.rs` | Search UI entry | ⭐ CREATE PANEL |
| `rmpc/src/player/youtube/protocol.rs` | IPC messages | 📖 Reference |

### Context (Don't Modify)
| File | Purpose |
|------|---------|
| `rmpc/src/lib.rs` | Library crate (for rmpcd) |
| `rmpc/src/bin/rmpcd.rs` | Daemon binary |
| `setup/rmpcd-install` | Systemd install script |

### Documentation
| File | Contents |
|------|----------|
| `docs/SEARCH_IMPLEMENTATION_GUIDE.md` | Step-by-step search impl |
| `docs/DAEMON_SETUP.md` | How daemon works |
| `walkthrough.md` | Recent session work |

---

## 🐛 Known Issues

| Issue | Impact | Status |
|-------|--------|--------|
| Search UI missing | Blocks all testing | 🔴 YOUR TASK |
| No search results panel | Cannot see suggestions | 🔴 YOUR TASK |
| `get_suggestions()` stubbed | Returns empty | 🔴 YOUR TASK |

---

## 💡 Tips

### Ratatui (TUI Framework)
```rust
// Create list widget
use ratatui::widgets::{List, ListItem};

let items: Vec<ListItem> = suggestions
    .iter()
    .map(|s| ListItem::new(s.clone()))
    .collect();

let list = List::new(items)
    .block(Block::default().title("Suggestions"));
```

### ytmapi-rs API
```rust
// Search for suggestions
let results = api.search("lofi", SearchType::Songs)?;

// Parse results
let suggestions: Vec<String> = results
    .into_iter()
    .map(|r| r.name)
    .collect();
```

### IPC Protocol
```rust
// In client (rmpc)
let cmd = Command::Search { query: "lofi".into() };
client.send(cmd)?;
let response = client.receive()?;

// In server (rmpcd)
match command {
    Command::Search { query } => {
        let results = api_service.get_suggestions(&query)?;
        Response::SearchResults(results)
    }
}
```

---

## 🚀 Getting Started Checklist

- [ ] Read this file completely
- [ ] Read `docs/SEARCH_IMPLEMENTATION_GUIDE.md`
- [ ] Locate `api_service.rs` and understand stub
- [ ] Check `ui/panes/search/mod.rs` structure
- [ ] Review `protocol.rs` for Search command/response
- [ ] Plan: API implementation first, then UI
- [ ] DO NOT touch daemon files
- [ ] Test incrementally (API → Protocol → UI)
- [ ] Consider E2E tests for validation (see below)

---

## 🧪 E2E Testing Approach (REQUIRED FOR TDD)

### Critical: Use Log-Based Testing

**Problem**: Search broke during refactoring. Need TDD loop to fix.

**Solution**: Log-file-based E2E tests

### Implementation (Recommended Approach)

**1. Create Test Script**
```bash
#!/bin/bash
# tests/test_search_regression.sh

LOG_FILE="/tmp/rmpc_search_test.log"
rm -f "$LOG_FILE"

# Start daemon
systemctl --user start rmpcd
sleep 1

# Run rmpc with logging
RUST_LOG=debug RMPC_LOG_FILE="$LOG_FILE" rmpc --config config/rmpc.ron &
RMPC_PID=$!
sleep 2

# Simulate search: "/" key, type "lofi", Enter
# (Use headless mode or xdotool if available)

sleep 3
kill $RMPC_PID

# Validate logs
if grep -q "search.*suggestions" "$LOG_FILE"; then
    echo "✅ Search API called"
else
    echo "❌ Search API NOT called"
    exit 1
fi

if grep -q "UI.*search.*panel" "$LOG_FILE"; then
    echo "✅ Search panel updated"
else  
    echo "❌ Search panel NOT updated"
    exit 1
fi

echo "✅ All tests passed"
```

**2. TDD Loop**
```bash
# Red: Test fails (current state)
./tests/test_search_regression.sh
# ❌ Search API NOT called

# Green: Fix integration bug
vim rmpc/src/ui/panes/search/mod.rs
vim rmpc/src/player/youtube/client.rs

# Verify: Test passes
./tests/test_search_regression.sh
# ✅ All tests passed
```

**3. What to Check in Logs**
```bash
# Search panel opened?
grep "search.*panel.*open" /tmp/rmpc_search_test.log

# API call made?
grep "ApiService.*get_suggestions" /tmp/rmpc_search_test.log

# Protocol command sent?
grep "Protocol.*Search" /tmp/rmpc_search_test.log

# Response received?
grep "SearchResults" /tmp/rmpc_search_test.log

# UI updated?
grep "render.*suggestions" /tmp/rmpc_search_test.log
```

### Alternative: Protocol-Level Testing
```rust
// Test daemon directly (bypasses UI)
#[test]
fn test_search_protocol() {
    let client = YouTubeClient::connect("/tmp/yrmpc-yt.sock").unwrap();
    
    // Send search command
    client.send(Command::Search { query: "lofi" }).unwrap();
    
    // Verify response
    let response = client.receive().unwrap();
    assert!(matches!(response, Response::SearchResults(_)));
    
    // Response should have suggestions
    if let Response::SearchResults(results) = response {
        assert!(!results.is_empty(), "Search should return results");
    }
}
```

### Integration Testing Priority

1. **Protocol test** - Test daemon IPC (isolate backend)
2. **Log-based E2E** - Full workflow validation
3. **Manual TUI test** - Visual confirmation

**TDD is REQUIRED**: This is a regression bug. Tests prevent future breaks.

---

## 📞 When Stuck

### Debug Checklist
1. Is daemon running? `systemctl --user status rmpcd`
2. Are sockets present? `ls /tmp/yrmpc-yt*`
3. Check logs: `journalctl --user -u rmpcd -n 50`
4. Build errors? Read carefully, don't guess
5. Still stuck? Ask user for clarification

### Common Pitfalls
- ❌ Don't refactor daemon (it works)
- ❌ Don't change protocol (it's stable)
- ❌ Don't assume tests exist (they don't)
- ✅ DO implement stub → wire UI → test manually

---

## 🎓 Learning Resources

- Ratatui docs: https://ratatui.rs
- ytmapi-rs: https://docs.rs/ytmapi-rs
- Rust async: Not needed (daemon handles async)
- Unix sockets: Client/server already work

**Your job**: Connect UI to working backend via existing protocol.

---

**Remember**: Daemon works. API exists. Protocol defined. Just wire the UI.
