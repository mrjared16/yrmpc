import { test, expect } from '@microsoft/tui-test';
import * as fs from 'fs';

const RMPC_BIN = './rmpc/target/release/rmpc';
const CONFIG_FILE = './config/rmpc.ron';
const LOG_FILE = '/tmp/rmpc-e2e-test.log';

// Helper to read log file
function readLogFile(): string {
  try {
    return fs.readFileSync(LOG_FILE, 'utf-8');
  } catch {
    return '';
  }
}

// Helper to clear log file
function clearLogFile(): void {
  try {
    fs.writeFileSync(LOG_FILE, '');
  } catch {
    // ignore
  }
}

/**
 * ============================================================================
 * TUI-TEST LIMITATIONS & TESTING STRATEGY
 * ============================================================================
 * 
 * These tests use @microsoft/tui-test which can only verify UI elements.
 * They CANNOT verify actual functionality because:
 * 
 * 1. Raw terminal mode: ratatui apps capture all keyboard input directly
 * 2. No IPC: tui-test cannot send keypresses that the TUI actually receives
 * 3. Async operations: YouTube API calls happen asynchronously
 * 
 * WHAT THESE TESTS CAN VERIFY:
 * ✅ App starts without crashing
 * ✅ UI elements are visible
 * ✅ Basic layout is rendered
 * 
 * WHAT THESE TESTS CANNOT VERIFY:
 * ❌ Search returns results from YouTube API
 * ❌ Enter key triggers playback  
 * ❌ Audio actually plays via MPV
 * ❌ Artist/playlist navigation works
 * ❌ Any keyboard-triggered functionality
 * 
 * FOR ACTUAL FUNCTIONALITY TESTING:
 * ============================================================================
 * 
 * 1. RUST INTEGRATION TESTS (recommended):
 *    cd rmpc && cargo test --test youtube_backend_tests
 *    cd rmpc && cargo test --test playback_integration
 * 
 * 2. MANUAL TESTING (required for TUI interactions):
 *    ./rmpc/target/release/rmpc --config ./config/rmpc.ron
 *    - Type 'i' to enter search, type query, press Enter
 *    - Navigate with j/k, press Enter on a song
 *    - Verify audio plays
 * 
 * 3. MPV STATE VERIFICATION:
 *    python3 tests/verify_audio.py
 *    Returns: 0=playing, 1=idle, 2=paused, 3=socket unavailable
 * 
 * ============================================================================
 */

test.describe('UI Visibility Tests', () => {

  test('app starts and shows tabs', async ({ terminal }) => {
    terminal.write(`${RMPC_BIN}\r`);
    await expect(terminal.getByText('Queue')).toBeVisible();
    await expect(terminal.getByText('Saved')).toBeVisible();
  });

  test('tab bar is visible', async ({ terminal }) => {
    terminal.write(`${RMPC_BIN}\r`);
    await expect(terminal.getByText('Queue')).toBeVisible();
  });

  test('search pane elements visible', async ({ terminal }) => {
    terminal.write(`${RMPC_BIN}\r`);
    await expect(terminal.getByText('Any Tag')).toBeVisible();
  });

});

