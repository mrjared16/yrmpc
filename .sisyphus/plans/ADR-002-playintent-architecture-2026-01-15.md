# ADR-002: PlayIntent Architecture for Low-Latency Playback

**Status**: Final Draft

**Date**: 2026-01-15 (supersedes 2026-01-14 draft)

**Owner**: (TBD)

**Audience**: rmpc contributors (daemon + TUI + backend)

---

## 0. Executive Summary

This ADR proposes a **PlayIntent-based architecture** to solve the "Play Album takes 5-25 seconds" problem:

1. **Single IPC command** (`ServerCommand::Play { intent, request_id }`) replaces composed command sequences
2. **PlayIntent enum** expresses user intent declaratively: Context, Next, Append, Radio
3. **Three-stage preparation pipeline** with explicit priority tiers
4. **Request-scoped cancellation** prevents stale work accumulation
5. **Configurable passthrough deadline** balances instant audio vs seek capability

**Key insight**: Intent belongs at the IPC boundary. The daemon derives preparation priorities from intent type, not from observing command sequences.

---

## 1. Problem Statement

### 1.1 What Users Experience

| Scenario | Current Latency | Target |
|----------|-----------------|--------|
| Play single song from search | 1-3s | <500ms |
| Play album (50 songs) | 5-25s | <500ms |
| Skip to next track | 0-3s | <200ms (cached) |
| Seek within song | Works only sometimes | Always (when prefix cached) |

### 1.2 Root Cause

The TUI sends composed commands:
```
clear_queue() → add_songs([50 songs]) → play_pos(0)
```

The daemon processes these sequentially, blocking on URL extraction for each song in the "prefetch window" before `play_pos(0)` ever runs.

**Intent is lost**: The daemon doesn't know that song[0] is Immediate priority while songs[1..50] are Background.

### 1.3 Previous Approach (Why It Failed)

The `CachedExtractor` implements `request_one()` vs `request_batch()` to guess urgency. This creates:
- Race conditions (fast path vs batch compete for same track)
- Complex OnceLock/in_flight deduplication logic
- Heuristics that fail edge cases

---

## 2. Design Decisions

### 2.1 User Answers (from consultation)

| Question | Decision |
|----------|----------|
| Shuffle model | Boolean (YAGNI, extend later if needed) |
| ContextSource | Optional metadata (for analytics/resume, daemon ignores) |
| Radio support | Include now (lazy fetch, auto-extend queue) |
| Next vs Append | Separate intents (clearer semantics, different priorities) |
| Next priority | First=Gapless, rest=Eager |
| Request ID | TUI generates (enables client-side cancellation) |
| Error handling | Daemon validates, returns Result |
| Passthrough deadline | Configurable (default 200ms) |

### 2.2 IPC Command

```rust
/// Single command for all playback intents.
/// Replaces: AddSong, AddSongs + PlayPosition composition.
pub enum ServerCommand {
    // ... existing commands ...
    
    /// Start playback with explicit intent.
    Play {
        intent: PlayIntent,
        request_id: RequestId,
    },
    
    /// Cancel pending preparation work for a request.
    CancelRequest {
        request_id: RequestId,
    },
}

pub type RequestId = Uuid;
```

### 2.3 PlayIntent Enum

```rust
/// Declarative user intent for playback.
pub enum PlayIntent {
    /// Replace current context and start playing.
    /// Priority: tracks[offset]=Immediate, tracks[offset+1]=Gapless, rest=Background
    Context {
        tracks: Vec<Song>,
        offset: usize,
        shuffle: bool,
        source: Option<ContextSource>,
    },
    
    /// Insert tracks to play after current song ends.
    /// Priority: tracks[0]=Gapless, rest=Eager
    Next {
        tracks: Vec<Song>,
    },
    
    /// Append tracks to end of queue.
    /// Priority: all=Background
    Append {
        tracks: Vec<Song>,
    },
    
    /// Start infinite radio from seed track.
    /// Priority: seed=Immediate, lazy-fetched tracks=Background
    Radio {
        seed: Song,
        mix_type: MixType,
    },
}

/// Optional context for analytics/resume (daemon ignores).
pub enum ContextSource {
    Album { album_id: String },
    Playlist { playlist_id: String },
    Artist { artist_id: String },
    Search { query: String },
    History,
    Queue,
}

pub enum MixType {
    SongRadio,      // Similar to this song
    ArtistRadio,    // More from this artist
    GenreRadio,     // More from this genre
}
```

