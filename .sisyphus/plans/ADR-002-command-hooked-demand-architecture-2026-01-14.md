# ADR-002: Command-Hooked Demand Injection for Low-Latency Playback Preparation

**Status**: Draft (for review)

**Date**: 2026-01-14

**Owner**: (TBD)

**Audience**: rmpc contributors (daemon + backend + UI)

**Scope**: YouTube backend first, but architecture must generalize to a “universal streaming music app” (other backends can plug in without re-building complex infra).

---

## 0. Executive Summary

This ADR proposes a **command-hooked demand architecture**:

- We **do not** add new IPC messages.
- We **hook** into the daemon’s existing command/handler boundaries (`AddSong`, `AddSongs`, `PlayPosition`, `Next`, `Previous`, …).
- These hooks derive **demand** (what to prepare + how urgent) using command context that already exists at the daemon.
- A background **Preparation Coordinator** executes three clearly separated domain concerns:
  1) `StreamUrlResolver` (video_id → stream_url)
  2) `AudioPrefixCache` (stream_url → cached prefix file)
  3) `PlaybackInputResolver` (state → mpv input: concat vs passthrough)

This eliminates the systemic root cause: **intent is currently lost**, forcing components to guess urgency and compete (fast-path vs batch), producing complex race-handling logic and large user-facing delays.

---

## 1. Problem Statement

### 1.1 What users experience

1) **“Play album” can take 6–18 seconds before first audio**.
   - Adding a 50-song album triggers sequential blocking work; the UI appears frozen.

2) **“Press play” can stall** (1–3 seconds) even for a single song.

3) **Skipping tracks can stall** if upcoming track isn’t prepared.

### 1.2 What contributors experience

- Urgent vs background work is not explicit.
- Optimizations become ad-hoc hacks in specific places.
- The system “works” but only because `CachedExtractor` implements a sophisticated in-flight + priority patch to mitigate collisions.
- New optimizations (prefix/chunk download) risk repeating the same complexity and producing more tech debt.

### 1.3 Root Cause

**Demand is not expressed explicitly at the point the system already knows it.**

Today, the daemon sees:
- “queue changed” (IDs were added)
- “play position” (index chosen)

But internal subsystems do not get a unified “this item is urgent, these are background” signal. Instead:
- queue-add work happens without knowing whether it is preparation or immediate playback
- play-time work happens without knowing what was supposed to be prepared earlier

Result: multiple call sites initiate competing work on the same items, producing races and forcing complicated fast-path logic.

---

## 2. Current Design (High-level)

### 2.1 Current flow (simplified)

```text
TUI action: Play Album (50 songs)
  ↓
Daemon: enqueue_multiple loops add_song 50x
  ↓
During add_song: if within prefetch window → resolve playback URL
  ↓
FfmpegConcatSource::build_mpv_input
  ↓
block_on(ensure_prefix)  ← blocking network + disk
  ↓
Only after all adds: PlayPos(0)
  ↓
orchestrator::play_position builds first 3 URLs synchronously
  ↓
more block_on(ensure_prefix)
  ↓
first audio
```

### 2.2 Observed anti-patterns

- **Surprise blocking** inside playback input creation.
- **Work duplication**: queue-added triggers some preparation, play triggers more preparation.
- **Races**: urgent single extraction vs background batch extraction.
- **Mismatched contracts**: “prefetch” components claim to prepare audio but only do URL extraction.

---

## 3. Goals / Non-Goals

### 3.1 Goals

G1) **Reduce time-to-first-audio**: first track should start quickly (target: sub-second; best-effort ~200–500ms on ytx).

G2) **No UI freeze on AddSongs**: adding many tracks must not do blocking network downloads in the command handling path.

G3) **Maintain strict separation of concerns**:
- Stream URL resolution stays its own component.
- Prefix download stays its own component.
- The “concat vs passthrough” decision stays pure.

G4) **Explicit demand**: urgency must be derived once and flow through the system.

G5) **Extensible priority**: allow inserting intermediate levels (e.g., between “Gapless” and “Background”) without refactoring all code.

G6) **Backend extensibility**: contributors can add backend-specific optimizations without rebuilding complex infra.

### 3.2 Non-goals (for this ADR)

N1) Full redesign of the UI/IPC protocol.

N2) Implementing multi-minute chunk downloads / full offline mode.

N3) Replacing MPV or changing MPV playlist semantics.

N4) Perfectly general “framework” for every possible workload; we focus on streaming-audio preparation primitives.

---

## 4. Decision

### 4.1 Adopt command-hooked demand injection

We introduce a **Hooked Command Boundary** around existing daemon command dispatch.

