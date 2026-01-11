# Decisions Log: Unified Streaming Audio File

## Requirements Clarified

| Original | Clarified |
|----------|-----------|
| "Gapless streaming" | Zero audible artifact at any point during playback, including cache-to-stream boundary |
| "Instant playback" | Any queued song plays immediately (<100ms latency) when selected |
| "Limited disk space" | Max ~100MB for audio cache, LRU eviction required |
| "Future crossfade" | Architecture must support having two tracks decoded simultaneously |

## Key Decisions

### Decision 1: Unified Temp File vs EDL Splice

**Context**: Current EDL approach causes 20ms glitch at cache-to-stream boundary.

**Options**:
1. EDL splice (current) - Two sources, decoder reinit
2. HTTP proxy - Serve cache+stream as one response
3. Unified temp file - Single file, progressive download

**Decision**: Option 3 - Unified temp file

**Rationale**:
- ONE decoder session = zero reinit glitch
- File-based = seekable (unlike pipe/FIFO)
- Less complexity than HTTP proxy
- Proven pattern (librespot uses this)

**Trade-offs**:
- (+) Zero audio artifacts
- (+) Seekable
- (-) More complex than EDL
- (-) Need RangeSet for byte tracking

### Decision 2: Prefetch Strategy

**Context**: Queue can have 10-100 songs, can't download all.

**Options**:
1. Download ALL queued songs (~800MB for 100 songs)
2. Download only current song
3. Sliding window: Current(full) + Next(full) + Next+2,3(30s)

**Decision**: Option 3 - Sliding window

**Rationale**:
- Balances instant start with disk usage
- 30s prefetch = enough buffer to complete download before playback
- ~19MB typical usage, ~50MB max

**Trade-offs**:
- (+) Low disk usage
- (+) Instant start for next track
- (-) Slight delay if skipping many tracks ahead

### Decision 3: Why 30s Prefetch (not shorter)

**Context**: User asked why 30s instead of shorter chunks.

**Calculation**:
- Song: 4 min = 8.3MB at 288kbps
- Network: 3Mbps typical = 0.375 MB/s
- Download time: 8.3MB / 0.375 = 22s
- Buffer margin: 30s - 22s = 8s for network variance

**Decision**: 30s prefetch for next+2, next+3 tracks

**Rationale**: Matches librespot's `PRELOAD_NEXT_TRACK_BEFORE_END = 30s`

### Decision 4: Resume Download (Not Restart)

**Context**: When track C is promoted from "30s prefetch" to "next", what happens?

**Decision**: RESUME download from byte 1.2MB, not restart

**Implementation**:
```
HTTP Range: bytes=1228800-
RangeSet already knows: [(0, 1228800)]
Continue from where we left off
```

### Decision 5: Temp File Location

**Context**: User specified .cache dir.

**Decision**: `~/.cache/rmpc/audio/{video_id}.webm.part`

**Eviction policy**: LRU when total > 100MB

## Assumptions

| Assumption | Impact if Wrong | Mitigation |
|------------|-----------------|------------|
| WebM clusters are self-contained | Decoder errors mid-cluster | Only expose complete clusters |
| YouTube supports HTTP Range | Download fails | Fall back to full download |
| MPV can read growing file | Playback stutters | Pre-buffer minimum bytes |
| 30s is enough buffer | Playback catches up to download | Show buffer indicator, increase prefetch |

## Scope Boundaries

### In Scope
- StreamingAudioFile implementation
- RangeSet byte tracking
- AudioFileManager with prefetch window
- LRU eviction
- Seek to undownloaded region
- URL expiration handling
- Remove legacy AudioCache/EDL

### Explicitly Out of Scope
- Crossfade implementation (future work)
- Gapless track-to-track (separate concern, uses --gapless-audio)
- Offline mode (no persistent cache)
- Quality selection (always 288kbps opus)
