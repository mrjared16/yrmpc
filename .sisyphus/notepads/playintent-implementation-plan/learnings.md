# Learnings - PlayIntent Implementation

## 2026-01-15 Phase 1b: TUI Migration

### Pattern: PlayIntent Usage in Context Menus
- Context menus use `ctx.queue_store().play(PlayIntent::...)` directly
- Radio uses `PlayIntent::Radio { seed, mix_type: MixType::SongRadio }`
- Log message convention: "Starting radio from seed: {}. Note: auto-extend not implemented in v1"

### Pattern: Handler Architecture
- `RadioHandler` in `rmpc/src/actions/handlers/radio.rs`
- Implements `Handler` trait with `execute()`, `priority()`, `name()`
- Returns `HandleResult::Done`, `HandleResult::Skip`, or `HandleResult::NotApplicable(&str)`

### Files Modified in Phase 1b
- `rmpc/src/core/queue_store.rs` - QueueStore.play(intent)
- `rmpc/src/ui/panes/search/mod.rs` - Search pane migration
- `rmpc/src/ui/browser.rs` - Browser context menu with Start Radio
- `rmpc/src/actions/handlers/radio.rs` - RadioHandler implementation

## 2026-01-15 Phase 1c: PreloadScheduler

### Pattern: PreloadScheduler Architecture
- Location: `rmpc/src/backends/youtube/services/preload_scheduler.rs`
- Job registry: `HashMap<(TrackId, ArtifactKind), PreloadJob>`
- 4 priority lanes: Immediate(∞), Gapless(2), Eager(1), Background(1)
- Each lane: `Lane { queue: VecDeque, pending: HashSet, semaphore: Arc<Semaphore> }`

### Pattern: Preparer Pipeline
- Location: `rmpc/src/backends/youtube/services/preparer.rs`
- Three stages: StreamUrl → AudioPrefix → MpvInput
- Tier-based wait policy: Immediate waits 200ms max, then passthrough
- Uses `tokio::time::advance` in tests (requires `test-util` feature)

### Pattern: CacheExecutor Coalescing (Core)
- Location: `rmpc/src/backends/youtube/services/cache_executor.rs`
- Single-flight per `track_id`: `HashMap<String, Arc<InFlightJob>>` with `Mutex<JobState>` + `Notify`
- `JobState` transitions: ResolvingUrl → UrlResolved → DownloadingPrefix → Completed
- Deadline policy: applies only to `PreloadTier::Immediate` (timeout returns `PrepareResult::Passthrough`)
- Concurrency gating: per-tier `Semaphore` limits (Immediate/Gapless/Eager=2, Background=1)

### Key Tokio Fix
- Added `tokio = { version = "1", features = ["test-util"] }` to `[dev-dependencies]`
- Required for `tokio::time::pause()` and `tokio::time::advance()` in tests

### Pattern: Wiring PreloadScheduler to Daemon
- YouTubeServer holds `Arc<Mutex<PreloadScheduler>>`
- `handle_play_with_intent()` takes scheduler reference
- QueueEventHandler uses `Option<Arc<Mutex<PreloadScheduler>>>`
- AudioPrefetcher deprecated with `#![deprecated]` and `#![allow(dead_code)]`

### Files Modified in Phase 1c
- `rmpc/src/backends/youtube/services/preload_scheduler.rs` - NEW
- `rmpc/src/backends/youtube/services/preparer.rs` - NEW
- `rmpc/src/backends/youtube/services/mod.rs` - exports
- `rmpc/src/backends/youtube/server/mod.rs` - wiring
- `rmpc/src/backends/youtube/server/handlers/play_intent.rs` - scheduler usage
- `rmpc/src/backends/youtube/server/handlers/queue_events.rs` - scheduler usage
- `rmpc/src/backends/youtube/services/audio_prefetcher.rs` - DEPRECATED
- `rmpc/tests/play_intent_integration_tests.rs` - latency tests

## 2026-01-15 Phase 4: Documentation

