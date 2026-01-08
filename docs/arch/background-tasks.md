# Background Tasks Architecture

> **Scope**: Scheduler, async patterns, thread spawning for non-blocking operations
> **Runtime**: Synchronous Rust with crossbeam channels (no tokio)

## Overview

yrmpc uses a **synchronous, thread-based** concurrency model:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Main Thread (Event Loop)                         │
│  Receives events from all sources, updates UI, dispatches actions        │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       │                       │                       │
       ▼                       ▼                       ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│  Scheduler   │      │ Work Thread  │      │ Client Thread│
│ (timed jobs) │      │ (background) │      │ (backend I/O)│
└──────────────┘      └──────────────┘      └──────────────┘
       │                       │                       │
       └───────────────────────┼───────────────────────┘
                               │
                     crossbeam channels
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Background Threads (spawned)                        │
│  - Image fetching/processing                                             │
│  - URL prefetching                                                       │
│  - Audio prefetching                                                     │
│  - MPV event loop                                                        │
│  - Ueberzug daemon                                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Scheduler

**Location**: `core/scheduler/mod.rs`

A timer-based job scheduler that fires events after delays or at intervals.

### Structure

```rust
pub struct Scheduler<T, P> {
    add_job_tx: Sender<SchedulerCommand<T>>,
    add_job_rx: Receiver<SchedulerCommand<T>>,
    handle: Option<JoinHandle<()>>,
    time_provider: P,
}

enum SchedulerCommand<T> {
    AddJob(Job<T>),
    AddRepeatedJob(RepeatedJob<T>),
    CancelJob(JobId),
    StopScheduler,
}
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `new(args)` | Create scheduler with default time provider |
| `add_job(run_at, data)` | Schedule one-shot job |
| `add_job_in(duration, data)` | Schedule job after delay |
| `add_repeated_job(interval, data)` | Schedule recurring job |
| `cancel_job(guard)` | Cancel scheduled job |
| `start()` | Start scheduler thread |

### Usage Pattern

```rust
// In main.rs
let scheduler = Scheduler::new((event_tx.clone(), client_tx.clone()));

// In Ctx - schedule a delayed action
ctx.scheduler.add_job_in(
    Duration::from_secs(5),
    (AppEvent::StatusUpdate, ClientRequest::Refresh),
);

// With cancellation guard
let guard = ctx.scheduler.add_job_in(
    Duration::from_millis(500),
    (AppEvent::DebouncedSearch, ClientRequest::Search(query)),
);
// Later...
drop(guard); // Cancels the job
```

### Current Uses

| Component | Job Type | Purpose |
|-----------|----------|---------|
| Config watcher | One-shot | Debounce config file changes |
| Status polling | Repeated | Refresh playback status |
| Search debounce | One-shot | Delay search until typing stops |
| Single mode fix | One-shot | Re-enable single after brief delay |

## Thread Spawning Patterns

### Pattern 1: Fire-and-Forget Background Work

```rust
// URL prefetching - no result needed in main thread
std::thread::spawn(move || {
    for id in video_ids {
        if let Err(e) = resolver.resolve_one(&id) {
            log::warn!("Failed to prefetch {}: {}", id, e);
        }
    }
});
```

**Used in**:
- `url_resolver.rs::prefetch()` - URL resolution
- `audio_cache.rs::prefetch_async()` - Audio chunk download
- `image_cache.rs::spawn_fetch()` - Image download

### Pattern 2: Named Thread with Event Callback

```rust
std::thread::Builder::new()
    .name("work".to_owned())
    .spawn(move || {
        // Do background work
        let result = expensive_operation();
        // Send result back to main thread
        event_tx.send(AppEvent::WorkComplete(result));
    })?;
```

**Used in**:
- `core/work.rs` - General work thread
- `core/client.rs` - Backend client thread
- `core/input.rs` - Input polling thread

### Pattern 3: Long-Running Service Thread

```rust
// MPV event loop - runs for entire session
thread::spawn(move || {
    loop {
        match mpv.wait_event(timeout) {
            Event::EndFile { .. } => {
                event_tx.send(AppEvent::TrackEnded);
            }
            Event::PropertyChange { name, value } => {
                event_tx.send(AppEvent::PropertyChanged(name, value));
            }
            Event::Shutdown => break,
        }
    }
});
```

**Used in**:
- `playback_service.rs::start_event_loop()` - MPV events
- `server/mod.rs` - YouTube backend server
- `image/ueberzug.rs` - Daemon management

### Pattern 4: Scoped Threads with Results

```rust
std::thread::scope(|s| {
    let handle = s.spawn_scoped(|| {
        // Work that needs to return a value
        compute_something()
    });
    
    // Can wait for result before scope ends
    let result = handle.join().expect("thread panicked");
});
```

**Used in**:
- `core/client.rs` - Coordinated client operations

## Prefetch System

### URL Prefetch

**Location**: `backends/youtube/url_resolver.rs`

```
Queue change detected
    │
    ▼
