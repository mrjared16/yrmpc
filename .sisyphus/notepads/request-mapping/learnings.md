# Request Coalescing and Deduplication Learnings

## Core Patterns Identified
1. **Async Coalescing (Media Preparer)**: Uses `tokio::sync::Notify` within an `Arc<InFlightJob>` structure. This allows multiple async tasks to wait for a single result without redundant IO.
2. **Synchronous Blocking (Extractor)**: Uses `std::sync::OnceLock` for transparent request coalescing. Simple and effective for non-async contexts but can block threads.
3. **Task Guarding (Image Cache)**: Uses `HashSet` to track pending operations. Prevents redundant background thread spawning.
4. **Event Debouncing (Orchestrator)**: Uses `HashSet` to ensure events that should only happen once per track (like prefetch triggers) are not duplicated.
5. **IO Synchronization (Streaming File)**: Uses `std::sync::Condvar` to bridge background downloads and reader threads.

## Architectural Observation
- The codebase consistently uses "functional core, imperative shell" principles by keeping the state tracking (HashMaps, Sets) in the shell/manager layer while the actual IO/logic is performed in dedicated tasks or threads.
- `OnceLock` is favored for simple deduplication in extractors, while `Notify` is used for more complex, state-machine-like async workflows in the preparer.
