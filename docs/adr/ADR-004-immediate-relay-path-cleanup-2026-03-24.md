# ADR-004: Immediate Relay Path Cleanup and Coordinator Ownership

**Status**: Accepted and implemented

**Date**: 2026-03-24

**Owner**: yrmpc playback architecture

**Audience**: yrmpc contributors working on YouTube playback, queue coordination, MediaPreparer, and RelayRuntime

---

## 0. Executive Summary

> **Implementation note (2026-03-25):** This ADR is now the rationale document for the live playback path. For the authoritative current runtime behavior, read [`../arch/playback-flow.md`](../arch/playback-flow.md).

This ADR redesigns the YouTube playback path around one rule:

> **Immediate-demand playback must be owned by one coordinator, use relay first, avoid duplicate work, and never compete with background preparation for the same track.**

The current system mixes immediate playback work and background queue work across multiple components. That creates duplicate extraction, conflicting prefix-prep, inconsistent queue/index/window tracking, and a play path that synchronously prepares more than the current track.

The new architecture introduces:

1. **One coordinator snapshot** as the single source of truth for current track, resolved playback horizon, next-3 background window, and per-track job state.
2. **Relay-first immediate playback**:
   - prefix cache hit -> relay serves cached prefix, then upstream continuation
   - prefix cache miss -> relay streams upstream immediately and tees only the configured prefix bytes into cache
   - direct URL is fallback only after the chosen relay strategy fails as a whole
3. **Separated ownership** between:
   - immediate play path
   - queue-wide extraction
   - next-3 background prefix work
4. **A relay planner** that owns strategy selection, while `stream_upstream_segment` becomes a **thin executor**.

The implemented system also made one internal contract explicit:

> During immediate playback startup, `PlaybackCoordinator` owns current-track identity. `PlayQueue.current_id` and transient MPV observations are advisory until playback is confirmed. Stale `TrackChanged(-1)` before playback start must be ignored and must not restore the previous track.

This ADR is intentionally self-contained. A new implementer should be able to begin work from this file alone.

---

## 1. Problem Statement

### 1.1 What is broken today

The current playback architecture has four linked problems:

1. **Immediate play does unnecessary preparation**
   - `Orchestrator::play_position_sync` prepares a 3-track plan synchronously.
   - The current track is not isolated cleanly from future-track preparation.

2. **Immediate and background paths conflict**
   - Queue add triggers queue-wide extraction work.
   - Idle queue add may also trigger prefetch/playback-window work.
   - Immediate play can start while batch extraction is still running.
   - The same track may appear in both immediate and background pipelines.

3. **State ownership is split and inconsistent**
   - Current track, next window, and in-flight work are inferred in multiple places.
   - Queue/index/horizon state diverges.
   - Late results can arrive with no clear ownership rule.

4. **`stream_upstream_segment` owns too much**
   - It currently acts as both strategy chooser and I/O executor.
   - Retry/fallback selection and byte transport are braided together.
   - That makes testing and reasoning harder than necessary.

### 1.2 What the user wants

The user’s architecture requirements were clarified explicitly during design review:

- no-stutter, gapless streaming experiment
- no unnecessary roundtrip disrupting listening
- immediate play should not trigger unnecessary background-style preparation
- relay is the normal path
- direct URL is fallback only
- duplicate/conflicting work across the 3 paths must be removed
- `stream_upstream_segment` must be cleaned up

### 1.3 Root cause summary

The core issue is **ownership complection**:

- the same track can be “owned” by immediate playback and background work at the same time
- queue/window computation is not centralized
- relay strategy decisions leak into low-level transport functions

This is an architecture problem, not just a bug.

---

## 2. Design Goals

### 2.1 Primary goals

1. **Immediate play must start the current track only**
2. **Background work must finish future-track prep before the next song starts**
3. **One track must have one active owner at a time for playback-critical work**
4. **Relay strategy must be explicit and testable**
5. **The current track must not be reprocessed by background prefix work during fragile startup**

### 2.2 Non-goals

This redesign is **not** for:

- queue semantics redesign
- shuffle/repeat feature redesign
- full offline caching
- full-song caching during direct fallback
- generic proxy platform work
- changing prefix cache keying beyond what the user explicitly requested

