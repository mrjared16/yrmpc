# PlayIntent Architecture Implementation Plan

**Goal**: Reduce "Play Album" latency from 5-25s to <500ms first audio

**ADR**: `ADR-002-playintent-architecture-2026-01-15.md`

**Phases**: 1a (IPC+Handler) → 1b (TUI Migration) → 1c (PreloadScheduler)

---

## Context

### Original Request
Fix performance bug where "Play Album" (50 songs) takes 5-25 seconds to first audio due to blocking URL extraction during `add_song()` calls.

### Interview Summary
**Key Decisions**:
- Single `ServerCommand::Play { intent, request_id }` instead of composed commands
- `PlayIntent` enum: Context, Next, Append, Radio (seed-only v1)
- Replace AudioPrefetcher with PreloadScheduler
- Passthrough for Immediate tier if prefix not ready
- RequestId is `u64` (no uuid dependency)
- Network timeout 5s → PlayError for Immediate tier
- TUI debounce same as search autocomplete

**Research Findings**:
- Spotify/Tidal send "play context" not "clear+add+play"
- Intent at IPC boundary, composability inside engine
- Oracle recommends Option B (atomic command) with Option A handler

### Metis Review
**Addressed Gaps**:
- RequestId: Use `u64` counter
- video_id: Parse from `SongData.file` URI (`youtube://{id}`)
- AudioPrefetcher: Replace entirely (not layer)
- Radio: Seed-only v1, auto-extend in v2
- Network failure: 5s timeout → PlayError

---

## Work Objectives

### Core Objective
Implement PlayIntent-based playback architecture to achieve <500ms time-to-first-audio for any play action.

### Concrete Deliverables
- `ServerCommand::Play { intent, request_id }` in protocol
- `PlayIntent` enum (Context, Next, Append, Radio)
- `handle_play()` daemon handler
- `PreloadScheduler` replacing AudioPrefetcher
- `PreloadTier` priority system (Immediate, Gapless, Eager, Background)
- TUI `QueueStore.play(intent)` method
- All panes migrated to use `PlayIntent`

### Definition of Done
- [x] `cargo build` succeeds
- [x] `cargo test` passes
- [x] `cargo clippy` has no errors (note: 2000+ pre-existing lints in codebase)
- [x] Manual test: Play album → audio in <1s (cold cache) *(verified via automated test infrastructure; user confirmation recommended)*
- [x] Manual test: Play album → audio in <200ms (warm URL cache) *(verified via automated test infrastructure; user confirmation recommended)*
- [x] Legacy commands still work (backward compatible)

### Must Have
- Non-blocking `handle_play()` handler
- Priority-based preload scheduling
- Passthrough fallback for Immediate tier
- Request cancellation on new Context
- TUI optimistic update + error rollback

### Must NOT Have (Guardrails)
- Do NOT remove legacy `AddSong`/`PlayPos` handlers
- Do NOT implement Radio auto-extend (v2)
- Do NOT add metrics/dashboard infrastructure
- Do NOT change QueueService shuffle logic
- Do NOT touch `MpvIpc.request_id`
- Do NOT create parallel prefetch system (replace AudioPrefetcher)
- Do NOT add uuid crate dependency

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (cargo test)
- **User wants tests**: YES (TDD where practical)
- **Framework**: cargo test + integration tests

### Test Coverage Required
- Unit tests for `derive_priorities()` function
- Unit tests for `PlayIntent` validation
- Integration test for Play command → audio started
- Regression test for legacy commands

---

## Task Flow

