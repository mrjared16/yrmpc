# yrmpc Project Memory

**Generated**: 2026-01-02 | **Sources**: Serena + Claude-mem | **Status**: Active Development

> **Quick Reference**: See [AGENTS.md](AGENTS.md) for commands and critical rules.

---

## Architecture

### Current (Navigator Pattern)
```
InteractiveListView → SectionList → ContentView → Panes → Navigator
```

**Feature flag**: `legacy_panes.enabled=false` enables Navigator architecture

### Backend Structure
```
src/backends/
├── api/                # Playback, Queue, Discovery traits (directory)
├── traits.rs           # MusicBackend trait (deprecated)
├── interaction.rs      # BackendActions (was MpdClientExt)
├── mpd/                # MPD backend + protocol
└── youtube/            # YouTube daemon (client, server, services)
    └── mpv/            # MPV IPC wrapper (inside youtube/)
```

### Critical Patterns

**Rolling Prefetch (MPV)**:
```rust
// WRONG: Destroys playlist, breaks auto-advance
self.playback.play(url, title, artist)?;

// CORRECT: 3-track window for gapless
self.playback.playlist_clear()?;
for url in urls { self.playback.playlist_append(&url)?; }
self.playback.playlist_play_index(0)?;
```

**Repeat Modes (MPD-style)**:
```rust
repeat: self.repeat != "off",
single: if self.repeat == "one" { OnOffOneshot::On } else { OnOffOneshot::Off }
```

**EDL Instant Playback**:
```
AudioCache (HTTP Range 10s) → ytx --bulk → edl://cache.opus,0,10;https://yt,10,
```

**Domain → UI Adapter**:
```rust
// Domain: ContentDetails.into_sections() -> Vec<Section>
// UI: impl From<Section> for SectionView
```

### Hybrid Queue
- **QueueService**: Owns metadata (all songs)
- **MPV**: Rolling window of 2-3 resolved URLs
- **Shuffle**: History stack for "previous" navigation

---

## Critical Rules

### NEVER
- Edit .beads/ files directly (use `bd` CLI only)
- Commit plan files to git (distill decisions to docs/, gitignore backlog/ and docs/plans/)
- Use `legacy_panes: (queue: false, search: false)` format (deprecated)
- Test component contracts without E2E flow verification
- Expect spaces in `type_icon()` tests (use actual emojis)
- Mark tasks done without manual E2E smoke tests
- Download entire playlists (stream only)

### ALWAYS
- Use `bd ready` and `bd update <id> --status=in_progress`
- Write E2E tests verifying API → Domain → UI flow
- Test with actual emojis: `assert_eq!(icon, "🎤")` not `" "`
- Verify config RON schema matches Rust struct
- Create feature parity matrix before migrations
- Manual smoke test: Search → Play → Queue → Find → Tab navigation

### Architecture Gotchas

**Icon Pipeline** (all layers must be correct):
```
YouTube API → Song.metadata["type"] → DetailItem::from() → type_icon() → UI
```

**Key Handling**: Navigator captures 1/2/3 tabs, Tab/Shift-Tab falls through to global

**Extractor**: Default is `ytx` (~200ms), yt-dlp fallback (avoid in tests - slow)

**Testing**: Test ENTIRE data flow, not component contracts. Wrong layer = hidden bugs.

**Rich List Patterns**:
- *Dual-Trait*: Both `ListItemDisplay` and `DirStackItem` need `is_focusable()` - headers unfocusable in both contexts
- *Metadata Flow*: `secondary_text()` checks subtitle BEFORE artist/album fallback (order matters)
- *Performance Guard*: Navigation loops have iteration limit to prevent infinite loops when skipping headers

---

## Current State (2026-01-03)

### Working ✅
Search • Playback • Queue • Auto-advance • Repeat/Shuffle • MPRIS • Daemon • Navigator • EDL cache • Sectioned results • Backend abstraction • CachedExtractor • MPV event-driven playback

### In Progress 🔄
MediaItem migration • Action system integration • QueueStore migration (40%) • Navigator consolidation (60%)

### Known Issues 🔴
- QueueStore + app_state + ctx.queue = triple source of truth (migration incomplete)
- Navigator + PaneContainer both own pane instances (dual runtime)
- Action system bypassed by panes (infrastructure exists, not integrated)
- Two ActionKind enums (domain/content.rs vs actions/intent.rs)
- Backend types leak to UI (MpdError, ctx.is_mpd() checks)

### Recent Completed (Jan 3)
✅ CachedExtractor: Request coalescing + LRU cache (deleted unsafe Send/Sync)
✅ MPV IPC: MpvCommand struct usage, event-driven playback
✅ PlaybackService: Fixed observe_property on correct connection
✅ PlaybackService: Thread stopped on Drop via AtomicBool
✅ PlaybackService: EDL URL percent-encoding for special chars
✅ Protocol: MediaItem-based IPC with browse support

---

## Key Files

| Layer | File |
|-------|------|
| **Navigator** | `ui/panes/navigator.rs`, `navigator_types.rs` |
| **Backend** | `backends/dispatcher.rs`, `backends/api.rs` |
| **Panes** | `ui/panes/search_pane_v2.rs`, `queue_pane_v2.rs` |
| **Widgets** | `ui/widgets/content_view.rs`, `detail_stack.rs` |
| **Domain** | `domain/detail_item.rs`, `domain/search/`, `domain/content_uri.rs` |
| **YouTube** | `backends/youtube/server/`, `backends/youtube/client.rs` |

