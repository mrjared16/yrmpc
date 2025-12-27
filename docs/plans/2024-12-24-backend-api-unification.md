# Backend API Unification

**Date:** 2024-12-24  
**Status:** ✅ COMPLETE  
**Author:** AI Assistant + Human Review

---

## Executive Summary

Unify the backend abstraction layer to be truly SOLID-compliant by:
1. ✅ Adding `Discovery::details()` with domain types (Phase 1 - COMPLETE)
2. ✅ Creating UI view models + fixing playlist bug (Phase 2 - COMPLETE)
3. ✅ Refactor to Type-Safe Hybrid ContentDetails (Phase 2.5 - COMPLETE)
4. ✅ Removing `youtube()` and `mpd()` escape hatches (Phase 3 - COMPLETE)
5. ✅ Migrating to new controller API + deprecating legacy (Phase 4 - COMPLETE)

### Phase 4 Completed
- ✅ Removed deprecated `domain/details.rs` module  
- ✅ Removed deprecated `youtube/backend.rs` (YouTubeBackend stub)
- ✅ Updated `ui/views/details.rs` to use new content types
- ✅ Migrated all deprecated method calls to use controllers
- ✅ Marked `MusicBackend` trait as deprecated
- ✅ Verified `api::*` traits have no MPD type leakage

### Final Architecture

```
UI Code
    │
    ▼
BackendDispatcher
    ├── .playback()  → PlaybackController → api::Playback
    ├── .queue()     → QueueController    → api::Queue  
    ├── .library()   → LibraryBrowser     → api::Discovery
    └── .volume_control() → VolumeController → api::Volume
    
Backends implement api::* traits (MPD-free):
    ├── MpdBackend (src/backends/mpd/api_impl.rs)
    └── YouTubeProxy (src/backends/youtube/client.rs)
```

---

## Part 1: Problem Statement (Unchanged)

### Problem 1: Escape Hatches Break Abstraction
### Problem 2: Two Parallel Trait Systems  
### Problem 3: MPD Types Leak Through Public API
### Problem 4: Missing Universal `details()` Abstraction
### Problem 5: Playlist Uses Wrong Query ✅ FIXED

---

## Part 2: Architecture Refinement (NEW)

### The Original Problem with Phase 1-2 Design

The current `domain::details` types are **YouTube-biased**:

```rust
// Current design - YouTube-specific fields
pub struct ArtistDetails {
    pub subscribers: Option<String>,      // YouTube-only
    pub related_artists: Vec<ArtistRef>,  // YouTube-only
}

pub struct PlaylistDetails {
    pub featured_artists: Vec<ArtistRef>, // YouTube-only
    pub related_playlists: Vec<PlaylistRef>, // YouTube-only
}
```

**Issues identified:**
1. MPD returns sparse objects with empty vectors (ambiguous: no data vs not supported)
2. Adding Spotify would require adding more fields (field explosion)
3. UI can't distinguish "feature not supported" from "no results"
4. Violates Open/Closed principle - adding backends requires changing types

### Refined Design: Type-Safe Hybrid Architecture

After extensive analysis (see conversation log), the refined design uses:
- **Type-specific structs** for semantic guarantees (AlbumContent, ArtistContent, PlaylistContent)
- **Dynamic Extensions** for optional/backend-specific content
- **#[non_exhaustive] enums** for extensibility without breaking changes

```
┌─────────────────────────────────────────────────────────────────┐
│                        ContentDetails                            │
│  ┌─────────────────┬─────────────────┬─────────────────┐        │
│  │  AlbumContent   │  ArtistContent  │ PlaylistContent │        │
│  ├─────────────────┼─────────────────┼─────────────────┤        │
│  │ • id (required) │ • id (required) │ • id (required) │        │
│  │ • title (req)   │ • name (req)    │ • title (req)   │        │
│  │ • artist (req)  │ • top_songs     │ • author        │        │
│  │ • tracks        │ • thumbnail     │ • tracks        │        │
│  │ • thumbnail     │ • bio           │ • thumbnail     │        │
│  │ • year          │                 │ • track_count   │        │
│  │ • release_type  │                 │                 │        │
│  ├─────────────────┴─────────────────┴─────────────────┤        │
│  │                    Extensions                        │        │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐             │        │
│  │  │ Section  │ │ Section  │ │ Section  │ ...         │        │
│  │  │ Stats    │ │ Related  │ │ Actions  │             │        │
│  │  └──────────┘ └──────────┘ └──────────┘             │        │
│  └──────────────────────────────────────────────────────┤        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Type-specific structs | Compile-time guarantees (album MUST have tracks) |
| Extensions container | Dynamic sections - backends return only what they support |
| #[non_exhaustive] enums | Add new section types without breaking existing code |
| SectionKey enum (not strings) | Type safety, IDE support, refactoring safety |
| StatValue typed variants | UI formats numbers/durations with locale support |
| ContentRef with subtitle | Flexible secondary text without field explosion |

### SOLID Compliance

| Principle | How Satisfied |
|-----------|---------------|
| **SRP** | `AlbumContent` = album data, `Extensions` = optional sections, UI = rendering |
| **OCP** | Add `SectionKey::Lyrics` without changing existing code |
| **LSP** | `ContentDetails::Album(...)` always has valid `tracks`, `artist` |
| **ISP** | Small focused types: `ContentRef`, `Stat`, `Action` |
| **DIP** | UI depends on `ContentDetails`, not `YouTubeAlbum` or `MpdAlbum` |

---

## Part 3: Refined Type Specification

### Core Types

```rust
// =============================================================================
// domain/content.rs - NEW FILE
// =============================================================================