- PRE hook: derives immediate demands (e.g., `PlayPosition` implies one song is urgent).
- POST hook: derives follow-up/background demands (e.g., `AddSongs` implies background work for all items).

No new IPC message types required.

### 4.2 Centralize demand derivation + execution

- A `DemandDeriver` maps (command + context) → `Demands`.
- A `PreparationCoordinator` consumes demands and schedules execution across the 3 core domain concerns.

### 4.3 Keep domain concerns explicit (do not hide them behind generic “Work”)

We commit to **domain nouns** as first-class components:

1) `StreamUrlResolver`
2) `AudioPrefixCache`
3) `PlaybackInputResolver`

Coordination is explicit via `PreparationCoordinator` (and supporting “Prepared Asset” store).

---

## 5. Proposed Architecture (Diagrams only)

### 5.1 Hooked Command Boundary

```text
                         (NO new IPC messages)
+---------+   existing cmd msg   +-----------------------+
|   TUI   | -------------------> | rmpc-daemon IPC recv   |
+---------+                      +-----------+-----------+
                                            |
                                            v
                                  +-----------------------+
                                  | CommandDispatcher      |
                                  | (existing match/call)  |
                                  +-----------+-----------+
                                              |
                                              v
   +------------------------------------------------------------------+
   | Hooked Command Boundary (NEW wrapper, handlers unchanged)         |
   |                                                                  |
   |   PRE hooks:                                                      |
   |     - DemandInjectorHook  ---> emits Demands ------------------+  |
   |     - (optional) metrics/logging                               |  |
   |                                                                |  |
   |   EXISTING handler (unchanged):                                |  |
   |     - AddSong / AddSongs / PlayPosition / Next / Previous       |  |
   |                                                                |  |
   |   POST hooks:                                                    |
   |     - DemandInjectorHook  ---> uses queue diff/now-playing ----+  |
   +------------------------------------------------------------------+  |
                                                                         v
                                                             +----------------+
                                                             | Demand Engine   |
                                                             | (priority+dedupe)|
                                                             +----------------+
```

### 5.2 Demand Derivation and Execution

```text
(Command) ----->| CommandContext Provider      |
(AddSongs,       | - cmd args                  |
 PlayPosition,   | - queue snapshot + diff     |
 Next/Previous)  | - recent_cmd history (TTL)  |
                 +---------------+-------------+
                                 |
                                 v
                     +--------------------------+
                     | DemandDeriver (rules)    |
                     | - map cmd -> demands     |
                     | - assign priority levels |
                     +------------+-------------+
                                  |
                                  v
                     +--------------------------+
                     | PreparationCoordinator    |
                     | - dedupe by (track,kind) |
                     | - priority escalation     |
                     +-----+----------+---------+
                           |          |
                           v          v
                    Immediate/GAPLESS/BG queues
                           |
                           v
            +----------------------------------------+
            | 3 explicit domain components            |
            | - StreamUrlResolver (id → url)          |
            | - AudioPrefixCache (url → prefix file)  |
            | - PlaybackInputResolver (state → input) |
            +----------------------------------------+
```

---

## 6. Demand Model

### 6.1 What is a “demand”

A demand is **not** “do some generic work”.

A demand is a request to prepare a specific artifact for a specific track.

Minimum conceptual structure:

- Track identity (e.g., video_id)
- Artifact kind:
  - Stream URL
  - Audio prefix
  - MPV input
- Priority level (registered level)
- Reason (why it’s being requested):
  - user pressed play
  - gapless next
  - queue warm
  - hover preview

### 6.2 Registered priority levels (extensible)

We choose **registered levels** instead of a closed enum.

Why:
- Contributors can add “middle” levels without refactoring core logic.
- Backends can map their own heuristics to stable level IDs.

Example conceptual ladder (ranks are illustrative):

- `IMMEDIATE` (900)
- `GAPLESS_NEXT` (700)
- `EAGER_WARM` (600)  ← insertable middle
- `BACKGROUND` (100)

By leaving numeric gaps, we allow insertion between existing levels.

---

## 7. Hook Rules (Initial)

These rules capture intent that’s currently lost:

- `AddSong(song)` POST → Background(song)
- `AddSongs(songs[])` POST → Background(all) + store `LastAddBatch { ids, start_index, ttl }`
- `PlayPosition(index)` PRE:
  - identify track at `index`
  - emit Immediate(track)
  - if `LastAddBatch` matches and within TTL, treat this as “batch-first play”; do not promote the entire batch
  - also emit GaplessNext(neighbors) based on prefetch window policy
- `Next` PRE → GaplessNext(upcoming)
- `Previous` PRE → Immediate(previous)

