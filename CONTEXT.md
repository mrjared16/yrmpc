# RMPC YouTube Music TUI - Knowledge Transfer

IMPORTANT: utilize the serena tool call as much as possible to effectively read and modify this big and complete code base.

> **Context for Next LLM Session**: This document provides complete context for continuing development of the rmpc YouTube Music fork.

---

## 🎯 Project Vision & User Intent

### What the User Wants
A **terminal-based YouTube Music client** that feels like the web interface but runs entirely in the terminal. Think "Spotify TUI but for YouTube Music."

### Why This Fork Exists
The original `rmpc` is an MPD client. The user forked it to:
1. Add **YouTube Music backend** alongside MPD/MPV backends
2. Adapt the **UI/UX to match YouTube Music** web app workflows
3. Keep the **TUI approach** (no browser required)
4. Enable **external control** (Rofi, scripts, keybindings) like MPD

### Core User Workflow
```
User opens TUI → Searches "beatles" → Gets suggestions while typing
→ Selects "The Beatles" → Browses albums → Plays "Abbey Road"
→ Music continues via MPV backend → Can control via keyboard/scripts
```

---

## 📊 Current Status (as of 2025-11-25)

### ✅ What's Working (64% of Phase 6 Complete)

**Core Features (Ready for Daily Use)**:
- ✅ **Search with Suggestions**: Type 2+ chars → Get YouTube Music suggestions → Navigate with ↑↓ → Select with Enter
- ✅ **Album Browsing**: Click album → See full tracklist → Play or add to queue
- ✅ **Artist Browsing**: Click artist → See top songs + albums → Navigate between sections
- ✅ **Playlist Viewing**: Click playlist → See all tracks → Play/queue
- ✅ **Queue Management**: Add/remove songs, shuffle, clear, move tracks
- ✅ **Playback**: Play, pause, next, previous, seek (via MPV backend)
- ✅ **Radio/Autoplay**: Continuous playback when queue ends
- ✅ **Stream Caching**: 1-hour TTL, LRU cache for performance

**Technical Foundation**:
- ✅ **Multi-backend architecture**: YouTube/MPD/MPV all work
- ✅ **Config-driven**: Switch backends via `config.toml`
- ✅ **ytmapi-rs 0.2.1**: Official crate from crates.io (migrated from local fork)
- ✅ **Clean compilation**: 0 errors, 20 pre-existing warnings

### ❌ What's Not Implemented (Deferred)

**UI Components (36% Missing)**:
- ❌ **HomePane**: YouTube Music home feed with "Listen Again" (needs complex grid layout)
- ❌ **ZenPane**: Full-screen player with large artwork + lyrics (complex UI composition)
- ❌ **LibraryPane Backend**: UI exists but doesn't fetch real data (shows categories only)

**External Control (Moved to Phase 7)**:
- ❌ **Rofi Integration**: No external control yet
- ❌ **CLI Commands**: No `rmpc-cli play` etc.
- ❌ **Daemon Mode**: Runs as monolithic TUI only

### 🎯 Next Phase: Server-Client Architecture (Phase 7)

**Goal**: Add **MPD-style daemon** for external control

**What This Enables**:
```bash
# Start daemon
rmpcd &

# Control from CLI
rmpc-cli search "lofi beats"
rmpc-cli play 0

# Control from Rofi
rofi-rmpc.sh  # GUI menu for play/pause/search

# Control from i3 keybindings
bindsym XF86AudioPlay exec rmpc-cli pause
```

**Why This Design?**:
- User wants Rofi integration (from original plan)
- Headless operation (music continues when TUI closes)
- Scriptability (bash automation)
- Multiple clients (TUI + CLI simultaneously)

---

## 🏗️ Architecture Overview

### Backend Abstraction

```rust
trait MusicBackend {
    fn play(&mut self) -> Result<()>;
    fn search(&mut self, filter: &[Filter]) -> Result<Vec<Song>>;
    fn get_search_suggestions(&mut self, query: String) -> Result<Vec<String>>;
    // ... many more methods
}

// Implementations:
- YouTubeBackend  → Uses ytmapi-rs + MPV for playback
- MpdBackend      → Wraps existing MPD client
- MpvBackend      → Direct MPV IPC control
```

### Data Flow for Search Suggestions

```
User types in SearchPane
    ↓
Debounce 300ms (via replace_id)
    ↓
ctx.query() with replace_id="search_suggestions"
    ↓
Client::get_search_suggestions(query)
    ↓
YouTubeBackend::get_search_suggestions(query)
    ↓
ytmapi-rs::get_search_suggestions API call
    ↓
MpdQueryResult::SearchSuggestions(Vec<String>)
    ↓
SearchPane::on_query_finished() updates UI
    ↓
Render suggestions list in preview area
```

