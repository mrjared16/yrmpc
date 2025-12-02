# Project Overview: yrmpc (YouTube MPC)

## What This Is
Terminal-based YouTube Music client built on MPD/MPC architecture. Alternative to web/mobile YouTube Music with keyboard-driven interface.

## Tech Stack
- **Language**: Rust
- **UI**: TUI (Terminal User Interface) via `ratatui`
- **Playback**: MPV (headless, audio-only)
- **API**: YouTube Music unofficial API via `ytmapi-rs`
- **Auth**: Cookie-based (Netscape format)

## Project Structure (Submodules)
```
yrmpc/                    # Parent repo (config, scripts)
├── rmpc/                 # Main application (submodule)
│   └── youtui/           # ytmapi-rs library (nested submodule)
└── config/rmpc.ron      # Runtime configuration
```

**Why submodules?**
- `rmpc` is forked/modified version of upstream rmpc
- `youtui/ytmapi-rs` provides YouTube Music API bindings
- Separation allows independent updates without breaking custom changes

## Current State
✅ **Implemented** (as of 2025-11-26):
- Comprehensive search (artists, albums, songs, videos, playlists, podcasts)
- Full navigation (artist pages, album pages, playlist pages)
- Direct playback from search
- MPV integration (headless audio)
- Queue management
- 23 automated tests (100% passing)

🚧 **Not Yet Implemented**:
[USER INPUT NEEDED - See questions in chat]

## User Expectations & Critical Features

### Primary Workflow

**1. Finding Music:**
- Search for saved playlists
- Search for songs, albums, artists
- Browse search results

**2. Viewing Options:**
- **Playlist View**: 
  - Show list of playable songs
  - Display featured artists with clickable navigation
  - Allow navigation between artists from playlist
- **Album/EP View**:
  - Show track listing
  - Support queue manipulation per track or entire album
- **Artist View**:
  - Display top songs
  - List albums
  - Show related content

**3. Queue Manipulation:**
Per-item or entire playlist controls:
- "Play Next" - Insert after current track
- "Play Last" - Append to end of queue
- Remove items from queue
- Repeat mode
- Shuffle mode
- **Auto-radio**: Add radio-generated songs to queue end when:
  - Playlist is not in loop mode
  - Currently at end of queue

### Must-Have Features (Priority Order)

**PRIORITY 1 - Interactive Search Results** 🚨
1. ✅ Basic search (Implemented)
2. ❌ **Enter key interactions**:
   - Song → Add to queue + play
   - Playlist/Album → Show detail view
   - Artist → Show artist page
3. ❌ **Detail Views**:
   - Playlist view (tracks, featured artists, related)
   - Album view (tracks, artist navigation)
   - Artist view (top songs, albums, related artists)
4. ❌ **Visual Selection** (vim-style):
   - V key for multi-select
   - Bulk operations: play next, play last, save
5. ❌ **Keyboard Navigation**:
   - Featured artists section (no mouse)
   - Related content keyboard-accessible
   - Breadcrumb navigation (back with Esc/q)

**PRIORITY 2 - Queue Management**
- ✅ Basic queue (add, play)
- ❌ Play Next/Play Last
- ❌ Remove from queue
- ❌ Repeat/Shuffle modes

**PRIORITY 3 - Playlist Features**
- ❌ Save playlists to YouTube account  
- ❌ Search saved playlists
- ❌ Playlist creation

**PRIORITY 4 - Auto-Radio**
- ❌ Generate related songs when queue ends
- ❌ Only if not in loop mode

**BACKLOG - Bugs**
- ❌ Top Results section missing from search (regression)
- ❌ Artists section missing from search results

**BACKLOG - Features**
- ❌ Enhanced Views with customizable layouts
- ❌ Album cover art rendering
- ❌ Batch operations (queue entire album/playlist)

### Must-Prevent Behaviors
1. ❌ **NEVER download entire playlists**
   - Stream only, no local storage of full tracks
   - Exception: Cache 10s at start of each track for instant playback
2. ❌ **NEVER have silent moments during playback**
   - Pre-buffer next track before current ends
   - Gapless playback critical
3. ✅ **NEVER show video windows** (Already enforced via `--vo=null`)

## Performance Targets

### Critical (Zero Tolerance)
- **Playback continuity**: NO silent gaps between songs
- **Track switching**: < 100ms delay (via 10s pre-cache)

### High Priority
- **Search results**: < 1s
- **Navigation**: < 500ms (tab switching, page loads)
- **Playback start**: < 2s from user action

### Acceptable
- **Initial app startup**: < 3s
- **First search (API init)**: < 2s

## Integration & Architecture Requirements

### MPD Protocol Compatibility
**Critical**: Backend must act as MPD service for external control

**Use cases:**
- `mpc` commands from shell scripts
- Rofi integration for launcher-based control
- Third-party MPD clients
- Polybar/i3status integration

**Implementation:**
- MPD protocol server (default port 6600)
- Compatible with `mpc` client
- Support core MPD commands:
  - `play`, `pause`, `next`, `prev`
  - `add <uri>`, `clear`, `shuffle`
  - `status`, `currentsong`, `playlist`

### Streaming Strategy
- **Stream-only**: Use `rusty_ytdl` for direct URL extraction
- **Pre-buffering**: Cache first 10s of next track
- **No full downloads**: MPV streams from YouTube CDN
- **Gapless**: Pre-load next track before current ends
