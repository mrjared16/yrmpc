# Execution Plan: Unified Streaming Audio File Architecture

## Epic: yrmpc-26c - Unified Streaming Audio File Architecture

**ADR**: `.sisyphus/adr/001-unified-streaming-audio-file.md`
**Decisions**: `.beads/decisions.md`

---

## Phase 1: Core Infrastructure (No Dependencies)

| Bead | Title | Priority | Estimated |
|------|-------|----------|-----------|
| yrmpc-nrs | Implement RangeSet for byte tracking | P1 | 2-3 hours |

**Acceptance Criteria**:
- `RangeSet::new()`, `add_range()`, `contains()`, `contiguous_from()`
- Unit tests for merge, overlap, gap detection
- No external dependencies

---

## Phase 2: Streaming File (Depends on Phase 1)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-271 | Implement StreamingAudioFile struct | yrmpc-nrs | 4-6 hours |

**Acceptance Criteria**:
- Pre-allocate temp file to content-length
- Background download with Range header
- Separate read/write file handles
- Condvar for blocking reads until bytes available
- `path()`, `is_ready()`, `wait_for_bytes(offset, len)`

---

## Phase 3: Manager (Depends on Phase 2)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-mas | Implement AudioFileManager | yrmpc-271 | 4-6 hours |

**Acceptance Criteria**:
- `get_or_create(video_id, stream_url, content_length)`
- Track all active StreamingAudioFiles
- Download pool (max 3 concurrent)
- Basic LRU tracking (eviction in separate task)

---

## Phase 4: Integration (Depends on Phase 3)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-7vy | Integrate with PlaybackService | yrmpc-mas | 3-4 hours |

**Acceptance Criteria**:
- Replace `build_playback_url()` EDL logic with file path
- MPV loads `audio_file.path()` directly
- Verify: instant start, no 20ms glitch, seek works

---

## Phase 5: Advanced Features (Parallel after Phase 4)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-cis | Implement sliding prefetch window | yrmpc-7vy | 3-4 hours |
| yrmpc-x66 | Implement T-30s prefetch trigger | yrmpc-7vy | 2-3 hours |
| yrmpc-vpc | Implement LRU eviction policy | yrmpc-mas | 2-3 hours |

---

## Phase 6: Edge Cases (Parallel after Phase 4)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-6gi | Handle seek to undownloaded region | yrmpc-7vy | 3-4 hours |
| yrmpc-4mn | Handle URL expiration and re-resolve | yrmpc-7vy | 2-3 hours |

---

## Phase 7: Cleanup (After All Above)

| Bead | Title | Blocked By | Estimated |
|------|-------|------------|-----------|
| yrmpc-d9h | Remove legacy AudioCache and EDL code | yrmpc-7vy | 1-2 hours |

---

## Dependency Graph

```
yrmpc-nrs (RangeSet)
    │
    ▼
yrmpc-271 (StreamingAudioFile)
    │
    ▼
yrmpc-mas (AudioFileManager) ──────┬──────────────────┐
    │                              │                  │
    ▼                              ▼                  ▼
yrmpc-7vy (Integration)      yrmpc-vpc (LRU)    (other managers)
    │
    ├──────────┬──────────┬──────────┬──────────┐
    ▼          ▼          ▼          ▼          ▼
yrmpc-cis  yrmpc-x66  yrmpc-6gi  yrmpc-4mn  yrmpc-d9h
(prefetch) (T-30s)    (seek)     (URL exp)  (cleanup)
```

---

## Ready to Start

```
bd ready → yrmpc-nrs (RangeSet for byte tracking)
```

---

## Total Estimated Effort

| Phase | Hours |
|-------|-------|
| Phase 1 (RangeSet) | 2-3 |
| Phase 2 (StreamingAudioFile) | 4-6 |
| Phase 3 (Manager) | 4-6 |
| Phase 4 (Integration) | 3-4 |
| Phase 5 (Advanced) | 7-10 |
| Phase 6 (Edge Cases) | 5-7 |
| Phase 7 (Cleanup) | 1-2 |
| **Total** | **26-38 hours** |

---

## Related Issues

| Bead | Title | Status |
|------|-------|--------|
| yrmpc-ofg | 1-item queue repeats after EOF despite RepeatMode::Off | Open (separate bug) |
