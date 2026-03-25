# Code Review: Immediate Relay Path Cleanup (ADR-004)

**Reviewer persona**: Principal-level streaming architecture engineer  
**Scope**: ADR-004 + Implementation Plan + Current codebase (11 files)  
**Lenses**: Architecture skill (Simplicity, FCIS, Coupling) + SA-Consultant (streaming domain)  
**Date**: 2026-03-24

---

## Executive Assessment

**Overall verdict**: The ADR and plan are **architecturally sound** and represent a significant quality improvement. The existing implementation already has partial progress toward ADR-004 goals. However, there are **5 findings** ranging from medium to critical that the plan should address before or during execution.

| Area | Grade | Notes |
|------|-------|-------|
| ADR clarity & completeness | **A** | Self-contained, authoritative, binding decisions documented |
| Plan decomposition | **A-** | Good batch ordering; minor dependency gaps |
| Current coordinator impl | **B+** | Pure functional core, but snapshot clone cost emerging |
| Current relay runtime | **B-** | Strategy dispatch lives in `stream_planned_response`, not yet thin |
| Current preparer | **C+** | Largest complection source; `wait_or_coalesce_impl` is a god function |
| Ownership enforcement | **C** | Coordinator exists but isn't wired into all conflict points yet |

---

## Finding 1: `stream_planned_response` Still Owns Strategy Dispatch

**Severity**: 🔴 Critical (directly blocks ADR-004 §6.2, §7.3)

### Current Design

```
stream_planned_response(writer, spec, plan, http_client)
    ├── match RelayPlanner::from_session(spec)
    │     ├── TeeMissRelay  → stream_tee_upstream(...)
    │     └── CacheHitRelay → stream_staged_segment(...) + stream_upstream_with_recovery_plans(...)
    │           └── calls RelayPlanner::from_session(spec) AGAIN for continuation_plans()
    └── DirectFallback → return Err(...)
```

```
relay_runtime.rs:257-285  ← strategy selection inside transport function
relay_runtime.rs:276      ← calls from_session() TWICE in the same response
```

### The Problem

This is the exact complection ADR-004 §6.2 calls out: **product-level strategy selection mixed with transport execution**. The function decides WHAT to do (which strategy?) AND does the I/O (stream bytes). This makes it impossible to test strategy selection without running actual HTTP connections.

The double `from_session()` call on lines 257 and 276 is a code smell — it means the strategy was computed, discarded, then re-derived mid-flight.

### Recommendation

The plan's Batch E + F should address this. However, the plan doesn't call out the **double `from_session()`** issue specifically. The implementer should:

1. Compute `RelayPlayStrategy` once, before entering `stream_planned_response`
2. Pass the chosen strategy as an argument
3. The function body should match on the strategy, not re-derive it

This is the **highest-value refactor** in the plan — it directly enables unit-testing relay strategy selection.

---

## Finding 2: `wait_or_coalesce_impl` Is a God Function (Simplicity Violation)

**Severity**: 🟡 High (ADR-004 §10.2 says preparer.rs "should shrink")

### Current Design

```
wait_or_coalesce_impl()  ← 130 lines, 8 parameters
    ├── loop on JobProgress
    ├── decides: cache hit → StagedPrefix
    ├── decides: immediate + stream_immediate_cache_miss → StreamAndCache
    ├── decides: immediate + allow_immediate_direct → Direct
    ├── spawns prefix downloads
    ├── waits for prefix results
    └── handles deadline timeouts with direct fallback
```

