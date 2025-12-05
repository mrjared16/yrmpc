# What's Still Missing for YouTube Streaming on rmpc

## 🚨 CRITICAL DISCOVERY: Daemon is a Stub!

### The Problem

**File:** `<PROJECT_ROOT>/rmpc/src/bin/rmpcd.rs`

**Current Content:** 25-line placeholder that does NOTHING
```rust
#[tokio::main]
async fn main() -> Result<()> {
    println!("Starting rmpcd on {}", args.bind);
    
    // Placeholder for server logic
    // let server = MpdServer::new(&args.bind).await?;
    // server.run().await?;
    
    Ok(())
}
```

**What it SHOULD do:** Run YouTubeServer!

**Status:** ❌ Daemon exists as binary but doesn't run YouTube server

---

## 📋 What Needs to Be Done

### 1. CRITICAL: Wire rmpcd to YouTubeServer ⚠️

**File:** `rmpc/src/bin/rmpcd.rs`

**Current:** Empty stub  
**Needed:** Actually instantiate and run YouTubeServer

**Implementation:**
```rust
use anyhow::Result;
use clap::Parser;
use std::path::PathBuf;
use rmpc::player::youtube::server::YouTubeServer;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Socket path for YouTube daemon
    #[arg(short, long, default_value = "/tmp/yrmpc-yt.sock")]
    socket: PathBuf,
    
    /// Cookie file for YouTube authentication
    #[arg(short, long)]
    cookies: Option<PathBuf>,
}

fn main() -> Result<()> {
    env_logger::init();
    let args = Args::parse();

    log::info!("Starting YouTube daemon at {:?}", args.socket);
    
    let server = YouTubeServer::new(
        &args.socket,
        args.cookies.as_deref().map(|p| p.to_str().unwrap()),
    )?;
    
    server.run()? // This blocks
}
```

**Effort:** 15 minutes  
**Priority:** 🔴 BLOCKING - Nothing works without this

---

### 2. MEDIUM: Improve Error Messages

**Current:** Generic error with no help
```rust
daemon.ensure_running()
    .context("Failed to ensure YouTube daemon is running")?;
```

**User sees when daemon fails:**
```
Error: Failed to ensure YouTube daemon is running
```

**Better Error Message:**
```rust
daemon.ensure_running()
    .map_err(|e| {
        daemon.print_start_command(); // Show command to user
        e
    })
    .context("Failed to ensure YouTube daemon is running")?;
```

**User would see:**
```
Error: Failed to ensure YouTube daemon is running

To manually start YouTube daemon:
  rmpcd --socket "/tmp/yrmpc-yt.sock"

Caused by:
    Connection refused (os error 111)
```

**Implementation:**

**File:** `rmpc/src/player/youtube/client.rs` (lines 38-42)

```rust
// BEFORE:
let mut daemon = super::daemon::DaemonManager::new(socket_path.to_path_buf());
daemon.ensure_running()
    .context("Failed to ensure YouTube daemon is running")?;

// AFTER:
let mut daemon = super::daemon::DaemonManager::new(socket_path.to_path_buf());
daemon.ensure_running()
    .map_err(|e| {
        eprintln!("\n❌ YouTube daemon failed to start!\n");
        daemon.print_start_command();
        eprintln!();
        e
    })
    .context("Failed to auto-start YouTube daemon")?;
```

**Effort:** 5 minutes  
**Priority:** 🟡 Nice to have

---

### 3. LOW: Update daemon.rs help text

**File:** `rmpc/src/player/youtube/daemon.rs` (lines 79-83)

**Current:**
```rust
pub fn print_start_command(&self) {
    eprintln!("To manually start YouTube daemon:");
    eprintln!("  rmpcd --socket {:?}", self.socket_path);
}
```

**Better (with cookies):**
```rust
pub fn print_start_command(&self) {
    eprintln!("To manually start YouTube daemon:");
    eprintln!("  rmpcd --socket {:?}", self.socket_path);
    eprintln!();
    eprintln!("If you need YouTube authentication:");
    eprintln!("  rmpcd --socket {:?} --cookies ~/.config/yrmpc/cookies.txt", self.socket_path);
    eprintln!();
    eprintln!("For debugging:");
    eprintln!("  RUST_LOG=debug rmpcd --socket {:?}", self.socket_path);
}
```

**Effort:** 2 minutes  
**Priority:** 🟢 Polish

---

## 📊 Streaming Readiness Assessment

### What's Actually Working ✅

1. **Architecture is solid**
   - Client-server split ✅
   - Services separated ✅
   - IPC protocol defined ✅

2. **YouTubeServer implementation exists**
   - ApiService (search, browse) ✅
   - PlaybackService (MPV control) ✅
   - QueueService (queue management) ✅

3. **YouTubeClient implementation works**
   - Connects to socket ✅
   - Sends commands ✅
   - Receives responses ✅

### What's Broken ❌

