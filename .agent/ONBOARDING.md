# Agent Onboarding Guide: yrmpc (YouTube Music TUI)

**Last Updated**: Dec 8, 2024  
**Status**: ✅ Rich List UI complete, backend stable, E2E tests passing

## Current Reality (Dec 2024)

### ✅ Backend Status
**ALL search types supported**:
- Artists, Albums, Playlists (Community + Featured), Songs, Videos
- Code: `rmpc/src/player/youtube_backend.rs:1177-1460`
- YouTube API returns diverse results ✅
- Enter handler routes correctly ✅

**No backend work needed!**

### ✅ Testing Status
**E2E tests**: 3/6 passing with real data validation
- Location: `tests/e2e/rmpc-tui-test.spec.ts`
- Verify actual song titles, artist names, logs
- Meaningful failures (not superficial)

### ✅ Repository Status
- Clean commit history (b60bf26)
- Tests organized in `tests/`
- 24 obsolete files removed
- Documentation consolidated

---

## Project Vision

**yrmpc** is a terminal-based YouTube Music client that provides a keyboard-driven, vim-inspired interface for discovering and playing music. Think Spotify TUI meets YouTube Music, with zero mouse dependency.

### Core Philosophy
- **Keyboard-first**: Every action accessible via keybindings (vim-style)
- **No downloads**: Stream-only, never download full tracks
- **Gapless playback**: Pre-buffer next track for seamless listening
- **Rich navigation**: Browse artists, albums, playlists like the web client
- **Visual selection**: Bulk operations on multiple tracks (vim visual mode)

### User's Primary Workflow
1. Search for music (songs, artists, albums, playlists)
2. Navigate to detail views (playlist → artist → album)
3. Visual select multiple tracks
4. Bulk operations: play next, play last, save to library
5. Queue management with auto-radio

---

## Essential Documentation

**Read these BEFORE starting any task:**