---

## 3. User-Approved Decisions (Authoritative)

These decisions came from direct user answers and are binding for implementation.

| Topic | Decision |
|---|---|
| Immediate play transport | **Relay only** |
| Direct URL usage | **Fallback only after the chosen relay strategy fails as a whole** |
| Immediate-demand track vs worker queue | **Reuse finished extraction only; do not let background prefix work own the immediate track** |
| Queue background extraction | **Extract all queued tracks** |
| Background prefix window | **Next 3 after current** |
| Background prefix concurrency | **One at a time** |
| Background window source | **Resolved playback horizon** |
| When to start background next-3 work | **After a one-shot `PlaybackStarted { playback_id, track_id }` event emitted by the orchestrator from the active MPV playback-confirmation lifecycle edge** |
| If queue changes during a prefix job | **Let current prefix job finish, then recompute** |
| If batch extract includes immediate target | **Keep batch for others, drop the target result** |
| If batch extract result for immediate target arrives late | **Drop it completely** |
| Prefix cache on immediate miss | **Relay upstream and tee only the prefix bytes into cache** |
| Prefix cache key | **Track id only** |
| If relay falls back to direct | **Swap owner, keep same current track, keep next-3 background work alive** |
| Direct fallback current-track caching | **No; direct fallback just plays** |
| Re-adopt current after direct fallback | **Only cache again during relay tee mode** |
| `stream_upstream_segment` ownership | **Thin executor only** |
| Continuation planning owner | **Relay planner** |
| Coordinator source of truth | **One coordinator snapshot** |
| Per-track job state model | **Minimal phases**: `None`, `Extracting`, `Extracted`, `Prefixing`, `PrefixReady`, `PlayingRelay`, `PlayingDirect`, `Failed` |

---

## 4. Proposed Architecture

### 4.1 New ownership model

```text
┌───────────────────────────────────────────────────────────────┐
│                  PlaybackCoordinator                         │
│   single source of truth for playback ownership/state        │
├───────────────────────────────────────────────────────────────┤
│ current_track                                                │
│ resolved_playback_horizon                                    │
│ next_three_window                                            │
│ per_track_state[track_id]                                    │
│ per_track_owner[track_id]                                    │
└───────────────┬───────────────────────────┬──────────────────┘
                │                           │
                │                           │
                ▼                           ▼
      Immediate Play Path            Background Window Path
      (current track only)           (future tracks only)
                │                           │
                ▼                           ▼
          RelayPlanner                 QueueExtractWorker
                │                      PrefixWindowWorker
                ▼
     Relay strategy = one of:
       - CacheHitRelay
       - TeeMissRelay
       - DirectFallback
```

### 4.2 Core idea

The system stops treating playback as “prepare everything near the play call.”

Instead:

- **Immediate path** owns the current track only.
- **Background path** owns only future tracks.
- **Coordinator** arbitrates ownership and state.
- **Relay planner** converts prepared facts into one concrete play strategy.
- **Relay runtime** executes that chosen strategy.

This removes most of today’s duplicate/concurrent work by construction.

---

## 5. Coordinator Snapshot Design

### 5.1 Snapshot state

The coordinator should own one immutable snapshot-like state structure (updated atomically by one imperative coordinator shell).

Proposed shape:

```rust
struct PlaybackCoordinatorSnapshot {
    current_track: Option<TrackId>,
    current_owner: Option<TrackOwner>,
    resolved_horizon: Vec<TrackId>,
    next_three_window: Vec<TrackId>,
    track_states: HashMap<TrackId, TrackJobState>,
}

enum TrackOwner {
    ImmediateRelay,
    DirectFallback,
    QueueExtract,
    QueuePrefix,
}

enum TrackJobState {
    None,
    Extracting,
    Extracted,
    Prefixing,
    PrefixReady,
    PlayingRelay,
    PlayingDirect,
    Failed,
}
```

### 5.2 Why this snapshot exists

It prevents three anti-patterns:

1. inferring ownership from active tasks
2. recomputing next-3 differently in different subsystems
3. allowing late/stale async results to mutate playback behavior implicitly

### 5.3 Coordinator invariants

These invariants should be enforced in code and tests:

