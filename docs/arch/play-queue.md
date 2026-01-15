# PlayQueue Architecture

## Purpose
Defines the two-layer architecture for queue management in the YouTube backend, ensuring strict synchronization between the UI ("what you see") and audio playback ("what you hear").

## Core Concepts

### Two-Layer Architecture

The system is divided into two distinct layers to separate state management from side effects.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 1: PlayQueue (Pure)                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  State Machine (No I/O, No Async)                                │   │
│  │                                                                  │   │
│  │  State:                                                          │   │
│  │    items: HashMap<Id, Song>                                      │   │
│  │    original_order: Vec<Id>                                       │   │
│  │    play_order: Vec<Id>                                           │   │
│  │    current_id: Option<Id>                                        │   │
│  │                                                                  │   │
│  │  Behavior:                                                       │   │
│  │    apply(Command) ──► Vec<Event>                                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │ Events (ItemsAdded, OrderChanged...)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Layer 2: Playback Bridge (Effects)                 │
│  ┌─────────────────────────────┐      ┌──────────────────────────────┐  │
│  │      Event Handlers         │─────►│         Components           │  │
│  │                             │      │                              │  │
│  │  On ItemsAdded:             │      │  • URL Resolver (ytx)        │  │
│  │    Resolve URLs             │      │  • Audio Prefetcher          │  │
│  │    Trigger Prefetch         │      │  • MPV Controller            │  │
│  │                             │      │  • MPRIS Sync                │  │
│  │  On OrderChanged:           │      │  • PendingAdvance FSM        │  │
│  │    Rebuild MPV Playlist     │      └──────────────────────────────┘  │
│  └─────────────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Layer 1: PlayQueue (The Source of Truth)

The `PlayQueue` is a pure Rust struct that manages the logical state of the queue. It knows nothing about YouTube, MPV, or the filesystem.

### State Model
- **ID-based**: All internal references use `Id` (String), never array indices. This prevents race conditions where indices shift during async operations.
- **Dual Orders**:
  - `original_order`: The sequence as added by the user.
  - `play_order`: The sequence currently being played (affected by shuffle).
- **Current Track**: `current_id` points to the active song ID.

### Playback Modes
- **Shuffle**:
  - **OFF**: `play_order` is a clone of `original_order`.
  - **ON**: `play_order` is a shuffled permutation. The `current_id` is always preserved and moved to the front or kept in place depending on user intent.
- **Repeat**:
  - **Off**: Stops after the last track.
  - **All**: Wraps around to the start of `play_order`.
  - **One**: Loops the `current_id`.

### Event-Driven Interface
The PlayQueue follows the Command/Event pattern:

```rust
// Input: Intent
enum QueueCommand {
    Add(Vec<Song>),
    Remove(Vec<Id>),
    SetShuffle(bool),
    SetRepeat(RepeatMode),
    Next,
    Prev,
}

// Output: Facts
enum QueueEvent {
    ItemsAdded { items: Vec<Song>, index: usize },
    ItemsRemoved { ids: Vec<Id> },
    OrderChanged { new_order: Vec<Id> },
    CurrentChanged { old: Option<Id>, new: Option<Id> },
    ModeChanged { shuffle: bool, repeat: RepeatMode },
}

## PlayIntent Queue Mutations

| Intent | Queue Mutation |
|--------|----------------|
| Context | Replace queue, set position to offset |
| Next | Insert after current position |
| Append | Add to end of queue |
| Radio | Replace queue with seed song |

## Layer 2: YouTubePlayback Bridge (The Effect Runner)

The Bridge listens to `QueueEvent`s emitted by Layer 1 and executes the necessary side effects.

### Component Responsibilities

#### 1. URL Resolver & Prefetcher
- **Trigger**: `ItemsAdded` or proximity to current track.
- **Action**: Resolves YouTube video IDs to audio URLs.
- **Prefetch**: Downloads audio chunks to disk (~/.cache/rmpc/audio/).
- **EDL Composition**: Creates Hybrid EDL URLs (`edl://cache,0,10;stream,10,`) allowing seamless transition from cached disk bytes to network stream.

#### 2. MPV Controller
- **Trigger**: `OrderChanged`, `CurrentChanged`.
- **Atomic Rebuild**: When shuffle toggles, the bridge rebuilds the MPV internal playlist *atomically* without stopping playback.
  - Keeps the current playing file.
  - Removes all subsequent entries.
  - Appends the new rest-of-queue in the correct order.

#### 3. PendingAdvance FSM
- **Purpose**: Handles track transitions and repeat logic.
- **States**: `Idle` -> `Playing` -> `PendingAdvance` -> `Playing`.
- **Intent**: On `end-file` from MPV, the FSM determines intent (Next, RepeatOne, Stop) based on Layer 1 state and executes it.

### Synchronization
To prevent desyncs (e.g., fast user input vs slow MPV), the system uses **Epochs**:
1. Every mutation in Layer 1 increments a `state_epoch`.
2. Events carry this epoch.
3. Async handlers check if the event epoch matches the current state epoch. Stale events are discarded.

## Key Invariants
1. **"What you see is what you hear"**: The TUI displays `play_order`, and MPV plays `play_order`.
2. **ID Consistency**: IDs are constant; indices are ephemeral.
3. **Optimistic UI**: Layer 1 updates instantly; Layer 2 catches up.
