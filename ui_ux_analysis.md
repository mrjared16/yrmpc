# UI/UX "Ultrathink" Analysis: Adapting YouTube Music to TUI

## The Challenge
You want to adapt 5 specific YouTube Music screens (Home, Artist, Album, Search, Player) into a TUI. This requires **layout flexibility** (grids, hero images, mixed lists) that most TUIs lack.

## The Contenders

### 1. Youtui (The "Browser" Model)
*   **UI Philosophy:** "Column Browser". It thinks in lists: Artist List -> Album List -> Song List.
*   **Layout Engine:** **Hardcoded**. The main view is a rigid 3-row layout (Header, Content, Footer).
*   **Adaptability:** **Low**. To create a "Home Grid" or "Artist Hero" page, we would have to fight the architecture. It is designed for *browsing*, not *experiencing*.

### 2. rmpc (The "Pane" Model)
*   **UI Philosophy:** "Composable Panes". It thinks in rectangles: "Split screen 40/60, put Art here, Queue there."
*   **Layout Engine:** **Recursive & Configurable**. You can define any layout in `config.ron`.
*   **Adaptability:** **High**. We can create new Pane types (e.g., `HomePane`, `HeroPane`) and slot them into the existing layout engine without breaking the app.

## Deep Dive: Adapting Your 5 Screens

### Screen 1: Home / Listen Again (Grid View)
*   **Youtui:** Cannot do this easily. It expects a list.
*   **rmpc:** We implement a `HomePane` widget that renders a grid. We define a Tab "Home" containing just this pane. **Perfect fit.**

### Screen 2: Artist Page (Hero Image + Horizontal Lists)
*   **Youtui:** Shows a list of albums. No "Hero" concept.
*   **rmpc:** We define a split layout:
    *   Top (30%): `HeroPane` (Image + Stats)
    *   Bottom (70%): `TabContent` (Top Songs / Albums / Singles)
    *   **Result:** Looks exactly like the screenshot.

### Screen 3: Album Detail (Side-by-Side)
*   **Youtui:** Just a list of songs.
*   **rmpc:** We already have this! The default "Queue" tab is a split view (Art on left, Songs on right). We just adapt it for the Album view.

### Screen 4: Search (Categorized Lists)
*   **Youtui:** Single list of results.
*   **rmpc:** We can create a `SearchPane` that renders multiple `ratatui` lists (Songs, Artists, Albums) in one view, navigable with `Tab`.

### Screen 5: Player (Focus Mode)
*   **Youtui:** Footer only.
*   **rmpc:** We can define a "Zen Mode" tab:
    *   Split Vertical:
        *   Top: Large Art + Lyrics
        *   Bottom: Up Next
    *   **Result:** Matches the "Now Playing" screen.

## The Verdict

**Winner: rmpc**

While **Youtui** has the right *backend* (YouTube logic), its **UI is too rigid** for your UX goals.
**rmpc** has the **UI engine** capable of rendering your design.

## The Strategy: "Antigravity"
We will **Fork rmpc** (for the UI) and **Pivot the Backend**.

1.  **Keep:** rmpc's TUI engine, Config system, Pane manager.
2.  **Delete:** rmpc's MPD client (`src/mpd`).
3.  **Inject:** `ytmapi-rs` (from Youtui) + `mpv` (for audio).
4.  **Build:** The 5 specific Panes (`Home`, `Hero`, `Grid`, etc.).

This is the only way to get the **Pixel Perfect** UI you want. It is more work than just using Youtui, but the result will be a *true* adaptation of the YouTube Music UX, not just a file browser.