1. `current_track` is never in `next_three_window`
2. at most one playback-critical owner exists for a given track at a time
3. late `QueueExtract` result for `current_track` is discarded
4. background prefix work may only target tracks inside the current `next_three_window`
5. prefix work runs one-at-a-time in resolved playback order

### 5.4 Playback-start event contract

The coordinator and background prefix worker must not depend on sampled player telemetry.

Use a single semantic domain event:

```rust
PlaybackStarted {
    playback_id: PlaybackId,
    track_id: TrackId,
}
```

Rules:

1. It is emitted by the **playback orchestrator**, not by downstream workers.
2. It is triggered only after the active player instance produces its first playback-confirmation lifecycle event (MPV `playback-restart` or equivalent).
3. It is emitted **at most once per `playback_id`**.
4. Stale confirmations for non-active playback attempts must be ignored.
5. Raw MPV events are adapter-private details and must not leak into the coordinator/background control plane.

This explicitly replaces any prior idea of using sampled properties such as `TimeRemaining` as a playback-start proxy.

---

## 6. Relay Planner and Strategy Model

### 6.1 Relay planner responsibilities

The relay planner should own **all strategy selection**.

Inputs:
- current track id
- extracted stream URL (or extraction handle/result)
- prefix cache metadata hit/miss
- transport mode / relay availability
- failure state for the current strategy

Output:

```rust
enum RelayPlayStrategy {
    CacheHitRelay {
        track_id: TrackId,
        stream_url: String,
        prefix: PrefixCacheEntry,
    },
    TeeMissRelay {
        track_id: TrackId,
        stream_url: String,
        prefix_target: PrefixCacheTarget,
    },
    DirectFallback {
        track_id: TrackId,
        stream_url: String,
    },
}
```

### 6.2 Important boundary

`stream_upstream_segment` must **not** decide strategy anymore.

It must only execute an already-chosen upstream read plan.

That keeps:
- planning pure/testable
- transport execution local
- fallback transitions explicit at the planner/coordinator level

### 6.3 Upstream continuation planning

Below relay planner, introduce a narrower transport plan type for RelayRuntime:

```rust
enum UpstreamReadPlan {
    QueryRange { start: u64, end: u64 },
    AnchoredQueryRange { start: u64, end: u64 },
    ChunkedQueryRange { start: u64, end: u64 },
}
```

This is separate from `RelayPlayStrategy` on purpose:
- `RelayPlayStrategy` is product-level play behavior
- `UpstreamReadPlan` is transport-level execution detail

---

## 7. Three Authoritative Flows

## 7.1 Path 1 — Immediate play request

### Desired behavior

Immediate play should prepare and start **only the current track**.

### Flow

```text
User Play Action
  -> Orchestrator / play command entry
  -> Coordinator sets current_track = T
  -> Coordinator marks T immediate-owned
  -> Coordinator invalidates any future background prefix ownership for T
  -> If usable extraction already exists for T, reuse it
     else start dedicated immediate extraction for T
  -> RelayPlanner chooses:
       a) CacheHitRelay if prefix cache exists
       b) TeeMissRelay if prefix cache missing
  -> PlaybackService registers relay session
  -> MPV starts current track through relay
  -> Orchestrator emits one-shot `PlaybackStarted { playback_id, track_id }`
     after the active MPV playback-confirmation lifecycle event
  -> Coordinator rebuilds next-three future window
  -> Background prefix worker begins next-3 processing
```

### Immediate path rules

- Do **not** synchronously prepare the next 3 tracks here.
- Do **not** let background prefix workers compete for T.
- Do **not** accept late batch-extract result for T.
- Do **not** emit playback-start optimistically after append / play / prepare success.
- If chosen relay strategy fails as a whole, swap owner of T to `DirectFallback` and play direct.

### Cache hit subcase

```text
Extracted URL + PrefixReady
  -> RelayPlanner => CacheHitRelay
  -> Relay serves prefix bytes from cache
  -> Relay continues upstream for the rest
```

### Cache miss subcase

```text
Extracted URL + no prefix cache
  -> RelayPlanner => TeeMissRelay
  -> Relay opens upstream immediately
  -> Relay tees only prefix bytes into cache while streaming playback
  -> After prefix bytes are captured, relay continues upstream passthrough
```