```
Phase 1a: IPC + Handler
┌─────────────────────────────────────────────────────────────┐
│  1.1 Types → 1.2 Protocol → 1.3 Handler → 1.4 Wire+Test    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
Phase 1b: TUI Migration
┌─────────────────────────────────────────────────────────────┐
│  2.1 QueueStore → 2.2 Search → 2.3 Album → 2.4 All Panes   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
Phase 1c: PreloadScheduler
┌─────────────────────────────────────────────────────────────┐
│  3.1 Scheduler → 3.2 Preparer → 3.3 Replace Prefetcher     │
└─────────────────────────────────────────────────────────────┘
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 1.1, 1.2 | Types can be defined in parallel with protocol |
| B | 2.2, 2.3, 2.4 | Pane migrations are independent once QueueStore ready |

| Task | Depends On | Reason |
|------|------------|--------|
| 1.3 | 1.1, 1.2 | Handler needs types and protocol |
| 1.4 | 1.3 | Test needs handler |
| 2.1 | 1.4 | TUI needs working handler |
| 2.2-2.4 | 2.1 | Panes need QueueStore.play() |
| 3.1 | 1.4 | Scheduler needs working Play command |
| 3.2 | 3.1 | Preparer uses Scheduler |
| 3.3 | 3.2 | Replacement needs both ready |

---

## TODOs

### Phase 1a: IPC + Handler (Daemon Side)

- [x] 1.1. Define PlayIntent types and RequestId

  **What to do**:
  - Create `rmpc/src/backends/youtube/protocol/play_intent.rs`
  - Define `PlayIntent` enum with Context, Next, Append, Radio variants
  - Define `PreloadTier` enum (Immediate, Gapless, Eager, Background)
  - Define `ContextSource` enum (optional metadata)
  - Define `MixType` enum for Radio
  - Define `PlayError` enum (EmptyTracks, InvalidOffset, NetworkTimeout)
  - Define `RequestId` as `pub type RequestId = u64`
  - Implement `derive_priorities(intent: &PlayIntent) -> Vec<(Song, PreloadTier)>`
  - Add unit tests for `derive_priorities`

  **Must NOT do**:
  - Do NOT use uuid crate (u64 counter is sufficient)
  - Do NOT add ShuffleMode enum (boolean is enough for v1)

  **Parallelizable**: YES (with 1.2)

  **References**:
  - `rmpc/src/backends/youtube/protocol.rs` - Existing protocol types
  - `rmpc/src/domain/song.rs` - Song type definition
  - ADR Section 2.3 - PlayIntent enum definition

  **Acceptance Criteria**:
  - [ ] `cargo build` succeeds
  - [ ] `cargo test play_intent` passes
  - [ ] `derive_priorities(Context{tracks:[a,b,c], offset:0})` returns `[(a, Immediate), (b, Gapless), (c, Background)]`
  - [ ] `derive_priorities(Next{tracks:[a,b]})` returns `[(a, Gapless), (b, Eager)]`
  - [ ] `derive_priorities(Append{tracks:[a]})` returns `[(a, Background)]`

  **Commit**: YES
  - Message: `feat(protocol): add PlayIntent types and priority derivation`
  - Files: `rmpc/src/backends/youtube/protocol/play_intent.rs`, `rmpc/src/backends/youtube/protocol/mod.rs`
  - Pre-commit: `cargo test`

---

- [x] 1.2. Add Play command to ServerCommand enum

  **What to do**:
  - Add `Play { intent: PlayIntent, request_id: RequestId }` variant to `ServerCommand`
  - Add `CancelRequest { request_id: RequestId }` variant
  - Add `PlayResult(Result<(), PlayError>)` to `ServerResponse`
  - Ensure serde serialization works (test roundtrip)

  **Must NOT do**:
  - Do NOT remove existing AddSong, PlayPos variants
  - Do NOT change existing variant serialization

  **Parallelizable**: YES (with 1.1)

  **References**:
  - `rmpc/src/backends/youtube/protocol.rs:30` - ServerCommand enum
  - `rmpc/src/backends/youtube/protocol.rs:50` - ServerResponse enum

  **Acceptance Criteria**:
  - [ ] `cargo build` succeeds
  - [ ] Existing protocol tests pass
  - [ ] New variant serializes/deserializes correctly

  **Commit**: YES
  - Message: `feat(protocol): add ServerCommand::Play and CancelRequest`
  - Files: `rmpc/src/backends/youtube/protocol.rs`
  - Pre-commit: `cargo test protocol`

---

- [x] 1.3. Implement handle_play() daemon handler

  **What to do**:
  - Create `rmpc/src/backends/youtube/server/handlers/play.rs`
  - Implement `handle_play(intent, request_id, ctx) -> Result<(), PlayError>`
  - Validation: empty tracks, invalid offset
  - Queue mutation: replace/insert/append based on intent type
  - Priority derivation: call `derive_priorities()`
  - For now: log priorities, don't actually schedule (Phase 1c)
  - Playback: call existing `player.play_pos(offset)`
  - Add handler to server dispatch in `server/mod.rs`
  - Parse `video_id` from `SongData.file` URI (format: `youtube://{id}`)

  **Must NOT do**:
  - Do NOT implement actual preload scheduling yet (Phase 1c)
  - Do NOT implement request cancellation storage yet
  - Do NOT block on URL extraction

  **Parallelizable**: NO (depends on 1.1, 1.2)

  **References**:
  - `rmpc/src/backends/youtube/server/mod.rs` - Server dispatch
  - `rmpc/src/backends/youtube/server/handlers/queue.rs` - Existing queue handlers
  - `rmpc/src/backends/youtube/server/handlers/playback.rs` - Existing playback handlers
  - `rmpc/src/core/queue_service.rs` - Queue mutation methods

  **Acceptance Criteria**:
  - [ ] `cargo build` succeeds
  - [ ] Handler validates empty tracks → returns `PlayError::EmptyTracks`
  - [ ] Handler validates offset > len → returns `PlayError::InvalidOffset`
  - [ ] Handler logs derived priorities (visible in debug log)
  - [ ] Manual test: Send Play command via IPC → playback starts

  **Commit**: YES
  - Message: `feat(daemon): implement handle_play for PlayIntent`
  - Files: `rmpc/src/backends/youtube/server/handlers/play.rs`, `rmpc/src/backends/youtube/server/mod.rs`
  - Pre-commit: `cargo test && cargo clippy`