### 2.4 Validation Errors

```rust
pub enum PlayError {
    EmptyTracks,
    InvalidOffset { offset: usize, len: usize },
    RadioSeedInvalid,
}
```

---

## 3. Architecture

### 3.1 Component Overview

```
TUI                          IPC                         DAEMON
───                         ─────                        ──────

QueueStore                   Play { intent,              handle_play()
    │                        request_id }                    │
    └─► play(intent) ────────────────────────────────────────┤
                                                             │
                                                             ▼
                                                    ┌────────────────────┐
                                                    │ Validate & Derive  │
                                                    │ - Check tracks/offset
                                                    │ - Cancel prev request
                                                    │ - Derive priorities │
                                                    └─────────┬──────────┘
                                                              │
                              ┌────────────────────────────────┼────────────────────────────────┐
                              │                               │                                │
                              ▼                               ▼                                ▼
                    ┌─────────────────┐             ┌─────────────────┐              ┌─────────────────┐
                    │ Queue Mutation  │             │ PreloadScheduler│              │ Playback        │
                    │                 │             │                 │              │                 │
                    │ queue.replace() │             │ submit(tier, id)│              │ player.play()   │
                    │ queue.insert()  │             │ dedup/escalate  │              │                 │
                    │ queue.append()  │             │ lane dispatch   │              │                 │
                    └─────────────────┘             └────────┬────────┘              └─────────────────┘
                                                             │
                                                             ▼
                                                    ┌────────────────────┐
                                                    │ Preparer (async)   │
                                                    │                    │
                                                    │ StreamUrlResolver  │
                                                    │ PrefixCache        │
                                                    │ MpvInputBuilder    │
                                                    └────────────────────┘
```

### 3.2 Priority Derivation (Pure Function)

```rust
fn derive_priorities(intent: &PlayIntent) -> Vec<(Song, PreloadTier)> {
    match intent {
        PlayIntent::Context { tracks, offset, shuffle, .. } => {
            let ordered = if *shuffle { shuffle_tracks(tracks) } else { tracks.clone() };
            ordered.iter().enumerate().map(|(i, song)| {
                let tier = match i.saturating_sub(*offset) {
                    0 => PreloadTier::Immediate,
                    1 => PreloadTier::Gapless,
                    _ => PreloadTier::Background,
                };
                (song.clone(), tier)
            }).collect()
        }
        
        PlayIntent::Next { tracks } => {
            tracks.iter().enumerate().map(|(i, song)| {
                let tier = if i == 0 { PreloadTier::Gapless } else { PreloadTier::Eager };
                (song.clone(), tier)
            }).collect()
        }
        
        PlayIntent::Append { tracks } => {
            tracks.iter().map(|s| (s.clone(), PreloadTier::Background)).collect()
        }
        
        PlayIntent::Radio { seed, .. } => {
            vec![(seed.clone(), PreloadTier::Immediate)]
            // Additional tracks fetched lazily
        }
    }
}
```

### 3.3 PreloadTier Definition

```rust
/// Priority tier for preload work.
/// Ordered by urgency: Immediate > Gapless > Eager > Background.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum PreloadTier {
    /// User is actively waiting. Never wait for prefix.
    Immediate,
    
    /// Next track for gapless transition. Wait for prefix.
    Gapless,
    
    /// Likely needed soon (visible queue, hover preview).
    Eager,
    
    /// Opportunistic. Fill idle bandwidth.
    Background,
}
```

