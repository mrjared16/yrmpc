# Capability: Lyrics (Optional)

> **Layer**: 2 (Optional Common)
> **Trait**: `api::optional::Lyrics`
> **Flag**: `Capability::Lyrics`

## Purpose

Fetch and display song lyrics.

## When to Implement

Implement if your service provides lyrics. Many services don't have comprehensive lyrics.

## Contract

### Trait Definition

```rust
pub trait Lyrics {
    fn get_lyrics(&self, track_id: &str) -> Result<Option<LyricsData>>;
}

pub struct LyricsData {
    pub text: String,
    pub synced: Option<Vec<SyncedLine>>,  // Timestamped lines
    pub source: String,                    // Attribution
}

pub struct SyncedLine {
    pub timestamp: Duration,
    pub text: String,
}
```

## UI Fallback

When `Lyrics` capability is absent:
- Hide lyrics pane
- Hide "Show Lyrics" keybinding

## Cross-References

- [Playback Feature](../features/playback.md) - Lyrics during playback
- [Capability System](./README.md) - Required vs optional
