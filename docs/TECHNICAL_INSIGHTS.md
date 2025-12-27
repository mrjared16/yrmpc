# Technical Insights

**Purpose**: Documented solutions to non-obvious problems encountered during development.

---

## Idle Loop Starvation (CPU Fix)

**Problem**: 146% CPU usage when idle - both `idle` and `request` threads spinning.

**Root Cause**: In `core/client.rs`, the idle loop used `continue` on timeout, preventing the client from ever being yielded to the request thread.

```rust
// BROKEN: continue restarts idle loop without yielding client
if let Some(MpdError::TimedOut(_)) = err.downcast_ref::<MpdError>() {
    continue;  // BUG: Request thread starves!
}

// FIXED: break yields client to request thread
if let Some(MpdError::TimedOut(_)) = err.downcast_ref::<MpdError>() {
    break vec![];  // Yield client, request thread can proceed
}
```

**Why This Mattered for YouTube**: MPD backend has `write_noidle()` that interrupts the socket read. YouTube backend's `write_noidle()` is a no-op, so timeout-based yielding was the ONLY way to give the request thread a turn.

**Pattern**: In dual-backend architectures, ensure timeout-based yields work even when interrupt mechanisms are no-ops.

---

## Monolithic Trait Anti-Pattern (Backend Refactor)

**Problem**: `MusicBackend` trait had 48 methods. YouTube backend implemented 10%, rest were stubs returning `unimplemented!()`.

**Symptoms**:
- YouTube development required touching massive file
- LLM agents got confused navigating the codebase
- Adding features meant modifying monolithic trait

**Solution**: Interface Segregation

```rust
// BEFORE: One massive trait
pub trait MusicBackend {
    fn play(...);      // Playback
    fn pause(...);     // Playback
    fn add_song(...);  // Queue
    fn search(...);    // Discovery
    fn sticker(...);   // MPD-specific
    // ... 40+ more methods
}

// AFTER: Focused traits
pub trait Playback { fn play(&mut self); fn pause(&mut self); fn seek(&mut self, pos: f64); }
pub trait Queue { fn add(&mut self, song: &Song); fn remove(&mut self, id: u32); }
pub trait Discovery { fn search(&self, query: &str) -> Vec<Song>; }
```

**Pattern**: When a trait has methods that some implementors can't meaningfully implement, split it by capability.

---

## MPV Playlist as Source of Truth

**Problem**: Early implementation used `loadfile replace` which destroys MPV's playlist on every song change. We manually tracked state, causing desync issues.

**Key Insight**: MPV has full playlist management we weren't using:
- `playlist-add`, `playlist-remove`, `playlist-move`, `playlist-clear`
- Event-driven updates via `observe_property`
- Built-in prefetching with `--prefetch-playlist=yes`

**Solution - Rolling Prefetch Window**:
```rust
// Instead of loading one song at a time:
mpv.loadfile(&url, "replace");  // WRONG: Destroys playlist

// Maintain a rolling window in MPV's playlist:
mpv.playlist_clear()?;
for i in 0..3 {  // Current + next 2 tracks
    let url = resolve_stream_url(&queue[pos + i])?;
    mpv.playlist_append(&url)?;
}
mpv.playlist_play_index(0)?;  // Play first in window
```

**Pattern**: Research what your dependencies can do before building abstractions on top.

---

## Reactive Event Loop vs Polling

**Problem**: No auto-advance - songs stopped after each track because we didn't know when tracks ended.

**Solution**: MPV property observation

```rust
// Register for property change notifications
mpv.observe_property(1, "playlist-pos")?;  // Track changes
mpv.observe_property(2, "pause")?;         // Pause state
mpv.observe_property(3, "idle-active")?;   // Playback ended

// Background thread processes events
while running.load(Ordering::SeqCst) {
    match mpv.read_event() {
        MpvEvent::TrackChanged { position } => handle_track_change(position),
        MpvEvent::EndFile { reason: "eof" } => handle_track_ended(),
        _ => {}
    }
}
```

**Pattern**: Prefer reactive (event-driven) over polling. It's more efficient and responsive.

---

## Composable Extractors via Decorators

**Problem**: Single `StreamExtractor` enum with sequential fallback logic was hard to extend.

**Solution**: Trait-based composition with decorators

```rust
// Core trait
pub trait Extractor: Send + Sync {
    fn extract_batch(&self, ids: &[&str]) -> Vec<Result<StreamInfo>>;
    fn clear_cache(&self) {}  // Default no-op
}

// Implementations
struct YtxExtractor;     // Fast bulk extraction
struct YtDlpExtractor;   // Reliable fallback

// Decorators
struct CachedExtractor<E: Extractor> { inner: E, cache: LruCache };
struct FallbackExtractor<P: Extractor, F: Extractor> { primary: P, fallback: F };

// Usage - compose at runtime
let extractor = FallbackExtractor::new(
    CachedExtractor::new(YtxExtractor::new(), 1000),
    YtDlpExtractor::new()
);
```

**Pattern**: Decorator pattern enables flexible feature composition without modifying core types.

---

## History-Based Shuffle

**Problem**: Shuffle mode needs "previous" to go back to the actually-previously-played song, not a random one.

**Solution**: Shuffle history stack

```rust
struct QueueService {
    shuffle_history: Vec<usize>,  // Stack of played indices
}

fn next_index(&self) -> Option<usize> {
    if self.shuffle_enabled {
        let next = self.pick_random_unplayed();
        self.shuffle_history.push(next);
        Some(next)
    } else {
        Some(self.current + 1)
    }
}

fn previous_index(&self) -> Option<usize> {
    if self.shuffle_enabled {
        self.shuffle_history.pop();  // Remove current
        self.shuffle_history.last().copied()  // Return previous
    } else {
        Some(self.current - 1)
    }
}
```

**Pattern**: Shuffle is not just random selection - it requires history for bidirectional navigation.

---

## Layered UI Architecture

**Problem**: Three different code paths for displaying lists led to duplicated key handling and inconsistent UX.

**Solution**: Single-responsibility layers

```
Layer 0: InteractiveListView  - Selection, scroll, marks, find mode
Layer 1: SectionList          - Section headers, Tab/Shift-Tab navigation
Layer 2: ContentView          - Stack management (push/pop levels)
Layer 3: Panes                - Map keys to PaneActions (ONLY)
Layer 4: Navigator            - Route actions to backend, manage pane lifecycle
```

**Key Insight**: "Pane's ONLY job is mapping keys to actions. No business logic in panes."

**Pattern**: Strict layer boundaries prevent logic duplication and make testing easier.

---

## Action Bubbling Pattern

**Problem**: How do low-level widgets communicate with high-level navigation without tight coupling?

**Solution**: Enum-based action bubbling

```rust
// Layer 0 returns
enum ListAction { Handled, Activate(usize), Delete(Vec<usize>), Passthrough }

// Layer 1 translates
enum SectionAction { Handled, Activate(Item), Delete(Vec<Item>), Passthrough }

// Layer 3 translates to
enum PaneAction { Play(Song), QueueDelete(Vec<u32>), NavigateTo(Entity) }

// Layer 4 executes
match action {
    PaneAction::Play(song) => ctx.command(|c| c.play(&song)),
    PaneAction::QueueDelete(ids) => ctx.command(|c| c.delete_ids(&ids)),
    PaneAction::NavigateTo(e) => self.navigate_to(e),
}
```

**Pattern**: Each layer translates actions to its own vocabulary. Higher layers have more context.

---

## References

- Session logs: December 2025 development sprint
- ADRs: `docs/ADR-*.md`
- Architecture: `docs/ARCHITECTURE.md`