### 3.4 Three-Stage Preparation Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     PREPARATION PIPELINE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Stage 1: StreamUrlResolver                                            │
│   ──────────────────────────────                                        │
│   Input:  track_id (stable, e.g., YouTube video_id)                     │
│   Output: StreamUrl { url, itag, expires_at }                           │
│   Cache:  UrlCache (in-memory, TTL ~5 hours)                            │
│   Latency: 100-500ms (network) or <1ms (cached)                         │
│                                                                         │
│   Stage 2: PrefixCache                                                  │
│   ─────────────────────                                                 │
│   Input:  (track_id, itag) ← stable key, survives URL expiry            │
│   Output: PrefixState { Cached(path) | NotCached | Downloading }        │
│   Cache:  Disk files (~2MB each), LRU eviction, ~1GB cap                │
│   Latency: 1-3s (download) or <1ms (cached)                             │
│                                                                         │
│   Stage 3: MpvInputBuilder                                              │
│   ──────────────────────────                                            │
│   Input:  (url, PrefixState, tier)                                      │
│   Output: MpvInput { Concat(prefix_path, url) | Passthrough(url) }      │
│   Logic:  Pure function, no IO                                          │
│                                                                         │
│   Decision Matrix:                                                      │
│   ┌────────────┬─────────────┬──────────────────────────────────┐       │
│   │ Tier       │ PrefixState │ Decision                         │       │
│   ├────────────┼─────────────┼──────────────────────────────────┤       │
│   │ Immediate  │ Cached      │ Concat (best quality)            │       │
│   │ Immediate  │ NotCached   │ Passthrough (instant audio)      │       │
│   │ Immediate  │ Downloading │ Wait up to deadline, then pass.  │       │
│   │ Gapless    │ Any         │ Wait for prefix (no time pressure)│      │
│   │ Eager      │ Any         │ Wait for prefix                  │       │
│   │ Background │ Any         │ Wait for prefix                  │       │
│   └────────────┴─────────────┴──────────────────────────────────┘       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.5 Passthrough Deadline (Configurable)

```rust
/// Config for playback preparation.
pub struct PreparerConfig {
    /// Max time to wait for prefix before falling back to passthrough.
    /// Only applies to Immediate tier.
    /// Default: 200ms
    pub passthrough_deadline_ms: u64,
}
```

When tier=Immediate and prefix is downloading:
1. Wait up to `passthrough_deadline_ms` for prefix to complete
2. If prefix ready within deadline → use Concat (seekable, gapless-ready)
3. If deadline exceeded → use Passthrough (instant audio, no seek)
4. Background continues downloading prefix (benefits future seeks/gapless)

### 3.6 Request Cancellation

```rust
impl PreloadScheduler {
    /// Cancel all pending work for a request.
    /// Called when user starts a new Context (supersedes previous).
    pub fn cancel_request(&self, request_id: RequestId) {
        // Remove pending jobs for this request
        // In-flight downloads continue (may benefit cache)
        // But no new work starts for this request
    }
}
```

---

## 4. Handler Implementation

### 4.1 Main Handler

```rust
async fn handle_play(
    intent: PlayIntent,
    request_id: RequestId,
    ctx: &mut DaemonContext,
) -> Result<(), PlayError> {
    // 1. Validate
    validate_intent(&intent)?;
    
    // 2. Cancel previous context (if starting new Context/Radio)
    if matches!(intent, PlayIntent::Context { .. } | PlayIntent::Radio { .. }) {
        ctx.scheduler.cancel_request(ctx.current_request_id);
        ctx.current_request_id = request_id;
    }
    
    // 3. Mutate queue (fast, no network)
    match &intent {
        PlayIntent::Context { tracks, shuffle, .. } => {
            let ordered = if *shuffle { shuffle_tracks(tracks) } else { tracks.clone() };
            ctx.queue.replace(ordered);
        }
        PlayIntent::Next { tracks } => {
            ctx.queue.insert_after_current(tracks.clone());
        }
        PlayIntent::Append { tracks } => {
            ctx.queue.append(tracks.clone());
        }
        PlayIntent::Radio { seed, mix_type } => {
            ctx.queue.replace(vec![seed.clone()]);
            ctx.queue.set_auto_extend(*mix_type);
        }
    }
    
    // 4. Submit preload requests (async, returns immediately)
    let priorities = derive_priorities(&intent);
    for (song, tier) in priorities {
        ctx.scheduler.submit(PreloadRequest {
            track_id: song.id.clone(),
            tier,
            request_id,
        });
    }
    
    // 5. Start playback (non-blocking)
    let start_pos = match &intent {
        PlayIntent::Context { offset, .. } => *offset,
        PlayIntent::Radio { .. } => 0,
        _ => return Ok(()), // Next/Append don't start playback
    };
    
    ctx.player.play_pos(start_pos);
    
    // 6. Metrics
    ctx.metrics.record_play_intent(request_id, &intent);
    
    Ok(())
}
```