┌─────────────────────────────────────────┐
│ prefetch(video_ids: Vec<String>)        │
│ 1. Filter to uncached IDs               │
│ 2. spawn thread for each batch          │
│ 3. resolve_one() per ID (uses extractor)│
│ 4. Store in cache (no callback needed)  │
└─────────────────────────────────────────┘
```

### Audio Prefetch

**Location**: `backends/youtube/audio_cache.rs`

```
URL resolved for upcoming track
    │
    ▼
┌─────────────────────────────────────────┐
│ prefetch_async(video_id, stream_url)    │
│ 1. spawn thread                         │
│ 2. HTTP Range request for first N bytes │
│ 3. Write to cache file                  │
│ 4. Log success/failure (no callback)    │
└─────────────────────────────────────────┘
```

### Prefetch Window (Queue)

**Location**: `backends/youtube/services/queue_service.rs`

```rust
/// Indices currently loaded in MPV's prefetch window
prefetch_indices: Mutex<Vec<usize>>,

// Methods
fn build_prefetch_window(&self, start_idx: usize, count: usize) -> Vec<usize>
fn get_prefetched_at(&self, mpv_pos: usize) -> Option<usize>
fn extend_prefetch_window(&self) -> Option<usize>
```

## Image Processing Threads

**Location**: `ui/image/*.rs`

Each image protocol has its own background thread:

| Protocol | Thread Name | Purpose |
|----------|-------------|---------|
| Kitty | kitty | Encode and send images via Kitty protocol |
| Sixel | sixel | Convert images to Sixel format |
| iTerm2 | iterm2 | Encode images for iTerm2 |
| Ueberzug | ueberzug | Manage external daemon process |
| Block | block | Convert images to Unicode blocks |

```rust
// Pattern used by all image threads
std::thread::Builder::new()
    .name("kitty".to_owned())
    .spawn(move || {
        while let Ok(request) = rx.recv() {
            let result = process_image(request);
            result_tx.send(result);
        }
    })
    .expect("Image thread to be spawned");
```

## Error Handling in Background Threads

### Pattern: Log and Continue

```rust
std::thread::spawn(move || {
    if let Err(e) = do_background_work() {
        log::warn!("Background task failed: {}", e);
        // Don't propagate - main thread doesn't need to know
    }
});
```

### Pattern: Send Error Event

```rust
std::thread::spawn(move || {
    match do_critical_work() {
        Ok(result) => event_tx.send(AppEvent::Success(result)),
        Err(e) => event_tx.send(AppEvent::Error(e.to_string())),
    }
});
```

## Key Files

| File | Purpose |
|------|---------|
| `core/scheduler/mod.rs` | Timer-based job scheduler |
| `core/work.rs` | General background work thread |
| `core/client.rs` | Backend client thread coordination |
| `backends/youtube/url_resolver.rs` | URL prefetch spawning |
| `backends/youtube/audio_cache.rs` | Audio prefetch spawning |
| `shared/image_cache.rs` | Image fetch/process spawning |

## Debug Commands

```bash
# See thread activity
RUST_LOG=debug cargo run 2>&1 | grep -E "spawn|thread|prefetch"

# Scheduler debug output
RUST_LOG=rmpc::core::scheduler=trace cargo run

# Prefetch debug output
RUST_LOG=rmpc::backends::youtube::url_resolver=debug cargo run
RUST_LOG=rmpc::backends::youtube::audio_cache=debug cargo run
```

## Extension Points

### Adding a New Background Task

1. **Fire-and-forget** (no result needed):
   ```rust
   std::thread::spawn(move || {
       // work
   });
   ```

2. **With result callback**:
   ```rust
   let event_tx = ctx.event_tx.clone();
   std::thread::spawn(move || {
       let result = work();
       let _ = event_tx.send(AppEvent::YourEvent(result));
   });
   ```

3. **Scheduled/delayed**:
   ```rust
   ctx.scheduler.add_job_in(
       Duration::from_secs(5),
       (AppEvent::YourEvent, ClientRequest::YourRequest),
   );
   ```

## Cross-References

- [Playback Engine](./playback-engine.md) - MPV event loop, prefetch integration
- [Library Sync](./library-sync.md) - Cache refresh patterns
- [Action System](./action-system.md) - Event types sent from background threads
