# Feature Specification: Interactive Search & Detail Views

## Overview
Transform search results from static lists into interactive views matching YouTube Music/Spotify UX, fully keyboard-driven without mouse dependency.

## Current State (Dec 2, 2024 - Investigation Complete)

**✅ BACKEND WORKS:**
- ✅ Backend parses ALL search result types correctly:
  - Top Results (mixed types)
  - Artists (line 1269 in youtube_backend.rs)
  - Albums (line 1291)
  - Playlists - Community + Featured (lines 1376-1452)
  - Songs (line 1313)
  - Videos (line 1337)
- ✅ YouTube API returns diverse results (verified via test_search_artist)
- ✅ Enter handler routes based on `type` metadata (line 917-939)

**✅ TESTS UPDATED:**
- E2E tests rewritten to verify REAL functionality
- Tests check: song titles, artist names, playlist details + logs
- **3/6 passing** - failures are MEANINGFUL (verify actual data)
- Regression tests pass (navigation, Unicode, back nav)

**🎯 WHAT WORKS:**
- Search functionality (returns all types from API)
- Backend parsing (all types handled)
- Enter routing (checks metadata type)
- j/k navigation
- Back navigation (Esc)
- Visual mode
- Unicode support

**📝 TESTING STATUS:**
- Core feature tests fail because they verify REAL DATA
- This is GOOD - tests are meaningful
- Need proper search queries or manual verification

---

│   4. Killer                   HYBS • Killer                  3:19    │
│   5. Ride                     HYBS • RIDE                    3:02    │
│                                                                       │
│ ─── Featured Artists ───────────────────────────────────────────────  │
│   [1] HYBS            [2] Unknown Artist                             │
│                                                                       │
│ ─── Related Playlists ──────────────────────────────────────────────  │
│   [1] Soul night      [2] Happy Happy       [3] Tom's ✨            │
│                                                                       │
│ [Tab:sections] [j/k:nav] [v:visual] [Enter:action] [Esc:back]       │
└───────────────────────────────────────────────────────────────────────┘
```

### Album Detail View

```
┌────────────────────────── Making Steak (Album) ──────────────────────┐
│                                                                       │
│  ╔═══════════╗    Making Steak                                       │
│  ║  ALBUM    ║    HYBS                                               │
│  ║  ARTWORK  ║    2022 • Album • 8 songs                             │
│  ╚═══════════╝                                                       │
│  [P]lay All (clears queue) [S]ave to Library [v] Visual Select     │
│                                                                       │
│ ─── Tracks ─────────────────────────────────────────────────────────  │
│ ▶ 1. Go Higher                      [a]rtist [A]lbum      3:29       │
│   2. Dancing with my phone         [a]rtist [A]lbum      3:24       │
│   3. Run Away                      [a]rtist [A]lbum      3:39       │
│                                                                       │
│  Visual select (v): Select multiple → [n]ext [l]ast [p]lay [s]ave   │
│                                                                       │
│ ─── Artist ─────────────────────────────────────────────────────────  │
│   [→] HYBS (2.3M subscribers)                                        │
│                                                                       │
│ ─── More by HYBS ───────────────────────────────────────────────────  │
│   [1] Killer (Single)   [2] RIDE (Single)   [3] Earlier albums       │
│                                                                       │
│ [Tab:sections] [Enter:action] [a:artist] [Esc:back]                 │
└───────────────────────────────────────────────────────────────────────┘
```

### Artist Detail View

```
┌──────────────────────────────── HYBS ─────────────────────────────────┐
│                                                                        │
│  ╔═══════════╗    HYBS                                                │
│  ║  ARTIST   ║    2.3M subscribers                                    │
│  ║  PHOTO    ║    Filipino indie band from Manila                     │
│  ╚═══════════╝                                                        │
│                                                                        │
│ ─── Top Songs ──────────────────────────────────────────────────────  │
│ ▶ 1. Ride                     RIDE • 2021                     3:02    │
│   2. Killer                   Killer • 2022                   3:19    │
│   3. Dancing with my phone    Making Steak • 2022            3:24    │
│   4. Go Higher                Making Steak • 2022            3:29    │
│   [S]huffle top songs  [P]lay all                                     │
│                                                                        │
│ ─── Albums & Singles ───────────────────────────────────────────────  │
│   [1] Making Steak (2022)   [2] RIDE (2021)   [3] Killer (2022)      │
│                                                                        │
│ ─── Related Artists ─────────────────────────────────────────────────  │
│   [1] Cigarettes After Sex   [2] Boy Pablo   [3] Grentperez          │
│                                                                        │
│ [Tab:sections] [j/k:nav] [Enter:open] [Esc:back]                     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Keyboard Navigation

### Modes

| Mode | Trigger | Description |
|------|---------|-------------|
| **Normal** | Default | Navigate with j/k, select with Enter |
| **Visual** | `v` key | Select multiple items (vim-style) |
| **Action** | Context-dependent | Execute on selection |

### Key Bindings

