# Feature: Playback

## Purpose
Documents the complete playback flow from song selection to audio output via MPV.

## When to Read
- **Symptoms**: Playback doesn't start, wrong URL extracted, audio gaps, cache issues
- **Tasks**: Fix URL extraction, modify MPV integration, add new extractor

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              UI Layer                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  User selects song → PaneAction::Play(song)                       │  │
│  │                   or PaneAction::Execute(Intent::Play)            │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────┬────────────────────────────┘
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PlaybackService                                  │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  play(song)      │───▶│ CachedExtractor  │───▶│  Audio Cache     │   │
│  │                  │    │ resolve URL      │    │  (rolling window)│   │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘   │
└────────────────────────────────────────────┬────────────────────────────┘
                                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              MPV IPC                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  loadfile(url)   │───▶│  MPV Process     │───▶│  Audio Output    │   │
│  │  (JSON IPC)      │    │  (headless)      │    │                  │   │
│  └──────────────────┘    └──────────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. User presses Enter on song in search results
        │
        ▼
2. Pane returns PaneAction::Play(song) or Execute(Intent::Play)
        │
        ▼
3. Navigator/ActionDispatcher routes to PlaybackService
        │
        ▼
4. PlaybackService::play(song)
   └─► Check if URL already cached
   └─► If not: CachedExtractor::extract(video_id)
        │
        ▼
5. CachedExtractor resolves playable URL
   └─► Primary: ytx (fast, ~200ms)
   └─► Fallback: yt-dlp (slower, Python)
   └─► Cache result with TTL
        │
        ▼
6. PlaybackService sends to MPV via IPC
   └─► mpv --input-ipc-server=/tmp/rmpc.sock
   └─► loadfile <url> replace
        │
        ▼
7. MPV streams audio, reports position/duration via IPC
```

## Playback Intents

The user can initiate playback in different ways via `PlayIntent`:

- **Play (Context)**: Replaces the queue with a new list of tracks (Album, Playlist, Search Results). Optimizes for immediate playback of the selected track.
- **Play Next**: Inserts tracks after the current song. Priority is given to the first track for gapless transition.
- **Add to Queue**: Appends tracks to the end of the queue. Handled in background priority.
- **Radio**: Starts a radio station from a seed track. Replaces queue with seed and lazy-fetches related tracks.

## Key Components

### CachedExtractor
```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CachedExtractor                                  │
│  ┌──────────────────┐                                                   │
│  │  URL Cache       │ ◄── video_id → (url, expiry)                      │
│  │  (HashMap)       │                                                   │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│  extract(video_id):                                                      │
│    1. Check cache → if valid, return cached URL                         │
│    2. Call ytx/yt-dlp to get fresh URL                                  │
│    3. Cache result with TTL (~4 hours)                                  │
│    4. Return URL                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Audio Cache (Rolling Window)
```
┌─────────────────────────────────────────────────────────────────────────┐
│  Queue: [Song1] [Song2] [Song3] [Song4] [Song5]                         │
│              ▲                                                           │
│         Currently Playing                                                │
│                                                                          │
│  Pre-cache window: Song2, Song3 (next 2)                                │
│  Keep cached: Song1 (just played, for back)                             │
│  Evict: Songs outside window                                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `rmpc/src/player/playback_service.rs` | PlaybackService, play/pause/seek |
| `rmpc/src/player/extractor.rs` | CachedExtractor, URL resolution |
| `rmpc/src/player/mpv.rs` | MPV IPC communication |
| `rmpc/src/player/audio_cache.rs` | Rolling window cache management |
| `rmpc/src/actions/handlers/play.rs` | PlayHandler action handler |

## Extractor Priority

| Extractor | Speed | When Used |
|-----------|-------|-----------|
| `ytx` | ~200ms | Default, preferred |
| `yt-dlp` | ~2-3s | Fallback if ytx fails |

**Note**: ytx is a lightweight YouTube URL extractor. yt-dlp spawns heavy Python process - avoid in tests.

## Debugging Checklist

| Symptom | Likely Cause | File |
|---------|--------------|------|
| Playback doesn't start | URL extraction failed | `extractor.rs` |
| Wrong song plays | video_id mismatch | Adapter or queue |
| Audio gaps | Cache miss, slow extraction | `audio_cache.rs` |
| MPV not responding | IPC socket issue | `mpv.rs` |
| "No audio" error | URL expired | Check TTL in cache |

## Gapless Playback

For gapless transitions:
1. Pre-extract next N songs in queue
2. Use EDL (Edit Decision List) format for seamless concat
3. Rolling window evicts old entries

```
EDL format: edl://url1;url2;url3
MPV plays continuously without gaps
```

## See Also

- [docs/arch/youtube-integration.md](../arch/youtube-integration.md) - URL/ID source
- [docs/features/queue.md](queue.md) - Queue management
- [docs/arch/action-system.md](../arch/action-system.md) - Play intent handling
