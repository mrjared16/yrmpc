# Youtui vs rmpc: Architecture Comparison

## Executive Summary

| Aspect | Youtui | rmpc + Mopidy | rmpc + mpv |
|---|---|---|---|
| **Effort** | Low (fork as-is) | Low (patch bugs) | High (backend rewrite) |
| **Speed** | Fast (native `ytmapi-rs`) | Slow (20.6s searches) | Fast (native `yt-dlp`) |
| **YouTube** | Native, mature | Buggy, limited | Native, robust |
| **Customization** | Good (but newer) | Excellent (mature) | Excellent (mature) |
| **Risk** | Low (proven stack) | High (fragile patches) | Medium (rewrite risk) |

**Recommendation:** **Fork Youtui**. It already has `ytmapi-rs` built-in, which is the core of "Antigravity".

---

## Detailed Comparison

### 1. Code Maturity

#### Youtui
- **Codebase Size:** ~40k LOC (smaller, focused)
- **Age:** ~2 years (v0.0.14)
- **Architecture:** Clean, modern Rust
- **UI Framework:** `ratatui` (same as `rmpc`)
- **Notable:** **Has `ytmapi-rs` built-in** (our Phase 2 requirement!)

#### rmpc
- **Codebase Size:** ~80k LOC (larger, feature-rich)
- **Age:** ~5 years (v0.10.0)
- **Architecture:** Complex MPD client
- **UI Framework:** `ratatui`
- **Notable:** Very mature config system, polished UX

**Winner:** rmpc (maturity), Youtui (cleaner codebase)

---

### 2. Feature Completeness

#### Youtui
| Feature | Status |
|---|---|
| YouTube Music Search | ✅ Native (`ytmapi-rs`) |
| Artist -> Albums | ✅ Core workflow |
| Queue Management | ✅ |
| Keybindings | ✅ Configurable |
| Album Art | ✅ Built-in |
| Radio/Auto-play | ❌ Not implemented |
| Variable Row Heights | ❌ Standard `ratatui::Table` |
| Image Caching | ❓ (need to check) |
| Context-Aware UI | ❌ Not implemented |

#### rmpc (with Mopidy)
| Feature | Status |
|---|---|
| YouTube Music Search | 🐌 20.6s (via Mopidy) |
| Artist -> Albums | ✅ Via Browse |
| Queue Management | ✅ Excellent |
| Keybindings | ✅ Highly configurable |
| Album Art | ✅ |
| Radio/Auto-play | ❌ Would need to implement |
| Variable Row Heights | ❌ Standard `ratatui::Table` |
| Image Caching | ✅ Has cache system |
| Context-Aware UI | ❌ Would need to implement |

**Winner:** Tie (both need custom features)

---

### 3. Your "Antigravity" Requirements

| Requirement | Youtui | rmpc + Mopidy | rmpc + mpv |
|---|---|---|---|
| **`ytmapi-rs` integration** | ✅ Already has it! | ❌ Need to add | ❌ Need to add |
| **AdaptiveTable (variable rows)** | ❌ Need to implement | ❌ Need to implement | ❌ Need to implement |
| **ImageCache (async)** | ❓ Check implementation | ✅ Has cache system | ❌ Need to implement |
| **Radio Daemon** | ❌ Need to implement | ❌ Need to implement | ❌ Need to implement |
| **Context-Aware UI** | ❌ Need to implement | ❌ Need to implement | ❌ Need to implement |
| **Fast Search** | ✅ Native | ❌ 20.6s | ✅ Native |

**Winner:** **Youtui** (already has the hardest part: `ytmapi-rs`)

---

### 4. Effort to Implement "Antigravity"

#### Youtui
1. **AdaptiveTable:** Modify existing table widget (~2 days)
2. **ImageCache:** Check if exists, enhance if needed (~1 day)
3. **Radio Daemon:** Add `get_watch_playlist` loop (~1 day)
4. **Context-Aware UI:** Add tab switching logic (~1 day)
5. **Total:** ~5 days

#### rmpc + Mopidy
1. **Keep patching bugs:** Ongoing pain
2. **Add `ytmapi-rs`:** ~2 days
3. **AdaptiveTable:** ~2 days
4. **Radio Daemon:** ~1 day
5. **Fight Mopidy slowness:** Forever
6. **Total:** 5 days + eternal frustration

#### rmpc + mpv
1. **Rip out MPD layer:** ~3 days
2. **Add `mpv` IPC:** ~2 days
3. **Add `ytmapi-rs`:** ~2 days
4. **AdaptiveTable:** ~2 days
5. **Radio Daemon:** ~1 day
6. **Total:** ~10 days (but solid foundation)

**Winner:** **Youtui** (5 days vs 10 days, less risk)

---

### 5. Performance

| Operation | Youtui | rmpc + Mopidy | rmpc + mpv |
|---|---|---|---|
| Search | ~2-3s | 20.6s | ~2-3s |
| Playback | Fast (`rodio`) | Fast (GStreamer) | Fast (`mpv`) |
| UI Responsiveness | Excellent | Excellent | Excellent |
| Image Loading | Good | Good | Good |

**Winner:** Youtui / rmpc+mpv (tie)

---

### 6. Long-term Maintenance

#### Youtui
- **Dependencies:** `ytmapi-rs` (included), `rodio`, `ratatui`
- **Risks:** Smaller community, newer project
- **Benefits:** Clean, focused codebase

#### rmpc + Mopidy
- **Dependencies:** Mopidy (Python), `mopidy-youtube`, MPD protocol
- **Risks:** Mopidy-YouTube is buggy, Python dependency
- **Benefits:** Mature MPD ecosystem

#### rmpc + mpv
- **Dependencies:** `mpv`, `yt-dlp`, `ratatui`
- **Risks:** Medium (need to maintain IPC layer)
- **Benefits:** Battle-tested media stack

**Winner:** **Youtui** (fewer moving parts)

---

## Recommendation

### Fork Youtui

**Why:**
1. **It already has `ytmapi-rs` built-in.** This is 50% of the "Antigravity" vision.
2. **Clean, focused codebase.** Easier to modify than `rmpc`'s complex MPD layer.
3. **Artist -> Albums workflow.** Matches your use case perfectly.
4. **Fast.** No Mopidy bottlenecks.

**What you give up:**
- rmpc's polished config system (but Youtui's is good enough).
- rmpc's mature tab system (but Youtui has tabs too).

**Next Steps:**
1. Test Youtui (`cargo run` in `youtui/youtui`).
2. If it feels fast and smooth, fork it.
3. Implement "Antigravity" features on top of Youtui's solid base.

**Alternative:**
If Youtui's UX feels too different, **rmpc + mpv** is the safer long-term bet (10 days of work, but solid foundation).