### Key Design Decisions

**1. Why "Inline Suggestions" (not popup)?**
- Reuses existing preview area
- No complex popup widget needed in TUI
- More terminal-friendly UX

**2. Why `replace_id` for debouncing?**
- Automatic query cancellation
- No manual timer management
- Simpler implementation

**3. Why 64% completion is acceptable?**
- Core playback works perfectly
- HomePane/ZenPane are **aesthetic** (not functional blockers)
- User prioritized external control (Phase 7) over UI polish

---

## 🗂️ Critical Files & Locations

### Configuration
```bash
~/.config/rmpc/config.toml     # User config
~/.config/rmpc/browser.json    # YouTube Music cookies (from ytmusicapi)
```

### Source Code Structure
```
rmpc/src/
├── player/
│   ├── backend.rs              # MusicBackend trait definition
│   ├── youtube_backend.rs      # YouTube implementation (ytmapi-rs + MPV)
│   ├── mpd_backend.rs          # MPD wrapper
│   ├── client.rs               # Unified Client wrapper
│   └── ...
├── ui/
│   ├── panes/
│   │   ├── search/mod.rs       # Search with suggestions ✅
│   │   ├── albums.rs           # Album detail view ✅
│   │   ├── artist.rs           # Artist detail view ✅
│   │   ├── playlist.rs         # Playlist view ✅
│   │   └── library.rs          # Library browser (UI only)
│   └── ...
├── shared/
│   └── mpd_query.rs            # Query result types (includes SearchSuggestions)
└── ...
```

### Documentation (Current Session)
```
~/.gemini/antigravity/brain/.../
├── implementation_plan.md              # Master plan (Phases 1-8)
├── task.md                             # Detailed checklist
├── planned_vs_delivered.md             # Honest 64% completion status
├── server_client_architecture_plan.md  # Phase 7 detailed design
├── search_suggestions_walkthrough.md   # Phase 6.6 implementation
└── work_summary.md                     # Latest session summary
```

---

## 🚀 How to Use (Current State)

### Setup
```bash
cd <PROJECT_ROOT>/rmpc

# 1. Build
cargo build --release

# 2. Generate YouTube Music cookies
pip install ytmusicapi
ytmusicapi browser  # Saves to browser.json

# 3. Configure
cat > ~/.config/rmpc/config.toml << EOF
[player]
backend = "youtube"

[youtube]
auth_file = "$HOME/.config/rmpc/browser.json"
EOF

# 4. Start MPV backend
mpv --no-video --idle=yes --input-ipc-server=/tmp/rmpc-mpv.sock &

# 5. Run rmpc
./target/release/rmpc
```

### Usage
1. **Search**: Type in search box → Suggestions appear
2. **Navigate**: Use ↑↓ to move, Enter to select
3. **Browse**: Select Album/Artist/Playlist from results
4. **Play**: Press Enter on a song to add to queue
5. **Queue**: Tab to Queue pane, manage playback

---

## 🎯 What You Need to Do (Phase 7)

### Objective
Implement **MPD-style server-client architecture** to enable external control.

### Success Criteria
```bash
# This should work:
rmpcd &                          # Start daemon
rmpc-cli search "beatles"        # Search from CLI
rmpc-cli play 0                  # Play from CLI
rofi-rmpc.sh                     # Rofi menu shows
bindsym XF86AudioPlay exec ...   # i3 keybindings work
```

