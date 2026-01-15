# PlayIntent Implementation Learnings

## Rust Enum Ordering Gotcha (2026-01-15)

**Issue**: Rust's `derive(Ord)` on enums orders variants by declaration position, not semantic meaning.

**Context**: `PreloadTier` enum needs urgency-based ordering (Immediate > Gapless > Eager > Background), but natural declaration order is opposite.

**Solution**: Declare enum variants in reverse priority order:
```rust
pub enum PreloadTier {
    Background,  // Lowest priority - declared first
    Eager,
    Gapless,
    Immediate,   // Highest priority - declared last
}
```

**Rationale**: 
- Rust's derived `Ord` compares enum discriminants, which increment from first to last variant
- Last variant gets highest discriminant → highest in comparisons
- Comment preserved to prevent future "fixes" that break semantics

**Test Verification**: `test_preload_tier_ordering` catches this regression.

## Protocol Module Structure

**Pattern**: YouTube backend uses `protocol/` directory (not single `protocol.rs` file)
- `protocol/mod.rs` - Main protocol types, IPC framing
- `protocol/play_intent.rs` - PlayIntent-specific types (this bead)

**Import Pattern**: Domain types use `use crate::domain::Song;` consistently across protocol files.

## Type Design Decisions

**RequestId**: `u64` sufficient (no need for UUID crate)
- Simple atomic counter in daemon
- Lightweight serialization
- Fits IPC frame size constraints

**Shuffle Handling**: Boolean in `PlayIntent::Context` 
- TUI handles actual shuffle logic (Fisher-Yates)
- Daemon just respects intent priorities
- Avoids coupling daemon to specific shuffle algorithm

## Task 1.2: Protocol Enum Updates

**Date**: 2026-01-15

### What Was Done
- Added `PlayWithIntent { intent, request_id }` and `CancelRequest { request_id }` to ServerCommand enum
- Added `PlayResult(Result<(), PlayError>)` to ServerResponse enum  
- Added import: `use play_intent::{PlayIntent, RequestId, PlayError};`
- Added stub handlers in server/mod.rs (return error responses)
- Verified with `cargo build` and `cargo test` - all pass

### Key Insights
- **Enum exhaustiveness checking**: Rust compiler catches missing match arms immediately
- **Stub implementation pattern**: Return error messages for unimplemented commands
- **Comment justification**: Added necessary section header comment for intent-based commands group

### Files Modified
- `rmpc/src/backends/youtube/protocol/mod.rs` (imports + enum variants)
- `rmpc/src/backends/youtube/server/mod.rs` (stub match arms)

### Next Task
Task 1.3 will implement the real handlers for these commands using the PlayIntent architecture.