### Direct fallback subcase

```text
Chosen relay strategy fails as a whole
  -> Coordinator swaps owner(T) from ImmediateRelay to DirectFallback
  -> Playback continues using direct URL for current track only
  -> Background next-3 work keeps running
  -> Direct path does not keep building current-track cache
```

---

## 7.2 Path 2 — Add multiple songs to queue

### Desired behavior

Queue add should optimize future listening without interfering with current immediate playback.

### Flow

```text
Queue add [A, B, C, ...]
  -> Queue mutation updates queue contents
  -> Coordinator recomputes resolved playback horizon
  -> QueueExtractWorker batches extraction for queued tracks
  -> If any extracted result belongs to current immediate track and is stale:
       drop that result
     else keep/store extraction result
  -> If current playback is already started:
       next_three_window = next 3 after current
       PrefixWindowWorker processes those tracks one-at-a-time
```

### Queue path rules

- Queue extraction may cover many tracks.
- Background prefixing only covers next 3 after current.
- If queue changes while a prefix job is running, let it finish, then recompute.
- If batch extract contains the immediate target, keep the batch for the others but invalidate that one result.

### Why extraction and prefixing differ

Extraction is cheap enough to be broadly useful.
Prefix work is expensive/conflict-prone enough to keep tightly scoped.

---

## 7.3 Path 3 — Relay serving current track

### Desired behavior

Relay runtime should execute a previously chosen strategy, not improvise product policy.

### Flow

```text
MPV requests /relay/sessions/{id}/stream
  -> RelayRuntime::handle_connection
  -> session lookup
  -> plan_response(downstream byte range)
  -> stream_planned_response
       if strategy/session == CacheHitRelay:
           serve staged prefix bytes
           execute upstream continuation via thin executor
       if strategy/session == TeeMissRelay:
           open upstream immediately
           tee only prefix bytes into cache
           continue streaming upstream to MPV
```

### Cleanup target for `stream_upstream_segment`

After redesign it should look conceptually like:

```rust
fn stream_upstream_segment(
    writer: &mut dyn Write,
    reader_plan: UpstreamReadPlan,
    session_ctx: &RelaySessionContext,
) -> Result<()> {
    // execute chosen plan only
}
```

It should **not**:
- decide product-level fallback
- know whether it is serving cache-hit vs tee-miss vs direct-fallback
- mutate coordinator ownership

---

## 8. Dead / Live Path Decisions

### 8.1 Live after redesign

- `PrepareResult::StagedPrefix` stays live for cache-hit and background-prepared future tracks.
- `PrepareResult::Direct` stays live only as fallback output.
- `PrepareResult::StreamAndCache` must become **live** for immediate cache misses.

### 8.2 Explicitly dead as normal path

- Direct-first immediate play
- Immediate path synchronously preparing current + next 3
- Background prefix worker owning the current immediate-demand track

---

## 9. Conflict Elimination Rules

These are implementation guardrails, not optional suggestions.

### Rule A — One track, one playback owner

For any track currently in immediate playback startup:
- background prefix ownership is forbidden
- late background extract result is ignored

### Rule B — Extraction reuse is allowed, prep reuse is not assumed

Immediate path may reuse a completed usable extraction result.
It must not rely on in-flight background prefix work for the current track.

### Rule C — Window recompute is serialized behind prefix jobs

If the queue changes mid-prefix:
- finish current prefix job
- recompute horizon and next-3
- continue from new window

### Rule D — Fallback swaps owner, not track identity

When direct fallback happens, the current track stays the same track.
Only the owner/strategy changes.

---

## 10. File-Level Redesign Map

This section is intentionally concrete for a new implementer.

### 10.1 New modules recommended

1. `rmpc/src/backends/youtube/server/playback_coordinator.rs`
   - owns snapshot state
   - owns ownership transitions
   - computes next-3 window from resolved horizon

2. `rmpc/src/backends/youtube/server/playback_horizon.rs`
   - pure helper for resolved playback order
   - repeat/random aware

3. `rmpc/src/backends/youtube/media/relay_planner.rs`
   - pure-ish relay strategy selector
   - returns `RelayPlayStrategy`

