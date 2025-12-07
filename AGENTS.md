# LLM Agent Guidelines - yrmpc

**Project**: YouTube Music TUI Client (Rust + Ratatui)  
**Updated**: 2025-12-08  
**Status**: ✅ Core Playable - Daily Use

---

## Quick Start
```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```

---

## Current State

| Feature | Status |
|---------|--------|
| Search (all types) | ✅ |
| Playback (MPV) | ✅ |
| Queue management | ✅ |
| MPRIS integration | ✅ |
| Daemon mode | ✅ |
| Autocomplete | ✅ |

---

## Next Priorities

| Priority | Task |
|----------|------|
| P1 | Rich List UI (thumbnail + 2-line) |
| P1 | High CPU idle (needs profiling) |
| P2 | API filtering (fetch only needed sections) |

---

## Key Files

| Purpose | File |
|---------|------|
| Search API | `player/youtube/api.rs` |
| Protocol | `player/youtube/protocol.rs` |
| Client | `player/youtube/client.rs` |
| Server | `player/youtube/server.rs` |
| SearchItem types | `domain/search/` |
| Config | `config/search.rs` |

---

## Read Order for New LLM

1. This file (`AGENTS.md`)
2. `LLM_ONBOARDING.md` - Research insights
3. `docs/ARCHITECTURE.md` - System design
4. `docs/FEATURES.md` - UX roadmap
5. `docs/YOUTUBE_API.md` - API reference