/// Type-safe content details with guaranteed structure per type
#[derive(Debug, Clone)]
pub enum ContentDetails {
    Album(AlbumContent),
    Artist(ArtistContent),
    Playlist(PlaylistContent),
}

/// Album with guaranteed core fields + optional extensions
#[derive(Debug, Clone)]
pub struct AlbumContent {
    // Required - compile-time guarantee
    pub id: String,
    pub title: String,
    pub artist: ContentRef,
    pub tracks: Vec<Song>,
    
    // Optional metadata
    pub thumbnail: Option<String>,
    pub year: Option<u16>,
    pub release_type: Option<ReleaseType>,
    pub description: Option<String>,
    
    // Dynamic extended content
    pub extensions: Extensions,
}

/// Artist with guaranteed core fields + optional extensions
#[derive(Debug, Clone)]
pub struct ArtistContent {
    pub id: String,
    pub name: String,
    
    pub thumbnail: Option<String>,
    pub bio: Option<String>,
    
    // Artist-specific: top songs (not "tracks")
    pub top_songs: Vec<Song>,
    
    pub extensions: Extensions,
}

/// Playlist with guaranteed core fields + optional extensions
#[derive(Debug, Clone)]
pub struct PlaylistContent {
    pub id: String,
    pub title: String,
    
    pub author: Option<ContentRef>,
    pub thumbnail: Option<String>,
    pub description: Option<String>,
    
    pub tracks: Vec<Song>,
    pub track_count: Option<usize>,  // May differ from tracks.len() if paginated
    
    pub extensions: Extensions,
}

/// Lightweight reference for relationships
#[derive(Debug, Clone, Default)]
pub struct ContentRef {
    pub id: String,
    pub name: String,
    pub content_type: ContentType,
    pub thumbnail: Option<String>,
    pub subtitle: Option<String>,  // "2024", "10 tracks", etc.
}
```

### Extensions System

```rust
/// Container for optional/dynamic sections
#[derive(Debug, Clone, Default)]
pub struct Extensions {
    sections: Vec<Section>,
}

impl Extensions {
    pub fn new() -> Self { Self { sections: Vec::new() } }
    pub fn builder() -> ExtensionsBuilder { ExtensionsBuilder::new() }
    pub fn add(&mut self, section: Section) -> &mut Self { ... }
    pub fn get(&self, key: SectionKey) -> Option<&Section> { ... }
    pub fn iter(&self) -> impl Iterator<Item = &Section> { ... }
    pub fn is_empty(&self) -> bool { ... }
}

/// A section of extended content
#[derive(Debug, Clone)]
pub struct Section {
    pub key: SectionKey,
    pub title: String,
    pub content: SectionData,
}

/// Well-known section keys (type-safe, extensible)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum SectionKey {
    // Statistics & Actions
    Stats,
    Actions,
    
    // Related content
    RelatedAlbums,
    RelatedArtists,
    RelatedPlaylists,
    MoreByArtist,
    FeaturedArtists,
    
    // Discography
    Albums,
    Singles,
    Compilations,
    AppearsOn,
}