### 4.2 Radio Auto-Extend

```rust
impl Queue {
    /// Enable auto-extend for radio mode.
    /// When queue is nearly depleted, fetch more related tracks.
    pub fn set_auto_extend(&mut self, mix_type: MixType) {
        self.auto_extend = Some(AutoExtend {
            mix_type,
            threshold: 3, // Fetch more when 3 tracks remaining
        });
    }
    
    /// Called when track changes. May trigger lazy fetch.
    pub async fn on_track_change(&mut self, current_pos: usize) {
        if let Some(auto) = &self.auto_extend {
            let remaining = self.len() - current_pos;
            if remaining <= auto.threshold {
                // Fetch more tracks in background
                let more = self.fetch_radio_tracks(auto.mix_type).await;
                self.append(more);
            }
        }
    }
}
```

---

## 5. TUI Integration

### 5.1 QueueStore Changes

```rust
impl QueueStore {
    /// Unified play method using PlayIntent.
    pub fn play(&self, intent: PlayIntent) {
        let request_id = Uuid::new_v4();
        
        // Optimistic local update
        match &intent {
            PlayIntent::Context { tracks, offset, shuffle, .. } => {
                let ordered = if *shuffle { shuffle(tracks) } else { tracks.clone() };
                self.local.replace(ordered);
                self.local.set_current(*offset);
            }
            PlayIntent::Next { tracks } => {
                self.local.insert_after_current(tracks.clone());
            }
            PlayIntent::Append { tracks } => {
                self.local.append(tracks.clone());
            }
            PlayIntent::Radio { seed, .. } => {
                self.local.replace(vec![seed.clone()]);
            }
        }
        
        // Fire-and-forget to daemon
        self.daemon.send(ServerCommand::Play { intent, request_id });
    }
}
```

### 5.2 Example TUI Usages

```rust
// search_pane.rs: Play single song
fn play_song(&self, song: Song) {
    self.queue_store.play(PlayIntent::Context {
        tracks: vec![song],
        offset: 0,
        shuffle: false,
        source: Some(ContextSource::Search { query: self.query.clone() }),
    });
}

// album_pane.rs: Play album from track
fn play_album(&self, album: &Album, start_track: usize) {
    self.queue_store.play(PlayIntent::Context {
        tracks: album.songs.clone(),
        offset: start_track,
        shuffle: false,
        source: Some(ContextSource::Album { album_id: album.id.clone() }),
    });
}

// album_pane.rs: Shuffle album
fn shuffle_album(&self, album: &Album) {
    self.queue_store.play(PlayIntent::Context {
        tracks: album.songs.clone(),
        offset: 0,
        shuffle: true,
        source: Some(ContextSource::Album { album_id: album.id.clone() }),
    });
}

// context_menu.rs: Play next
fn play_next(&self, song: Song) {
    self.queue_store.play(PlayIntent::Next { tracks: vec![song] });
}

// context_menu.rs: Add to queue
fn add_to_queue(&self, song: Song) {
    self.queue_store.play(PlayIntent::Append { tracks: vec![song] });
}

// song_pane.rs: Start radio
fn start_radio(&self, song: Song) {
    self.queue_store.play(PlayIntent::Radio {
        seed: song,
        mix_type: MixType::SongRadio,
    });
}
```

---

## 6. Observability

### 6.1 SLI: Time to First Audio

```rust
// Start timer when intent received
ctx.metrics.record_play_intent(request_id, &intent);

// Stop timer when MPV reports playback started
ctx.metrics.record_first_audio(request_id);

// SLI: p50 < 500ms, p99 < 1500ms
```

### 6.2 Logging

