# Backlog: Metadata Consistency Between Search and Queue

> **Priority:** P2  
> **Status:** Research Complete, Ready for Implementation  
> **Estimated Effort:** 1-2 hours

---

## Problem

Song metadata (album, artist) may display differently in Search vs Queue views because:
1. Queue pane may use legacy MPD-style patterns for extracting metadata
2. YouTube songs store album in `metadata["album"]` HashMap

## Research Findings (ALREADY VERIFIED)

### Data Flow Is Correct ✅

```
ytmusicapi response (has album.name)
  ↓
domain/search/convert.rs:40 → SongItem.album = r.album.map(|a| a.name)
  ↓
domain/search/items.rs:71-73 → Song.metadata["album"] = album
  ↓
protocol.rs:221 → PlayableData.album preserved
  ↓
client.rs:52-53 → metadata.insert("album", album)
  ↓
server.rs:324 → song_data.to_song() → queue.add(song)
```

**Album IS stored in queue correctly.**

### Key Files

| File | Line | Purpose |
|------|------|---------|
| `domain/song.rs` | 30-35 | `Song.album()` method |
| `domain/song.rs` | 116-130 | `ListItemDisplay.secondary_text()` |
| `ui/panes/queue.rs` | - | Queue pane rendering |
| `domain/display.rs` | - | `ListItemDisplay` trait |

### Song.album() Implementation (CURRENT)

```rust
// domain/song.rs - Song struct methods
pub fn album(&self) -> Option<&str> {
    self.metadata.get("Album").and_then(|v| v.first()).map(|s| s.as_str())
}
```

**ISSUE:** Uses `"Album"` (capital A) but YouTube stores as `"album"` (lowercase).

---

## Fix

### Option 1: Fix Song.album() Case-Insensitivity (Recommended)

**File:** `rmpc/src/domain/song.rs`

```rust
pub fn album(&self) -> Option<&str> {
    // Try lowercase first (YouTube backend)
    self.metadata.get("album")
        .or_else(|| self.metadata.get("Album")) // MPD fallback
        .and_then(|v| v.first())
        .map(|s| s.as_str())
}
```

### Option 2: Ensure Queue Pane Uses ListItemDisplay

**File:** `rmpc/src/ui/panes/queue.rs`

Audit queue pane and replace direct metadata access:
```rust
// AVOID:
song.metadata.get("album")

// USE:
song.secondary_text() // From ListItemDisplay trait
```

---

## Verification Steps

1. Build: `cd rmpc && cargo build --release`
2. Run: `./rmpc/target/release/rmpc --config config/rmpc.ron`
3. Search for a song with album info
4. Add to queue
5. Verify album shows in queue view

---

## References

- ytmusicapi search response: Album is `{ "name": "...", "id": "..." }`
- https://github.com/sigma67/ytmusicapi
- Session doc: `docs/session-2025-12-08-rich-list-fixes.md`
