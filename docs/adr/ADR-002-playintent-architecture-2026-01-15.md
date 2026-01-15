# ADR-002: PlayIntent Architecture for Low-Latency Playback

**Status**: Final Draft (Rev 2 - Unified CacheExecutor)

**Date**: 2026-01-16 (supersedes 2026-01-15 draft)

**Owner**: (TBD)

**Audience**: rmpc contributors (daemon + TUI + backend)

**Revision History**:
| Date | Change |
|------|--------|
| 2026-01-14 | Initial draft: Hook existing commands |
| 2026-01-15 | Rev 1: PlayIntent model, separate PreloadScheduler + Preparer |
| 2026-01-16 | Rev 2: **Unified CacheExecutor** replaces separate scheduler/preparer |

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

### 3.0 Key Design Change: Unified CacheExecutor (Rev 2)

**Previous Design (Rev 1)**: Separate PreloadScheduler (queues jobs) + Preparer (executes preparation).
Playback path bypassed the scheduler and called UrlResolver/AudioCache directly.

**Problem**: Two paths competing for same caches → race conditions, duplicate work, coordination complexity.

**New Design (Rev 2)**: **Unified CacheExecutor** handles ALL cache work - both preload and playback.

| Aspect | Rev 1 (Two-Path) | Rev 2 (Unified) |
|--------|-----------------|-----------------|
| Playback | Calls caches directly | Submits to executor, waits for result |
| Preload | Separate scheduler + executor | Same executor, different tier |
| Coordination | CachedExtractor in_flight | Executor owns single in_flight map |
| Races | Two systems competing | One system, no races by construction |
| Deadline | In Preparer, separate from preload | In executor, applies uniformly |

### 3.1 Component Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              UNIFIED CACHE EXECUTOR                                      │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│   TUI                          IPC                              DAEMON                  │
│   ───                         ─────                             ──────                  │
│                                                                                         │
│   QueueStore                   Play { intent,                   handle_play()           │
│       │                        request_id }                         │                   │
│       └─► play(intent) ─────────────────────────────────────────────┤                   │
│                                                                     │                   │
│                                                                     ▼                   │
│                                                           ┌─────────────────────┐       │
│                                                           │ Validate & Derive   │       │
│                                                           │ - Check tracks/offset│       │
│                                                           │ - Cancel prev request│       │
│                                                           │ - Derive priorities │       │
│                                                           └──────────┬──────────┘       │
│                                                                      │                  │
│                                    ┌─────────────────────────────────┼──────────┐       │
│                                    │                                 │          │       │
│                                    ▼                                 ▼          │       │
│                          ┌─────────────────┐               ┌─────────────────┐  │       │
│                          │ Queue Mutation  │               │ CacheExecutor   │  │       │
│                          │                 │               │ (UNIFIED)       │◄─┘       │
│                          │ queue.replace() │               │                 │          │
│                          │ queue.insert()  │               │ submit(Prepare) │          │
│                          │ queue.append()  │               │ wait/deadline   │          │
│                          └─────────────────┘               │ in_flight dedup │          │
│                                                            └────────┬────────┘          │
│                                                                     │                   │
│                                             ┌───────────────────────┼───────────────┐   │
│                                             │                       │               │   │
│                                             ▼                       ▼               ▼   │
│                                    ┌──────────────┐        ┌──────────────┐ ┌───────────┐
│                                    │ UrlResolver  │        │ AudioCache   │ │ MPV       │
│                                    │ (extract)    │        │ (prefix)     │ │ (play)    │
│                                    └──────────────┘        └──────────────┘ └───────────┘
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.1.1 CacheExecutor Design

The CacheExecutor is a **single tokio task** that:
1. Receives prepare requests via channel
2. Maintains in_flight map to deduplicate/coalesce concurrent requests
3. Executes preparation with tier-appropriate deadline logic
4. Returns results via oneshot channels

#### Executor State

| Field | Type | Purpose |
|-------|------|---------|
| `rx` | `mpsc::Receiver<CacheRequest>` | Incoming requests |
| `in_flight` | `HashMap<TrackId, InFlightJob>` | Coalesce concurrent requests |
| `url_resolver` | `Arc<UrlResolver>` | Extract stream URLs |
| `audio_cache` | `Arc<AudioCache>` | Manage prefix files |
| `background_queue` | `PriorityQueue` | Pending background work |
| `permits` | `TierPermits` | Concurrency limits (2/2/2/1) |

#### Request Types

| Request | Has Response? | Description |
|---------|---------------|-------------|
| `Prepare` | Yes (oneshot) | Playback needs track NOW |
| `Preload` | No | Background hint, fire-and-forget |
| `Cancel` | No | Remove pending work for request_id |
| `Shutdown` | No | Graceful shutdown |

