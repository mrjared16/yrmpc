# Debug Session Guide

## What We Know
- ✅ Code compiles
- ✅ Tests pass (9/9 integration tests)
- ❌ App doesn't work for user
- ⚠️ Never tested end-to-end with real YouTube Music

## Immediate Debug Steps

### 1. Check if App Starts

```bash
cd /home/phucdnt/workspace/projects/yrmpc/rmpc

# Try to run
RUST_LOG=info ./target/release/rmpc 2>&1 | tee startup.log

# If it crashes, check:
cat startup.log | grep -i error
```

**Expected issues:**
- Auth file not found
- Cookies expired
- Config file missing
- MPV not spawned

### 2. Verify Authentication

```bash
# Check cookie file exists
ls -la ~/.config/rmpc/cookie.txt

# Check cookie format (should be tab-separated)
head -5 ~/.config/rmpc/cookie.txt

# Verify SAPISID cookie present
grep SAPISID ~/.config/rmpc/cookie.txt
```

**If missing**: Re-export from browser (see DEVELOPMENT.md)

### 3. Test Search Manually

```bash
# Start app with debug logs
cd rmpc
RUST_LOG=debug ./target/release/rmpc 2> debug.log &

# In the app:
# 1. Press "/" to search
# 2. Type "test"
# 3. Press Enter

# Check logs
grep -i "search" debug.log
grep -i "error" debug.log
grep -i "youtube" debug.log
```

**Look for:**
- "Search query: test"
- "API call successful"
- "Results found: X"
- Or errors: "Auth failed", "Network error", etc.

### 4. Test Playback

```bash
# After search, try to play something
# Press Enter on a result

# Check MPV:
pgrep -af mpv

# Check logs:
grep -i "mpv" debug.log
grep -i "play" debug.log
```

## Common Issues & Fixes

### Issue: App Won't Start

**Symptoms:**
- Crashes immediately
- "Config not found"
- "Auth file missing"

**Fix:**
```bash
# Create config directory
mkdir -p ~/.config/rmpc

# Copy project config
cp /home/phucdnt/workspace/projects/yrmpc/config/rmpc.ron ~/.config/rmpc/

# Or create minimal config:
cat > ~/.config/rmpc/rmpc.ron << 'EOF'
(
    backend: youtube,
    youtube: (
        auth_file: Some("~/.config/rmpc/cookie.txt"),
    ),
)
EOF
```

### Issue: Search Returns Nothing

**Symptoms:**
- No results after search
- Empty list
- "0 results found"

**Possible causes:**
1. **Cookies expired** → Re-export from browser
2. **API not initialized** → Check logs for "YouTube API loaded"
3. **Backend not selected** → Check config has `backend: youtube`
4. **Network error** → Test internet connection

**Debug:**
```bash
# Check if YouTubeBackend is being used
grep "backend" ~/.config/rmpc/rmpc.ron

# Test API manually (Python):
python3 - << 'EOF'
from ytmusicapi import YTMusic
yt = YTMusic("~/.config/rmpc/cookie.txt")
results = yt.search("test")
print(f"Found {len(results)} results")
EOF
```

### Issue: Can't Navigate to Artist/Album

**Symptoms:**
- Search works
- Can see results
- Pressing Enter does nothing

**Possible causes:**
1. **UI events not wired up** → Check if code in `search/mod.rs` got compiled
2. **Tab doesn't exist** → Check config has Artists/Albums tabs
3. **Browse fails silently** → Check logs for browse errors

**Debug:**
```bash
# Enable trace logging
RUST_LOG=trace ./target/release/rmpc 2> trace.log

# Try to navigate, then:
grep "OpenArtist\|OpenAlbum" trace.log
grep "fetch_data" trace.log
```

### Issue: No Audio Playback

**Symptoms:**
- Song selected
- No sound
- MPV not running

**Possible causes:**
1. **MPV not installed** → `which mpv`
2. **MPV spawn failed** → Check logs for spawn errors
3. **URL extraction failed** → rusty_ytdl issue
4. **Audio device issue** → MPV can't access audio

**Debug:**
```bash
# Check MPV installed
which mpv
mpv --version

# Test MPV directly
mpv --vo=null https://www.youtube.com/watch?v=dQw4w9WgXcQ

# Check if rmpc spawned MPV
pgrep -af mpv

# Check MPV logs (if rmpc started it)
ls -la /tmp/rmpc-mpv.sock
```

## Manual Test Checklist

Run through this systematically:

- [ ] **App Startup**
  - [ ] App launches without crash
  - [ ] UI renders correctly
  - [ ] No error messages in logs
  
- [ ] **Authentication**
  - [ ] Cookie file exists
  - [ ] Cookies parsed successfully
  - [ ] YouTube API initialized
  - [ ] Logs show "API loaded" or similar
  
- [ ] **Search**
  - [ ] Press `/` opens search input
  - [ ] Typing updates input
  - [ ] Press Enter triggers search
  - [ ] Results appear (at least 1)
  - [ ] Results show correct metadata (title, artist)
  
- [ ] **Navigation**
  - [ ] Up/Down arrows move selection
  - [ ] Enter on artist → Artist page loads
  - [ ] Enter on album → Album page loads
  - [ ] Esc goes back
  - [ ] Tab switches between panes
  
- [ ] **Playback**
  - [ ] Enter on song → MPV starts
  - [ ] Audio plays
  - [ ] No gaps/stuttering
  - [ ] Next/Previous works
  - [ ] Pause/Resume works

## Data Collection

If nothing works, collect this info:

```bash
# System info
uname -a
mpv --version
rustc --version

# Config
cat ~/.config/rmpc/rmpc.ron

# Cookies (sanitized)
cat ~/.config/rmpc/cookie.txt | grep -c "youtube.com"

# Startup logs
RUST_LOG=debug ./target/release/rmpc 2> full_debug.log
# (Let it run for 10 seconds, try search, quit)

# Zip logs
tar -czf rmpc_debug_$(date +%Y%m%d).tar.gz \
    full_debug.log \
    ~/.config/rmpc/rmpc.ron

echo "Send rmpc_debug_*.tar.gz for analysis"
```

## Expected vs Actual

### Expected Behavior
```
1. Start rmpc
2. Press "/" → Search input appears
3. Type "son tung mtp" → Text shown
4. Press Enter → Results appear (artist, albums, songs)
5. Arrow down to artist → Highlights
6. Press Enter → Artist page loads with top songs
7. Arrow to song → Highlights
8. Press Enter → Audio starts playing
```

### If NONE of this works
Start from scratch:
1. Rebuild: `cargo clean && cargo build --release`
2. Check cookies are fresh (< 1 week old)
3. Try simplest case: Play ONE video by ID

## Simplest Test Case

```bash
# Minimal test: Can we play a hardcoded video?
cat > test_play.rs << 'EOF'
use rusty_ytdl::Video;
use std::process::Command;

#[tokio::main]
async fn main() {
    let video = Video::new("dQw4w9WgXcQ").unwrap();
    let url = video.get_download_url().await.unwrap();
    
    println!("Stream URL: {}", url);
    
    Command::new("mpv")
        .arg("--vo=null")
        .arg(&url)
        .spawn()
        .unwrap();
    
    std::thread::sleep(std::time::Duration::from_secs(10));
}
EOF

# Run
cargo run --bin test_play
```

If this doesn't play audio, problem is:
- MPV not working
- rusty_ytdl not working
- Network issue

If it DOES play audio, problem is:
- rmpc UI not wired to backend
- Events not triggering
- Integration issue
