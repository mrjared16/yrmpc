# Phase 2: The Antigravity Pivot

**Goal:** Transform `rmpc` from an MPD client into a standalone YouTube Music client powered by `mpv` and `ytmapi-rs`.

## 📋 Checklist

### Step 1: Core Surgery (Strip MPD)
- [x] **Delete MPD Module:** Remove `src/mpd/` directory.
- [x] **Clean Client Logic:** Remove `Client` struct dependency on MPD in `src/core/client.rs`.
- [x] **Clean Main Entry:** Remove MPD connection logic in `src/main.rs`.
- [x] **Clean Dependencies:** Remove `mpd-client` from `Cargo.toml`.

### Step 2: Inject the Brain (ytmapi-rs)
- [ ] **Add Dependencies:** Add `ytmapi-rs`, `tokio`, `reqwest` to `Cargo.toml`.
- [ ] **Port API Logic:** Create `src/api/mod.rs` and port `youtui/app/server/api.rs`.
- [ ] **Verify API:** Create a simple test to fetch search suggestions.

### Step 3: The "Invisible" Backend (mpv)
- [ ] **Implement IPC:** Create `src/player/mpv_ipc.rs` for JSON IPC.
- [ ] **Implement Client Trait:** Create `src/player/client.rs` implementing the `Client` trait (simulating MPD).
- [ ] **Implement Listener:** Create `src/player/mpv_listener.rs` to translate `mpv` events to `AppEvent::IdleEvent`.
- [ ] **Gapless Logic:** Implement "Append" logic for pre-buffering.

## 📝 Progress Log
- **[PENDING]** Initializing Phase 2.