4. `rmpc/src/backends/youtube/media/upstream_plan.rs`
   - `UpstreamReadPlan`
   - pure transport-plan selection for RelayRuntime

### 10.2 Existing files that should shrink

1. `server/orchestrator.rs`
   - stop owning detailed playback/work arbitration
   - delegate to coordinator and immediate-play path

2. `server/handlers/queue_events.rs`
   - stop duplicating playback-window ownership logic
   - notify coordinator instead of directly making independent scheduling choices

3. `media/preparer.rs`
   - make `StreamAndCache` live for immediate miss path
   - stop forcing staged-prefix semantics on all relay cache misses

4. `media/relay_runtime.rs`
   - keep HTTP mechanics
   - remove product-level continuation/planning logic from `stream_upstream_segment`

5. `services/playback_service.rs`
   - remain transport boundary, not scheduler/ownership brain

---

## 11. Migration Strategy

Implement in this order to avoid turning the refactor into a giant flag day.

### Phase 1 — Coordinator state before behavior change

Add coordinator snapshot and event-driven ownership tracking first, while preserving current behavior.

### Phase 2 — Immediate path split

Make play-now prepare only the current track.
Keep background next-3 scheduling behind the orchestrator-owned `PlaybackStarted` event sourced from MPV playback confirmation.

### Phase 3 — Make tee-miss path live

Revive `StreamAndCache` for immediate cache misses.

### Phase 4 — Thin-executor cleanup

Move continuation/strategy planning out of `stream_upstream_segment`.

### Phase 5 — Remove duplicated window ownership

Move queue-event scheduling authority into coordinator-driven logic.

---

## 12. Verification Requirements

The redesign is not done unless these are demonstrably true.

### 12.1 Playback path

- immediate play prepares the current track only
- next-3 work begins only after `PlaybackStarted { playback_id, track_id }` fires for the active playback attempt
- current track is never simultaneously prefix-owned by background work

### 12.2 Queue/background path

- batch extraction continues to work for queue population
- late extract result for current track is dropped
- next-3 prefix work runs one-at-a-time

### 12.3 Relay path

- cache-hit path serves cached prefix through relay
- cache-miss immediate path uses tee-miss relay
- direct fallback triggers only after full relay strategy failure
- `stream_upstream_segment` executes plans but does not choose product strategies

---

## 13. Risks and Trade-offs

### Positive trade-offs

- simpler immediate play path
- less duplicated work
- better ownership clarity
- more testable relay runtime

### Costs

- new coordinator module and explicit state machine
- migration effort across orchestrator, queue handlers, preparer, relay runtime
- temporary complexity while old and new paths coexist during migration

### Accepted risk

Prefix cache remains keyed by track id only because the user explicitly chose that. If extractor/client context later proves this unsafe, revisit via a new ADR.

---

## 14. Final Decision

Adopt a **single-coordinator, relay-first architecture** where:

- immediate play owns only the current track
- future-track work is background-only and window-bounded
- immediate cache miss becomes live tee-miss relay behavior
- direct is fallback only
- relay planner owns strategy selection
- `stream_upstream_segment` becomes a thin executor

This is the architecture to implement unless a future experiment disproves one of the explicitly accepted user decisions above.

## 15. ADR Override — Playback Start Signaling

This ADR is overridden on one implementation detail:

- **Old wording**: start next-3 work from the "earliest easy hook" once bytes appear to be flowing.
- **Replacement decision**: use a one-shot orchestrator-owned domain event,
  `PlaybackStarted { playback_id, track_id }`, emitted from the active MPV playback-confirmation lifecycle edge (`playback-restart` or equivalent).

Why this override exists:

- sampled properties like `TimeRemaining` are continuous telemetry, not lifecycle edges
- optimistic startup from our own command flow fires too early and can violate current-track startup exclusivity
- a translated one-shot domain event keeps MPV details at the adapter boundary while preserving correctness and idempotency

Therefore:

1. `TimeRemaining` must not be used in the internal playback control plane.
2. Workers must not subscribe directly to raw MPV lifecycle events.
3. Coordinator/background startup logic must key off `PlaybackStarted` only.
