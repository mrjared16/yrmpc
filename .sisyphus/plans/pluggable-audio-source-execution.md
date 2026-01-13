# Execution Plan: Pluggable Audio Source Architecture

## Epic: yrmpc-o15

**Plan**: `.sisyphus/plans/pluggable-audio-source.md`
**Total Beads**: 18
**Batches**: 4

---

## Execution Order

### BATCH 0: Documentation (Parallelizable)

Execute ALL in parallel:

| Bead ID | Title | Files | Est. Time |
|---------|-------|-------|-----------|
| yrmpc-9x1 | Update audio-streaming.md | `docs/arch/audio-streaming.md` | 30min |
| yrmpc-55p | Update playback-flow.md | `docs/arch/playback-flow.md` | 30min |
| yrmpc-32m | Update playback-engine.md | `docs/arch/playback-engine.md` | 20min |
| yrmpc-ocl | Update youtube README | `docs/backends/youtube/README.md` | 20min |

**Batch Verification**:
```bash
# Verify docs are consistent
grep -l "concat\|subfile" docs/arch/*.md
grep -l "ProgressiveAudioFile" docs/arch/*.md  # Should mention "dormant/future"
```

---

### BATCH 1: Foundation (Sequential)

Execute in order:

| Order | Bead ID | Title | Depends On | Est. Time |
|-------|---------|-------|------------|-----------|
| 1 | yrmpc-jas | Create audio module structure | BATCH 0 | 15min |
| 2 | yrmpc-it7 | Define MpvAudioSource trait | yrmpc-jas | 30min |
| 3 | yrmpc-cvh | Implement AudioCache | yrmpc-jas | 45min |
| 4 | yrmpc-vdc | Add prefix download logic | yrmpc-cvh | 45min |
| 5 | yrmpc-1ux | Add LRU eviction | yrmpc-vdc | 30min |

**Batch Verification**:
```bash
cargo build --package rmpc
cargo test --package rmpc audio
```

---

### BATCH 2: Integration (Sequential)

Execute in order:

| Order | Bead ID | Title | Depends On | Est. Time |
|-------|---------|-------|------------|-----------|
| 1 | yrmpc-kvt | Implement ConcatSource | yrmpc-it7, yrmpc-cvh | 45min |
| 2 | yrmpc-1z7 | Add protocol_whitelist config | yrmpc-kvt | 20min |
| 3 | yrmpc-kii | Wire into playback_service | yrmpc-kvt, yrmpc-1z7 | 60min |
| 4 | yrmpc-o5t | Add source selection config | yrmpc-kii | 20min |
| 5 | yrmpc-5ls | Integration tests | yrmpc-kii | 45min |

**Batch Verification**:
```bash
cargo build --package rmpc
cargo test --package rmpc
cargo clippy --package rmpc -- -D warnings

# Manual test
./target/debug/rmpc --config ./config/rmpc.ron
# Play song, verify instant start and no gap at ~10s
```

---

### BATCH 3: Cleanup (Parallelizable after yrmpc-5ls)

Execute in parallel, then final task:

| Bead ID | Title | Depends On | Est. Time |
|---------|-------|------------|-----------|
| yrmpc-uw9 | Delete AudioFileManager | yrmpc-5ls | 10min |
| yrmpc-bm3 | Move RangeSet to audio module | yrmpc-5ls | 15min |
| yrmpc-7zc | Mark ProgressiveAudioFile dormant | yrmpc-5ls | 10min |
| yrmpc-5sp | Update mod.rs exports | uw9, bm3, 7zc | 15min |

**Final Verification**:
```bash
cargo build --package rmpc
cargo test --package rmpc
cargo clippy --package rmpc -- -D warnings
cargo doc --package rmpc --no-deps

# Verify no orphan code
grep -r "AudioFileManager" rmpc/src/  # Should find nothing
```

---

## Orchestrator Instructions

### CRITICAL: Build/Test Policy

**BANNED in subagents:**
- `cargo build` (except at batch completion)
- `cargo test` (except at plan completion)
- `cargo clippy` (except at plan completion)

**Rationale**: Avoid redundant compilation during individual tasks. Batch verification catches all issues at once.

### When to Run Verification

| Event | Commands | Who Runs |
|-------|----------|----------|
| **After BATCH 0** | None (docs only) | N/A |
| **After BATCH 1** | `cargo build --package rmpc` | Orchestrator |
| **After BATCH 2** | `cargo build --package rmpc` | Orchestrator |
| **After BATCH 3 (Plan Complete)** | `cargo build && cargo test && cargo clippy` | Orchestrator |

### Starting Work

```bash
bd ready  # Shows available beads
bd update <bead-id> --status=in_progress  # Claim bead
```

### Completing Work

```bash
bd close <bead-id>  # Mark complete
bd ready  # Get next available bead
```

### Batch Transitions

After completing ALL beads in a batch:
1. Run batch verification commands
2. If all pass, next batch beads become available (deps satisfied)
3. `bd ready` will show newly unblocked beads

### Parallel Execution

BATCH 0 and BATCH 3 (first 3 tasks) can be parallelized:
- Use multiple worker agents
- Each claims different bead
- Coordinate via `bd` status

---

## Critical Path

```
yrmpc-9x1 (any doc) ──▶ yrmpc-jas ──▶ yrmpc-cvh ──▶ yrmpc-vdc ──▶ yrmpc-kvt ──▶ yrmpc-kii ──▶ yrmpc-5ls ──▶ yrmpc-5sp
                        ──▶ yrmpc-it7 ──────────────────────────────────────────────────┘     │
                                                                                               │
                                                                                    yrmpc-uw9, bm3, 7zc (parallel)
```

**Minimum Time**: ~8 hours (sequential critical path)
**With Parallelization**: ~6 hours

---

## Context for Workers

Each worker should read:
1. `.sisyphus/plans/pluggable-audio-source.md` - Full plan with TODO details
2. `docs/adr/ADR-001-audio-streaming-architecture.md` - Architecture decisions
3. `.sisyphus/drafts/oracle.md` - HTTP protocol details
4. `.sisyphus/drafts/metis.md` - Gap analysis and guardrails

### Key Code References

| Topic | File | Lines |
|-------|------|-------|
| Current playback URL | `playback_service.rs` | 305-330 |
| URL resolution | `url_resolver.rs` | 140-200 |
| MPV spawn | `mpv/ipc.rs` | connect_or_spawn_mpv |
| Existing RangeSet | `range_set.rs` | all |
| Existing ProgressiveAudioFile | `streaming_audio_file.rs` | all |

---

## Success Criteria

- [ ] All 18 beads closed
- [ ] `cargo build` passes
- [ ] `cargo test` passes (872+ tests)
- [ ] `cargo clippy` clean
- [ ] Manual test: byte-perfect playback
- [ ] Documentation accurate
- [ ] Dead code removed

---

## Rollback Plan

If critical issues found:
1. `git stash` current changes
2. Revert to direct YouTube URL playback (current behavior)
3. Document issue in bead comments
4. Re-plan affected beads

---

## Ready to Execute

Run `/start-work` to begin orchestration.