### 1. Project Overview (MUST READ FIRST)
- [`docs/PROJECT_OVERVIEW.md`](file://<PROJECT_ROOT>/docs/PROJECT_OVERVIEW.md) - What this is, tech stack, current state, priorities

### 2. Feature Specifications
- [`docs/FEATURES.md`](file://<PROJECT_ROOT>/docs/FEATURES.md) - Complete UX design, wireframes, keyboard navigation, visual selection

### 3. Development Guide
- [`docs/DEVELOPMENT.md`](file://<PROJECT_ROOT>/docs/DEVELOPMENT.md) - Build, test, run, authentication setup

### 4. Architecture
- [`docs/ARCHITECTURE.md`](file://<PROJECT_ROOT>/docs/ARCHITECTURE.md) - Submodule structure, data flow, component relationships

### 5. Codebase Map
- [`docs/CODEBASE_MAP.md`](file://<PROJECT_ROOT>/docs/CODEBASE_MAP.md) - Where to find code, quick navigation

### 6. YouTube API Details
- [`docs/YOUTUBE_API.md`](file://<PROJECT_ROOT>/docs/YOUTUBE_API.md) - YouTube Music API, browseId, gotchas, ytmapi-rs usage

### 7. Rich List UI Architecture (NEW)
- [`docs/ADR-rich-list-ui.md`](file://<PROJECT_ROOT>/docs/ADR-rich-list-ui.md) - Architecture decision record, key files, known issues
- [`docs/ui-ux-provised.md`](file://<PROJECT_ROOT>/docs/ui-ux-provised.md) - Full UI/UX specification

---

## Current Implementation Status

### ✅ Completed
- **Rich List UI** (thumbnail + 2-line layout, configurable)
- Basic search (songs, albums, artists, playlists)
- MPV integration (headless audio playback)
- YouTube Music API integration (ytmapi-rs)
- HTTP 400 sticker bug fix
- YouTube API browse methods (playlist, album, artist)

### 🚧 In Progress
- **Thumbnail rendering fix** (displays corner only)

### 🚧 In Progress (Phase 1)
- **Interactive search results** (PRIORITY 1)
  - Enter key routing by item type
  - Detail views for playlist/album/artist
  - Navigation stack with breadcrumbs

### ❌ Not Yet Implemented
- Visual selection mode (vim V key)
- Bulk operations (play next/last, save)
- Featured artists keyboard navigation
- Queue management enhancements
- Auto-radio feature

### 🐛 Known Issues (Backlog)
- Top Results section missing from search (regression)
- Artists section missing from search results

---

## MCP Tools You Should Use

### Serena (Code Navigation & Editing)

**When to use**: Any code exploration or modification task

**Key tools**:
```bash
# Find symbols
mcp2_find_symbol --name_path_pattern "method_name" --relative_path "rmpc/src/..."

# Search for patterns
mcp2_search_for_pattern --substring_pattern "\.pause_toggle\(" --relative_path "rmpc/src"

# Get file overview
mcp2_get_symbols_overview --relative_path "rmpc/src/ui/panes/search/mod.rs"

# Insert code
mcp2_insert_after_symbol --name_path "existing_method" --body "new code"

# Replace code
mcp2_replace_symbol_body --name_path "method" --body "updated implementation"
```

**Best practices**:
- Always activate project first: `mcp2_activate_project --project "yrmpc"`
- Use `find_symbol` before editing to understand context
- Use `find_referencing_symbols` to check impact of changes

### Sequential Thinking (Complex Problem Solving)

**When to use**: 
- Planning multi-step implementations
- Debugging complex issues
- Designing new features
- Analyzing architecture decisions

**How to use**:
```bash
mcp1_sequentialthinking \
  --thought "Breaking down the problem..." \
  --thoughtNumber 1 \
  --totalThoughts 5 \
  --nextThoughtNeeded true
```

**Best practices**:
- Start with 5-10 estimated thoughts
- Adjust total as you progress
- Use for design before implementation
- Mark revisions when changing approach

---

## Development Workflow

### 1. Understand the Task
- Read relevant docs (PROJECT_OVERVIEW, FEATURES, etc.)
- Check current progress in `task.md` artifact
- Review `implementation_plan.md` for context

### 2. Plan Your Approach
- Use **sequential thinking** for complex tasks
- Break down into actionable steps
- Update `task.md` with your plan

### 3. Implement
- Use **Serena** for code navigation
- Follow existing code style
- Add logging for debugging
- Keep changes focused and atomic

### 4. Test
- Build: `cargo build --release --manifest-path=rmpc/Cargo.toml`
- Run: `./rmpc/target/release/rmpc`
- E2E tests: `node node_modules/@microsoft/tui-test/index.js <test-file>`

### 5. Document
- Update `task.md` with completed items
- Update `walkthrough.md` with what was done
- Update relevant docs if architecture changed

---

## Code Style & Conventions

### Rust
- Use `anyhow::Result` for error handling
- Log at appropriate levels: `log::debug!`, `log::info!`, `log::error!`
- Follow existing patterns in codebase
- Add doc comments for public APIs

### UI Components
- Vim-style keybindings (j/k for navigation, v for visual mode)
- Section-based layouts (Tab to switch sections)
- Clear visual feedback for selections
- Breadcrumb navigation for deep views

### YouTube API
- Always use ytmapi-rs types (`PlaylistID`, `AlbumID`, `ArtistChannelID`)
- Handle missing data gracefully (Options, fallbacks)
- Log API calls for debugging
- Cache when appropriate

---

## Common Tasks

### Adding a New UI View
1. Create component in `rmpc/src/ui/panes/<name>.rs`
2. Implement `render()` and `handle_input()` methods
3. Add to navigation stack in app state
4. Wire up routing logic in parent component

### Adding a New YouTube API Method
1. Check ytmapi-rs for available queries
2. Add method to `rmpc/src/player/youtube/api.rs`
3. Parse response into rmpc `Song` or custom struct
4. Add logging for debugging
5. Expose through client/server if needed

### Fixing a Bug
1. Reproduce the issue
2. Add logging to trace execution
3. Use sequential thinking to analyze root cause
4. Implement fix with minimal changes
5. Verify fix doesn't break other functionality

---

## Project Structure

```
yrmpc/
├── rmpc/                    # Main application (submodule)
│   ├── src/
│   │   ├── player/
│   │   │   └── youtube/     # YouTube backend
│   │   │       ├── api.rs   # YouTube Music API wrapper
│   │   │       ├── details.rs  # Playlist/Album/Artist details
│   │   │       ├── client.rs   # Client for TUI
│   │   │       └── server.rs   # Server managing MPV
│   │   ├── ui/
│   │   │   └── panes/       # UI components
│   │   │       ├── search/  # Search results view
│   │   │       ├── queue/   # Queue management
│   │   │       └── ...
│   │   └── core/            # Event loop, state management
│   └── Cargo.toml
├── youtui/                  # ytmapi-rs library (submodule)
├── config/rmpc.ron          # Runtime configuration
├── docs/                    # Documentation (READ THIS!)
└── package.json             # TUI test framework
```

---

## Testing Strategy

### Manual Testing
- Search for real content: "kim long", "HYBS", "making steak"
- Test Vietnamese characters (Unicode handling)
- Verify keyboard navigation works without mouse
- Check error messages are user-friendly

### Automated Testing
- E2E tests with `@microsoft/tui-test` framework
- Use Node 20.x for compatibility
- Focus on functional validation, not exact UI snapshots
- Test error scenarios (API failures, empty results)

### Debugging
- Logs: `/tmp/rmpc_debug.log`
- Add debug logging liberally
- Use `grep` to filter relevant log lines
- Check MPV logs for playback issues

---

## Critical Reminders

### ⚠️ NEVER
- Download entire playlists (stream only!)
- Use mouse-dependent UI patterns
- Break vim-style keyboard navigation
- Ignore Unicode/Vietnamese character support
- Make changes without reading relevant docs

### ✅ ALWAYS
- Read PROJECT_OVERVIEW.md and FEATURES.md first
- Use sequential thinking for complex tasks
- Update task.md as you progress
- Test with real YouTube content
- Log important operations for debugging
- Keep user's vision in mind (keyboard-first, rich navigation)

---

## Getting Help

### Documentation
- All docs in `docs/` directory
- Check `docs/COMMON_TASKS.md` for recipes
- Review `docs/YOUTUBE_API.md` for API quirks

### Code Examples
- Search existing code with Serena
- Look at similar components for patterns
- Check git history for context

### User Expectations
- Refer to FEATURES.md for UX design
- Check PROJECT_OVERVIEW.md for priorities
- User wants Spotify/YouTube Music UX in terminal

---

## Success Criteria

You're doing well if:
- ✅ Code compiles without errors
- ✅ Features match FEATURES.md specification
- ✅ Keyboard navigation works smoothly
- ✅ No mouse required for any operation
- ✅ Vietnamese/Unicode content works
- ✅ Documentation is updated
- ✅ User can achieve their workflow goals

---

## Quick Start Checklist

Before starting ANY task:
- [ ] Read PROJECT_OVERVIEW.md
- [ ] Read FEATURES.md (if UI/UX related)
- [ ] Check task.md for current progress
- [ ] Activate Serena project: `mcp2_activate_project --project "yrmpc"`
- [ ] Use sequential thinking for planning
- [ ] Update task.md with your plan
- [ ] Implement with Serena tools
- [ ] Test manually
- [ ] Update walkthrough.md with results

---

**Remember**: This project is about creating a delightful keyboard-driven music experience. Every feature should feel natural, fast, and powerful. Think vim meets Spotify!
