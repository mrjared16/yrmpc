# Playback System Redesign Plan

**Date:** 2025-12-21
**Status:** Draft - Awaiting Approval
**Scope:** Queue UX + Playback Service + Prefetch Logic

---

## Executive Summary

This plan addresses three core problems:
1. **Confusing toggle behavior** - Enter doesn't pause/resume same song
2. **Audio latency** - 0.5-1s delay when playing any song
3. **Naming confusion** - "Playlist" vs "Queue" vs "Buffer" unclear

### Goals
- **Instant playback** for any song in queue (<100ms perceived latency)
- **Gapless transitions** between songs
- **Intuitive toggle** - Enter on same song = pause/resume
- **Clear naming** - Components do what their names suggest

---

## Part 1: Queue UX Changes

### 1.1 Toggle Behavior (Critical UX Fix)

**Current Behavior:**
| Action | Result |
|--------|--------|
| Enter on song (not playing) | Play from start |
| Enter on same song (playing) | Restart from start ❌ |
| Enter on same song (paused) | Restart from start ❌ |

**New Behavior:**
| Action | Result |
|--------|--------|
| Enter on song (not playing) | Play from start |
| Enter on same song (playing) | **Pause** ✓ |
| Enter on same song (paused) | **Resume** ✓ |

### 1.2 Visual Feedback

Queue pane should show:
- **Playing indicator** (▶) on currently playing song
- **Paused indicator** (⏸) when paused
- **Buffering indicator** (◌) when loading
- **Primed indicator** (●) for songs with audio cached

### 1.3 On-Focus Priming

When user navigates queue (cursor moves), immediately start priming the focused song:

```
User scrolls to song 15:
  → Cursor on song 15 (not pressed Enter yet)
  → Background: Start buffering song 15
  → User presses Enter 500ms later
  → Song 15 already partially buffered
  → Faster playback start
```

---

## Part 2: Playback Service Redesign

### 2.1 Current Architecture (Problems)

```
YouTubeServer
  ├── QueueService (manages song list)
  ├── PlaybackService (MPV interaction)
  │     └── StreamExtractor (URL resolution)
  └── ApiService (YouTube API)
```

**Problems:**
- `PlaybackService` name doesn't reflect prefetching responsibility
- No separation between URL resolution and audio buffering
- Toggle logic missing
- MPV playlist management buried in server

### 2.2 New Architecture

```
YouTubeServer (thin router)
  │
  ├── QueueService (song list + metadata)
  │     └── Emits: QueueChanged, SongAdded events
  │
  ├── StreamResolver (URL resolution)  ← RENAMED from StreamExtractor
  │     ├── YtxExtractor
  │     ├── YtDlpExtractor
  │     ├── CachedExtractor (2hr TTL)
  │     └── FallbackExtractor
  │
  ├── AudioPrefetcher (NEW - audio data caching)
  │     ├── Listens to QueueChanged events
  │     ├── Downloads first 10s of audio
  │     └── Manages disk cache
  │
  ├── PlaybackController (NEW - orchestrates playback)  ← RENAMED/REFACTORED
  │     ├── play_or_toggle(song_id)
  │     ├── jump_to_song(song_id)
  │     ├── Manages MPV hot window
  │     └── Handles on-focus priming
  │
  └── AudioPlayer (trait abstraction for MPV)
        ├── append_track(url)
        ├── clear_buffer()
        ├── toggle_pause()
        └── seek(position)
```

### 2.3 Component Responsibilities

| Component | Single Responsibility |
|-----------|----------------------|
| `QueueService` | Song list management, metadata, events |
| `StreamResolver` | video_id → stream_url (cached, bulk) |
| `AudioPrefetcher` | stream_url → cached audio data (first 10s) |
| `PlaybackController` | Orchestrate playback, toggle, window management |
| `AudioPlayer` | Abstract interface to audio backend (MPV) |

### 2.4 Naming Changes

| Old Name | New Name | Reason |
|----------|----------|--------|
| `StreamExtractor` | `StreamResolver` | "Resolve" is clearer than "Extract" |
| `PlaybackService` | `PlaybackController` | "Controller" implies orchestration |
| `playlist_clear()` | `player.clear_buffer()` | Clarify it's player buffer, not queue |
| `playlist_append()` | `player.append_track()` | Clearer intent |
| `play_position()` | `jump_to_position()` | Clarify it's a jump/seek |

---

## Part 3: Prefetch Logic

