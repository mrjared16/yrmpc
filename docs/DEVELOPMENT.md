# Development Guide

## Prerequisites

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# MPV (for playback)
sudo pacman -S mpv     # Arch
sudo apt install mpv   # Debian/Ubuntu

# Git (for submodules)
sudo pacman -S git
```

## Initial Setup

### 1. Clone with Submodules
```bash
git clone --recurse-submodules https://github.com/USER/yrmpc.git
cd yrmpc

# If already cloned without --recurse-submodules:
git submodule update --init --recursive
```

### 2. Authentication Setup

**Export cookies from browser:**
1. Install "EditThisCookie" Chrome extension
2. Go to music.youtube.com
3. Click EditThisCookie icon → Export → Copy
4. Save to `~/.config/rmpc/cookie.txt`

**Cookie format (Netscape):**
```
# HTTP Cookie File
.youtube.com	TRUE	/	TRUE	1735689600	SAPISID	abc123...
.youtube.com	TRUE	/	TRUE	1735689600	__Secure-3PAPISID	xyz789...
```

**Critical cookies:**
- `SAPISID` - Required for auth hash
- `__Secure-3PAPISID` - Required for auth

### 3. Configuration

**Create/edit `~/.config/rmpc/rmpc.ron`:**
```ron
(
    backend: youtube,
    youtube: (
        auth_file: Some("~/.config/rmpc/cookie.txt"),
    ),
    theme: Some("default"),
)
```

**Or use project config:**
```bash
# yrmpc/config/rmpc.ron already configured
# rmpc will find it via --config flag or default search paths
```

## Build

```bash
cd rmpc

# Debug build (fast compile, slow runtime)
cargo build

# Release build (slow compile, fast runtime)
cargo build --release

# Binary location:
# Debug: ./target/debug/rmpc
# Release: ./target/release/rmpc
```

## Run

```bash
# From rmpc directory
cd rmpc
./target/release/rmpc

# From yrmpc directory with custom config
./rmpc/target/release/rmpc --config config/rmpc.ron

# In tmux (recommended for background running)
tmux new-session -s rmpc './rmpc/target/release/rmpc'
```

## Test

### Run All Tests
```bash
cd rmpc
cargo test
```

### Run Specific Tests
```bash
# Integration tests only
cargo test --test youtube_search_integration_tests

# Unit tests in youtube_backend.rs
cargo test youtube_backend_tests

# Navigation tests
cargo test search_navigation_tests

# Specific test
cargo test test_artist_id_format

# With output
cargo test -- --nocapture
```

### Test Results (Expected)
```
running 23 tests
test result: ok. 23 passed; 0 failed; 0 ignored
```

## Development Workflow

### 1. Make Changes
```bash
cd rmpc/src/player
$EDITOR youtube_backend.rs
```

### 2. Test Locally
```bash
cargo test
cargo build --release
./target/release/rmpc
```

### 3. Commit
```bash
# In rmpc submodule
cd rmpc
git add .
git commit -m "feat: add new feature"
git push origin feature/branch-name

# In parent
cd ..
git add rmpc  # Update submodule pointer
git commit -m "chore: update rmpc submodule"
git push
```

## Debugging

### Enable Logs
```bash
# Set log level
RUST_LOG=debug ./target/release/rmpc 2> debug.log

# Or in code:
env_logger::init();
log::debug!("Debug message");
log::info!("Info message");
```

### Check MPV Process
```bash
# Is MPV running?
pgrep -af mpv

# Check MPV socket
ls -la /tmp/rmpc-mpv.sock

# Query MPV (requires socat)
echo '{ "command": ["get_property", "media-title"] }' | socat - /tmp/rmpc-mpv.sock
```

### Common Issues

**"No cookies found"**
- Check `~/.config/rmpc/cookie.txt` exists
- Verify Netscape format (tab-separated, 7 columns)
- Ensure SAPISID cookie present

**"MPV not found"**
- Install MPV: `which mpv` should return path
- Check PATH environment variable

**"Search returns no results"**
- Check logs for API errors
- Verify cookies not expired (re-export from browser)
- Test API manually (Python ytmusicapi)

**"Can't navigate to artist/album"**
- Check metadata["type"] is set correctly
- Verify browse_id format (artist:UC..., album:MPREb_...)
- Check UI event handlers in `ui/mod.rs`

## Hot Reload (cargo-watch)

```bash
# Install cargo-watch
cargo install cargo-watch

# Auto-rebuild on file changes
cargo watch -x build

# Auto-test on changes
cargo watch -x test
```

## Profiling

```bash
# CPU profiling
cargo build --release
perf record ./target/release/rmpc
perf report

# Memory profiling (valgrind)
cargo build
valgrind --leak-check=full ./target/debug/rmpc
```

## Updating Dependencies

### Update ytmapi-rs
```bash
cd rmpc/youtui
git pull origin main
cd ../..
git add rmpc
git commit -m "chore: update ytmapi-rs"
```

### Update Rust crates
```bash
cd rmpc
cargo update
cargo build --release
cargo test  # Verify no breakage
```

## Code Style

```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Fix clippy warnings
cargo clippy --fix
```
