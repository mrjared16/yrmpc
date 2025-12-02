# UI/UX Adaptation Plan: Working with rmpc's Architecture

## Discovered: rmpc Already Has Infrastructure!

You're absolutely right - there's existing UI infrastructure I should build on, not reinvent.

### What rmpc Already Has

#### 1. **Pane Trait System** ✅

All UI components implement the `Pane` trait:

```rust
pub trait Pane {
    fn render(&mut self, frame: &mut Frame, area: Rect, ctx: &Ctx) -> Result<()>;
    fn handle_action(&mut self, event: &mut KeyEvent, ctx: &mut Ctx) -> Result<()>;
    fn on_event(&mut ...


self, event: &mut UiEvent, is_visible: bool, ctx: &Ctx) -> Result<()>;
    fn on_query_finished(&mut self, id: &str, data: MpdQueryResult, ...) -> Result<()>;
    // ... other lifecycle methods
}
```

**Existing panes**:
- `SearchPane` - Search with suggestions overlay
- `QueuePane` - Queue management
- `PlaylistsPane` - Browse playlists
- `AlbumsPane` - Browse albums (exists!)
- `ArtistPane` - Browse artists (exists!)

#### 2. **Search Suggestions Pattern** ✅

SearchPane already has an overlay pattern for suggestions (lines 73-75, 158-178):

```rust
pub struct SearchPane {
    // ...
    suggestions: Vec<String>,
    showing_suggestions: bool,
    suggestions_state: ListState,
}

fn render_suggestions(&mut self, frame, area, ctx) {
    let block = Block::default()
        .borders(Borders::ALL)
        .title("Suggestions");
    
    let items: Vec<ListItem> = self.suggestions.iter()
        .map(|s| ListItem::new(Span::raw(s)))
        .collect();
    
    let list = List::new(items)
        .block(block)
        .highlight_style(ctx.config.theme.current_item_style);
    
    frame.render_stateful_widget(list, area, &mut self.suggestions_state);
}
```

**This is the pattern I should follow for detail views!**

#### 3. **UiAppEvent Routing** 🚧 (Partially Implemented)

SearchPane already tries to route to detail views (lines 704-760):

```rust
// In SearchPane::handle_result_phase_action, when user presses Enter:
if let Some(type_) = selected.metadata.get("type").and_then(|v| v.first()) {
    if type_ == "album" {
        log::info!("Opening album: {}", album_id);
        ctx.app_event_sender.send(AppEvent::UiEvent(
            UiAppEvent::OpenAlbum(album_id.clone())
        ))?;
        return Ok(());
    } else if type_ == "artist" {
        log::info!("Opening artist: {}", selected.file);
        ctx.app_event_sender.send(AppEvent::UiEvent(
            UiAppEvent::OpenArtist(selected.file.clone())
        ))?;
        return Ok(());
    } else if type_ == "playlist" {
        log::info!("Opening playlist: {}", selected.file);
        ctx.app_event_sender.send(AppEvent::UiEvent(
            UiAppEvent::OpenPlaylist(selected.file.clone())
        ))?;
        return Ok(());
    }
}
```

**This routing logic exists but the events aren't handled yet!**

#### 4. **Phase-Based Navigation** ✅

SearchPane uses `Phase` enum for state:

```rust
enum Phase {
    Search,
    BrowseResults { filter_input_on: bool },
}
```

Left/Right arrow keys switch between phases. This pattern works!

---

## Why My Original Plan Needs Revision

### ❌ What I Proposed (Too Complex)
- Create new `PlaylistDetailView`, `AlbumDetailView`, `ArtistDetailView` components
- New `NavigationStack` system
- Custom routing logic

**Problem**: This ignores rmpc's existing:
- `AlbumsPane` and `ArtistPane` already exist!
- `UiAppEvent` routing pattern
- Tab-based navigation system

### ✅ What I Should Do Instead (Work with rmpc)
1. **Enhance existing AlbumsPane/ArtistPane** instead of creating new ones
2. **Complete the UiAppEvent routing** that's partially implemented
3. **Use rmpc's tab switching** instead of a new navigation stack
4. **Follow the suggestions overlay pattern** for detail views

---

## Revised Implementation Plan

### Phase 1: Complete UiAppEvent Routing

#### Step 1: Define UiAppEvent variants

**File**: `rmpc/src/ui/mod.rs`

```rust
pub enum UiAppEvent {
    // Existing variants...
    
    // NEW: Navigation events
    OpenAlbum(String),      // album_id
    OpenArtist(String),     // artist_id
    OpenPlaylist(String),   // playlist_id
}
```

#### Step 2: Handle events in UI layer

**File**: `rmpc/src/ui/mod.rs` (or wherever Ui struct is)

```rust
impl Ui {
    fn handle_ui_event(&mut self, event: UiAppEvent, ctx: &Ctx) -> Result<()> {
        match event {
            UiAppEvent::OpenAlbum(album_id) => {
                // Switch to Albums tab
                self.switch_to_tab(PaneType::Albums);
                
                // Tell AlbumsPane to load this album
                // Use query mechanism or direct state update
                self.albums_pane.load_album(&album_id, ctx)?;
            }
            UiAppEvent::OpenArtist(artist_id) => {
                self.switch_to_tab(PaneType::Artist);
                self.artist_pane.load_artist(&artist_id, ctx)?;
            }
            UiAppEvent::OpenPlaylist(playlist_id) => {
                // If PlaylistDetailPane exists, use it
                // Otherwise enhance PlaylistsPane to show detail view
                self.switch_to_tab(PaneType::Playlists);
                self.playlists_pane.load_playlist(&playlist_id, ctx)?;
            }
            // ... other events
        }
        Ok(())
    }
}
```

