# Design Doc: The "Antigravity" YouTube Music Client

**Target System:** Arch Linux (Wayland/Niri)
**Philosophy:** "Weightless Interaction." The UI never blocks. The Audio never stutters. Visuals float.

---

## 1. The "Antigravity" Principles

### 1.1 Optimistic UI (Zero Latency)
* **Problem:** Waiting for MPD to confirm a "Play" command feels heavy.
* **Solution:** When `Enter` is pressed, the TUI updates the "Now Playing" state *immediately* in the UI memory. The `mpd_client` command is sent asynchronously. If it fails, we revert state (rare), but 99% of the time, it feels instant.

### 1.2 Floating Layers (Zero Context Switching)
* **Problem:** Navigating away from a list to add a song to a playlist destroys context.
* **Solution:** Use **Floating Modals** (Popups) for all secondary interactions.
    * *Playlist Picker:* Floats center-screen.
    * *Featuring Artists:* Floats near the cursor.
    * *Background:* The main list dims but remains visible (using `ratatui::widgets::Clear`).

### 1.3 The "Invisible" Backend
* **Authentication:** Single Source of Truth (`cookie.txt`).
* **Radio:** The "Infinite Queue" logic runs in a detached thread. It silently appends tracks 5 steps ahead. To the user, the music just never stops.

---

## 2. Visual Architecture: "The Rich Table"

We replace the rigid grid with a **Dynamic Flow Table**.

### 2.1 Variable Row Heights (Density vs. Clarity)
* **Containers (Artists/Albums):**
    * **Height:** 4 Lines.
    * **Visual:** 60x60px Thumbnail.
    * **Typography:** Title is **Bold Yellow**. Metadata is Dimmed.
* **Playables (Songs):**
    * **Height:** 2 Lines.
    * **Visual:** Small Icon (`🎵`) or 30x30px Thumbnail (cached).
    * **Typography:** Title is **White**. Artist is Dimmed.

---

## 3. System Architecture (The Loop)

[Input] --> [Optimistic UI State] --> [Ratatui Frame]
                   |
           (Async Channels)
                   v
[Network Thread]        [Audio Thread]
(Reqwest/Ytmapi)        (MPD Client)
       |                      |
[Image Resizer]         [Status Update]

### 3.1 The "Radio Daemon"
A background watcher that ensures the queue is never empty.
* **Trigger:** `MPD_Queue_Length - Current_Pos < 5`.
* **Action:** Fetch `get_watch_playlist(current_seed)`.
* **Outcome:** Silently append tracks. The user just sees the "Next" list grow automatically.

---

## 4. Workflow Specifications

### 4.1 The Search Flow
1.  User types `/`. Search bar floats at top.
2.  Results appear in `RichTable`.
3.  **Artist:** Click -> Pushes `ArtistView`.
4.  **Song:** Click -> **Instantly** marks as playing in UI. Sends signal to MPD.

### 4.2 The "Context" Flow (Key `f` or `p`)
1.  User hits `f` on a song.
2.  **No screen transition.** A small bordered box **floats** over the current row.
3.  List: `[ Ft. Pharrell Williams ]`, `[ Ft. Nile Rodgers ]`.
4.  Selection pushes new view; `Esc` closes popup instantly.

---

## 5. Keybindings (Vim-Native)

| Key | Action | Visual Behavior |
| :--- | :--- | :--- |
| `/` | Search | Input floats at top |
| `Enter` | Play / Open | Instant transition |
| `a` | Queue Append | Toast notification: "Added" |
| `p` | Playlist | **Floating Modal** (Center) |
| `f` | Featuring | **Floating Modal** (Cursor relative) |
| `s` | Save Library | Toast notification |
| `r` | Toggle Radio | Icon toggles in Status Bar |