# youtui Curated Features for rmpc Adaptation

**Source Codebase**: `youtui` (local reference)
**Target**: `rmpc` (Antigravity Project)

## 1. Search Logic & UX (`songsearch.rs`)

### Feature: Debounced Search with State Management
**Why**: Provides a responsive "instant search" feel without spamming the API.
**Adaptation**:
- **State Machine**: `InputRouting` enum (Search, List, Filter, Sort) to manage focus.
- **Debouncing**: `SearchBlock` component handles text entry and triggers API calls only after a pause or submit.
- **Async Handling**: `AsyncTask` pattern for non-blocking UI updates during API fetches.

### Feature: Filterable Results
**Why**: Allows users to refine large search result sets locally.
**Adaptation**:
- **Local Filtering**: `FilterManager` applies text-based filters to the already fetched list.
- **Column-based Filtering**: Specific filters for "Artist", "Album", etc.

## 2. Artist Pane UX (`artistsearch.rs`)

### Feature: Split-Pane Navigation
**Why**: Efficient browsing of artist discography without losing context.
**Adaptation**:
- **Dual-Pane Layout**: Left pane for Artist list, Right pane for Top Songs/Albums.
- **Routing Logic**: `InputRouting` (Artist <-> Song) handles focus switching with Left/Right keys.
- **Lazy Loading**: Fetching artist details/songs only when an artist is selected.

## 3. Playlist & Queue Management (`playlist.rs`)

### Feature: Gapless Playback Logic
**Why**: Essential for a premium listening experience.
**Adaptation**:
- **Pre-buffering**: `SONGS_AHEAD_TO_BUFFER` constant (set to 3) triggers pre-fetching of next tracks.
- **Threshold Trigger**: `GAPLESS_PLAYBACK_THRESHOLD` (1s) determines when to ensure the next track is ready.
- **Autoplay Logic**: `autoplay_next_or_stop` handles seamless transitions.

### Feature: Download/Cache Management
**Why**: Reduces bandwidth and improves performance for repeated plays.
**Adaptation**:
- **Scoped Caching**: `drop_unscoped_from_id` removes old tracks from memory/cache to manage resources.
- **Background Downloading**: `download_upcoming_from_id` fetches future tracks in the background.

## 4. General UI Patterns

### Feature: Action Handler Pattern
**Why**: Clean separation of UI events and business logic.
**Adaptation**:
- **Action Enums**: `BrowserSongsAction`, `PlaylistAction` define all possible user intents.
- **KeyRouter**: Maps keybinds to specific Actions, making configuration easy.

### Feature: Async Effects
**Why**: Keeps the TUI responsive during heavy operations.
**Adaptation**:
- **ComponentEffect**: Returns a tuple of (Task, Callback) to handle side effects (like API calls) without freezing the main loop.
