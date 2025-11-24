# Instructions for Coding Agent: Project "Antigravity"

**Task:** Fork `rmpc` and implement a high-performance, non-blocking "Rich" client.
**Core Philosophy:** "UI Priority." The render loop must never block on I/O.

## Step 1: System & Auth Setup
Generate `setup.sh`:
1.  Install: `yay -S mopidy mopidy-mpd mopidy-scrobbler python-ytmusicapi mopidy-youtube-git`.
2.  Symlink: `ln -sf ~/.config/rmpc/cookie.txt /var/lib/mopidy/.config/mopidy/cookie.txt`.
3.  **Validation:** Ensure `ytmusicapi` can read this Netscape-format cookie file.

## Step 2: Rust Architecture (Async-First)
Fork `mierak/rmpc`. Update `Cargo.toml` with:
`ytmapi-rs` (Async features), `ratatui-image` (Crossterm/Kitty), `tokio` (Full), `parking_lot` (Fast Mutex).

### 2.1 The Image Pipeline (The "Weightless" Feel)
Create `src/services/image_cache.rs`.
* **Structure:** `Arc<RwLock<HashMap<Url, DynamicImage>>>`.
* **Logic:**
    * When `RichTable` requests an image, check cache.
    * **If Miss:** Return `None` (render placeholder) and spawn `tokio::task`.
    * **Task:** Download -> **Resize to exact row height** (60px or 30px) -> Insert to Cache -> Send `AppEvent::Redraw`.
    * *Why:* Resizing huge images in the render loop causes stutter. Resizing in background makes scrolling buttery smooth.

## Step 3: Visual Components

### 3.1 `AdaptiveTable` Widget
Create `src/ui/widgets/adaptive_table.rs`.
* Use `ratatui::widgets::Table`.
* **Logic:** Map `ItemType` to `Row::height()`.
    * **Artist/Album:** Height 4. Render cached 60px thumb.
    * **Song:** Height 2. Render cached 30px thumb/icon.
* **Styling:** Use `Style::default().fg(Color::Reset)` for a clean, high-contrast look.

### 3.2 Floating Modals
Create `src/ui/components/modal.rs`.
* Use `Clear` widget to erase background behind the popup.
* Render a `Block::bordered()` centered on screen.
* **Usage:** Use this for the "Playlist Picker" (`p`) and "Featuring" (`f`) menus.

## Step 4: Logic Daemons

### 4.1 Client-Side Radio
Create `src/features/radio.rs`.
* **Loop:** `interval(5 sec)` check on MPD Queue.
* **Condition:** If `queue.len() < 5` and `radio_active`.
* **Action:** Fetch `get_watch_playlist()` -> `mpc.add()`.

### 4.2 Library Sync
Create `src/features/library.rs`.
* **Action:** `save_item(id, type)`.
* **Feedback:** Spawn a "Toast" notification (small overlay at bottom right) that fades out after 2 seconds.

## Step 5: Configuration
Update `src/config/mod.rs` to include the specific keybinds:
* `p` -> Open Playlist Modal.
* `f` -> Open Artist Context Modal.
* `s` -> Save to Library (Toast).