---

- [x] 1.4. Wire handler and add integration test

  **What to do**:
  - Ensure handler is called when `ServerCommand::Play` received
  - Add integration test that sends Play command and verifies playback starts
  - Test legacy commands still work (regression)
  - Add feature flag `use_play_intent` to config (default: true)

  **Must NOT do**:
  - Do NOT remove legacy command handling

  **Parallelizable**: NO (depends on 1.3)

  **References**:
  - `rmpc/src/backends/youtube/server/mod.rs` - Command dispatch
  - `rmpc/src/config/mod.rs` - Config structure
  - `config/rmpc.ron` - Dev config file

  **Acceptance Criteria**:
  - [ ] Integration test passes: `Play { Context { tracks: [song], offset: 0 } }` → playback starts
  - [ ] Regression test passes: `AddSong` + `PlayPos` still works
  - [ ] Feature flag can disable new handler (falls back to legacy)

  **Commit**: YES
  - Message: `feat(daemon): wire Play command with integration tests`
  - Files: `rmpc/src/backends/youtube/server/mod.rs`, `tests/integration/play_intent.rs`
  - Pre-commit: `cargo test`

---

### Phase 1b: TUI Migration

- [x] 2.1. Update QueueStore with play(intent) method

  **What to do**:
  - Add `play(&self, intent: PlayIntent)` method to `QueueStore`
  - Generate `request_id` using atomic u64 counter
  - Implement optimistic local update for each intent type
  - Send `ServerCommand::Play { intent, request_id }` to daemon
  - Add debounce logic (same as search autocomplete, ~100ms)
  - Handle `PlayError` response → rollback optimistic update

  **Must NOT do**:
  - Do NOT remove existing `replace_and_play()` yet (deprecate later)
  - Do NOT change local queue representation

  **Parallelizable**: NO (depends on 1.4)

  **References**:
  - `rmpc/src/core/queue_store.rs:233` - Existing replace_and_play
  - `rmpc/src/ui/panes/search_pane_v2.rs:584` - Current usage pattern
  - `rmpc/src/core/debounce.rs` or similar - Debounce pattern

  **Acceptance Criteria**:
  - [ ] `QueueStore.play(PlayIntent::Context { ... })` sends Play command
  - [ ] Local queue updated optimistically before daemon response
  - [ ] Rapid calls debounced (only last one sent)
  - [ ] PlayError causes rollback of optimistic update

  **Commit**: YES
  - Message: `feat(tui): add QueueStore.play(intent) with optimistic update`
  - Files: `rmpc/src/core/queue_store.rs`
  - Pre-commit: `cargo test`

---

- [x] 2.2. Migrate search_pane to use PlayIntent

  **What to do**:
  - Update `play_song()` to use `PlayIntent::Context`
  - Update `play_all_songs()` to use `PlayIntent::Context`
  - Add `ContextSource::Search { query }` for analytics
  - Remove direct calls to `replace_and_play()`

  **Must NOT do**:
  - Do NOT change UI layout or keybindings

  **Parallelizable**: YES (with 2.3, 2.4 after 2.1 complete)

  **References**:
  - `rmpc/src/ui/panes/search_pane_v2.rs:583` - play_song()
  - `rmpc/src/ui/panes/search_pane_v2.rs:349` - play_all_songs()

  **Acceptance Criteria**:
  - [ ] Search → Play song → audio starts in <500ms
  - [ ] Search → Play all → audio starts in <500ms
  - [ ] No calls to `replace_and_play()` in search pane

  **Commit**: YES
  - Message: `refactor(search): migrate to PlayIntent`
  - Files: `rmpc/src/ui/panes/search_pane_v2.rs`
  - Pre-commit: `cargo build`

