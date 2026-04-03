# YouTube Music Streaming - Build & Run Guide

## 🔨 Building

```bash
# Build both binaries (client + daemon)
cargo build --release

# Binaries created:
# - target/release/rmpc   (TUI client)
# - target/release/rmpcd  (YouTube daemon server)
```

---

## 🚀 Running

### Option 1: Auto-start Daemon (Recommended)

```bash
# Just run rmpc - daemon auto-starts
./target/release/rmpc
```

**What happens:**
1. rmpc detects no daemon running
2. Spawns `rmpcd` automatically
3. Connects to daemon
4. Ready to stream!

### Option 2: Manual Daemon Start

```bash
# Terminal 1: Start daemon
./target/release/rmpcd --socket /tmp/yrmpc-yt.sock

# Terminal 2: Start client
./target/release/rmpc
```

---

## 🍪 Authentication (Required for Most Features)

YouTube Music requires authentication. Export cookies from your browser:

### 1. Get Cookies

**Using Chrome Extension:**
1. Install "Get cookies.txt" extension
2. Go to music.youtube.com
3. Click extension → Export cookies.txt
4. Save as `~/.config/yrmpc/cookies.txt`

### 2. Configure

**Option A: Command line**
```bash
rmpcd --socket /tmp/yrmpc-yt.sock --cookies ~/.config/yrmpc/cookies.txt
```

**Option B: Config file**
```toml
# ~/.config/yrmpc/youtube.toml
[api]
cookie_file = "~/.config/yrmpc/cookies.txt"

[audio]
# balanced (default): next-N future tracks via extract_one (lower rate-limit risk)
# performance: queue-wide URL extraction after startup via extract_batch
background_extract_mode = "balanced"
future_track_count = 2
```

---

## 🎵 Features

Once authenticated, you can:

- ✅ **Search** - Press `/`, type query, get results
- ✅ **Autocomplete** - Real-time suggestions while typing
- ✅ **Play songs** - Gapless audio streaming
- ✅ **Browse artists** - View artist discography
- ✅ **Browse playlists** - Explore playlists
- ✅ **Queue management** - Add, remove, reorder
- ✅ **Playback control** - Play, pause, next, previous, seek

---

## 🐛 Troubleshooting

### Daemon Won't Start

```bash
# Check if daemon is running
ps aux | grep rmpcd

# Start with debug logging
RUST_LOG=debug rmpcd --socket /tmp/yrmpc-yt.sock

# Check socket exists
ls -la /tmp/yrmpc-yt.sock
```

### No Search Results

**Cause:** Missing cookies (not authenticated)

**Fix:**
1. Export cookies from browser
2. Save to `~/.config/yrmpc/cookies.txt`
3. Restart daemon with `--cookies` flag

### Playback Issues

**Check MPV:**
```bash
# Is MPV installed?
which mpv

# Check MPV logs
RUST_LOG=debug rmpcd --socket /tmp/yrmpc-yt.sock 2>&1 | grep mpv
```

---

## ⚙️ Configuration

**Location:** `~/.config/yrmpc/youtube.toml`

**Example:**
```toml
[daemon]
auto_start = true
max_retries = 3

[mpv]
volume = 80
extra_args = ["--gapless-audio=yes", "--prefetch-playlist=yes"]

[api]
cookie_file = "~/.config/yrmpc/cookies.txt"
cache_duration = "1h"
max_search_results = 50

[audio]
background_extract_mode = "balanced"
future_track_count = 2
```

- `balanced`: next-N future tracks using `extract_one` (lower rate-limit risk)
- `performance`: queue-wide URL extraction after startup using `extract_batch`
- `future_track_count`: number of future tracks in the bounded extract/prefix window (default `2`)

See `youtube.toml.example` for all options.

---

## 📦 Installation

```bash
# Install to system
cargo install --path rmpc --bin rmpc
cargo install --path rmpc --bin rmpcd

# Now available as:
rmpc  # From anywhere
```

---

## 🔄 Development Workflow

```bash
# Build debug (faster)
cargo build

# Run with debug logging
RUST_LOG=debug ./target/debug/rmpc

# Build release (optimized)
cargo build --release

# Test
cargo test
```

---

## 📋 Quick Reference

| Command | Description |
|---------|-------------|
| `rmpc` | Start TUI client (auto-starts daemon) |
| `rmpcd --socket PATH` | Start daemon manually |
| `rmpcd --cookies FILE` | Start with authentication |
| `RUST_LOG=debug rmpcd` | Start with debug logs |
| `pkill rmpcd` | Stop daemon |
| `cargo build --release` | Build optimized binaries |

---

## 🎯 Success Criteria

After building and running, you should be able to:

1. ✅ Start rmpc without errors
2. ✅ See daemon auto-start (check `ps aux | grep rmpcd`)
3. ✅ Search for music (press `/`)
4. ✅ Get autocomplete suggestions while typing
5. ✅ Play songs with gapless audio
6. ✅ Browse artist pages
7. ✅ Browse playlist pages

**All features working = Streaming experience successful! 🎉**
