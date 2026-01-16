# Async Patterns in yrmpc/rmpc Codebase

## PrepareResult and Result Types

### Local (yrmpc/rmpc)
- `rmpc/src/backends/youtube/services/cache_executor.rs`: `pub enum PrepareResult { Concat { prefix_path: PathBuf, stream_url: String, content_length: u64 }, Passthrough { stream_url: String }, Failed(String) }`
- Input request carries deadline: `CacheRequest::Prepare { ..., deadline: Option<Duration>, response: oneshot::Sender<PrepareResult> }`
- Used as a "prepare audio source" decision: concat cached prefix + stream vs passthrough vs failed

### External examples (GitHub)
- `amethyst/rendy`: `graph/src/node/render/mod.rs` defines `pub enum PrepareResult { DrawRecord, DrawReuse }` with doc comment "Result of draw preparation."
- `ostreedev/ostree-rs-ext` (and `bootc-dev/bootc` vendoring the same code): `lib/src/container/store.rs` defines `pub enum PrepareResult { AlreadyPresent(Box<LayeredImageState>), Ready(Box<PreparedImport>) }` with doc comment "Result of invoking ImageImporter::prepare".
- `jdx/mise`: `src/prepare/engine.rs` defines `pub struct PrepareResult { pub steps: Vec<PrepareStepResult> }` and `pub enum PrepareStepResult { Ran, WouldRun, Fresh, Skipped }` (step-by-step aggregation pattern).
- `paritytech/polkadot`: `node/core/pvf/common/src/error.rs` defines `pub type PrepareResult = Result<PrepareStats, PrepareError>;` (alias for a domain-specific result type).
- `aptos-labs/aptos-core`: `consensus/consensus-types/src/pipelined_block.rs` defines `pub type PrepareResult = (Arc<Vec<SignatureVerifiedTransaction>>, Option<u64>);` (tuple "prepare" stage output).
- `tweag/nickel`: `cli/src/input.rs` defines `pub type PrepareResult<T> = Result<T, PrepareError>;` (generic alias).
- `fluencelabs/marine`: `core/src/misc/mod.rs` defines `type PrepareResult<T> = std::result::Result<T, PrepareError>;` (generic alias).

- Extensive use of `Result<T>` throughout codebases for error handling

## Async Preparation Patterns
- Multi-stage preparation: sync work before async awaits
- Job coalescing to avoid duplicate cache downloads
- Semaphore acquisition before async operations
- Stream URL resolution before async I/O

## Deadline/Timeout Handling

### Local (yrmpc/rmpc): "deadline" = relative timeout Duration
- `CacheRequest::Prepare` carries `deadline: Option<Duration>` (not an `Instant`).
- Applies only to `PreloadTier::Immediate`: `tokio::time::timeout(deadline, wait).await`.
- Fallback behavior on timeout (or `PrepareResult::Failed(_)`): returns `PrepareResult::Passthrough { stream_url }`.
- Non-immediate tiers block until completion (no timeout).

### External examples
- `paritytech/polkadot`: has explicit preparation timeouts and a `PrepareError::TimedOut` variant; host config includes `prepare_worker_spawn_timeout: Duration` and worker logs warn when `cpu_time_elapsed > preparation_timeout`.
- General Rust deadline utilities found while searching:
  - `tokio-util` `DelayQueue` uses per-item deadlines.
  - Rust std `mpmc::Sender::send_timeout` uses `Instant::now().checked_add(timeout)` and `send_deadline`.

- `tokio::time::timeout(deadline, future).await` pattern
- Race between prefix caching and passthrough fallback
- Configurable `passthrough_deadline_ms` (default 200ms)
- Different timeout behaviors per PreloadTier

## Key Async Functions
- `prepare()` - Main preparation entry point
- `prepare_with_deadline()` - Immediate tier with timeout
- `prepare_with_prefix()` - Gapless/Eager tier with caching
- `ensure_prefix()` - Downloads and caches audio prefixes
- `wait_or_coalesce()` - Handles concurrent requests for same track

## Dependencies
- `tokio = "1"` with `features = ["full"]` - Primary async runtime
- `futures = "0.3"` in ytmapi submodule
- No other async runtimes (no async-std, etc.)

## Successful Patterns
- Racing cache downloads vs passthrough prevents UI stalls
- Job coalescing reduces redundant network requests
- Oneshot channels for clean result transmission
- Notification-based waiting with timeouts