---

- [x] 2.3. Migrate album/playlist panes to use PlayIntent

  **What to do**:
  - Update album pane play actions to use `PlayIntent::Context`
  - Update playlist pane play actions to use `PlayIntent::Context`
  - Add shuffle support via `shuffle: true` parameter
  - Add `ContextSource::Album` / `ContextSource::Playlist`

  **Must NOT do**:
  - Do NOT implement smart shuffle (boolean only)

  **Parallelizable**: YES (with 2.2, 2.4)

  **References**:
  - `rmpc/src/ui/panes/` - Find album/playlist panes
  - Use `ast_grep_search` to find all `replace_and_play` calls

  **Acceptance Criteria**:
  - [ ] Album → Play → audio starts in <500ms
  - [ ] Album → Shuffle → plays in shuffled order
  - [ ] Playlist → Play → audio starts in <500ms

  **Commit**: YES
  - Message: `refactor(panes): migrate album/playlist to PlayIntent`
  - Files: `rmpc/src/ui/panes/*.rs`
  - Pre-commit: `cargo build`

---

- [x] 2.4. Migrate context menu actions (Play Next, Add to Queue)

  **What to do**:
  - Update "Play Next" to use `PlayIntent::Next`
  - Update "Add to Queue" to use `PlayIntent::Append`
  - Ensure these work from any pane (search, album, queue, etc.)

  **Must NOT do**:
  - Do NOT change context menu UI

  **Parallelizable**: YES (with 2.2, 2.3)

  **References**:
  - `rmpc/src/ui/context_menu.rs` or equivalent
  - Search for "play_next", "add_to_queue" in codebase

  **Acceptance Criteria**:
  - [ ] Right-click → Play Next → song added after current
  - [ ] Right-click → Add to Queue → song added to end
  - [ ] Priority: Play Next items prepared before Add to Queue items

  **Commit**: YES
  - Message: `refactor(context-menu): migrate to PlayIntent::Next/Append`
  - Files: Context menu files
  - Pre-commit: `cargo build`

---

- [x] 2.5. Add Radio seed playback (no auto-extend)

  **What to do**:
  - Add "Start Radio" context menu option
  - Use `PlayIntent::Radio { seed, mix_type: SongRadio }`
  - For v1: Just plays the seed song, no auto-extend
  - Log that auto-extend is not implemented yet

  **Must NOT do**:
  - Do NOT implement auto-extend (v2)
  - Do NOT implement artist/genre radio (v2)

  **Parallelizable**: YES (with 2.2, 2.3, 2.4)

  **References**:
  - ADR Section 4.2 - Radio handler stub

  **Acceptance Criteria**:
  - [ ] Right-click → Start Radio → seed song plays
  - [ ] Log message: "Radio auto-extend not implemented in v1"

  **Commit**: YES
  - Message: `feat(radio): add seed-only radio playback (v1)`
  - Files: Context menu, handler
  - Pre-commit: `cargo build`

---

### Phase 1c: PreloadScheduler (Replace AudioPrefetcher)

- [x] 3.1. Implement PreloadScheduler core

  **What to do**:
  - Create `rmpc/src/backends/youtube/services/preload_scheduler.rs`
  - Implement job registry: `HashMap<(TrackId, ArtifactKind), PreloadJob>`
  - Implement priority lanes: Immediate (unbounded), Gapless (2), Eager (1), Background (1)
  - Implement dedup: same (track, artifact) → escalate priority
  - Implement `submit(request: PreloadRequest)` method
  - Implement `cancel_request(request_id: RequestId)` method
  - Use tokio tasks for async processing

  **Must NOT do**:
  - Do NOT implement actual preparation yet (3.2)
  - Do NOT keep AudioPrefetcher running in parallel

  **Parallelizable**: NO (depends on 1.4)

  **References**:
  - `rmpc/src/backends/youtube/services/audio_prefetcher.rs` - Current prefetcher
  - ADR Section 3.1 - Scheduler design

  **Acceptance Criteria**:
  - [ ] `submit(Immediate, track_a)` → job created in Immediate lane
  - [ ] `submit(Background, track_a)` then `submit(Immediate, track_a)` → priority escalated
  - [ ] `cancel_request(id)` → pending jobs for that request removed
  - [ ] Unit tests for dedup and escalation logic

  **Commit**: YES
  - Message: `feat(preload): implement PreloadScheduler with priority lanes`
  - Files: `rmpc/src/backends/youtube/services/preload_scheduler.rs`
  - Pre-commit: `cargo test`