---

## Lessons from Failures

### MPV Event Observation (Jan 2026)
**Mistake**: Called `observe_property()` on main connection but read events from separate `event_reader` connection.

**Reality**: MPV observation is per-connection. Events were never received.

**Fix**: Call `observe_property()` on the SAME connection that calls `read_event()`.

### Unsafe Send/Sync (Jan 2026)
**Mistake**: Added `unsafe impl Send/Sync` without bounds to fix compile errors.

**Reality**: Unconditional unsafe impl can cause UB if inner type isn't thread-safe.

**Fix**: Delete unsafe impls and rely on auto-derivation, or add `E: Send + Sync` bounds.

### Idle Loop Starvation (CPU Fix)
**Problem**: 146% CPU when idle - both `idle` and `request` threads spinning.

**Root Cause**: In `core/client.rs`, idle loop used `continue` on timeout, preventing client from yielding to request thread.

**Fix**: Use `break vec![]` instead of `continue` on timeout to yield client.

**Pattern**: In dual-backend architectures, ensure timeout-based yields work even when interrupt mechanisms are no-ops.

### Composable Extractors via Decorators
**Problem**: Single `StreamExtractor` enum with sequential fallback was hard to extend.

**Solution**: Trait-based composition with decorators:
```rust
let extractor = FallbackExtractor::new(
    CachedExtractor::new(YtxExtractor::new(), 1000),
    YtDlpExtractor::new()
);
```

**Pattern**: Decorator pattern enables flexible feature composition without modifying core types.

### Navigator Migration (Dec 2025)
**Mistake**: Marked task "done" based on structural AC (routing added, tests pass) without behavior verification.

**Reality**: Play broken, queue broken, images missing, headers wrong, find broken.

**Cause**: No E2E smoke tests. Unit tests verified contracts, not user workflows.

**Fix**: Feature parity matrix + manual E2E before marking done.

### Icon Bug (Dec 2025)
**Mistake**: Tests passed but icons showed spaces instead of emojis.

**Cause**: Tests expected wrong values `assert_eq!(icon, " ")` instead of `assert_eq!(icon, "🎤")`.

**Fix**: Test entire pipeline (API → Domain → UI), expect correct values.

### Config Schema (Dec 2025)
**Mistake**: Config used old format, code expected new struct.

**Fix**: Always verify RON schema matches Rust struct definition.

---

## Migration Checklist

Use this before marking any migration task "done":

- [ ] Feature parity matrix (every user-visible behavior)
- [ ] Manual E2E: Search → Play → Queue → Tab → Find → Mark
- [ ] All P0 architecture issues → blocking tasks
- [ ] Feature flag stays legacy until parity verified
- [ ] AC includes "all legacy behaviors work in new system"

---

## Import Patterns

```rust
// Current (use these)
use crate::backends::{BackendDispatcher, BackendActions};
use crate::backends::{MusicBackend, QueueOperations};
use crate::backends::{MpdBackend, YouTubeBackend};

// Deprecated (still work, avoid in new code)
use crate::backends::MpdClientExt;      // → BackendActions
use crate::backends::PlayerController;  // → BackendDispatcher
```

---

## Future Work

**Immediate**: Complete MediaItem migration, integrate action system, queue cleanup

**Medium**: Abstract backend errors, Library pane sections, multi-backend UX

**Long**: Trait split (Core + Extensions), improved daemon mode, additional backends

---

## PlayIntent Architecture (2026-01-15)

### Pattern: Intent-Based Playback
```rust
// OLD: Composed commands (blocking, slow)
queue.clear()?;
for song in songs { queue.add(song).await?; }  // Each add blocks on URL extraction
player.play_pos(0)?;

// NEW: Atomic intent (non-blocking, <500ms)
queue.play(PlayIntent::Context { 
    tracks: songs, 
    offset: 0, 
    shuffle: false 
});
```

### Key Types
- `PlayIntent`: Context, Next, Append, Radio(seed)
- `PreloadTier`: Immediate > Gapless > Eager > Background
- `RequestId`: u64 counter for dedup/cancel

### PreloadScheduler (replaces AudioPrefetcher)
- Priority lanes with concurrency limits: Immediate(∞), Gapless(2), Eager(1), Background(1)
- Dedup: same (track, artifact) → escalate priority
- Cancel: remove pending jobs by request_id

### Preparer (three-stage pipeline)
1. StreamUrl: Resolve playback URL (reuses CachedExtractor)
2. AudioPrefix: Download first ~200KB (HTTP Range)
3. MpvInput: Build Concat or Passthrough URL

### Tier-Based Wait Policy
- Immediate: Wait up to 200ms for prefix, then passthrough
- Gapless/Eager/Background: Wait for full prefix

### Lessons Learned

**Intent at IPC boundary, composability inside engine**:
- TUI sends single `ServerCommand::PlayWithIntent { intent, request_id }`
- Daemon handler derives priorities and schedules preload jobs
- Queue mutation and playback happen atomically

**Passthrough fallback for latency**:
- If prefix not ready within deadline, use direct stream URL
- User hears audio immediately, quality may be slightly lower initially

**Dedup with priority escalation**:
- Background request for track A, then Immediate for same track
- Job is escalated to Immediate lane, not duplicated

---

## Documentation

`CLAUDE.md` - LLM guidelines | `docs/ARCHITECTURE.md` - System design | `docs/VISION.md` - Project goals | Beads CLI (`bd`) - Task management | `docs/arch/*.md` - Architectural decisions
