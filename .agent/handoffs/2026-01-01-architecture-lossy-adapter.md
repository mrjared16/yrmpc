# Architecture Analysis: Lossy Adapter Chain Anti-Pattern

**Date**: 2026-01-01
**Status**: Analysis started, incomplete
**Triggered by**: Task-53/Task-39 root cause investigation

## The Anti-Pattern Identified

### "Lossy Adapter Chain"

Data flows through multiple conversion layers, and one incomplete adapter silently drops fields:

```
YouTube API Response
        │
        ▼
┌───────────────────┐
│  SearchItemData   │  ← Rich: title, artist, thumbnail, browse_id
│  (protocol.rs)    │
└────────┬──────────┘
         │ search_item_data_to_song()
         ▼
┌───────────────────┐
│      Song         │  ← Rich: metadata HashMap with all fields ✓
│  (domain/song.rs) │
└────────┬──────────┘
         │ Item::from(&Song)
         ▼
┌───────────────────┐
│      Item         │  ← Rich: all fields ✓
│  (api/content.rs) │
└────────┬──────────┘
         │ item_to_song()  ← 🐛 LOSSY HERE
         ▼
┌───────────────────┐
│      Song         │  ← POOR: missing thumbnail, type
└───────────────────┘
```

## SOLID Violations

1. **Open/Closed Principle**: Adding new fields requires updating EVERY converter
2. **Liskov Substitution**: Same type (Song) but different data quality

## Similar Patterns to Audit

Found in codebase search - need verification:

1. `SongData::to_song()` - protocol.rs:201
2. `Item::from(&Song)` - api/content.rs:167
3. `search_item_data_to_song()` - youtube/client.rs:36
4. `song_from_playable()` - youtube/client.rs:46
5. `song_from_browsable()` - youtube/client.rs:67

## Proposed Solutions (Not Yet Implemented)

### Option 1: Single Canonical Type
Eliminate intermediate conversions, use one rich type throughout.

### Option 2: Builder Pattern with Required Fields
Make field omission a compile error.

### Option 3: Derive Macro for Field Mapping
Auto-generate conversions that map all fields.

### Option 4: Integration Tests
E2E tests that verify field preservation through full pipeline.

## Incomplete Analysis

The architectural review was interrupted. To continue:

1. Run `/streaming-architecture-review` skill
2. Prompt: "Continue analyzing the Lossy Adapter Chain pattern and propose solutions"
3. Review similar conversion functions for field completeness

## Questions for User

1. Should we consolidate to fewer types?
2. Is backward compatibility with Song worth the complexity?
3. What's the testing strategy to prevent future field loss?
