# Project Overview

**Purpose**: The *yrmpc* project is a Rust-based terminal music player client for MPD (Music Player Daemon). It provides a modern, configurable TUI with features such as optimistic UI updates, floating modals, background radio daemon, YouTube playback, and rich visual design.

**Tech Stack**:
- Language: Rust (edition 2024, rust-version 1.88)
- Build system: Cargo
- UI: `ratatui` (terminal UI library)
- Async: `crossbeam`, `tokio` style channels, background threads
- Audio backend: MPD via `mpd` crate, optional YouTube via `ytmusicapi`
- Configuration: TOML (`rmpc.ron`, `rmpc.toml`)
- Image handling: `image` crate, supports Kitty/Sixel protocols
- Logging: `flexi_logger`
- Linting/Formatting: `clippy` (pedantic deny), `rustfmt`

**High‑Level Architecture** (from design.md):
- Optimistic UI layer updates state immediately on user actions.
- Core loop connects UI → Scheduler → Network/Audio threads.
- Separate modules: `config`, `core`, `ctx`, `mpd`, `player`, `shared`, `ui`.
- Background Radio daemon monitors queue length and fetches tracks.
- Floating modals for secondary interactions (playlist picker, featuring artists).

**Key Design Principles**:
- Zero latency UI (optimistic updates).
- Floating layers to avoid context switches.
- Invisible backend handling.

This overview captures the essential purpose, stack, and architecture of the project.