Important: these rules operate on **existing commands** and **queue context**.

---

## 8. Separation of Concerns (Explicit)

### 8.1 StreamUrlResolver (video_id → stream_url)

Responsibilities:
- Resolve stream URL.
- Internal caching and rate limiting.
- May support batch extraction.

Non-responsibilities:
- Must not download audio data.
- Must not decide which IDs are urgent; it consumes demand priority.

### 8.2 AudioPrefixCache (stream_url → cached prefix file)

Responsibilities:
- Download first N bytes via HTTP Range.
- Store on disk.
- Enforce eviction policy.

Non-responsibilities:
- Must not resolve stream URLs.
- Must not block user-facing command handling.

### 8.3 PlaybackInputResolver (state → mpv input)

Responsibilities:
- Decide which input to use:
  - If prefix ready → concat input
  - If not ready and user is waiting → passthrough

Non-responsibilities:
- Must not perform downloads.

### 8.4 PreparationCoordinator

Responsibilities:
- Deduplicate demands.
- Execute demands asynchronously.
- Escalate priority.
- Apply rate limiting.

Non-responsibilities:
- Must not encode backend-specific extraction logic.
- Must not embed special-case “album play hacks”; those live in DemandDeriver rules.

---

## 9. Real Example Walkthrough: “Play Album (50 songs)”

### 9.1 Before

1) UI triggers add 50 songs.
2) daemon loops add command; each add may trigger blocking prefix downloads.
3) only after adds complete does play start.

Time-to-first-audio: 6–18 seconds.

### 9.2 After (hooked)

Command stream remains the same:

- `AddSongs([A..AX])`
- `PlayPosition(0)`

But hooks derive demand:

- POST AddSongs:
  - Background(StreamUrl) for all tracks
  - Background(AudioPrefix) optional for tail (depending on policy)
  - Store `LastAddBatch` correlation

- PRE PlayPosition(0):
  - Immediate(StreamUrl) for A
  - Immediate(PlaybackInput) for A
  - GaplessNext(AudioPrefix) for neighbors

PlaybackInputResolver rule:
- If A prefix not ready → passthrough A immediately.

Now:
- first audio starts quickly (URL fast path)
- background work continues for neighbors

---

## 10. Why This Fixes the Original Pathologies

### 10.1 Removes lost intent

The daemon knows the command sequence; hooks capture it and translate into demand.

### 10.2 Eliminates scattered competing work

There is one place where “what to do next” is decided: DemandDeriver + PreparationCoordinator.

### 10.3 Avoids blocking in hot path

Downloads and heavy extraction occur in background execution.

### 10.4 Enables extensible priority

We can add `HOVER_PREVIEW` or “between eager and background” without rewriting logic.

---

## 11. Alternatives Considered

A1) New IPC “PlaybackIntent” message
- Pros: explicit intent
- Cons: invasive protocol/UI changes

A2) Generalize fast-path hacks into a generic scheduler
- Pros: reuse existing `CachedExtractor` mechanics
- Cons: scales workaround; doesn’t encode demand at source; naming drift risk

A3) Keep everything as-is and tune rate limiting
- Pros: minimal work
- Cons: does not solve queue-add blocking or intent loss

Decision: Command-hooked demand injection is the least invasive change that restores lost intent and preserves clean domain boundaries.

---

## 12. Risks & Mitigations

R1) Incorrect correlation between `AddSongs` and `PlayPosition`
- Mitigation: short TTL + validate track identity at index.

R2) Starvation of background work under repeated urgent demand
- Mitigation: lane scheduling and rate limiting.

R3) MPV protocol whitelist behavior when switching inputs
- Mitigation: apply whitelist consistently; ensure passthrough and concat can coexist.

R4) Duplicate resolver instances
- Mitigation: make StreamUrlResolver a singleton per backend instance.

---

## 13. Open Questions (for future refinement)

Q1) Naming:
- StreamUrlResolver vs TrackUrlResolver
- AudioPrefixCache vs AudioWarmCache vs StartupBufferCache
- PreparationCoordinator vs PreparationService vs PreloadCoordinator

Q2) Priority levels:
- Which core levels should be standardized?
- How much should be backend-configurable?

Q3) Demand granularity:
- Prefix only vs chunk/range objects
- How to represent partial readiness

Q4) Where to host the hook boundary:
- CommandDispatcher wrapper vs inside each handler

---

## 14. Decision

Proceed with command-hooked demand injection to:
- preserve current IPC
- restore demand/intent semantics
- keep domain components clean and separable
- unblock future priority/optimization additions without new hacks