```rust
tracing::info!(
    request_id = %request_id,
    intent_type = ?intent.variant_name(),
    track_count = intent.track_count(),
    "Play intent received"
);

tracing::debug!(
    request_id = %request_id,
    track_id = %track_id,
    tier = ?tier,
    "Preload submitted"
);

tracing::info!(
    request_id = %request_id,
    elapsed_ms = elapsed.as_millis(),
    input_type = ?input.variant_name(),
    "First audio started"
);
```

---

## 7. Migration Plan

### 7.1 Phase 1: Add New Command (Backward Compatible)

1. Add `ServerCommand::Play { intent, request_id }`
2. Add `PlayIntent` enum
3. Implement `handle_play()` handler
4. Keep old commands working

### 7.2 Phase 2: Migrate TUI

1. Update `QueueStore.play()` to use new command
2. Update panes to call `play(PlayIntent::...)`
3. Remove direct calls to `add_and_play()`, etc.

### 7.3 Phase 3: Deprecate Old Commands

1. Mark old composed commands as deprecated
2. Log warnings when used
3. Eventually remove

---

## 8. Appendix: Full Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              PLAY ALBUM FLOW (50 songs)                                 │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│   T=0ms     User clicks "Play Album"                                                    │
│             │                                                                           │
│             └─► TUI: queue_store.play(PlayIntent::Context {                             │
│                     tracks: [s1..s50], offset: 0, shuffle: false                        │
│                 })                                                                      │
│                 │                                                                       │
│                 ├─► Optimistic: local.replace([s1..s50])  [instant]                     │
│                 └─► daemon.send(Play { intent, request_id })  [fire-and-forget]         │
│                                                                                         │
│   T=1ms     Daemon receives Play command                                                │
│             │                                                                           │
│             ├─► Validate: tracks.len() > 0, offset < len  [instant]                     │
│             ├─► Cancel previous request                    [instant]                    │
│             ├─► queue.replace([s1..s50])                   [instant]                    │
│             │                                                                           │
│             ├─► scheduler.submit(Immediate, s1)            [instant]                    │
│             ├─► scheduler.submit(Gapless, s2)              [instant]                    │
│             ├─► scheduler.submit_batch(Background, s3..s50)[instant]                    │
│             │                                                                           │
│             └─► player.play_pos(0)                                                      │
│                     │                                                                   │
│                     └─► Preparer.prepare(s1, Immediate)                                 │
│                             │                                                           │
│   T=2ms                     ├─► StreamUrlResolver.resolve(s1.id)                        │
│                             │       │                                                   │
│                             │       └─► UrlCache: MISS → fetch from YouTube            │
│                             │                                                           │
│   T=300ms                   │   URL ready                                               │
│                             │                                                           │
│                             ├─► PrefixCache.get_if_ready(s1.id, itag)                   │
│                             │       │                                                   │
│                             │       └─► MISS                                            │
│                             │                                                           │
│                             ├─► tier=Immediate, wait up to deadline (200ms)            │
│                             │       │                                                   │
│                             │       └─► Deadline exceeded, prefix not ready            │
│                             │                                                           │
│                             ├─► MpvInputBuilder: Passthrough(url)                       │
│                             │                                                           │
│                             └─► MPV plays via direct URL                                │
│                                                                                         │
│   T=350ms   USER HEARS AUDIO                                                           │
│                                                                                         │
│   MEANWHILE (parallel, non-blocking):                                                   │
│             │                                                                           │
│             ├─► s1 prefix downloading in background (benefits future seek)             │
│             ├─► s2 preparing (Gapless tier, will wait for prefix)                      │
│             └─► s3..s50 queued in Background lane                                       │
│                                                                                         │
│   T=3s      s2 fully prepared with prefix → gapless transition ready                   │
│                                                                                         │
│   T=30s+    Background lane processes remaining songs                                   │
│             User scrolls queue → songs already cached                                   │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Decision Record

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-14 | Hook existing commands | Minimize IPC changes |
| 2026-01-15 | Switch to PlayIntent model | Intent at IPC boundary, not composed commands |
| 2026-01-15 | Include Radio | User requested; fits intent model |
| 2026-01-15 | Configurable passthrough deadline | User preference for tuning latency/seek tradeoff |
| 2026-01-15 | TUI generates request_id | Enables client-side cancellation |
| 2026-01-15 | Separate Next/Append | Different priorities, clearer semantics |
