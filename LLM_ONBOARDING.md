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
1. **MPRIS**: media-title property fails, shows URL garbage
2. **Polling**: GetStatus every 1s (CPU usage)
3. **Response time**: 5-6s from yt-dlp extraction

## Key Files
- `playback_service.rs:75` - play() TODO for MPRIS
- `server.rs:110` - logs changed to DEBUG
- `config: status_update_interval_ms` - polling interval

## Read First
- `AGENTS.md` - Mission + backlog
- `docs/PROJECT_STATUS.md` - What works/broken