### Phase 2: Enhance Existing Panes

#### AlbumsPane Enhancement

**Current**: Browses albums from MPD library  
**Need**: Load specific album by YouTube album_id

```rust
impl AlbumsPane {
    // NEW METHOD
    pub fn load_album(&mut self, album_id: &str, ctx: &Ctx) -> Result<()> {
        // Extract ID from "album:XXXXX" format
        let id = album_id.strip_prefix("album:").unwrap_or(album_id);
        
        // Query YouTube API for album details
        ctx.query()
            .id("album_details")
            .target(PaneType::Albums)
            .query(move |client| {
                let details = client.browse_album(id)?;
                Ok(MpdQueryResult::AlbumDetails(details))
            });
        
        Ok(())
    }
}
```

#### ArtistPane Enhancement

Similar to AlbumsPane - add `load_artist(&artist_id)` method.

#### PlaylistsPane Enhancement  

Add detail view phase similar to SearchPane's two-phase approach:

```rust
enum PlaylistPhase {
    List,           // Show all playlists
    Detail {        // Show specific playlist details
        playlist_id: String,
        tracks: Vec<Song>,
    },
}
```

### Phase 3: Detail View Rendering

**Follow SearchPane's suggestion overlay pattern**:

```rust
// In PlaylistsPane or new PlaylistDetailOverlay
fn render_playlist_detail(
    &mut self,
    frame: &mut Frame,
    area: Rect,
    details: &PlaylistDetails,
    ctx: &Ctx,
) {
    // Split area into sections
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(5),    // Header with metadata
            Constraint::Min(10),      // Tracks list
            Constraint::Length(3),    // Featured artists
            Constraint::Length(5),    // Related playlists
        ])
        .split(area);
    
    // Render header
    self.render_header(frame, chunks[0], details, ctx);
    
    // Render tracks (reuse browser widget)
    self.render_tracks(frame, chunks[1], &details.tracks, ctx);
    
    // Render featured artists (numbered for quick nav)
    self.render_featured_artists(frame, chunks[2], &details.featured_artists, ctx);
    
    // Render related playlists
    self.render_related(frame, chunks[3], &details.related_playlists, ctx);
}
```

---

## Key Patterns to Follow

### 1. **Use existing Browser widget** for song lists
- Don't reinvent song list rendering
- `BrowserArea` already handles selection, scrolling, marking

### 2. **Use ListState pattern** for navigation
- `suggestions_state: ListState` in SearchPane
- Same pattern for featured artists, related content

### 3. **Use Phase enum** for view states
- Search/BrowseResults pattern
- List/Detail pattern for playlists

### 4. **Use ctx.query()** for async data fetching
- Existing pattern for MPD queries
- Works for YouTube API calls too

### 5. **Use MpdQueryResult** for data passing
- Add new variants: `AlbumDetails`, `ArtistDetails`, `PlaylistDetails`
- Handled in `on_query_finished()`

---

## What This Means for My Backend Work

✅ **YouTube API browse methods are correct** - Keep them!

✅ **Data structures are correct** - PlaylistDetails, AlbumDetails, ArtistDetails are good

⚠️ **Don't need new UI components** - Enhance existing panes instead

⚠️ **Don't need NavigationStack** - Use rmpc's tab system

⚠️ **Do need**:
1. Complete UiAppEvent handling
2. Add browse methods to Client/Server (wire up backend)
3. Enhance existing AlbumsPane/ArtistPane/PlaylistsPane
4. Add new MpdQueryResult variants

---

## Revised Task Breakdown

### Backend (Keep Current Progress) ✅
- [x] YouTube API browse methods
- [x] Data structures (PlaylistDetails, etc.)
- [ ] Wire through Client/Server protocol
- [ ] Add to MpdQueryResult enum

### UI (Revise Approach)
- [ ] Add UiAppEvent::OpenAlbum/Artist/Playlist variants
- [ ] Handle UiAppEvent routing in Ui layer
- [ ] Enhance AlbumsPane with load_album() method
- [ ] Enhance ArtistPane with load_artist() method
- [ ] Add detail phase to PlaylistsPane
- [ ] Implement detail view rendering following SearchPane pattern

### Testing
- [ ] Manual test: Search → select playlist → view details
- [ ] Manual test: Navigate between tabs with detail views
- [ ] Verify back navigation with Esc

---

## Questions for User

1. Should I enhance existing AlbumsPane/ArtistPane or create separate detail views?
2. Should playlist details be in PlaylistsPane or a new tab?
3. Keep breadcrumb navigation or rely on tab switching?

---

## Next Steps (Awaiting Approval)

1. **Document this in implementation_plan.md** (updated strategy)
2. **Wire backend through Client/Server**
3. **Add UiAppEvent variants**
4. **Enhance one pane (AlbumsPane) as proof of concept**
5. **Test end-to-end flow**

This approach works WITH rmpc's architecture, not against it!