### Updated Docs
- `docs/adr/ADR-002-playintent-architecture-2026-01-15.md` - NEW ADR
- `docs/ARCHITECTURE.md` - PlayIntent command pattern section
- `docs/arch/playback-engine.md` - PreloadScheduler, priority tiers
- `docs/arch/playback-flow.md` - Intent-based flow diagram
- `docs/arch/audio-streaming.md` - Passthrough/concat decision
- `docs/arch/play-queue.md` - Queue mutation semantics
- `docs/features/playback.md` - Radio, Play Next, Add to Queue
- `docs/backends/youtube/README.md` - Handler, protocol updates
- `docs/INDEX.md` - ADR link
- `MEMORY.md` - PlayIntent patterns section

## Blockers

### Manual Testing Required
- Play album latency tests require human interaction
- Cannot automate: starting daemon, playing albums, measuring time-to-audio
- Marked as [BLOCKED: requires human] in plan file

## 2026-01-15 Bug Fix: Tokio Runtime in Orchestrator

### Bug: "No tokio runtime available for cache download"

**Root Cause**: `FfmpegConcatSource.build_mpv_input()` called `Handle::try_current()` to get a tokio runtime handle. But the orchestrator runs on a **std::thread** (not a tokio task), so there was no runtime available on that thread.

**Call chain**:
1. `orchestrator::play_position()` - runs on std::thread
2. → `playback.build_playback_url(video_id)`
3. → `playback_service.build_mpv_input()`
4. → `FfmpegConcatSource.build_mpv_input()`
5. → `Handle::try_current()` - FAILS!

**Fix**: Store the tokio runtime handle at construction time in `FfmpegConcatSource`:
```rust
// Before (broken):
impl MpvAudioSource for FfmpegConcatSource {
    fn build_mpv_input(&mut self, video_id: &str) -> Result<MpvInput> {
        let handle = Handle::try_current().context("No tokio runtime")?;  // FAILS on std::thread
        handle.block_on(self.cache.ensure_prefix(...))?;
    }
}

// After (fixed):
pub struct FfmpegConcatSource {
    cache: Arc<AudioCache>,
    resolve_url: UrlResolver,
    runtime_handle: Handle,  // Store at construction
}

impl FfmpegConcatSource {
    pub fn new(cache: Arc<AudioCache>, resolve_url: UrlResolver) -> Self {
        let runtime_handle = Handle::try_current().unwrap_or_else(|_| {
            tokio::runtime::Runtime::new().expect("...").handle().clone()
        });
        Self { cache, resolve_url, runtime_handle }
    }
}

impl MpvAudioSource for FfmpegConcatSource {
    fn build_mpv_input(&mut self, video_id: &str) -> Result<MpvInput> {
        self.runtime_handle.block_on(self.cache.ensure_prefix(...))?;  // Uses stored handle
    }
}
```

**Lesson**: When code will be called from non-tokio threads (std::thread, crossbeam, etc.), capture the runtime handle at construction time, not at call time.

## 2026-01-15 Bug Fix: MPV Protocol Whitelist Not Passed

### Bug: "Cannot open file 'concat:...: No such file or directory"

**Symptoms**:
- MPV receives concat URL but fails immediately with EndFile { reason: "error" }
- MPV debug log shows it's trying to open concat URL as literal file path
- Cache file exists and is valid (correct WebM header)

**Root Cause**: `play_with_input()` in `playback_service.rs` was ignoring `MpvInput.mpv_args`:

```rust
// Before (broken):
pub fn play_with_input(&self, input: &MpvInput, ...) -> Result<()> {
    self.mpv.lock().send_command(vec!["loadfile", &input.url, "replace"])?;
    // mpv_args with protocol_whitelist option IGNORED!
}
```

**Fix**: Pass mpv_args via loadfile options parameter:

```rust
// After (fixed):
if input.mpv_args.is_empty() {
    self.mpv.lock().send_command(vec!["loadfile", &input.url, "replace"])?;
} else {
    let options = input.mpv_args.iter()
        .filter_map(|arg| arg.strip_prefix("--"))
        .collect::<Vec<_>>()
        .join(",");
    self.mpv.lock().send_command(vec!["loadfile", &input.url, "replace", "-1", &options])?;
}
```

**Lesson**: When building abstraction layers (MpvInput), ensure ALL fields are used by consumers. Tests should verify the full data flow, not just URL generation.
