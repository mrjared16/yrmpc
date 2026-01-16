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

**Verify changes**: `cargo fmt && cargo clippy && cargo nextest run`

> **Note**: Only use `--release` after confirming all changes work. Release build takes ~4 min.

---

## CRITICAL: Design for testability using "functional core, imperative shell"

- Keep pure business logic separate from code that does IO.

---

## CRITICAL: Cargo Commands

**ALWAYS run cargo from `rmpc/` directory, NOT from `yrmpc/` root.**

```bash
# CORRECT
cd rmpc && cargo build
cd rmpc && cargo test
cd rmpc && cargo clippy

# WRONG - will fail (no Cargo.toml at root)
cargo build  # from yrmpc/
```

There is NO `Cargo.toml` at the workspace root. The main crate is in `rmpc/`.

---

## CRITICAL: Integration Wiring Checklist

**Before marking any feature "complete", verify ALL integration points:**

### The "Incomplete Wiring" Anti-Pattern

A common bug pattern: implementing components that compile and pass unit tests, but are **never actually called** at runtime.

**Symptoms:**

- Feature works in tests but not in production
- Code exists but has no observable effect
- Stub methods (always return false/None) never replaced with real logic

### Mandatory Verification Steps

1. **Trace the call path**: From user action → UI → backend → new code
2. **Check for stub implementations**: Search for `false`, `None`, `todo!()`, `unimplemented!()`
3. **Verify runtime activation**: Add a log line, rebuild, test manually, check logs
4. **Check config wiring**: Is the new feature enabled by default? Passed to constructors?

### Example: Audio Cache Bug (2026-01)

**What happened:**

- `FfmpegConcatSource` implemented with `ensure_prefix()` for downloading
- `build_mpv_input()` checked if cache exists but **never called download**
- `has_cached_audio()` was a stub returning `false` always
- Result: Cache feature "worked" in tests but never created files

**How to prevent:**

```rust
// RED FLAG: Stub that always returns false/None
pub fn has_cached_audio(&self, _video_id: &str) -> bool {
    false  // ← This should delegate to actual cache check
}

// RED FLAG: Async method exists but sync caller never uses it
impl Cache {
    async fn ensure_prefix(...) { ... }  // ← Never called!
}
fn build_mpv_input(...) {
    if path.exists() { ... }  // ← But nothing downloads it first!
}
```

### Integration Test Pattern

For features with multiple components, write an integration test:

```rust
#[test]
fn test_audio_cache_integration() {
    // 1. Create real instances (not mocks)
    // 2. Call the entry point users would trigger
    // 3. Verify the expected side effect (file exists, log appears, etc.)
}
```

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

---

## Authentication Context (YouTube)

**Why auth matters for debugging:** If YouTube features fail (search, playback), cookies are often the cause.

**Cookie location:** `~/.config/rmpc/cookie.txt` (Netscape format)

**Critical cookies:** `SAPISID`, `__Secure-3PAPISID`

**Common auth errors in logs:**

- `"No cookies found"` → File missing or wrong path
- `"401 Unauthorized"` → Cookies expired, need refresh
- `"403 Forbidden"` → Missing critical cookies

**For humans setting up auth:** See [docs/USER_GUIDE.md](docs/USER_GUIDE.md) for browser export instructions.

---

## Debugging

### Enable Logs

```bash
RUST_LOG=debug ./target/release/rmpc 2> debug.log
```

### Check MPV Process

```bash
pgrep -af mpv                    # Is MPV running?
ls -la /tmp/rmpc-mpv.sock        # Check socket
echo '{ "command": ["get_property", "media-title"] }' | socat - /tmp/rmpc-mpv.sock
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "No cookies found" | Check `~/.config/rmpc/cookie.txt` exists, verify Netscape format |
| "MPV not found" | Install MPV, check PATH |
| Search returns no results | Check logs, verify cookies not expired |
| Can't navigate to artist/album | Check metadata["type"], verify browse_id format |

---

## Hot Reload & Profiling

```bash
# Hot reload (cargo-watch)
cargo install cargo-watch
cargo watch -x build

# CPU profiling
perf record ./target/release/rmpc && perf report

# Memory profiling
valgrind --leak-check=full ./target/debug/rmpc
```