#### Result Types

| Result | When Returned | MPV Command |
|--------|---------------|-------------|
| `Concat { path, url, length }` | Prefix cached | `play_concat()` (gapless, seekable) |
| `Passthrough { url }` | Deadline exceeded | `play_url()` (instant, no seek) |
| `Failed(msg)` | Network/extraction error | Show error to user |

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
/// Priority tier for cache preparation work.
/// Ordered by urgency: Immediate > Gapless > Eager > Background.
/// 
/// The tier determines:
/// 1. Queue priority (higher tier = processed first)
/// 2. Concurrency limits (higher tier = more concurrent slots)
/// 3. Deadline behavior (Immediate has deadline; others wait indefinitely)
/// 4. Fallback policy (Immediate can fallback to passthrough; others cannot)
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum PreloadTier {
    /// User actively waiting for playback to start.
    /// - Deadline: 200ms (configurable)
    /// - If prefix not ready within deadline: passthrough fallback
    /// - If prefix cached: concat mode (gapless, seekable)
    /// - Concurrency: 2 concurrent requests
    Immediate,
    
    /// Next track for gapless transition.
    /// - No deadline (wait for complete preparation)
    /// - MUST produce concat mode (gapless requires byte-perfect concat)
    /// - Concurrency: 2 concurrent requests
    Gapless,
    
    /// Likely needed soon (visible queue window).
    /// - No deadline
    /// - Produces concat mode
    /// - Concurrency: 2 concurrent requests
    Eager,
    
    /// Opportunistic background preparation.
    /// - No deadline
    /// - Produces concat mode
    /// - Concurrency: 1 concurrent request (bandwidth preservation)
    Background,
}
```

#### Tier Decision Matrix (Updated)

| Tier       | Deadline | Prefix Required | Fallback Allowed | Use Case |
|------------|----------|-----------------|------------------|----------|
| Immediate  | 200ms    | No (preferred)  | Yes (passthrough)| User pressed PLAY |
| Gapless    | None     | **Yes (required)** | **No** | Next track for gapless |
| Eager      | None     | Yes | No | Queue prefetch window |
| Background | None     | Yes | No | Discovery, radio suggestions |

**Critical**: Gapless tier **must** wait for prefix. Passthrough breaks gapless because:
1. Passthrough requires new HTTP connection at track boundary
2. Network latency (50-200ms) causes audible gap
3. Concat mode is byte-perfect (no gap)

### 3.4 CacheExecutor Behavior

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     EXECUTOR PREPARATION ALGORITHM                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Request arrives: Prepare(track_id, tier, deadline)                        │
│         │                                                                   │
│         ▼                                                                   │
│   ┌─────────────────────┐                                                   │
│   │ Check in_flight map │                                                   │
│   └──────────┬──────────┘                                                   │
│              │                                                              │
│      ┌───────┴───────┐                                                      │
│      ▼               ▼                                                      │
│   FOUND           NOT FOUND                                                 │
│   (coalesce)      (start new)                                               │
│      │               │                                                      │
│      │               ├──► Add to in_flight                                  │
│      │               ├──► Stage 1: Resolve URL                              │
│      │               ├──► Stage 2: Check prefix cache                       │
│      │               │        │                                             │
│      │               │    ┌───┴───┐                                         │
│      │               │   HIT    MISS                                        │
│      │               │    │       │                                         │
│      │               │    │       ├──► Stage 3: Apply tier logic            │
│      │               │    │       │                                         │
│      │               │    │   ┌───┴───────────────────────────┐             │
│      │               │    │   │                               │             │
│      │               │    │   ▼                               ▼             │
│      │               │    │ IMMEDIATE               GAPLESS/EAGER/BACKGROUND│
│      │               │    │ (with deadline)         (wait indefinitely)     │
│      │               │    │   │                               │             │
│      │               │    │   │ timeout?                      │             │
│      │               │    │   ├─► YES: Passthrough            │             │
│      │               │    │   └─► NO:  Concat                 └──► Concat   │
│      │               │    │                                                 │
│      │               │    └──► Return Concat                                │
│      │               │                                                      │
│      └───────────────┴──► Notify waiters, remove from in_flight             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key behaviors:**

| Scenario | Behavior |
|----------|----------|
| Same track requested twice | Second request waits on first (coalescing) |
| Immediate + deadline exceeded | Return Passthrough, continue download in background |
| Gapless tier | Always wait for prefix (gapless requires byte-perfect concat) |
| Request cancelled | Remove from background queue; in-flight continues |

### 3.5 In-Flight Coalescing

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COALESCING SCENARIO                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   T=0ms   Preload submits: track "abc", tier=Background                     │
│           │                                                                 │
│           └──► Executor starts download, adds to in_flight["abc"]           │
│                                                                             │
│   T=50ms  User presses PLAY on "abc"                                        │
│           │                                                                 │
│           └──► PlaybackService: Prepare(abc, Immediate, deadline=200ms)     │
│                    │                                                        │
│                    └──► Executor: in_flight["abc"] EXISTS                   │
│                              │                                              │
│                              └──► Attach to existing job                    │
│                                   Apply deadline logic                      │
│                                                                             │
│   T=200ms Deadline reached                                                  │
│           │                                                                 │
│           ├──► If prefix ready: Return Concat (both waiters get result)     │
│           │                                                                 │
│           └──► If not ready:                                                │
│                ├──► Return Passthrough to Immediate waiter                  │
│                └──► Background waiter continues waiting                     │
│                                                                             │
│   T=500ms Download completes                                                │
│           │                                                                 │
│           └──► Background waiter receives Concat                            │
│               (cached for future gapless/seeks)                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Why this matters**: Preload work is never wasted. If playback arrives while preload is in progress, it benefits from the ongoing download rather than starting a competing one.

### 3.6 Request Cancellation

| Action | Pending Jobs | In-Flight Jobs |
|--------|--------------|----------------|
| `Cancel(request_id)` | Removed from queue | Continue (may benefit cache) |

**Rationale**: Cancellation is for resource management. In-flight downloads may still populate the cache for future use (e.g., user skips forward then back).
```