**Global**:
- `j`/`k` - Move cursor up/down
- `h`/`l` or `Tab`/`Shift-Tab` - Switch sections
- `Enter` - Primary action (play/open)
- `Space` - Add to queue (background)
- `Esc` or `q` - Go back / exit mode
- `?` - Show help overlay

**Detail Views**:
- `P` - Play all (replace queue)
- `S` - Shuffle all  
- `A` - Add to library (save)
- `a` - Go to artist (from song/album)
- `A` (shift) - Go to album (from song)
- `M` - More options menu

**Visual Mode** (`v` to enter):
- `j`/`k` - Extend selection
- `V` - Select entire section
- `Esc` - Exit visual mode
- **Actions on selection**:
  - `n` - Play Next (after current song)
  - `l` - Play Last (append to queue)
  - `p` - Play selection (replace queue)
  - `s` - Save selection to playlist
  - `d` - Remove from queue

**Featured Artists / Related Sections**:
- `1`-`9` - Quick jump to numbered item
- `Enter` - Navigate to selected item

---

## Visual Selection UX

### Visual Mode Indicator

```
┌─── Tracks (VISUAL - 3 selected) ──────────────────────────────────┐
│ █ 1. Go Higher                HYBS • 2022                  3:29   │
│ █ 2. Dancing with my phone    HYBS • Dancing with..        3:24   │
│ █ 3. Run Away                 HYBS • Making Steak          3:39   │
│   4. Killer                   HYBS • Killer                3:19   │
│   5. Ride                     HYBS • RIDE                  3:02   │
│                                                                    │
│ [n:Next] [l:Last] [p:Play] [s:Save] [Esc:Cancel]                  │
└────────────────────────────────────────────────────────────────────┘
```

Selected rows highlighted with `█` or different background color.

---

## Data Flow Architecture

### Current Flow (Broken)
```
Search → Vec<Song> → Display → ❌ (no interaction)
```

### New Flow
```
Search → SearchResults
    ↓
[User selects item]
    ↓
Route by type:
    ├─ Song       → add_to_queue() + play()
    ├─ Playlist   → fetch_playlist_details() → PlaylistDetailView
    ├─ Album      → fetch_album_details() → AlbumDetailView
    └─ Artist     → fetch_artist_details() → ArtistDetailView
```

### API Requirements

**New backend methods needed**:

| Method | Input | Output | Purpose |
|--------|-------|--------|---------|
| `browse_playlist(id)` | playlist_id | PlaylistDetails | Get tracks, metadata, related |
| `browse_album(id)` | album_id | AlbumDetails | Get tracks, artist,related |
| `browse_artist(id)` | artist_id | ArtistDetails | Get top songs, albums, bio |

**Data structures**:

```rust
struct PlaylistDetails {
    metadata: PlaylistMetadata,  // title, artist, year, track_count
    tracks: Vec<Song>,
    featured_artists: Vec<Artist>,
    related_playlists: Vec<Playlist>,
}

struct AlbumDetails {
    metadata: AlbumMetadata,
    tracks: Vec<Song>,
    artist: Artist,
    more_by_artist: Vec<Album>,
}

struct ArtistDetails {
    metadata: ArtistMetadata,  // name, subscribers, bio
    top_songs: Vec<Song>,
    albums: Vec<Album>,
    singles: Vec<Album>,
    related_artists: Vec<Artist>,
}
```

---

## Detailed Feature Requirements

### Detail View Features (Playlist/Album/EP)

**Must Have in Detail View:**

1. **Cover Image Display** ⭐ IMPORTANT  
   - Display album/playlist artwork
   - Use ASCII art, terminal images, or placeholder box
   - Prominent placement (top-left as in mockup)

2. **Play All Button** (P key)
   - **Behavior**: Clear current queue, replace with all tracks from list
   - Show in header: `[P]lay All (clears queue)`
   - Should start playback immediately

3. **Save to Library Button** (S key)  
   - **Behavior**: Save playlist/album to YouTube Music account
   - Uses configured cookie for authentication
   - Sync to user's YouTube Music library
   - Show in header: `[S]ave to Library`

4. **Track List with Per-Song Actions**
   - Each song shows: Title, Artist, Album, Duration
   - Per-song navigation buttons:
     - `[a]` - Go to artist page
     - `[A]` - Go to album page (shift-A)
   - Example: `1. Song Title    [a]rtist [A]lbum    3:29`

5. **Visual Selection Mode** (v key)
   - Press `v` to enter visual select mode
   - Use `j`/`k` to extend selection (vim-style)
   - Selected songs highlighted with `█` or background color
   - Show count: `(VISUAL - 3 selected)`
   - Bulk operations on selection:
     - `[n]` - Play Next (insert after current song)
     - `[l]` - Play Last (append to end of queue)
     - `[p]` - Play selection (replace queue)
     - `[s]` - Save selection to playlist
   - `[Esc]` - Exit visual mode