[preparer.rs:561-693](file://<PROJECT_ROOT>/rmpc/src/backends/youtube/media/preparer.rs#L561-L693)

### The Problem

This function braids **four** concerns (Hickey complection):
1. **Job lifecycle** (resolving → downloading → completed)
2. **Strategy selection** (which PrepareResult variant?)
3. **Tier-based policy** (immediate gets direct fallback, background doesn't)
4. **Async coordination** (semaphores, deadlines, spawning tasks)

Each concern has a different reason to change. Adding a new strategy (e.g., partial cache hit) requires modifying this 130-line function, violating OCP.

### Recommendation

The plan mentions making `StreamAndCache` live (Batch D) and changing preparer logic. When doing that:

1. Extract strategy selection into a **pure function**: `fn choose_prepare_result(progress: JobProgress, tier: PreloadTier, config: PrepareConfig) -> PrepareDecision`
2. Keep the async coordination as the imperative shell
3. This aligns perfectly with the FCIS pillar and makes the preparer testable without real semaphores

---

## Finding 3: Coordinator Snapshot Clone-on-Read

**Severity**: 🟠 Medium (performance + API design)

### Current Design

```rust
// playback_coordinator.rs:44-47
pub fn snapshot(&self) -> PlaybackCoordinatorSnapshot {
    self.snapshot.clone()  // clones HashMap<String, TrackJobState> every time
}
```

Every caller that needs to check a single field (e.g., `current_track`) pays for a full `HashMap` clone. This is called from:
- `handle_playback_started_for_current_track()` — clones to check one `Option<String>`
- `play_position_sync_defers_future_window...` test — clones in assertions

### The Problem

This will become worse as the coordinator gets more fields and more callers (Batch B adds hook callbacks, Batch C adds queue notifications). The `HashMap<String, TrackJobState>` is unbounded — in a long listening session with queue churn, this could have hundreds of entries.

### Recommendation

Either:
- **Option A**: Add targeted getters (`fn current_track(&self) -> Option<&str>`, `fn next_three_window(&self) -> &[String]`)
- **Option B**: Make `snapshot()` return `&PlaybackCoordinatorSnapshot` (behind the mutex borrow)
- **Option C**: Accept the clone cost but add periodic GC for completed track states

Option A is the cleanest — it keeps the snapshot type for serialization/debugging but doesn't force cloning for hot-path queries. **This should be addressed in Batch A before more callers are added.**

---

## Finding 4: Dual Horizon Computation (Coupling Violation)

**Severity**: 🟠 Medium (directly violates ADR-004 §5.3 invariant 4)

### Current Design

Two separate `resolved_horizon_track_ids` functions exist:

```
orchestrator.rs:69-77     → fn resolved_horizon_track_ids(queue, start_idx) -> Vec<String>
queue_events.rs:237-256   → fn resolved_horizon_track_ids(play_queue, play_order, current_id) -> Vec<String>
```

Both compute the resolved playback horizon from different source data:
- The orchestrator version uses `QueueService`
- The queue_events version uses `PlayQueue` (the underlying data structure)

### The Problem

The ADR explicitly states: **"Coordinator source of truth: One coordinator snapshot"** (§3, §5.3). Having two horizon computation sites means they can diverge if the queue and play_queue are out of sync, which is exactly the anti-pattern the coordinator is designed to eliminate.

### Recommendation

This isn't explicitly called out in the plan's batch structure. It should be addressed in **Batch C** (Queue Extraction vs Prefix Ownership Cleanup):

1. Consolidate into a single `ResolvedPlaybackHorizon::from_queue()` or `::from_play_order()` factory
2. Both sites should call the same function
3. Add a test proving both paths produce identical results for the same logical queue state

---

## Finding 5: `build_playback_plan` Still Builds Multi-Track Plans

**Severity**: 🟢 Low (but contradicts ADR-004 §7.1 "current track only")

### Current Design

```rust
// orchestrator.rs:476-526
pub fn build_playback_plan(queue, pos, window_size: usize) -> Result<PlaybackPlan>
```

This still accepts a `window_size` parameter and builds a multi-track `PlaybackPlan`. The caller (`play_position_sync_with_services`) currently only uses `tracks.first()`, but the function still computes the full window.

### Why This Is Low Severity

The function is pure and the caller correctly ignores the extra tracks. However, having `PREFETCH_WINDOW_SIZE` passed to `build_playback_plan` is misleading API surface — it suggests the immediate path still cares about future tracks.

### Recommendation

In Batch B, either:
- Change the function signature to `build_current_track_plan(queue, pos) -> Result<PlannedTrack>`
- Or simply pass `window_size: 1` from the immediate path

---

## Plan Gap Analysis vs ADR-004

| ADR-004 Requirement | Plan Batch | Current Status | Risk |
|---|---|---|---|
| Coordinator as single source of truth | A ✅ | Implemented, needs targeted getters | Low |
| Immediate play = current track only | B ✅ | Current code already does this | Low |
| Background starts after bytes hook | B ✅ | Hook exists but only updates coordinator state | Medium — **who starts the prefix worker?** |
| `StreamAndCache` live for cache miss | D ✅ | Already live in preparer | Low |
| Relay planner owns strategy | E ✅ | `RelayPlanner` exists, but runtime still dispatches | High |
| Thin executor for `stream_upstream_segment` | F ✅ | Function is already thin; the **caller** isn't | **Plan misfocuses** |
| Direct fallback explicit transition | G ✅ | `swap_current_track_to_direct_fallback()` exists | Low |
| Dual horizon computation eliminated | Not explicitly | Two functions exist | Medium |

> [!WARNING]
> **The plan's Batch F targets `stream_upstream_segment` but the actual problem is in `stream_planned_response`** (Finding 1). The segment executor is already a thin function — it pattern-matches on `UpstreamReadPlan` and calls the appropriate transport. The strategy/product logic that ADR-004 wants removed lives one level up in `stream_planned_response`.

---

## Cross-Cutting: "Bytes Started" Hook → PrefixWindowWorker

The ADR says background next-3 work starts after a "bytes started" hook fires. Currently:

```
handle_playback_started_for_current_track()
    → coordinator.mark_bytes_started(track_id)
        → recompute_next_three_window()
```

This correctly computes the window but **nobody consumes it**. There's no `PrefixWindowWorker` yet. The plan creates one conceptually but doesn't specify:

1. Where the worker lives (tokio task? thread? inside preparer?)
2. What triggers it to poll `claim_next_prefix_job()`
3. How it signals `finish_prefix_job()` back to the coordinator

> [!IMPORTANT]
> **This is the biggest integration wiring risk in the plan.** The coordinator computes the window, but there's no mechanism to drive actual prefix work from it. Batch B says "Add an explicit hook placeholder" — make sure this isn't just a log line but an actual channel/callback.

---

## Summary Table

| # | Finding | Severity | Plan Batch | Action |
|---|---------|----------|------------|--------|
| 1 | `stream_planned_response` owns strategy dispatch | 🔴 Critical | E/F | Refactor caller, not callee |
| 2 | `wait_or_coalesce_impl` is a god function | 🟡 High | D | Extract pure strategy selection |
| 3 | Coordinator snapshot clone-on-read | 🟠 Medium | A | Add targeted getters |
| 4 | Dual horizon computation | 🟠 Medium | C | Consolidate into shared function |
| 5 | `build_playback_plan` multi-track API | 🟢 Low | B | Narrow signature or pass `1` |
| — | PrefixWindowWorker not wired | 🔴 Critical | B/C | Design the activation mechanism |

---

## Architecture Principles Scorecard

### Simplicity (Rich Hickey)
- ✅ Coordinator snapshot is a value type, not mutable state
- ✅ `UpstreamReadPlan` separates transport from product strategy
- ❌ `wait_or_coalesce_impl` braids 4 concerns
- ❌ `stream_planned_response` braids strategy selection with I/O

### FCIS (Functional Core, Imperative Shell)
- ✅ `ResolvedPlaybackHorizon::next_tracks_after()` is pure
- ✅ `RelayPlanner::from_prepared()` is pure
- ✅ `build_playback_plan()` is pure
- ⚠️ `PlaybackCoordinator` is mostly pure but uses `clone()` for snapshots
- ❌ `wait_or_coalesce_impl` mixes async coordination with business logic

### Coupling & Cohesion
- ✅ `relay.rs` types (contract, session, byte range) are high-cohesion data modules
- ✅ `upstream_plan.rs` is minimal and focused
- ❌ Two `resolved_horizon_track_ids` functions = split cohesion
- ❌ `stream_planned_response` has content coupling with `RelayPlanner`

---

## Final Recommendation

The plan is **ready to execute** with these adjustments:

1. **Batch A**: Add targeted getters to `PlaybackCoordinator` to avoid clone-on-read
2. **Batch B**: Design the `PrefixWindowWorker` activation mechanism (channel? polling? event-driven?)
3. **Batch C**: Consolidate the two `resolved_horizon_track_ids` into one shared function
4. **Batch E/F**: Refocus on `stream_planned_response` as the primary refactor target, not `stream_upstream_segment`
5. **Batch D**: When making `StreamAndCache` changes in preparer, extract the strategy selection from `wait_or_coalesce_impl` into a pure function

> The ADR is one of the best I've reviewed in this codebase. The ownership model is clear, the binding decisions table (§3) eliminates ambiguity, and the file-level map (§10) is practically executable. The main risk is **incomplete wiring** — which is the exact anti-pattern your AGENTS.md warns about.