### 3.1 Two-Layer Prefetch

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: URL RESOLUTION                          │
│                                                                      │
│  Trigger: Song added to queue                                       │
│  Action:  ytx --bulk to resolve stream URLs                         │
│  Cache:   CachedExtractor (2hr TTL, LRU)                           │
│  Result:  video_id → stream_url (instant lookup)                   │
│                                                                      │
│  Status: ✅ ALREADY IMPLEMENTED                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: AUDIO DATA PREFETCH                     │
│                                                                      │
│  Trigger: Song URL resolved (Layer 1 complete)                      │
│  Action:  HTTP Range request for first 10s of audio                │
│  Cache:   Disk cache (~240KB per song)                             │
│  Result:  Instant playback start for any song in queue             │
│                                                                      │
│  Status: 🆕 NEW - TO BE IMPLEMENTED                                │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Audio Prefetch Flow

```
Song added to queue
       │
       ▼
┌──────────────────┐
│ StreamResolver   │
│ (ytx --bulk)     │
└────────┬─────────┘
         │ stream_url + bitrate
         ▼
┌──────────────────┐
│ AudioPrefetcher  │
│                  │
│ 1. Calculate:    │
│    bytes = (bitrate/8) * 10s * 1.2  │
│                  │
│ 2. HTTP Request: │
│    Range: bytes=0-{bytes}           │
│                  │
│ 3. Save to:      │
│    ~/.cache/rmpc/audio/{video_id}   │
└────────┬─────────┘
         │
         ▼
   Cache ready
   (song.audio_cached = true)
```

### 3.3 Playback with EDL (Seamless Continuation)

When playing a song with cached audio:

```rust
// Instead of direct URL:
mpv.loadfile("https://youtube-stream-url");

// Use EDL for seamless local→remote transition:
let edl = format!(
    "edl://{},0,10;{},10,",
    cache_path,      // Local: first 10s
    stream_url       // Remote: from 10s onward
);
mpv.loadfile(&edl);
```

**Result:**
- 0-10s: Plays from local cache (INSTANT)
- 10s+: Seamlessly continues from network
- User perceives: Instant playback

### 3.4 Hot Window Management

Maintain 5-10 songs buffered in MPV for gapless playback:

```
Queue:        [A, B, C, D, E, F, G, H, I, J]
                  ^current

MPV Buffer:   [B*, C*, D*, E*, F*]
               ^playing

* = EDL with cached audio (instant start)

Song B ends → Gapless transition to C (already in MPV)
            → Slide window: add G to MPV buffer
            → MPV Buffer: [C*, D*, E*, F*, G*]
```

---

## Part 4: Implementation Phases

### Phase 1: Toggle Logic (P0 - Critical UX)
**Effort:** 1-2 hours

1. Add `is_current_song(video_id)` check to PlaybackService
2. Implement `play_or_toggle()` method
3. Update Queue pane Enter handler
4. Update Search pane Enter handler

```rust
fn play_or_toggle(&self, video_id: &str) -> Result<()> {
    if self.is_current_song(video_id) {
        self.player.toggle_pause()
    } else {
        self.jump_to_song(video_id)
    }
}
```

### Phase 2: Rename & Restructure (P1 - Clarity)
**Effort:** 2-3 hours

1. Rename `StreamExtractor` → `StreamResolver`
2. Rename `PlaybackService` → `PlaybackController`
3. Extract `AudioPlayer` trait
4. Update all call sites

### Phase 3: Audio Prefetcher (P2 - Performance)
**Effort:** 4-6 hours

1. Create `AudioPrefetcher` struct
2. Implement HTTP Range download
3. Implement disk cache management
4. Wire to queue add events

```rust
struct AudioPrefetcher {
    cache_dir: PathBuf,
    http_client: reqwest::Client,
    prefetch_seconds: f64,  // 10.0
}

impl AudioPrefetcher {
    async fn prefetch(&self, song: &Song) -> Result<PathBuf>;
    fn get_edl_url(&self, song: &Song) -> String;
    fn cleanup_old_cache(&self);
}
```

### Phase 4: Hot Window + EDL (P3 - Gapless)
**Effort:** 3-4 hours

1. Implement hot window manager
2. Generate EDL URLs for cached songs
3. Slide window on track advance
4. Handle jump outside window

### Phase 5: On-Focus Priming (P4 - Polish)
**Effort:** 1-2 hours

1. Add `on_selection_changed` to Queue pane
2. Send prime request to daemon
3. Add primed song to hot candidate slot

### Phase 6: Visual Feedback (P5 - Polish)
**Effort:** 2-3 hours

1. Add play/pause/buffering icons to queue
2. Show cache status indicator
3. Update status bar with buffer info

---

## Part 5: File Changes

### New Files
| File | Purpose |
|------|---------|
| `src/player/youtube/audio_prefetcher.rs` | Audio data caching |
| `src/player/youtube/audio_player.rs` | Player trait abstraction |
| `src/player/youtube/playback_controller.rs` | Playback orchestration |