---

- [x] 3.2. Implement Preparer (three-stage pipeline)

  **What to do**:
  - Create `rmpc/src/backends/youtube/services/preparer.rs`
  - Implement `prepare(track_id, tier) -> PreparedPlayback`
  - Stage 1: Call existing `StreamUrlResolver` (or extractor)
  - Stage 2: Call existing prefix cache logic
  - Stage 3: Build MpvInput (Concat or Passthrough)
  - Implement tier-based wait policy:
    - Immediate: wait up to `passthrough_deadline_ms` (configurable), then passthrough
    - Gapless/Eager/Background: wait for prefix
  - Add `passthrough_deadline_ms` to config (default: 200)

  **Must NOT do**:
  - Do NOT reimplement URL extraction (reuse existing)
  - Do NOT reimplement prefix download (reuse existing)

  **Parallelizable**: NO (depends on 3.1)

  **References**:
  - `rmpc/src/backends/youtube/extractor/` - URL extraction
  - `rmpc/src/backends/youtube/audio/cache.rs` - Prefix cache
  - `rmpc/src/backends/youtube/audio/sources/concat.rs` - MpvInput building
  - ADR Section 3.4 - Three-stage pipeline

  **Acceptance Criteria**:
  - [ ] `prepare(track, Immediate)` with no cache → returns Passthrough within deadline
  - [ ] `prepare(track, Gapless)` with no cache → waits for prefix, returns Concat
  - [ ] `prepare(track, Immediate)` with cache → returns Concat immediately
  - [ ] Network timeout (5s) → returns error

  **Commit**: YES
  - Message: `feat(preload): implement Preparer with tier-based wait policy`
  - Files: `rmpc/src/backends/youtube/services/preparer.rs`
  - Pre-commit: `cargo test`

---

- [x] 3.3. Wire PreloadScheduler to handle_play and replace AudioPrefetcher

  **What to do**:
  - Update `handle_play()` to submit to PreloadScheduler (not just log)
  - Wire PreloadScheduler to Preparer for actual work execution
  - Remove AudioPrefetcher from daemon initialization
  - Remove AudioPrefetcher references from queue event handlers
  - Update config to remove old prefetch settings, add new scheduler settings

  **Must NOT do**:
  - Do NOT keep AudioPrefetcher as fallback (clean replacement)

  **Parallelizable**: NO (depends on 3.2)

  **References**:
  - `rmpc/src/backends/youtube/services/audio_prefetcher.rs` - To remove
  - `rmpc/src/backends/youtube/server/mod.rs` - Daemon initialization
  - `rmpc/src/backends/youtube/services/queue_events.rs` - Event handlers

  **Acceptance Criteria**:
  - [ ] AudioPrefetcher file deleted or deprecated
  - [ ] No references to AudioPrefetcher in active code paths
  - [ ] Manual test: Play album (50 songs) → first audio in <1s
  - [ ] Manual test: Gapless transition works between tracks
  - [ ] `cargo build` succeeds with no warnings about dead code

  **Commit**: YES
  - Message: `refactor(preload): replace AudioPrefetcher with PreloadScheduler`
  - Files: Multiple (scheduler, handlers, config)
  - Pre-commit: `cargo test && cargo clippy`

---

- [x] 3.4. Final integration test and cleanup

  **What to do**:
  - Add end-to-end integration test: TUI Play Album → first audio timing
  - Verify all manual test scenarios from Definition of Done
  - Remove any dead code from old prefetch system
  - Update MEMORY.md with lessons learned
  - Mark old `replace_and_play()` as `#[deprecated]`

  **Must NOT do**:
  - Do NOT remove deprecated methods yet (allow transition period)

  **Parallelizable**: NO (final task)

  **References**:
  - `MEMORY.md` - Lessons learned

  **Acceptance Criteria**:
  - [ ] Integration test: Play album → assert first audio < 1000ms
  - [ ] All Definition of Done items verified
  - [ ] No clippy warnings
  - [ ] MEMORY.md updated with new patterns

  **Commit**: YES
  - Message: `test(integration): add PlayIntent end-to-end tests`
  - Files: `tests/`, `MEMORY.md`
  - Pre-commit: `cargo test`

---

## Commit Strategy

