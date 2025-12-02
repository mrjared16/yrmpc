# User Guide: Interactive Search & Navigation

## Overview

Search and explore YouTube Music with a flexible interface that adapts to your needs:
- **Quick browsing**: Three-column layout with instant previews
- **Deep exploration**: Full-detail views with all metadata
- **Seamless navigation**: Move between artists, albums, and playlists

---

## The Basics

### Three-Column Layout

When you search, you see three columns:

```
┌──────────────────────────────────────────────────┐
│ Search  │ Results      │ Preview                 │
│ Inputs  │              │                         │
└──────────────────────────────────────────────────┘
```

- **Left**: Your search filters and inputs
- **Middle**: Search results (songs, artists, albums, playlists)
- **Right**: Quick preview of selected item

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `j`/`k` or `↓`/`↑` | Navigate up/down in results |
| `Tab` | Switch between columns |
| `i` | Focus search input |
| `Enter` | Expand to full details OR play song |
| `Space` | Add to queue (without expanding) |
| `h` or `Esc` | Go back / collapse detail view |

---

## Workflow 1: Quick Browsing

**Scenario**: You want to find a song quickly

1. **Search**: Press `i`, type "nói anh nghe"
2. **Browse**: Use `j`/`k` to navigate results
3. **Preview**: See song info in right column
4. **Play**: Press `Space` to add to queue or `Enter` to play

**You never leave three-column mode!**

---

## Workflow 2: Exploring an Artist

**Scenario**: You discovered a new artist and want to explore their music

### Step 1: Search and Preview

```
Search > Results
────────────────
Query: HYBS      Artists           Preview
[Search]        ▶HYBS             ┌──────────────┐
                                  │ HYBS         │
                Songs             │ 2.3M subs    │
                - Run Away        │              │
                - Killer          │ Top 3:       │
                                  │ 1. Ride      │
                Albums            │ 2. Killer    │
                - Making Steak    │ 3. Dancing...│
                                  │              │
                                  │[Enter:more]  │
                                  └──────────────┘
```

**Keys**: `j`/`k` to navigate, see quick preview

### Step 2: Expand to Full Details

Press `Enter` on "HYBS" artist:

```
Search > Artist: HYBS                        [h:back]
───────────────────────────────────────────────────
 ╔═══╗  HYBS
 ║PHO║  2.3M subscribers
 ╚═══╝  Filipino indie band from Manila

─── Top Songs (10) ──────────────────────────────
▶ 1. Ride                           3:02
  2. Killer                         3:19
  3. Dancing with my phone          3:24
  4. Go Higher                      3:29
  5. Run Away                       3:39
  ... (all 10 songs)

─── Albums & Singles (8) ───────────────────────
  [1] Making Steak (2022)
  [2] RIDE (2021)
  [3] Killer (2022)
  ... (all albums)

─── Related Artists ─────────────────────────────
  [1] Cigarettes After Sex
  [2] Boy Pablo
```

**Now you see EVERYTHING!**

### Step 3: Navigate Deeper

- Press `1` to quick-jump to "Making Steak" album
- Or use `j`/`k` to navigate and press `Enter`

```
Search > Artist: HYBS > Album: Making Steak  [h:back]
──────────────────────────────────────────────────────
 ╔═══╗  Making Steak
 ║CVR║  HYBS • 2022
 ╚═══╝  8 tracks • 26 minutes

 [P]lay All  [S]huffle  [A]dd to Library

─── Tracks ───────────────────────────────────────
▶ 1. Go Higher                    3:29
  2. Dancing with my phone        3:24
  3. Run Away                     3:39
  ... (all tracks)

─── More by HYBS ─────────────────────────────────
  [1] RIDE (2021)
  [2] Killer (2022)
```

### Step 4: Go Back

- Press `h` → Back to HYBS artist page
- Press `h` again → Back to search results (three-column mode)

**Breadcrumb always shows where you are!**

---

## Workflow 3: Playlist Exploration

**Scenario**: Found a playlist, want to explore and queue songs

### Three-Column Preview

```
Search > Results
────────────────
Query:           Playlists         Preview
vietnamese       ▶Bolero Mix      ┌───────────────┐
hits                              │ Bolero Mix    │
                                  │ 156 songs     │
                                  │ 8h 24min      │
                                  │               │
                                  │ First 5:      │
                                  │ 1. Tình Xa    │
                                  │ 2. Đêm Lạnh   │
                                  │ 3. Mưa Rơi    │
                                  │ ...           │
                                  │               │
                                  │[Enter:all]    │
                                  └───────────────┘
```

### Expand to See All Tracks

Press `Enter`:

```
Search > Playlist: Bolero Mix                [h:back]
──────────────────────────────────────────────────────
 ╔═══╗  Bolero Mix
 ║CVR║  Various Artists • 156 songs • 8h 24min
 ╚═══╝
 [P]lay All  [S]huffle  [A]dd to Library

─── Tracks (156) ─────────────────────────────────
▶ 1. Như Quỳnh - Tình Xa              4:20
  2. Như Quỳnh - Đêm Lạnh              4:32
  3. Kim Long - Mưa Rơi                3:45
  4. Giao Linh - Người Tình            4:12
  ... (scroll to see all 156)

─── Featured Artists ─────────────────────────────
  [1] Như Quỳnh    [2] Kim Long    [3] Giao Linh

─── Related Playlists ────────────────────────────
  [1] Vietnamese Classics
  [2] Nostalgia Mix
```