### Detailed Plan
See [`server_client_architecture_plan.md`](file://~/.gemini/antigravity/brain/e9a7c3ae-3a28-4702-86a8-230c2457d326/server_client_architecture_plan.md) for:
- 6-week implementation timeline
- Protocol specification (text-based, MPD-style)
- Command set (play, pause, search, queue, etc.)
- Code structure and examples
- Testing strategy

### Phase 7 Breakdown (6 weeks)

**Week 1: Core Server**
- Create `rmpcd` binary
- Unix socket server (`/tmp/rmpc.sock` or `~/.config/rmpc/socket`)
- Text protocol parser (`play 5\nOK\n`)
- Connection handling

**Week 2: Commands**
- Playback: `play`, `pause`, `stop`, `next`, `previous`
- Queue: `add`, `delete`, `clear`, `shuffle`
- Status: `status`, `currentsong`, `queue`
- Search: `search`, `search_suggestions`

**Week 3: CLI Client**
- `rmpc-cli` binary
- Client library (socket communication)
- All command wrappers

**Week 4: Rofi Integration**
- `rofi-rmpc.sh` - Main menu
- `rofi-rmpc-search.sh` - Search interface
- `rofi-rmpc-queue.sh` - Queue browser

**Week 5: TUI Refactor (Optional)**
- Refactor TUI to connect as client
- State sync via `idle` command
- Both TUI and CLI can control same daemon

**Week 6: Advanced**
- `idle` command (event subscriptions)
- Command batching
- TCP support (optional remote control)

---

## ⚠️ Critical Context for Implementation

### Don't Break Backward Compatibility
- Keep monolithic TUI mode as default
- Server mode should be **opt-in** via config
- User should be able to use current TUI without daemon

### Protocol Must Be Simple
- Text-based (like MPD), not binary
- Each line is a command or response
- `OK` for success, `ACK [error]` for failure
- Example: `play 5\nOK\n` or `status\nOK state: playing\nsong: 0\n`

### Reuse Existing Backend
- Don't reimplement playback logic
- Daemon wraps existing `Client` wrapper
- Commands delegate to `MusicBackend` trait methods

### Why Unix Socket First?
- Fast (no TCP overhead)
- Secure (local only)
- Standard on Unix systems
- Can add TCP later if needed

---

## 🐛 Known Issues & Edge Cases

### Current Bugs (Not Critical)
1. **LibraryPane**: Shows categories but doesn't fetch data
2. **Cookie Expiration**: Manual refresh needed (no clear error)
3. **MPV Socket**: Must start manually before rmpc

### Testing Edge Cases for Phase 7
1. **Multiple Clients**: Can TUI + CLI control daemon simultaneously?
2. **Socket Cleanup**: What happens if daemon crashes? Stale socket?
3. **State Sync**: How do clients know when state changes? (`idle` command)
4. **Error Handling**: Clear errors when daemon not running

---

## 📝 Code Patterns to Follow

### Adding New Commands
```rust
// 1. Add to Command enum (src/server/commands.rs)
enum Command {
    Play { id: Option<u32> },
    Search { query: String },
    // ...
}

// 2. Parse in protocol.rs
fn parse_command(line: &str) -> Result<Command> {
    match parts[0] {
        "play" => Ok(Command::Play { id: parts.get(1).map(|s| s.parse().ok()).flatten() }),
        // ...
    }
}

// 3. Handle in CommandHandler
impl CommandHandler {
    async fn handle(&mut self, cmd: Command) -> Result<Response> {
        match cmd {
            Command::Play { id } => {
                self.backend.lock().await.play_id(id)?;
                Ok(Response::ok())
            }
            // ...
        }
    }
}
```

### Client Library Pattern
```rust
// Client wrapper (src/client/mod.rs)
pub struct Client {
    stream: UnixStream,
}

impl Client {
    pub fn play(&mut self, id: Option<u32>) -> Result<()> {
        let cmd = if let Some(id) = id {
            format!("play {}", id)
        } else {
            "play".to_string()
        };
        self.send_command(&cmd)?;
        Ok(())
    }
    
    fn send_command(&mut self, cmd: &str) -> Result<String> {
        writeln!(self.stream, "{}", cmd)?;
        self.read_response()
    }
}
```

---

## 🎓 Key Learnings from This Session

### What Went Well
1. **Clean abstraction**: `MusicBackend` trait worked perfectly
2. **Implicit debouncing**: `replace_id` was simpler than manual timers
3. **Inline suggestions**: Reusing preview area avoided popup complexity
4. **ytmapi-rs migration**: Official crate worked flawlessly

### What Was Challenging
1. **LibraryPane**: Backend stubs need full implementation (low priority)
2. **Compilation warnings**: Tight iteration needed to fix all 8
3. **Documentation sprawl**: Many interim artifacts created (now cleaned up)

### User Preferences
- **Honesty over optimism**: User appreciated 64% completion disclosure
- **Pragmatic design**: Skip complex features (HomePane) for high-value ones (external control)
- **Clean commits**: Separate logical commits, good messages

---

## 💬 User Communication Style

### What the User Values
- **Honesty**: Don't oversell. Say "64% done" not "almost finished"
- **Clarity**: Use tables, diagrams, examples
- **Actionability**: Give next steps, not just analysis
- **Efficiency**: No fluff, get to the point

### What to Avoid
- Vague promises ("coming soon")
- Hiding missing features
- Overly verbose explanations
- Assumptions without confirmation

---

## 🔧 Development Workflow

### Before Starting Work
1. Read `implementation_plan.md` - Know the big picture
2. Read `planned_vs_delivered.md` - Know what's missing
3. Read `server_client_architecture_plan.md` - Phase 7 details
4. Check `task.md` - Current checklist

### During Development
1. Update `task.md` as you progress (mark `[/]` in-progress, `[x]` done)
2. Keep `implementation_plan.md` updated if plan changes
3. Write concise commit messages (see git history for examples)

### Before Finishing
1. Run `cargo check` - Must be 0 errors
2. Update documentation if design changed
3. Create walkthrough for significant features
4. Ask user for testing/feedback

---

## 📦 Dependencies & Prerequisites

### Rust Crates
```toml
ytmapi-rs = "0.2.1"  # Official YouTube Music API
ratatui = "..."       # TUI framework
tokio = "..."         # Async runtime
serde = "..."         # Serialization
```

### External Tools
- **MPV**: Media player (playback backend)
- **ytmusicapi** (Python): Generate YouTube cookies
- **Rofi/dmenu**: GUI menus (Phase 7)

### User Environment
- Linux/Unix system
- Terminal with Unicode support
- Kitty terminal (for album art, optional)

---

## ✅ Acceptance Criteria for Phase 7

### Minimal Viable Product (MVP)
```bash
# Must work:
rmpcd &                     # Daemon starts
rmpc-cli play              # Plays current/resume
rmpc-cli pause             # Pauses
rmpc-cli next              # Next track
rmpc-cli status            # Shows current state
rmpc-cli search "beatles"  # Returns results
```

### Stretch Goals
```bash
# Nice to have:
rmpc-cli add <uri>         # Add to queue
rmpc-cli queue             # List queue
rofi-rmpc.sh               # Rofi menu works
rmpc (TUI client mode)     # TUI connects to daemon
```

### Non-Goals (Don't Implement)
- Web UI (Phase 8 maybe)
- Remote TCP (Week 6, optional)
- Mobile apps (out of scope)

---

## 🚨 Red Flags to Watch For

### Architecture Smells
- ❌ Duplicating backend logic in daemon
- ❌ Not reusing `MusicBackend` trait
- ❌ Complex binary protocols (keep it text)
- ❌ Breaking existing TUI (must stay compatible)

### Implementation Smells
- ❌ Not handling socket cleanup
- ❌ No error handling for daemon not running
- ❌ Blocking I/O (use async)
- ❌ Hardcoded paths (use config)

### User Experience Smells
- ❌ Daemon required to run TUI
- ❌ Confusing error messages
- ❌ No migration path from monolithic mode
- ❌ Breaking changes without documentation

---

## 📚 Further Reading

### Key Documents (in order of importance)
1. [`server_client_architecture_plan.md`](file://~/.gemini/antigravity/brain/e9a7c3ae-3a28-4702-86a8-230c2457d326/server_client_architecture_plan.md) - Phase 7 detailed design ⭐
2. [`implementation_plan.md`](file://~/.gemini/antigravity/brain/e9a7c3ae-3a28-4702-86a8-230c2457d326/implementation_plan.md) - Master plan Phases 1-8
3. [`planned_vs_delivered.md`](file://~/.gemini/antigravity/brain/e9a7c3ae-3a28-4702-86a8-230c2457d326/planned_vs_delivered.md) - What's actually done
4. [`search_suggestions_walkthrough.md`](file://~/.gemini/antigravity/brain/e9a7c3ae-3a28-4702-86a8-230c2457d326/search_suggestions_walkthrough.md) - Latest implementation example

### External References
- [MPD Protocol Spec](https://www.musicpd.org/doc/html/protocol.html) - Your north star for Phase 7
- [ytmapi-rs Docs](https://docs.rs/ytmapi-rs) - YouTube Music API
- [Ratatui Docs](https://ratatui.rs) - TUI framework

---

## 🎯 Your Mission (Next LLM)

**Primary Objective**: Implement Phase 7 - Server-Client Architecture

**Success**: User can control rmpc from Rofi, CLI, and keybindings

**Approach**:
1. Read this document completely
2. Read `server_client_architecture_plan.md`
3. Start with Week 1 (Core Server)
4. Follow the testing plan
5. Keep user updated with honest progress

**Remember**:
- User values honesty over optimism
- Clean, incremental commits
- Don't break backward compatibility
- Ask questions if context is unclear

**Good luck! You're building something the user will use daily. Make it solid.** 🚀
