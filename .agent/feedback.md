# Feedback on technical_context.md

**Date**: 2025-11-23  
**Reviewer**: Claude (Sonnet 4.5 Thinking)  
**Document**: `.agent/technical_context.md`

---

## ✅ What I Got Right

### 1. **Architecture Approach**
- ✅ Streaming-first architecture (vs youtui's download-and-play)
- ✅ Using MPV as the playback engine (proven, robust)
- ✅ Three-layer stack: ytmapi-rs → rusty_ytdl → MPV
- ✅ App-layer queue management (Phase 3 completion)
- ✅ Backend abstraction allowing MPD/YouTube coexistence

### 2. **Key Technical Decisions**
- ✅ Pre-buffering for gapless playback (2-3 tracks ahead)
- ✅ Stream URL caching with TTL (~1 hour expiration awareness)
- ✅ Async/sync boundary handling (tokio::Runtime::block_on)
- ✅ Cookie-based auth as initial implementation (simpler than OAuth)

### 3. **Clear Success Criteria**
- ✅ Well-defined deliverables for each phase
- ✅ Testable outcomes (gapless, no silence, same UX as MPD)
- ✅ Configuration-driven backend selection

### 4. **Reference Usage**
- ✅ Correctly identified youtui as API reference only (not implementation)
- ✅ Acknowledged Harmony Music as gapless streaming reference

---

## ❌ What Needs Correction

### 1. **Critical: MPV Pre-Buffering Assumptions** ⚠️
**Issue**: The document assumes MPV's `queue_next()` or similar API for pre-buffering.

**Reality**: 
- MPV does NOT have a built-in "queue" API in the traditional sense
- MPV's `loadfile` command with `append` flag can queue, BUT:
  - It starts loading immediately (not lazy)
  - No fine-grained control over pre-buffer timing
  - Limited feedback on buffer status

**Correction Needed**:
```rust
// WRONG (as documented):
self.mpv.queue_next(&url)?;  // ❌ No such simple API

// RIGHT (actual MPV IPC):
self.mpv.command(&[
    "loadfile", 
    &url, 
    "append-play"  // or "append"
])?;
```

**Better Approach**:
- Use `playlist-pos` to track current track
- On track change event, check if `playlist-count - playlist-pos <= 2`
- If so, append next track URL
- Monitor `playlist-next` property for gapless confirmation

### 2. **Stream URL Extraction Flow**
**Issue**: `rusty_ytdl` usage is mentioned but not fully specified.

**Problem**: 
- `rusty_ytdl` extracts stream URLs, BUT it's designed for downloading
- We need the URL extraction only, not the download pipeline

**Correction**:
```rust
// Use rusty_ytdl's URL extraction only
use rusty_ytdl::{Video, VideoOptions};

async fn get_stream_url(video_id: &str) -> Result<String> {
    let video = Video::new_with_options(
        &format!("https://youtube.com/watch?v={}", video_id),
        VideoOptions {
            quality: VideoQuality::Highest,  // or config-driven
            filter: VideoSearchOptions::Audio,  // Audio-only!
            ..Default::default()
        }
    )?;
    
    let info = video.get_info().await?;
    
    // Get best audio stream URL (NOT download)
    let audio_format = info.formats
        .iter()
        .filter(|f| f.has_audio && !f.has_video)
        .max_by_key(|f| f.bitrate.unwrap_or(0))
        .ok_or(anyhow!("No audio stream found"))?;
    
    Ok(audio_format.url.clone())
}
```

### 3. **Authentication Flow Incomplete**
**Issue**: Cookie-based auth mentioned but not specified.

**Missing Details**:
- How to extract cookies from browser?
- Which cookies are required? (typically `__Secure-1PSID`, others)
- Cookie refresh mechanism?
- Fallback if cookies expire?

**Add to Plan**:
```markdown
### Cookie Authentication Details
1. Use `ytmusicapi` Python tool to extract cookies (one-time)
2. Store in `~/.config/rmpc/youtube_cookie.txt`
3. ytmapi-rs reads cookies on init
4. Auto-detect 401/403 responses → prompt for re-auth
5. Document: "Run `ytmusicapi browser` to refresh cookies"
```

### 4. **Radio Feature Placement**
**Issue**: Radio is Phase 6, but it's tightly coupled to streaming logic.

**Problem**: Implementing radio after streaming means refactoring later.

**Correction**: Move radio to Phase 4 as "sub-feature"
- Implement `get_watch_playlist` alongside search
- Add queue-end detection in same pass as streaming
- Config can disable it, but code is present

**Rationale**: Radio relies on the same API & stream flow. Separating it is artificial.

---

## 🔍 Missing Details

### 1. **Error Handling Strategy**
**Missing**: What happens when...
- Stream URL extraction fails?
- YouTube returns 403 (geo-blocked)?
- Network drops mid-stream?
- API rate limits hit?

**Add**:
```markdown
### Error Recovery
- **Stream Failure**: Skip track, log error, continue queue
- **403 Errors**: Refresh stream URL (may be expired), retry once
- **Network Loss**: MPV handles buffering, app shows status
- **Rate Limits**: Exponential backoff, cache API responses
- **Auth Expiry**: Prompt user, pause playback until re-auth
```

### 2. **Performance & Resource Management**
**Missing**: 
- Memory footprint of stream caching?
- Thread/async task management?
- MPV process lifecycle (spawn once or per-backend)?

**Add**:
```markdown
### Resource Limits
- Stream cache: Max 100 URLs, TTL 1 hour, LRU eviction
- ytmapi requests: Connection pool (max 10 concurrent)
- MPV: Singleton process, shared across app lifecycle
- Async runtime: Single tokio runtime, reused for all API calls
```

### 3. **Testing Strategy**
**Missing**: How to test without real YouTube API?

**Add**:
```markdown
### Testing Plan
1. **Unit Tests**: Mock ytmapi responses, test URL extraction
2. **Integration Tests**: Use test video ID (e.g., "dQw4w9WgXcQ")
3. **Gapless Verification**: Script to measure silence between tracks
4. **Stress Test**: 100-track queue, measure memory/CPU
```

### 4. **Migration Path for Existing Users**
**Missing**: What if user has MPD configured?

**Add**:
```markdown
### Backward Compatibility
- Default backend remains "mpd" if config exists
- New installs default to "youtube"
- Provide `rmpc migrate` command to set up YouTube auth
- Document side-by-side usage (MPD for local, YT for streaming)
```

---

## 🎯 Should You Research Harmony Music?

### Answer: **YES, but Scoped** ✅

**What to Research** (1-2 hours max):
1. ✅ **Gapless Implementation**: How they handle `flutter_sound` buffering
2. ✅ **Stream Caching**: TTL, cache invalidation, URL refresh logic
3. ✅ **Error Handling**: Network drops, 403 handling, fallback strategies
4. ✅ **Pre-buffering Timing**: When to fetch next track (% played, time remaining?)

**What to SKIP**:
- ❌ Flutter UI patterns (irrelevant to TUI)
- ❌ Mobile-specific optimizations (battery, data usage)
- ❌ Their API client (we have ytmapi-rs)

**Where to Look**:
```bash
# Harmony Music repo
git clone https://github.com/anandnet/Harmony-Music
cd Harmony-Music

# Key files:
lib/services/audio_service.dart      # Stream playback
lib/services/youtube_service.dart    # URL extraction
lib/utils/cache_manager.dart         # Caching logic
```

**Expected Learnings**:
- Exact buffering thresholds (e.g., "pre-fetch at 80% played")
- Stream URL refresh patterns (when to re-extract)
- Gapless edge cases (playlist loops, shuffle)

---

## 📊 Priority Corrections (Before Starting Phase 4)

### High Priority (MUST FIX)
1. ⚠️ **Research MPV's actual playlist API** (2 hours)
   - Read MPV docs: https://mpv.io/manual/stable/
   - Test `loadfile` with `append` flag
   - Verify gapless behavior

2. ⚠️ **Clarify rusty_ytdl usage** (1 hour)
   - Confirm audio-only stream extraction
   - Test URL validity (playable by MPV?)
   - Check if we need `yt-dlp` instead

3. ⚠️ **Document cookie auth flow** (30 min)
   - Specify exact cookie names
   - Add troubleshooting steps

### Medium Priority (SHOULD ADD)
4. 📝 **Error handling section** (1 hour)
5. 📝 **Testing strategy** (30 min)
6. 📝 **Resource management** (30 min)

### Low Priority (NICE TO HAVE)
7. 💡 **Migration guide** (if time permits)

---

## 🎬 Recommended Action Plan

### Before Phase 4 Starts:
1. **Research Session** (4 hours total):
   - 2h: MPV playlist/gapless API deep-dive
   - 1h: Harmony Music code review (focused)
   - 1h: rusty_ytdl + MPV integration test

2. **Update technical_context.md**:
   - Add MPV API corrections
   - Add error handling section
   - Add testing strategy
   - Clarify cookie auth

3. **Create Proof of Concept** (Optional but recommended):
   ```rust
   // Test: Can we play 2 YT tracks gaplessly via MPV?
   // Files to create:
   // - tests/youtube_stream_poc.rs
   // - Demonstrates URL extraction → MPV append → gapless
   ```

### Then Proceed to Phase 4 Implementation

---

## ✨ Final Verdict

**Overall Quality**: 8/10 🌟

**Strengths**:
- Clear vision and architecture
- Realistic about youtui limitations
- Good phase separation

**Weaknesses**:
- MPV API assumptions need verification
- Missing error handling & testing strategy
- Cookie auth underspecified

**Recommendation**: 
**Spend 4 hours on research/corrections, then proceed with confidence.** The plan is 80% solid, but the 20% gaps are in critical areas (MPV gapless, error handling) that could derail Phase 4 if not addressed upfront.

---

**Next Steps**:
1. ✅ Approve this feedback
2. → Do research session (MPV + Harmony)
3. → Update technical_context.md
4. → Start Phase 4 implementation