---

## Workflow 4: Visual Selection & Bulk Operations

**Scenario**: Want to queue specific tracks from a playlist

### Step 1: Open Playlist Details

1. Search for playlist
2. Press `Enter` to expand
3. Navigate to tracks section

### Step 2: Visual Mode (Coming in Phase 2)

```
Playlist: Making Steak                       [v:visual]
──────────────────────────────────────────────────────
─── Tracks (VISUAL - 3 selected) ─────────────────
█ 1. Go Higher                    3:29
█ 2. Dancing with my phone        3:24
█ 3. Run Away                     3:39
  4. Killer                       3:19
  5. Ride                         3:02

[n:Play Next] [l:Play Last] [p:Play] [s:Save] [Esc:Cancel]
```

**Keys**:
- `v` - Enter visual mode
- `j`/`k` - Extend selection
- `n` - Play selected next (after current song)
- `l` - Play selected last (append to queue)
- `p` - Play selected now (replace queue)
- `s` - Save selection to playlist

---

## Keyboard Shortcuts Reference

### Global (Works Everywhere)

| Key | Action |
|-----|--------|
| `i` | Focus search input |
| `j`/`k` or `↓`/`↑` | Navigate up/down |
| `h`/`l` or `←`/`→` | Navigate left/right OR back/forward |
| `Tab` | Switch sections/columns |
| `Esc` | Go back / cancel |
| `?` | Show help |

### Three-Column Mode

| Key | Action |
|-----|--------|
| `Enter` | Expand to full details (or play song) |
| `Space` | Add to queue without expanding |
| `j`/`k` | Navigate results |
| `Tab` | Switch between columns |

### Full-Detail Mode

| Key | Action |
|-----|--------|
| `h` or `Esc` | Collapse to three-column mode |
| `Enter` | Navigate deeper (artist → album, etc.) |
| `1`-`9` | Quick jump to numbered items |
| `j`/`k` | Navigate within section |
| `Tab` | Switch sections (Tracks, Artists, Related) |
| `v` | Enter visual selection mode |

### Visual Selection Mode (Phase 2)

| Key | Action |
|-----|--------|
| `j`/`k` | Extend selection |
| `V` | Select all in section |
| `n` | Play selected next |
| `l` | Play selected last |
| `p` | Play selected (replace queue) |
| `s` | Save selection to playlist |
| `Esc` | Exit visual mode |

### Detail View Actions

| Key | Action |
|-----|--------|
| `P` | Play all tracks |
| `S` | Shuffle all |
| `A` | Add all to library |
| `a` | Go to artist (from song/album) |
| `A` (Shift) | Go to album (from song) |

---

## Common Workflows

### "I want to discover similar artists"

1. Search for known artist
2. `Enter` to expand artist details
3. Scroll to "Related Artists"
4. Press `1` (or navigate + `Enter`) to view related artist
5. Explore their top songs and albums
6. Press `h` to go back and try another

### "I want to create a playlist from multiple sources"

1. Search and expand first album
2. `v` to enter visual mode
3. Select tracks you like
4. `s` to save selection
5. `h` back to search
6. Search second album
7. Repeat visual selection
8. `s` and choose same playlist (append)

### "I want to play an album immediately"

**Quick way**:
1. Search for album
2. See preview in right column
3. Press `Space` - adds all tracks to queue
4. Play starts!

**Detailed way**:
1. Search for album
2. `Enter` to see all tracks
3. Review track list
4. Press `P` for "Play All" (clears queue, plays album)

### "I want to queue songs from different artists"

1. Search first artist
2. See preview, press `Space` to queue
3. `i` to search again
4. Search second artist
5. `Enter` to expand
6. `v` to select specific songs
7. `l` to add to queue (play last)
8. Continue exploring...

---

## Tips & Tricks

💡 **Quick Preview**: Use three-column mode to browse many items quickly. Only expand when you want full details.

💡 **Breadcrumbs**: Always check the breadcrumb bar to know where you are. Example: `Search > Playlist > Artist > Album`

💡 **Quick Jump**: In full-detail mode, use `1`-`9` keys to instantly jump to featured artists or related content.

💡 **Context Preservation**: Going back preserves your scroll position and selection. Safe to explore!

💡 **Multi-Tab Workflow**: Open detail view in Search tab, switch to Queue tab to manage, come back - detail view is still there!

---

## What's Next?

**Phase 2** (Coming Soon):
- Visual selection mode (vim-style)
- Bulk operations
- Save to YouTube library

**Phase 3** (Future):
- Album cover art in preview
- Lyrics display
- Custom queue manipulation

---

## Need Help?

Press `?` anytime to see keyboard shortcuts overlay (coming in Phase 3).

For now, remember:
- `Enter` = Explore deeper
- `h`/`Esc` = Go back
- `j`/`k` = Navigate
- `v` = Visual mode (Phase 2)
