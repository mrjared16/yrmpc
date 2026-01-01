# ADR: Section-as-Container Pattern

**Status**: Approved (Implementation: task-58)
**Date**: 2026-01-01
**Author**: Agent + streaming-architecture-review skill
**Decision**: Make Section a first-class domain container, not a marker in flat lists

---

## Context

### The Problem

Search results were experiencing a "nested headers" bug where section headers appeared inside other sections. After 5+ iteration cycles trying to fix this with various marker-based approaches, architectural analysis revealed the root cause: **sections were encoded as data, not modeled as structure**.

```rust
// BROKEN APPROACH (5+ failed iterations)
items = [
    Header("Top Results"),  // Just another item
    Song(A),
    Song(B),
    Header("Songs"),        // Just another item
    Song(C),
    ...
]
```

**Why this kept failing:**
1. Every consumer must scan for `Header` markers and reconstruct sections
2. `SearchPaneV2::reorder_by_config_sections()` groups items and adds headers
3. `build_sections()` doesn't recognize embedded headers, re-groups by type
4. Headers get pushed into "Songs" section as regular items → nested display
5. Config ordering logic duplicated across UI and domain layers

### The Anti-Pattern: Encoding Structure as Data

This is analogous to modeling a tree as a flat list with indent markers:

```rust
// BAD: Structure hidden in data
["  parent", "    child1", "    child2", "  parent2"]

// GOOD: Structure explicit
Tree {
    Node("parent", [Node("child1"), Node("child2")]),
    Node("parent2", [])
}
```

**The fundamental flaw:** We were flattening the YouTube API's native shelf structure into markers, then trying to reconstruct it at render time.

---

## Decision

### Make Section a First-Class Domain Object

Sections are **containers** that hold their items, not **markers** embedded in flat lists.

```rust
// Domain layer (pure data structures)
pub struct Section {
    pub key: String,           // "songs", "albums", "top_results"
    pub title: String,         // Display name
    pub items: Vec<MediaItem>, // Content (NOT flat with markers)
}

pub struct SearchResults {
    pub query: String,
    pub sections: Vec<Section>, // Structured!
}
```

### Three-Layer Separation of Concerns

```
┌─────────────────────────────────────────────────────────┐
│ DOMAIN LAYER                                            │
│ • Section struct (key, title, items)                    │
│ • SearchResults { sections: Vec<Section> }              │
│ • group_items_into_sections() utility                   │
│ • NO config awareness (pure data)                       │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ BACKEND LAYER                                           │
│ • YouTube: Parse shelves → Vec<Section> directly        │
│ • MPD: Use group_items_into_sections() utility          │
│ • Returns SearchResults in NATIVE order                 │
│ • NO config awareness                                   │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ UI LAYER                                                │
│ • apply_config_order(sections, config) → Vec<Section>  │
│ • Config ordering is a PRESENTATION concern             │
│ • Maps Section → SectionView                            │
└─────────────────────────────────────────────────────────┘
```

### Key Principle: Config Ordering Belongs in UI

**Before (WRONG):**
```rust
// Domain layer doing presentation work!
impl SearchResults {
    pub fn reorder_by_config(&mut self, order: &[String]) { ... }
}
```

**After (CORRECT):**
```rust
// UI layer handles presentation
impl SearchPaneV2 {
    fn apply_config_order(
        &self,
        sections: Vec<Section>,
        config_order: &[String]
    ) -> Vec<Section> { ... }
}
```

---

## Consequences

### Positive

1. **No Reconstruction Needed**
   - Sections are already structured when returned from backend
   - UI just iterates: `for section in sections { ... }`

2. **Single Responsibility**
   - Domain: Owns data structure
   - Backend: Produces sections in native order
   - UI: Applies config-driven ordering

3. **Backend-Agnostic**
   - YouTube: Parse native shelves
   - MPD: Use domain utility
   - Same `SearchResults` type for all backends

4. **Type Safety**
   - No need to scan for markers
   - Compiler enforces structure
   - Headers can't be in wrong places

5. **Eliminates Entire Class of Bugs**
   - No more nested headers
   - No more reconstruction logic bugs
   - No more dual-ownership conflicts

### Negative

1. **Migration Effort**
   - Change `SearchResultsContent.items: Vec<DetailItem>` → `sections: Vec<Section>`
   - Update YouTube parser to emit sections
   - Update UI to use `apply_config_order()`
   - Remove `MediaItem::Header` variant

2. **API Surface Area**
   - Adds `Section` struct to domain
   - Adds `group_items_into_sections()` utility

### Neutral

1. **Config Stays in Config**
   - Config location doesn't change
   - Just moves from domain to UI layer