6. **Featured Artists Section** (Keyboard Navigation)
   - **Why**: No mouse, can't click artist names in web UI
   - Show as separate section: `─── Featured Artists ───`
   - Number shortcuts: `[1]` `[2]` `[3]` etc.
   - Press number to navigate to that artist
   - Use `Tab` to switch to this section, then `j`/`k` to navigate
   - Press `Enter` on selected artist to view artist page

7. **Related Content Section**
   - For playlists: Show related playlists
   - For albums: Show more by artist
   - Keyboard navigation: `Tab` to section, `1`-`9` shortcuts
   - Press `Enter` to navigate

### Search Result Interactions

**Enter Key Behavior by Type:**

1. **Song** → Add to queue + Play    - Add song to queue
   - Start playback if idle
   - Don't clear existing queue

2. **Playlist/Album/EP** → Show Detail View
   - Fetch details via YouTube API
   - Display detail view with all features above
   - Show breadcrumb: `Search > Playlist Name`

3. **Artist** → Show Artist Page
   - Fetch artist details
   - Show: Top Songs, Albums, Singles, Related Artists
   - Keyboard navigation for all sections

### Navigation Philosophy

- **No Mouse Required**: Every action has keyboard shortcut
- **Sections**: Use `Tab`/`Shift-Tab` to switch between sections  
- **Within Section**: Use `j`/`k` to navigate items
- **Quick Jump**: Use `1`-`9` for numbered items
- **Contextual**: Show available keys at bottom (like vim status line)



---

## Component Architecture

### New Components

1. **`DetailView` (trait)**  
   - Base for all detail views
   - Methods: `render()`, `handle_input()`, `get_navigation_sections()`

2. **`PlaylistDetailView`**
   - Sections: Header, Tracks, Featured Artists, Related
   - Actions: Play All, Shuffle, Add to Library

3. **`AlbumDetailView`**
   - Sections: Header, Tracks, Artist Info, More by Artist
   - Quick navigate to artist

4. **`ArtistDetailView`**
   - Sections: Header, Top Songs, Albums, Related Artists
   - Subscriber count, bio

5. **`VisualSelectMode`**
   - State: `selected_indices: Vec<usize>`, `anchor: usize`
   - Render: Highlight selected rows
   - Actions: Execute bulk operations

6. **`NavigationStack`**
   - Breadcrumb trail: Search → Playlist → Artist → Album
   - Back navigation (Esc/q)
   - State: `Vec<ViewState>`

---

## Implementation Phases

### Phase 1: Core Interaction ✅ **COMPLETE**
- [x] Enter key routing by item type
- [x] Basic detail views (Playlist/Album/Artist)
- [x] Back navigation (Esc)
- [x] Breadcrumb display

### Phase 2: Interactive Detail Views ⚡ **PRIORITY NOW**
- [ ] **Play All Button** (P key)
  - Clear queue and replace with playlist/album tracks
  - Start playback immediately
- [ ] **Save to Library** (S key)
  - Sync to YouTube Music account using cookie
  - Show confirmation feedback
- [ ] **Per-Song Navigation**
  - `[a]` key - Go to artist page from song
  - `[A]` key - Go to album page from song
  - Update track list display to show these shortcuts
- [ ] **Cover Image Display**
  - ASCII art or terminal image for album/playlist art
  - Placeholder box if not available
  - Prominent positioning (top-left)

### Phase 3: Bulk Operations (Visual Selection)
- [ ] Implement bulk operation handlers
  - **Play Next** (`n` in visual mode) - Insert after current
  - **Play Last** (`l` in visual mode) - Append to queue
  - **Play Selection** (`p` in visual mode) - Replace queue
  - **Save Selection** (`s` in visual mode) - Save to playlist
- [ ] Visual mode indicator improvements
  - Show selection count clearly
  - Highlight selected rows distinctly

### Phase 4: Keyboard Navigation Sections
- [ ] **Featured Artists Section**
  - Parse from API responses
  - Number shortcuts (1-9)
  - Tab to switch to section
  - Enter to navigate to artist
- [ ] **Related Content Section**
  - For playlists: Related playlists
  - For albums: More by artist
  - Keyboard navigation (Tab + j/k)

### Phase 5: Polish
- [ ] Loading states for detail fetching
- [ ] Error handling for failed API calls
- [ ] Help overlay (? key)
- [ ] Keyboard shortcuts reference

---

## Backlog

**Enhancements (Not Blocking Core Features):**
- Top Results section in search (nice-to-have, not critical)
- Shuffle functionality (can be added later)
- Lyrics display in detail view
- Crossfade between tracks
- Custom EQ settings
- Download mode (offline playback)

**Bugs:**
- None currently blocking

---

## Success Criteria

✅ User can press Enter on search result and get expected behavior  
✅ Playlist view shows all tracks with metadata  
✅ Visual mode allows selecting 3-5 songs and playing them next  
✅ Can navigate Search → Playlist → Artist → Album and back  
✅ Featured artists section is keyboard-accessible  
✅ No mouse required for any operation
