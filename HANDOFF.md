# HANDOFF: Demand-Based Audio Architecture

**Date**: 2026-01-14
**Status**: Design Complete, Implementation Pending
**Context**: Fixing blocking playback/queue issues in `rmpc`

---

## 🚨 CRITICAL ISSUES (Why we are doing this)

### 1. The Queue-Add Blocker (5-15s Freeze)
**Location**: `rmpc/src/backends/interaction.rs` (enqueue_multiple)
**Symptom**: When user adds an album (50 songs), the UI freezes for 10+ seconds.
**Cause**: The loop calls `add_song` 50 times. If the song falls into the prefetch window, `build_mpv_input` triggers a **blocking** `ensure_prefix` download (200KB).
**Impact**: User thinks app is broken.

### 2. The Play-Time Blocker (1-3s Delay)
**Location**: `rmpc/src/backends/youtube/audio/sources/concat.rs`
**Symptom**: Pressing "Play" has a noticeable delay.
**Cause**: `FfmpegConcatSource::build_mpv_input` calls `handle.block_on(cache.ensure_prefix())`.
**Impact**: Poor UX, feeling of sluggishness.

### 3. The "Fast Path" Race Condition
**Location**: `rmpc/src/backends/youtube/extractor/cached.rs`
**Symptom**: Complex `OnceLock` and `in_flight` logic to handle when "Play" and "Prefetch" request the same URL.
**Cause**: The system doesn't know "Play" is urgent and "Prefetch" is background until they collide.

---

## 🏗️ ARCHITECTURE: Command-Hooked Demand

Instead of rewriting the whole world, we hook into the existing command stream.

### 1. The Hook Pattern
We intercept commands at `CommandDispatcher`.

```rust
// Before executing handler
fn pre_hook(cmd: &ServerCommand, context: &Context) {
    let demands = derive_demands(cmd, context);
    demand_engine.submit(demands);
}
```

### 2. The Rules (DemandDeriver)

| User Action | Command Sequence | Hook Logic | Result |
|-------------|------------------|------------|--------|
| **"Play Album"** | 1. `AddSongs([A,B,C...])`<br>2. `PlayPosition(0)` | **Post-Add**: Store batch info, emit `Background(All)`<br>**Pre-Play**: Match index 0 to batch. Promote A to `Immediate`. | A plays NOW.<br>B,C prep in background. |
| **"Next"** | 1. `Next` | **Pre-Next**: Identify upcoming track. Emit `Gapless(Next)`. | Seamless transition. |

### 3. The Demand Engine
Manages three lanes of work:
1. **Immediate Lane**: Bypasses everything. Returns result to waiter.
2. **Gapless Lane**: High priority, ensures next track is ready.
3. **Background Lane**: Rate-limited (1 req/sec). Fills cache.

### 4. Components to Build

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `StreamUrlResolver` | Extract URLs (ytx/yt-dlp). Wraps existing `CachedExtractor`. | **Refactor needed** |
| `AudioPrefixCache` | Download HTTP ranges. Replaces logic in `AudioCache`. | **Refactor needed** |
| `PlaybackInputFactory` | Returns `Concat` if ready, `Passthrough` if not. | **New** |
| `DemandEngine` | Coordinator. Tracks in-flight, priorities. | **New** |

---

## 🛠️ IMPLEMENTATION PLAN (Beads)

The work is broken down into beads (tasks) in `.beads/`:

1. **`yrmpc-b43`**: Create `Work` trait and `Priority` enum.
2. **`yrmpc-uae`**: Implement `DemandScheduler` (the engine).
3. **`yrmpc-slb`**: Refactor `CachedExtractor` to use scheduler.
4. **`yrmpc-0vd`**: Implement `PrefixDownloadWork`.
5. **`yrmpc-d09`**: **CRITICAL FIX** - Remove blocking from queue add path.
6. **`yrmpc-y1c`**: Remove blocking from `FfmpegConcatSource`.

---

## ⚠️ KNOWN RISKS / GOTCHAS

1. **MPV Protocol Whitelist**: `FfmpegConcatSource` relies on MPV args `--demuxer-lavf-o=protocol_whitelist=...`. If we switch to Passthrough, we must ensure these args don't break playback or are applied correctly when switching back.
   - *Mitigation*: Apply whitelist globally to MPV instance, not per-track.

2. **Tokio Runtime**: Current blocking code assumes a Tokio runtime exists (`Handle::try_current()`). New async code must ensure it runs on the correct runtime.
   - *Mitigation*: `DemandEngine` manages its own runtime/task set.

3. **State Synchronization**: `LastAddBatch` state must be ephemeral (TTL ~500ms) to avoid incorrect promotion of unrelated play commands.

---

## 🔗 REFERENCES

- **CachedExtractor**: `rmpc/src/backends/youtube/extractor/cached.rs` (Reference for the "fast path" pattern)
- **Queue Handler**: `rmpc/src/backends/youtube/server/handlers/queue.rs` (Where the blocking add happens)
- **Playback Service**: `rmpc/src/backends/youtube/services/playback_service.rs` (Where prefetch is triggered)