---

## 4. Handler Implementation

### 4.1 Play Intent Handler Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         handle_play(intent, request_id)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Step 1: VALIDATE                                                          │
│   ────────────────                                                          │
│   • tracks.len() > 0                                                        │
│   • offset < tracks.len() (for Context)                                     │
│   • Return PlayError if invalid                                             │
│                                                                             │
│   Step 2: CANCEL PREVIOUS (for Context/Radio only)                          │
│   ────────────────────────────────────────────────                          │
│   • Send Cancel(old_request_id) to executor                                 │
│   • Update current_request_id                                               │
│                                                                             │
│   Step 3: MUTATE QUEUE (instant, no network)                                │
│   ──────────────────────────────────────────                                │
│   │                                                                         │
│   ├─► Context: queue.replace(tracks), apply shuffle                         │
│   ├─► Next:    queue.insert_after_current(tracks)                           │
│   ├─► Append:  queue.append(tracks)                                         │
│   └─► Radio:   queue.replace([seed]), enable auto_extend                    │
│                                                                             │
│   Step 4: SUBMIT PRELOAD HINTS (fire-and-forget)                            │
│   ──────────────────────────────────────────────                            │
│   • derive_priorities(intent) → [(track, tier), ...]                        │
│   • For each: executor.send(Preload { track_id, tier, request_id })         │
│   • Returns immediately (no await)                                          │
│                                                                             │
│   Step 5: PREPARE FIRST TRACK (for Context/Radio only)                      │
│   ─────────────────────────────────────────────────────                     │
│   • executor.send(Prepare { track[offset], Immediate, deadline=200ms })     │
│   • AWAIT response (this is the blocking part)                              │
│   │                                                                         │
│   ├─► Concat:      mpv.play_concat(prefix_path, url, length)                │
│   ├─► Passthrough: mpv.play_url(url)                                        │
│   └─► Failed:      return PlayError                                         │
│                                                                             │
│   Step 6: METRICS                                                           │
│   ───────────────                                                           │
│   • record_play_intent(request_id, intent)                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Intent-to-Tier Mapping

| Intent | Track Position | Tier Assigned |
|--------|----------------|---------------|
| **Context** | `tracks[offset]` | Immediate |
| **Context** | `tracks[offset+1]` | Gapless |
| **Context** | `tracks[offset+2..]` | Background |
| **Next** | `tracks[0]` | Gapless |
| **Next** | `tracks[1..]` | Eager |
| **Append** | All | Background |
| **Radio** | Seed | Immediate |
| **Radio** | Lazy-fetched | Background |

### 4.3 PlaybackService Integration

PlaybackService no longer calls caches directly. All cache access goes through executor:

```
┌──────────────────┐         ┌──────────────────┐         ┌──────────────┐
│ PlaybackService  │────────►│  CacheExecutor   │────────►│    MPV       │
│                  │         │                  │         │              │
│ prepare_next()   │ Prepare │ • in_flight      │ Result  │ play_concat  │
│ on_track_end()   │────────►│ • deadline logic │────────►│ play_url     │
│                  │ (await) │ • coalescing     │         │              │
└──────────────────┘         └──────────────────┘         └──────────────┘
```

**Key change**: `prepare_next_track()` uses tier=Gapless (no deadline, must wait for prefix).
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
