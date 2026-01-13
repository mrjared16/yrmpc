# Beads Execution Plan Reference

This file tells beads-orchestrator where to find the plan artifacts.

## Plan Files

| Artifact | Location |
|----------|----------|
| **Work Plan** | `.sisyphus/plans/pluggable-audio-source.md` |
| **Execution Plan** | `.sisyphus/plans/pluggable-audio-source-execution.md` |
| **Decisions** | `docs/adr/ADR-001-audio-streaming-architecture.md` |
| **Oracle Consultation** | `.sisyphus/drafts/oracle.md` |
| **Metis Consultation** | `.sisyphus/drafts/metis.md` |

## Epic

**Epic ID**: `yrmpc-o15` - [EPIC] Pluggable Audio Source Architecture

## Batches

### BATCH 0: Documentation (Parallelizable)
| Bead ID | Title | Worker |
|---------|-------|--------|
| yrmpc-9x1 | Update audio-streaming.md | document-writer |
| yrmpc-55p | Update playback-flow.md | document-writer |
| yrmpc-32m | Update playback-engine.md | document-writer |
| yrmpc-ocl | Update youtube README | document-writer |

### BATCH 1: Foundation (Sequential)
| Bead ID | Title | Worker | Depends On |
|---------|-------|--------|------------|
| yrmpc-jas | Create audio module structure | sdd:developer | BATCH 0 |
| yrmpc-it7 | Define MpvAudioSource trait | sdd:developer | yrmpc-jas |
| yrmpc-cvh | Implement AudioCache | sdd:developer | yrmpc-jas |
| yrmpc-vdc | Add prefix download logic | sdd:developer | yrmpc-cvh |
| yrmpc-1ux | Add LRU eviction | sdd:developer | yrmpc-vdc |

### BATCH 2: Integration (Sequential)
| Bead ID | Title | Worker | Depends On |
|---------|-------|--------|------------|
| yrmpc-kvt | Implement ConcatSource | sdd:developer | yrmpc-it7, yrmpc-cvh |
| yrmpc-1z7 | Add protocol_whitelist config | sdd:developer | yrmpc-kvt |
| yrmpc-kii | Wire into playback_service | sdd:developer | yrmpc-kvt, yrmpc-1z7 |
| yrmpc-o5t | Add source selection config | sdd:developer | yrmpc-kii |
| yrmpc-5ls | Integration tests | sdd:developer | yrmpc-kii |

### BATCH 3: Cleanup (Parallelizable after yrmpc-5ls)
| Bead ID | Title | Worker | Depends On |
|---------|-------|--------|------------|
| yrmpc-uw9 | Delete AudioFileManager | sdd:developer | yrmpc-5ls |
| yrmpc-bm3 | Move RangeSet to audio module | sdd:developer | yrmpc-5ls |
| yrmpc-7zc | Mark ProgressiveAudioFile dormant | sdd:developer | yrmpc-5ls |
| yrmpc-5sp | Update mod.rs exports | sdd:developer | yrmpc-uw9, yrmpc-bm3, yrmpc-7zc |

## Build/Test Policy

**BANNED in subagents:**
- `cargo build` - Only at batch completion
- `cargo test` - Only at plan completion
- `cargo clippy` - Only at plan completion

| Event | Commands | Who |
|-------|----------|-----|
| After BATCH 0 | None | N/A |
| After BATCH 1 | `cargo build --package rmpc` | Orchestrator |
| After BATCH 2 | `cargo build --package rmpc` | Orchestrator |
| After BATCH 3 | `cargo build && cargo test && cargo clippy` | Orchestrator |

## Worker Context

Workers should read:
1. `.sisyphus/plans/pluggable-audio-source.md` - Full TODO details
2. `docs/adr/ADR-001-audio-streaming-architecture.md` - Architecture decisions

## Start Execution

```bash
bd ready  # Shows: yrmpc-9x1, yrmpc-55p, yrmpc-32m, yrmpc-ocl (BATCH 0)
```
