# LLM Onboarding - yrmpc

**Status**: Playable but Terrible UX  
**Updated**: 2025-12-07

## Quick Start
```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config setup/config.ron
```

## Current State
- Search + Enter → plays song (5-6s delay)
- Queue updates after adding

## Open Bugs (Backlog)
1. ~~**MPRIS**~~: ✅ Fixed (force-media-title before loadfile)
2. **P0: Enter on song doesn't play** - adds to queue but no playback
3. **P0: Clear queue doesn't stop MPV** - likely root cause of #2
4. **Polling**: GetStatus every 1s (CPU usage)
5. **Response time**: 5-6s from yt-dlp extraction

## Key Files
- `playback_service.rs:75` - play() with MPRIS fix
- `server.rs:110` - logs changed to DEBUG
- `config: status_update_interval_ms` - polling interval

## Read First
- `AGENTS.md` - Mission + backlog
- `docs/PROJECT_STATUS.md` - What works/broken
