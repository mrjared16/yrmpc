# Common Tasks - Quick Reference

## Add New Search Result Type

**File:** `rmpc/src/player/youtube_backend.rs` (search method)

```rust
// 1. Parse new type from ytmapi-rs results
for new_type in results.new_types {
    let mut metadata = HashMap::new();
    metadata.insert("type".to_string(), vec!["new_type".to_string()]);
    metadata.insert("title".to_string(), vec![new_type.title]);
    
    songs.push(Song {
        file: format!("new_type:{}", new_type.id),
        metadata,
        duration: None,
        ...
    });
}

// 2. Add navigation handler in rmpc/src/ui/panes/search/mod.rs
if type_ == "new_type" {
    ctx.app_event_sender.send(
        AppEvent::UiEvent(UiAppEvent::OpenNewType(id))
    )?;
}

// 3. Add event variant in rmpc/src/ui/mod.rs
enum UiAppEvent {
    OpenNewType(String),
}

// 4. Add handler
UiAppEvent::OpenNewType(id) => {
    // Find tab, switch, load data
}
```

## Modify Search Filters

**File:** `rmpc/src/player/youtube_backend.rs`

```rust
// Current: General search
let search_query = SearchQuery::new(query);

// Add filter:
use ytmapi_rs::query::SearchFilter;
let search_query = SearchQuery::new(query)
    .with_filter(SearchFilter::Songs);  // Songs only
    // Or: Artists, Albums, Videos, etc.
```

## Change MPV Arguments

**File:** `rmpc/src/player/youtube_backend.rs` (constructor)

```rust
Command::new("mpv")
    .arg("--idle=yes")
    .arg("--vo=null")           // No video output (audio only)
    .arg("--no-terminal")       // No MPV's own terminal UI
    .arg("--input-ipc-server=/tmp/rmpc-mpv.sock")
    .arg("--volume=50")         // ADD: Set default volume
    .arg("--audio-channels=2")  // ADD: Force stereo
    .spawn()?;
```

## Add Metadata Field

**File:** `rmpc/src/player/youtube_backend.rs` (search method)

```rust
// In parsing loop:
metadata.insert("genre".to_string(), vec![song.genre.unwrap_or_default()]);
metadata.insert("plays".to_string(), vec![song.play_count.to_string()]);

// Display in UI: rmpc/src/ui/panes/search/mod.rs
if let Some(genre) = song.metadata.get("genre") {
    // Show genre in search results
}
```

## Update ytmapi-rs Library

```bash
cd rmpc/youtui
git pull origin main
cd ../..

# Test changes
cd rmpc
cargo build
cargo test

# Commit
git add youtui
git commit -m "chore: update ytmapi-rs to latest"
```

## Fix "Cookies Expired" Error

```bash
# 1. Export fresh cookies from browser
# Chrome → EditThisCookie → Export → Netscape format

# 2. Overwrite cookie file
cat > ~/.config/rmpc/cookie.txt
# Paste cookies
# Ctrl+D

# 3. Verify format
head -5 ~/.config/rmpc/cookie.txt
# Should show tab-separated values

# 4. Restart rmpc
pkill rmpc
./target/release/rmpc
```

## Add New UI Pane

```bash
# 1. Create pane module
mkdir rmpc/src/ui/panes/mypane
touch rmpc/src/ui/panes/mypane/mod.rs

# 2. Define pane struct
# rmpc/src/ui/panes/mypane/mod.rs
pub struct MyPane {
    // state
}

impl BrowserPane for MyPane {
    fn fetch_data(&mut self, item: &DirOrSong, ctx: &AppContext) {
        // Load data for this pane
    }
}

# 3. Register in rmpc/src/ui/panes/mod.rs
pub mod mypane;
pub use mypane::MyPane;

# 4. Add to PaneType enum
pub enum PaneType {
    MyPane,
}

# 5. Add to Panes enum
pub enum Panes {
    MyPane(&'pane_ref mut MyPane),
}
```

## Debug Search Not Working

```bash
# 1. Enable debug logs
RUST_LOG=debug ./target/release/rmpc 2> debug.log

# 2. Search for something
# Type / then "test search"

# 3. Check logs
grep -i "search" debug.log
grep -i "error" debug.log

# 4. Common causes:
# - Cookies expired (re-export)
# - Network error (check internet)
# - Invalid query (special characters)
# - API change (update ytmapi-rs)
```

## Add Integration Test

**File:** `rmpc/tests/youtube_search_integration_tests.rs`

```rust
#[test]
fn test_my_feature() {
    // Setup
    let mut metadata = HashMap::new();
    metadata.insert("key".to_string(), vec!["value".to_string()]);
    
    // Test
    assert_eq!(metadata.get("key").unwrap()[0], "value");
}
```

Run: `cargo test test_my_feature`

## Change Search Result Display

**File:** `rmpc/src/ui/panes/search/mod.rs`

```rust
// Find render method
fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &AppContext) {
    // Modify how results are displayed
    // Change colors, layout, formatting
}
```

## Extract Video URL (for debugging)

```rust
use rusty_ytdl::Video;

let video = Video::new(video_id)?;
let url = video.get_download_url().await?;
println!("Stream URL: {}", url);
```

## Test API Call Manually

### Python
```python
from ytmusicapi import YTMusic
ytmusic = YTMusic("~/.config/rmpc/cookie.txt")

# Test search
results = ytmusic.search("son tung mtp")
print(results[0])

# Test browse
artist = ytmusic.get_artist("UC3muIvzjhubNpJ4Pn_0kCQw")
print(artist['name'])
```

### Rust
```rust
// In youtube_backend.rs, add temporary method:
pub fn test_api(&self) -> Result<()> {
    let api = self.api.lock().clone().unwrap();
    let results = self.rt.block_on(async {
        use ytmapi_rs::query::SearchQuery;
        api.query(SearchQuery::new("test")).await
    })?;
    println!("{:?}", results);
    Ok(())
}
```

## Profile Performance

```bash
# CPU profiling
cargo build --release --features=profiling
perf record ./target/release/rmpc
# Use app, then:
perf report

# Memory profiling
cargo build
valgrind --tool=massif ./target/debug/rmpc
ms_print massif.out.*
```

## Update Config Schema

```rust
// rmpc/src/config/mod.rs
#[derive(Deserialize)]
pub struct Config {
    pub backend: BackendType,
    pub new_field: Option<String>,  // Add new field
}

// config/rmpc.ron
(
    backend: youtube,
    new_field: Some("value"),
)
```

## Run in Docker (Headless)

```dockerfile
FROM rust:latest
RUN apt-get update && apt-get install -y mpv
WORKDIR /app
COPY . .
RUN cargo build --release
CMD ["./target/release/rmpc"]
```

## Batch Update Submodules

```bash
git submodule update --remote --merge
git add .
git commit -m "chore: update all submodules"
```