test.describe('Feature Tests - MUST FAIL until bugs are fixed', () => {

  /**
   * TEST: Play Song
   * EXPECTED: When pressing Enter on a song, MPV should receive loadfile command
   * CURRENT BUG: enqueue_multiple is a no-op for YouTube backend
   * THIS TEST SHOULD FAIL until Bug 1 is fixed
   */
  test('FEATURE: play song - Enter triggers MPV loadfile', async ({ terminal }) => {
    clearLogFile();
    terminal.write(`RMPC_LOG_FILE=${LOG_FILE} RUST_LOG=debug ${RMPC_BIN} --config ${CONFIG_FILE}\r`);
    await expect(terminal.getByText('Queue')).toBeVisible({ timeout: 3000 });
    
    // Search for a song
    terminal.write('i');
    await new Promise(r => setTimeout(r, 100));
    terminal.write('lofi');
    terminal.write('\r');
    
    // Wait for search results
    await new Promise(r => setTimeout(r, 3000));
    
    // Navigate to Songs section and select first song
    terminal.write('l');  // Right to results
    await new Promise(r => setTimeout(r, 100));
    // Navigate down past headers to find a song
    for (let i = 0; i < 5; i++) {
      terminal.write('j');
    }
    terminal.write('\r');  // Press Enter to play
    
    // Wait for playback action
    await new Promise(r => setTimeout(r, 2000));
    
    // Check log - MUST contain loadfile (MPV command to play)
    const log = readLogFile();
    const hasLoadfile = log.includes('loadfile');
    const hasPlayId = log.includes('play_id');
    
    // THIS ASSERTION SHOULD FAIL until Bug 1 is fixed
    expect(hasLoadfile || hasPlayId).toBe(true);
  });

  /**
   * TEST: View Artist
   * EXPECTED: When pressing Enter on an artist, should show artist detail view
   * CURRENT BUG: HTTP 400 error because ID prefix not stripped
   * THIS TEST SHOULD FAIL until Bug 2 is fixed
   */
  test('FEATURE: view artist - browse_artist called without HTTP 400', async ({ terminal }) => {
    clearLogFile();
    terminal.write(`RMPC_LOG_FILE=${LOG_FILE} RUST_LOG=debug ${RMPC_BIN} --config ${CONFIG_FILE}\r`);
    await expect(terminal.getByText('Queue')).toBeVisible({ timeout: 3000 });
    
    // Search for an artist
    terminal.write('i');
    await new Promise(r => setTimeout(r, 100));
    terminal.write('taylor swift');
    terminal.write('\r');
    
    // Wait for search results
    await new Promise(r => setTimeout(r, 3000));
    
    // Navigate to artist in results
    terminal.write('l');  // Right to results
    await new Promise(r => setTimeout(r, 100));
    terminal.write('j');  // Down to first item (likely artist header or artist)
    terminal.write('j');  // Down to artist
    terminal.write('\r');  // Enter to browse artist
    
    // Wait for browse action
    await new Promise(r => setTimeout(r, 3000));
    
    // Check log
    const log = readLogFile();
    const hasBrowseAttempt = log.includes('browse_artist') || log.includes('fetch_artist') || log.includes('Fetching artist');
    const hasHttp400 = log.includes('status: 400') || log.includes('Bad Request') || log.includes('browse_artist failed');
    
    // MUST have attempted browse AND no HTTP 400
    // THIS SHOULD FAIL until Bug 2 is fixed
    expect(hasBrowseAttempt).toBe(true);  // Verify action was attempted
    expect(hasHttp400).toBe(false);        // Verify no error
  });

  /**
   * TEST: View Playlist
   * EXPECTED: When pressing Enter on a playlist, should show playlist details
   * CURRENT BUG: HTTP 400 error because ID prefix not stripped
   * THIS TEST SHOULD FAIL until Bug 2 is fixed
   */
  test('FEATURE: view playlist - browse_playlist called without HTTP 400', async ({ terminal }) => {
    clearLogFile();
    terminal.write(`RMPC_LOG_FILE=${LOG_FILE} RUST_LOG=debug ${RMPC_BIN} --config ${CONFIG_FILE}\r`);
    await expect(terminal.getByText('Queue')).toBeVisible({ timeout: 3000 });
    
    // Search for a playlist
    terminal.write('i');
    await new Promise(r => setTimeout(r, 100));
    terminal.write('lofi playlist');
    terminal.write('\r');
    
    // Wait for search results
    await new Promise(r => setTimeout(r, 3000));
    
    // Navigate to playlist in results
    terminal.write('l');  // Right to results
    await new Promise(r => setTimeout(r, 100));
    // Navigate down to find a playlist result
    for (let i = 0; i < 3; i++) {
      terminal.write('j');
    }
    terminal.write('\r');  // Enter to browse playlist
    
    // Wait for browse action
    await new Promise(r => setTimeout(r, 3000));
    
    // Check log
    const log = readLogFile();
    const hasBrowseAttempt = log.includes('browse_playlist') || log.includes('fetch_playlist') || log.includes('Fetching playlist');
    const hasHttp400 = log.includes('status: 400') || log.includes('Bad Request') || log.includes('browse_playlist failed');
    
    // MUST have attempted browse AND no HTTP 400
    // THIS SHOULD FAIL until Bug 2 is fixed
    expect(hasBrowseAttempt).toBe(true);  // Verify action was attempted
    expect(hasHttp400).toBe(false);        // Verify no error
  });

});

/**
 * ============================================================================
 * KNOWN BUGS & ROOT CAUSES (as of 2024-12-02)
 * ============================================================================
 * 
 * BUG 1: Enter on song does nothing, no audio plays
 * -----------------------------------------------
 * ROOT CAUSE: In shared/mpd_client_ext.rs, the `enqueue_multiple` implementation
 * for YouTube backend is a no-op:
 * 
 *   crate::player::Client::YouTube(_) => {
 *       log::debug!("enqueue_multiple not fully supported in MPV/YouTube backend");
 *       Ok(())
 *   }
 * 
 * EXPECTED BEHAVIOR: Should call YouTubeBackend::play_id() or add song to queue
 * 
 * TEST: cd rmpc && cargo test --test youtube_backend_tests test_play_song_from_search
 * 
 * 
 * BUG 2: HTTP 400 on artist/playlist browse
 * -----------------------------------------
 * ROOT CAUSE: The browse_artist() and browse_playlist() functions receive IDs
 * with prefixes like "artist:UC..." but the ytmapi-rs API expects raw IDs
 * without the prefix.
 * 
 * EXPECTED BEHAVIOR: Should strip prefix before calling API
 * 
 * TEST: cd rmpc && cargo test --test youtube_backend_tests test_browse_artist
 *       cd rmpc && cargo test --test youtube_backend_tests test_browse_playlist
 * 
 * ============================================================================
 */