/// Section data variants (typed, extensible)
#[derive(Debug, Clone)]
#[non_exhaustive]
pub enum SectionData {
    Items(Vec<ContentRef>),
    Tracks(Vec<Song>),
    Stats(Vec<Stat>),
    Actions(Vec<Action>),
    Paginated { items: Vec<ContentRef>, total: usize, has_more: bool },
    Error(String),  // Partial failure handling
}
```

### Statistics & Actions

```rust
#[derive(Debug, Clone)]
pub struct Stat {
    pub key: StatKey,
    pub label: String,
    pub value: StatValue,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum StatKey {
    Year,
    TrackCount,
    Duration,
    Subscribers,
    Followers,
    MonthlyListeners,
    Popularity,
    PlayCount,
}

#[derive(Debug, Clone)]
pub enum StatValue {
    Text(String),
    Number(i64),
    Duration(std::time::Duration),
}

#[derive(Debug, Clone)]
pub struct Action {
    pub kind: ActionKind,
    pub enabled: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum ActionKind {
    Play,
    Shuffle,
    Radio,
    AddToQueue,
    AddToLibrary,
    Share,
}
```

---

## Part 4: Revised Implementation Plan

### Phase 1: Add View Model & `details()` ✅ COMPLETE

- Created `src/domain/details.rs` with domain types
- Created `src/backends/api/` module with Discovery trait
- Created `src/ui/views/` module with DetailsPage view model
- Implemented `Discovery::details()` for YouTube and MPD
- Added BackendDispatcher dispatch

### Phase 2: Fix Playlist Bug & Migrate Callers ✅ COMPLETE

- Fixed `get_playlist_details()` to use `GetPlaylistDetailsQuery` for metadata
- Added `From` impls for YouTube→domain type conversions
- Added `.into()` conversions in search panes
- Build passes, 655 tests pass

### Phase 2.5: Refactor to Type-Safe Hybrid (NEW)

**Goal:** Replace current YouTube-biased domain types with the refined architecture.

**New Files:**
- `src/domain/content.rs` - New ContentDetails, AlbumContent, etc.

**Modified Files:**
- `src/domain/mod.rs` - Export new content module
- `src/backends/api/discovery.rs` - Update return type
- `src/backends/youtube/client.rs` - Build Extensions
- `src/backends/mpd/api_impl.rs` - Build minimal Extensions
- `src/backends/messaging.rs` - Update QueryResult variants
- `src/ui/views/details.rs` - Update conversions
- `src/ui/panes/search/*.rs` - Update consumers

**Checklist:**
- [ ] Create `src/domain/content.rs` with new types
- [ ] Add ExtensionsBuilder for ergonomic construction
- [ ] Update YouTube backend to return AlbumContent with Extensions
- [ ] Update MPD backend to return minimal AlbumContent
- [ ] Update UI to render Extensions dynamically
- [ ] Deprecate old `domain/details.rs` types
- [ ] Verify: `cargo build && cargo test`

**Estimated Effort:** ~700 lines, 2-3 focused sessions

### Phase 3: Delete Escape Hatches & Add Optional Traits

**Goal:** Remove `youtube()`, `mpd()`, `backend_mut()` and add optional traits.

(Unchanged from original plan)

### Phase 4: Remove Legacy Traits

**Goal:** Delete `MusicBackend` and `QueueOperations` traits entirely.

(Unchanged from original plan)

---

## Part 5: Backend Comparison Matrix

| Feature | YouTube | MPD | Future Spotify |
|---------|---------|-----|----------------|
| `AlbumContent.tracks` | ✅ Full list | ✅ From tags | ✅ Full list |
| `AlbumContent.artist.thumbnail` | ✅ | ❌ None | ✅ |
| `AlbumContent.year` | ✅ | ⚠️ Parse from tags | ✅ |
| `Extensions::Stats` | ✅ Subscribers, etc | ❌ Empty | ✅ Popularity |
| `Extensions::RelatedAlbums` | ✅ "More by artist" | ❌ Empty | ✅ "Fans also like" |
| `Extensions::Actions` | ✅ Play, Shuffle, Radio | ✅ Play, AddToQueue | ✅ All |

**Key insight**: MPD returns valid `AlbumContent` with empty `Extensions`. No fake data, no ambiguity.

---

## Part 6: Per-Backend UI Configuration

The rmpc config system can specify section ordering/visibility per backend:

```ron
backend_layouts: {
    "youtube": {
        sections_order: ["stats", "actions", "tracks", "related_albums"],
        hidden_sections: [],
    },
    "mpd": {
        sections_order: ["actions", "tracks"],
        hidden_sections: ["stats"],  // MPD stats aren't useful
    },
}
```

This allows:
- YouTube users get rich detail pages
- MPD users get streamlined experience
- Future backends can define their own defaults

---

## Part 7: Success Criteria (Updated)

### Quantitative
- **Before:** 50+ methods across 2 trait systems, YouTube-biased types
- **After:** 25 core + 10 optional methods, ONE trait system, backend-agnostic types

### Qualitative
- [ ] No `youtube()` or `mpd()` escape hatches
- [ ] No `MusicBackend` or `QueueOperations` traits
- [ ] No MPD types in public API
- [ ] ✅ Playlist titles display correctly (DONE)
- [ ] No empty vectors masquerading as missing features
- [ ] Extensions system for dynamic content
- [ ] Adding Spotify requires only implementing 5 core traits + Extensions

### SOLID Compliance
- **S** (Single Responsibility): Type-specific structs + Extensions
- **O** (Open/Closed): Add SectionKey variants without changing existing code
- **L** (Liskov Substitution): Any backend works in any UI code
- **I** (Interface Segregation): Small focused types, optional traits for extras
- **D** (Dependency Inversion): UI depends on ContentDetails, not backend types

---

## Appendix: Conversation Analysis Summary

Key insights from the design refinement discussion:

1. **Song type is well-designed** - follows Mopidy's metadata HashMap pattern
2. **ContentDetails needs refactoring** - current types are YouTube-biased
3. **Section-based approach** solves the "empty vec" ambiguity problem
4. **Type-specific structs** preserve semantic guarantees
5. **#[non_exhaustive]** enables forward compatibility
6. **Per-backend config** allows UI customization without code changes
7. **Builder pattern** improves ergonomics for Extensions construction
8. **Typed StatValue** enables locale-aware formatting