---

## Implementation Plan (task-58)

### Phase 1: Domain Layer (Pure Data)
1. Add `Section` struct (`src/domain/section.rs`)
2. Add `SearchResults` struct (`src/domain/search.rs`)
3. Add `group_items_into_sections()` utility (for flat backends)

### Phase 2: Backend API
4. Update `Discovery::search` return type to `SearchResults`
5. Update YouTube backend to parse shelves → `Vec<Section>`

### Phase 3: UI Layer (Presentation)
6. Add `apply_config_order()` in `SearchPaneV2`
7. Simplify `build_sections()` to just map `Section → SectionView`
8. Remove `reorder_by_config_sections()` from UI

### Phase 4: Cleanup
9. Remove `MediaItem::Header` variant
10. Remove `DetailItem::header()` factory
11. Add tests for nested headers fix
12. Add tests for config ordering

---

## Design Rationale

### Why Not Keep Headers as Markers?

**Attempted fixes (all failed):**
1. Add `MediaItem::Header` → Headers become items, need scanning
2. `reorder_by_config_sections` in UI → Returns flat list with embedded headers
3. `build_sections` detects headers → Doesn't recognize them, re-groups by type
4. Add `DetailItem::header()` factory → Same problem, still a flat list
5. Add "pre-sectioned" flag → Complex conditional logic, multiple code paths

**Root cause:** All attempts tried to make markers work. The problem is markers themselves.

### Why Config Ordering in UI Layer?

**Separation of Concerns:**
- **Config** = User preference (presentation layer)
- **Section structure** = Data organization (domain layer)
- **Backend response** = Service contract (backend layer)

Mixing config into domain creates tight coupling between user preferences and data structures.

### Why Not Enum for Section Keys?

**String vs. Enum trade-off:**

```rust
// Considered:
pub enum SectionKey {
    TopResults,
    Songs,
    Albums,
    Artists,
    Playlists,
    Videos,
    Custom(String), // Extensibility
}
```

**Decision: Use String for now**
- Simpler for initial implementation
- Backend-specific sections don't require code changes
- Can refactor to enum later if needed (backward-compatible)
- Config already uses strings

---

## Historical Context

### Timeline of Failures

| Date | Attempt | Why It Failed |
|------|---------|---------------|
| Iteration 1 | Add `MediaItem::Header` | Headers need scanning to find |
| Iteration 2 | UI groups items | Returns flat list with headers |
| Iteration 3 | `build_sections` should respect | Doesn't recognize embedded headers |
| Iteration 4 | Add `DetailItem::header()` | Still a flat list with markers |
| Iteration 5 | Add pre-sectioned detection | Complex flags, multiple code paths |
| **2026-01-01** | **Sections as containers** | **Fixes root cause** |

### Lessons Learned

1. **Don't encode structure as data** - Use type system to model structure
2. **5+ failed iterations = wrong abstraction** - Step back and rethink
3. **Config is presentation** - Keep it out of domain layer
4. **Backend-agnostic requires domain abstraction** - Not UI workarounds

---

## Future Considerations

### When Adding New Backend

```rust
// If backend has native sections (like YouTube):
impl Discovery for SpotifyBackend {
    fn search(&mut self, query: SearchQuery) -> Result<SearchResults> {
        let response = self.api.search(&query);
        let sections = response.sections.iter().map(|s| Section {
            key: s.type_name.clone(),
            title: s.display_name.clone(),
            items: parse_items(&s.items),
        }).collect();
        Ok(SearchResults { query: query.q, sections })
    }
}

// If backend returns flat items (like MPD):
impl Discovery for MpdBackend {
    fn search(&mut self, query: SearchQuery) -> Result<SearchResults> {
        let items = self.mpd.search(&query)?;
        let sections = group_items_into_sections(items);
        Ok(SearchResults { query: query.q, sections })
    }
}
```

### Backward Compatibility

**Not applicable** - This is a new architecture. Once implemented:
- Old `MediaItem::Header` can be removed
- No backward compatibility needed for internal structures

---

## References

- **docs/ARCHITECTURE.md** - Section Architecture section
- **task-58** - Implementation tracking
- **Memory: section-architecture.md** - Quick reference guide
- **Skill: streaming-architecture-review** - Architectural analysis that found root cause

---

## Approval

**Decision Maker**: Project Architecture Review
**Consulted**: streaming-architecture-review skill analysis
**Informed**: task-58 created with 11 acceptance criteria

**Rationale**: Five iteration cycles proved the marker approach fundamentally flawed. Making Section a container fixes the root cause and establishes proper separation of concerns for backend-agnostic architecture.