### Modified Files
| File | Changes |
|------|---------|
| `src/player/youtube/stream.rs` | Rename to stream_resolver.rs |
| `src/player/youtube/services/playback_service.rs` | Refactor → controller |
| `src/player/youtube/server.rs` | Thin router, delegate to controller |
| `src/ui/panes/queue_pane_v2.rs` | Toggle logic, on-focus priming |
| `src/ui/panes/search/mod.rs` | Toggle logic |

### Deleted Files
| File | Reason |
|------|--------|
| `src/player/youtube/services/playback_service.rs` | Replaced by controller |

---

## Part 6: Data Flow Diagrams

### 6.1 Song Added to Queue

```
User adds song
       │
       ▼
┌──────────────┐     QueueChanged event
│ QueueService │ ─────────────────────────┐
└──────────────┘                          │
                                          ▼
                               ┌────────────────────┐
                               │  StreamResolver    │
                               │  (ytx --bulk)      │
                               └─────────┬──────────┘
                                         │ URL resolved
                                         ▼
                               ┌────────────────────┐
                               │  AudioPrefetcher   │
                               │  (HTTP Range 10s)  │
                               └─────────┬──────────┘
                                         │ Audio cached
                                         ▼
                               ┌────────────────────┐
                               │  Update song:      │
                               │  - stream_url ✓    │
                               │  - audio_cached ✓  │
                               └────────────────────┘
```

### 6.2 User Presses Enter

```
Enter on song X
       │
       ▼
┌──────────────────────────────────────────────────┐
│              PlaybackController                   │
│                                                   │
│  if X == current_song:                           │
│      player.toggle_pause()                       │
│  else:                                           │
│      jump_to_song(X)                             │
└──────────────────────────────────────────────────┘
       │
       ▼ (if jump)
┌──────────────────────────────────────────────────┐
│              jump_to_song(X)                      │
│                                                   │
│  1. Check if X in hot window:                    │
│     → YES: player.play_index(X_index)            │
│     → NO:  rebuild_window(X)                     │
│                                                   │
│  2. rebuild_window(X):                           │
│     - player.clear_buffer()                      │
│     - For songs X to X+5:                        │
│       - Get EDL URL (cached + remote)            │
│       - player.append_track(edl_url)             │
│     - player.play_index(0)                       │
└──────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│                    MPV                            │
│                                                   │
│  Plays EDL:                                      │
│  - 0-10s: From local cache (INSTANT)             │
│  - 10s+:  From network (seamless)                │
└──────────────────────────────────────────────────┘
```

### 6.3 Song Ends (Auto-Advance)

```
Song B ends
       │
       ▼
┌──────────────────────────────────────────────────┐
│         PlaybackController.on_track_end()         │
│                                                   │
│  1. Update queue.current_index++                 │
│                                                   │
│  2. Slide hot window:                            │
│     - Remove B from MPV buffer                   │
│     - Append next song (G) to MPV buffer         │
│                                                   │
│  3. Update MPRIS metadata                        │
│                                                   │
│  MPV auto-advances to C (already buffered)       │
│  = GAPLESS TRANSITION                            │
└──────────────────────────────────────────────────┘
```

---

## Part 7: Success Criteria

| Metric | Before | After |
|--------|--------|-------|
| Play song in queue | 0.5-1s | <100ms |
| Toggle same song | Restarts | Pause/Resume |
| Gapless transitions | Sometimes gaps | Always gapless |
| Jump to distant song | 0.5-1s | <300ms |
| Code clarity | Confusing names | Clear names |

---

## Part 8: Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| YouTube Range request fails | Fallback to direct URL (current behavior) |
| EDL format changes in MPV | Test with multiple MPV versions |
| Disk cache grows too large | LRU eviction, max 500MB |
| URL expires mid-cache | Re-resolve on play failure |
| HTTP prefetch slows network | Rate limit to 2 concurrent downloads |

---

## Part 9: Testing Plan

### Unit Tests
- `StreamResolver::get_urls()` batch resolution
- `AudioPrefetcher::calculate_bytes()` duration→bytes
- `PlaybackController::play_or_toggle()` toggle logic

### Integration Tests
- Queue add → URL resolved → audio prefetched
- Enter on same song → pause/resume
- Jump outside window → rebuild + play

### Manual Tests
- Play through 10-song queue (gapless)
- Jump to song 50 (acceptable delay)
- Toggle pause on playing song
- Network disconnect during playback

---

## Appendix: EDL Reference

MPV EDL format for seamless local→remote:

```
# Syntax: file,start_time,duration
# Empty duration = rest of file

# Example: Play 10s from cache, then continue from network at 10s
edl:///tmp/cache/abc123.opus,0,10;https://youtube-url,10,
```

---

## Approval

- [ ] Design approved
- [ ] Phase breakdown approved
- [ ] Ready to implement