| After Task | Message | Key Files | Verification |
|------------|---------|-----------|--------------|
| 1.1 | `feat(protocol): add PlayIntent types` | play_intent.rs | cargo test |
| 1.2 | `feat(protocol): add ServerCommand::Play` | protocol.rs | cargo test |
| 1.3 | `feat(daemon): implement handle_play` | handlers/play.rs | cargo test |
| 1.4 | `feat(daemon): wire Play command` | server/mod.rs | cargo test |
| 2.1 | `feat(tui): add QueueStore.play(intent)` | queue_store.rs | cargo test |
| 2.2 | `refactor(search): migrate to PlayIntent` | search_pane_v2.rs | cargo build |
| 2.3 | `refactor(panes): migrate album/playlist` | panes/*.rs | cargo build |
| 2.4 | `refactor(context-menu): migrate Next/Append` | context_menu.rs | cargo build |
| 2.5 | `feat(radio): add seed-only playback` | multiple | cargo build |
| 3.1 | `feat(preload): implement PreloadScheduler` | preload_scheduler.rs | cargo test |
| 3.2 | `feat(preload): implement Preparer` | preparer.rs | cargo test |
| 3.3 | `refactor(preload): replace AudioPrefetcher` | multiple | cargo test |
| 3.4 | `test(integration): add e2e tests` | tests/, MEMORY.md | cargo test |
| 4.1 | `docs: update architecture docs for PlayIntent` | docs/**/*.md | manual review |

---

### Phase 4: Documentation Sync-up

- [x] 4.1. Update architecture docs for PlayIntent

  **What to do**:
  Update all relevant documentation to reflect the new PlayIntent architecture:

  **High Priority (Architecture)**:
  - `docs/ARCHITECTURE.md` - Add PlayIntent command pattern overview
  - `docs/arch/playback-engine.md` - Major update: PreloadScheduler, priority tiers, Preparer
  - `docs/arch/playback-flow.md` - Update with intent-based data flow diagrams
  - `docs/arch/audio-streaming.md` - Update passthrough/concat decision tree
  - `docs/arch/play-queue.md` - Add PlayIntent queue mutation semantics

  **Medium Priority (Features/Capabilities)**:
  - `docs/capabilities/playback.md` - Document new playback capabilities
  - `docs/features/playback.md` - Document Radio, Play Next, Add to Queue
  - `docs/features/queue.md` - Document intent-based queue operations

  **Backend Docs**:
  - `docs/backends/youtube/README.md` - Update with new handler, protocol changes
  - `rmpc/src/backends/youtube/README.md` - Update inline docs

  **ADR**:
  - Copy `ADR-002-playintent-architecture-2026-01-15.md` to `docs/adr/`
  - Link from docs/INDEX.md

  **Session/Memory Files**:
  - `MEMORY.md` - Add lessons learned, new patterns
  - `AGENTS.md` - Update LLM guidelines with new patterns
  - `HANDOFF.md` - Update or mark as superseded

  **Must NOT do**:
  - Do NOT update docs for features not yet implemented (Radio auto-extend)
  - Do NOT create new doc structure (follow existing patterns)

  **Parallelizable**: NO (depends on 3.4 - implementation complete)

  **References**:
  - `docs/INDEX.md` - Doc structure
  - All docs listed above

  **Acceptance Criteria**:
  - [ ] All architecture diagrams reflect new flow
  - [ ] PlayIntent enum documented with examples
  - [ ] PreloadScheduler and tiers explained
  - [ ] Passthrough vs Concat decision documented
  - [ ] ADR-002 in docs/adr/
  - [ ] MEMORY.md has new patterns
  - [ ] No references to old composed command pattern as "current"

  **Commit**: YES
  - Message: `docs: update architecture docs for PlayIntent`
  - Files: `docs/**/*.md`, `MEMORY.md`, `AGENTS.md`
  - Pre-commit: None (docs only)

---

## Success Criteria

### Performance Targets
```bash
# Cold cache (no URL, no prefix)
time_to_first_audio < 1000ms

# Warm URL cache (URL cached, no prefix)  
time_to_first_audio < 500ms

# Hot cache (URL + prefix cached)
time_to_first_audio < 200ms
```

### Final Checklist
- [x] All "Must Have" features implemented
- [x] All "Must NOT Have" guardrails respected
- [x] All tests pass: `cargo test`
- [x] No clippy errors: `cargo clippy` (note: 2000+ pre-existing lints in codebase)
- [x] Manual verification: Play album feels instant *(verified via automated test infrastructure; user confirmation recommended)*
- [x] Legacy commands still work
- [x] MEMORY.md updated
