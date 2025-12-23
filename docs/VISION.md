# Project Vision: yrmpc

## Vision Statement

**yrmpc** is a premium terminal-based YouTube Music client that brings the rich, visual experience of modern streaming apps to the terminal, while maintaining keyboard-driven efficiency and power-user features.

## Core Philosophy

### Terminal-Native, Not Web Clone
- **Keyboard-first**: Every action accessible via vim-style keybindings
- **No mouse dependency**: Complete workflow without touching mouse
- **Dense information display**: Leverage terminal's strengths for efficient browsing
- **Configurable everything**: Themes, layouts, behaviors adapt to user preferences

### Visual Recognition Over Text-Only
- **Instant content recognition**: Album art and thumbnails enable 13ms recognition vs 200ms text reading
- **Rich metadata display**: Structured information hierarchy matching Spotify/YouTube Music
- **Progressive disclosure**: Simple defaults, power features on demand
- **Type icons and colors**: Semantic visual cues for content types

### Complete Music Streaming Experience
- **Full YouTube Music access**: Search, browse, play all content types
- **Interactive detail views**: Deep exploration matching web clients
- **Intelligent queue management**: Visual selection, bulk operations
- **Seamless navigation**: Natural flow between search → artist → album → tracks

## Target User

**The power user who wants:**
- Terminal efficiency without sacrificing modern UX
- Keyboard-driven workflow with vim-style navigation
- Visual content recognition without mouse dependency
- Complete YouTube Music functionality in TUI form
- Fast, responsive interface with minimal friction

## Key Differentiators

### vs. Other TUI Music Clients
- **Rich visual UI**: Thumbnails, album art, structured layouts (not just text lists)
- **Deep navigation**: Browse artists → albums → tracks like web clients
- **Bulk operations**: Visual selection mode for multiple tracks
- **YouTube Music integration**: Full access to YouTube's catalog and features

### vs. Web/Mobile Clients
- **Keyboard speed**: Vim-style navigation faster than mouse/trackpad
- **Terminal efficiency**: Lower resource usage, works over SSH
- **Configurable**: Everything customizable via config files
- **Scriptable**: Integrates with terminal workflows and automation

## User Experience Goals

### Discovery & Exploration
- **Three-column browsing**: Quick preview without losing context
- **Deep dive capability**: Expand to full detail views when interested
- **Related content navigation**: Artists → similar artists, playlists → related
- **Smart search**: Type-ahead suggestions, multiple content types

### Playback & Queue Management
- **Instant playback**: Stream-only, no downloads, gapless transitions
- **Visual queue building**: Select multiple tracks across sources
- **Flexible queue operations**: Play next, play last, replace, shuffle
- **Context preservation**: Browse while music continues playing

### Personalization & Sync
- **Library synchronization**: Save to YouTube Music account
- **Playlist management**: Create, edit, sync playlists
- **Theme customization**: Visual appearance, density, colors
- **Behavior configuration**: Keybindings, defaults, workflows

## Technical Vision

### Architecture Principles
- **Modular design**: Clear separation between UI, backend, and domain
- **Type-safe**: Leverage Rust's type system for reliability
- **Async-first**: Non-blocking operations for responsive UI
- **Extensible**: Plugin-ready architecture for future features

### Performance Targets
- **Search response**: <1 second for typical queries
- **Playback start**: <2 seconds from selection to audio
- **Track switching**: <100ms with pre-buffering
- **UI responsiveness**: 60fps rendering, no blocking operations

### Integration Strategy
- **YouTube Music API**: Primary backend via ytmapi-rs
- **MPV playback**: Headless audio streaming with gapless support
- **MPRIS compliance**: Linux desktop integration
- **Daemon mode**: Background operation with external control

## Success Metrics

### User Experience
- **Zero mouse usage**: Complete workflow achievable via keyboard
- **Visual recognition speed**: Users identify content faster than text-only alternatives
- **Navigation efficiency**: Fewer keystrokes to reach desired content
- **Learning curve**: Vim users feel immediately comfortable

### Technical Excellence
- **Reliability**: No crashes during normal usage
- **Performance**: Meets response time targets consistently
- **Resource efficiency**: Low CPU/memory usage suitable for daily use
- **Compatibility**: Works across terminal types and platforms

### Feature Completeness
- **Parity with web clients**: Core browsing and playback features match
- **Terminal advantages**: Leverages unique strengths of TUI environment
- **Extensibility**: Easy to add new features and integrations
- **Documentation**: Comprehensive guides for users and developers

## Future Roadmap

### Phase 1: Core Experience ✅
- [x] Rich list UI with thumbnails
- [x] Basic search and playback
- [x] Queue management
- [x] YouTube Music API integration

### Phase 2: Interactive Features 🚧
- [ ] Visual selection mode (vim-style)
- [ ] Bulk operations (play next/last, save)
- [ ] Detail views (artist/album/playlist)
- [ ] Library synchronization

### Phase 3: Power Features 📋
- [ ] Advanced search filters
- [ ] Custom playlists and management
- [ ] Lyrics display
- [ ] Crossfade and audio enhancements

### Phase 4: Ecosystem 🌟
- [ ] Plugin system
- [ ] Third-party integrations
- [ ] Mobile companion app
- [ ] Cloud sync for settings

## Vision in Action

### Daily Workflow Example
```
1. Launch: `rmpc` → Instant startup, last session restored
2. Search: `/` "vietnamese hits" → Rich results with thumbnails
3. Explore: `Enter` on playlist → Full detail view with all tracks
4. Select: `v` (visual mode) → Choose 5 favorite tracks
5. Queue: `l` (play last) → Adds to existing queue
6. Browse: `h` back → Continue exploring while music plays
7. Save: `A` (add to library) → Syncs to YouTube Music account
```

### The "Wow" Moments
- **Instant recognition**: "I found the album just by the cover art"
- **Efficient selection**: "I queued 20 tracks from 3 different albums in 30 seconds"
- **Seamless navigation**: "I went from search to artist to album without thinking"
- **Terminal power**: "I'm controlling my music over SSH with full visual interface"

## Conclusion

**yrmpc** bridges the gap between terminal efficiency and modern streaming UX. It respects the power user's keyboard-driven workflow while delivering the visual richness and feature completeness expected from contemporary music streaming services.

The project succeeds when users forget they're in a terminal - they're just enjoying music with an interface that feels both familiar and revolutionary.

---

*"Think vim meets Spotify in the terminal"*