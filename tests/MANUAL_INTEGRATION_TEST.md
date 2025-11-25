# Manual Integration Test Guide

## Prerequisites
- Valid YouTube Music authentication in `~/.config/rmpc/headers_auth.json`
- MPV installed
- Terminal access

## Test: Search and Stream Songs

### 1. Start Application
```bash
cd rmpc
./target/release/rmpc --config ../config/rmpc.ron
```

**Expected:** 
- Application starts
- MPV auto-spawns (headless, no window)
- UI displays

### 2. Search for Music
1. Press `6` to go to Search tab
2. Press `/` to enter search mode
3. Type: `lofi hip hop` (or any query)
4. Press `Enter` to search

**Expected:**
- Search results appear
- Song list displayed

### 3. Add to Queue
1. Navigate to desired song with `j/k`
2. Press `a` to add to queue
3. Press `1` to view Queue tab

**Expected:**
- Song appears in queue
- Shows title, artist, duration

### 4. Play Song
1. In Queue tab, press `Space` to play

**Expected:**
- Song starts streaming
- Progress bar updates
- MPV process active (check with `ps aux | grep mpv`)
- **No MPV window appears** (headless with --vo=null)

### 5. Verify Headless MPV
```bash
# In another terminal
ps aux | grep "[m]pv.*vo=null"
```

**Expected output:**
```
phucdnt  12345  ... mpv --idle=yes --vo=null --no-terminal --input-ipc-server=/tmp/rmpc-mpv.sock
```

**No window should appear on screen**

### 6. Test Controls
- `Space` - Pause/resume
- `>` - Next track  
- `<` - Previous track
- `+` - Volume up
- `-` - Volume down
- `s` - Stop

### 7. Exit
Press `q` to quit

**Expected:**
- Application exits
- MPV process terminates
- No orphan processes

## Troubleshooting

**No search results:**
- Check YouTube auth cookies are valid
- Check network connection
- Look for errors in logs (`RUST_LOG=debug`)

**MPV window appears:**
- Should be fixed with --vo=null flag
- Verify with: `ps aux | grep mpv` (should show --vo=null)

**No audio:**
- Check system audio is working
- Check volume isn't muted
- Verify MPV can play audio: `mpv --vo=null <test.mp3>`

## Success Criteria

✅ Application starts without errors  
✅ Search returns results  
✅ Songs added to queue  
✅ Playback streams successfully  
✅ **No MPV window visible** (headless)  
✅ Controls work (pause, next, volume)  
✅ Clean exit with process cleanup
