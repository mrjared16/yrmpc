# AGENTS.md - LLM Agent Guidelines

**Project**: yrmpc - YouTube Music TUI Client (Rust + Ratatui)
**Memory**: [MEMORY.md](MEMORY.md) (patterns, lessons learned)

---

## Quick Start

```bash
cd rmpc && cargo build              # Debug build (~45s, use for dev)
./restart_daemon_debug.sh          # Start daemon with debug logging
./rmpc/target/debug/rmpc --config ./config/rmpc.ron  # Start TUI
```

**Verify changes**: `cargo fmt && cargo clippy && cargo test`

> **Note**: Only use `--release` after confirming all changes work. Release build takes ~4 min.

---

## Repo Layout

```
yrmpc/                          # Workspace root (NO Cargo.toml here)
├── rmpc/                       # Main crate - run cargo HERE
│   └── src/
│       ├── ui/panes/           # Navigator, Search, Queue panes
│       ├── backends/           # YouTube, MPD backends
│       │   └── api/            # Playback, Queue, Discovery traits
│       └── domain/             # Song, Album, Artist types
├── ytmapi-yrmpc/               # YouTube API submodule
├── .beads/                     # Issue tracking (tracked in git)
├── config/rmpc.ron             # Dev config
└── docs/                       # Architecture docs
```

### Key Files

| Purpose | Path |
|---------|------|
| UI Controller | `rmpc/src/ui/panes/navigator.rs` |
| Backend Router | `rmpc/src/backends/dispatcher.rs` |
| API Traits | `rmpc/src/backends/api/` |
| YouTube Protocol | `rmpc/src/backends/youtube/protocol.rs` |
| Domain Types | `rmpc/src/domain/` |
| Dev Config | `config/rmpc.ron` |

---

## Architecture

- **Navigator**: Central UI controller (when `legacy_panes.enabled=false`)
- **BackendDispatcher**: Routes commands to active backend
- **API Traits**: `api::Playback`, `api::Queue`, `api::Discovery` (preferred)
- **MusicBackend**: DEPRECATED - do not use

> Deep dives: [docs/INDEX.md](docs/INDEX.md) → arch/, features/, backends/

---

## Task Management (Beads)

```bash
bd ready                              # Find work (no blockers)
bd update <id> --status=in_progress   # Claim it
bd close <id>                         # Complete it
```

**Session close** (ephemeral branch, no push):
```bash
git add -A && git commit -m "..."
bd sync --from-main                   # Pull beads updates
```

**Use `bd` CLI only. Never edit .beads/ files directly.**

> Full beads docs: `bd --help` or beads-context in system prompt.

---

## Don'ts

| Don't | Why |
|-------|-----|
| Run cargo from `yrmpc/` | No Cargo.toml at root. Run from `rmpc/` |
| Skip daemon restart | Backend changes require `../restart_daemon_debug.sh` |
| Use yt-dlp in tests | ytx is default (200ms vs 4s). Python spawn breaks CI |
| Edit .beads/ directly | Use `bd` CLI. Files are git-tracked |
| Use --release for dev | 4 min build. Debug catches same errors in 45s |
| Touch MusicBackend trait | Deprecated. Use `api::Playback/Queue/Discovery` |
| Push to remote | Ephemeral branch. Merge to main locally |

---

## When to Restart Daemon

| Change Type | Restart Needed? |
|-------------|-----------------|
| Backend code (youtube/, mpd/) | Yes |
| Protocol/API changes | Yes |
| UI-only (panes, widgets) | No - just rebuild TUI |
| Config changes | Yes |