1. **rmpcd binary doesn't run YouTubeServer**
   - Just prints "Starting rmpcd" and exits
   - Never instantiates YouTubeServer
   - CRITICAL BLOCKER

2. **Daemon auto-start will fail silently**
   - DaemonManager tries to spawn `rmpcd`
   - rmpcd starts but does nothing
   - No socket created
   - Client connection fails
   - User sees cryptic error

### What Streaming Requires

**For basic playback:**
1. ✅ YouTube Music API (ytmapi-rs) - EXISTS
2. ✅ Stream URL extraction (rusty_ytdl) - EXISTS  
3. ✅ MPV process management - EXISTS
4. ❌ **Working daemon binary** - MISSING!
5. ❌ **Cookie file for auth** - User must provide

**For full experience:**
6. ✅ Search functionality - EXISTS
7. ✅ Browse artists/albums - EXISTS
8. 🟡 Playlist support - STUBBED
9. 🟡 Autocomplete - STUBBED  
10. 🟡 Library management - STUBBED

---

## 🎯 Immediate Action Items

### Must Do (Blocks All Functionality):

**1. Fix rmpcd.rs (15 min)**
```rust
// Replace entire src/bin/rmpcd.rs content
use anyhow::Result;
use clap::Parser;
use std::path::PathBuf;
use rmpc::player::youtube::server::YouTubeServer;

#[derive(Parser)]
struct Args {
    #[arg(short, long, default_value = "/tmp/yrmpc-yt.sock")]
    socket: PathBuf,
    
    #[arg(short, long)]
    cookies: Option<PathBuf>,
}

fn main() -> Result<()> {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info")
    ).init();
    
    let args = Args::parse();
    
    log::info!("Starting YouTube daemon at {:?}", args.socket);
    
    let server = YouTubeServer::new(
        &args.socket,
        args.cookies.as_deref().and_then(|p| p.to_str()),
    )?;
    
    log::info!("YouTube daemon ready, entering event loop...");
    server.run()
}
```

**Test:**
```bash
# Build
cargo build --release

# Start daemon manually
RUST_LOG=info ./target/release/rmpcd --socket /tmp/test-yt.sock

# Should see:
# [INFO] Starting YouTube daemon at "/tmp/test-yt.sock"
# [INFO] YouTube daemon ready, entering event loop...
# [INFO] Listening on /tmp/test-yt.sock
```

### Should Do (UX improvement):

**2. Better error messages (5 min)**
```rust
// In client.rs:connect(), add error context
daemon.ensure_running()
    .map_err(|e| {
        eprintln!("\n❌ Failed to start YouTube daemon!\n");
        daemon.print_start_command();
        e
    })
    .context("YouTube daemon auto-start failed")?;
```

### Could Do (Polish):

**3. Enhanced help text (2 min)**
```rust
// In daemon.rs:print_start_command()
// Add cookie and debug examples
```

---

## 🧪 Testing Checklist (After Fixes)

```bash
# 1. Clean environment
pkill -9 rmpc rmpcd mpv

# 2. Build everything
cargo build --release

# 3. Test manual daemon start
./target/release/rmpcd --socket /tmp/yrmpc-yt.sock &
sleep 2
ps aux | grep rmpcd  # Should see daemon

# 4. Test client connection
./target/release/rmpc
# Should:
# - Connect to existing daemon
# - Show YouTube backend active
# - Allow searching

# 5. Test daemon auto-start
pkill rmpcd  # Kill daemon
./target/release/rmpc
# Should:
# - Auto-start daemon
# - Connect successfully
# - Work normally

# 6. Test search
# In rmpc:
# Press /
# Type "test"
# Should show results

# 7. Test playback
# Select song
# Press Enter
# Should play (if cookies configured)
```

---

## 📝 Cookie Setup (Required for Auth)

YouTube Music requires authentication for most features.

**Steps:**
1. Export cookies from browser (use extension like "Get cookies.txt")
2. Save to `~/.config/yrmpc/cookies.txt`
3. Start daemon with cookies:
   ```bash
   rmpcd --socket /tmp/yrmpc-yt.sock --cookies ~/.config/yrmpc/cookies.txt
   ```

**Or configure in youtube.toml:**
```toml
[api]
cookie_file = "~/.config/yrmpc/cookies.txt"
```

---

## 🎯 Summary

**What LLM Did (Excellent):**
- ✅ Refactored architecture 
- ✅ Created services
- ✅ Implemented client-server protocol
- ✅ Set up configuration

**What's Still Missing (Critical):**
- ❌ **rmpcd binary is empty stub!**
- ❌ Needs 15 minutes of work to wire YouTubeServer
- ❌ Error messages don't help users

**After fixing rmpcd.rs:**
- ✅ Daemon will actually run
- ✅ Auto-start will work
- ✅ Streaming will be functional
- ✅ Users can play YouTube Music

**Effort to make it work:** ~20 minutes
- 15 min: Wire rmpcd to YouTubeServer
- 5 min: Improve error messages
- 0 min: Test and verify

**Current state:** Architecture complete, just needs final wiring.
