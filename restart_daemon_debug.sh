#!/bin/bash
# Restart rmpcd daemon with debug output
# Automatically restarts MPV if it has existing playlist (for clean testing)

set -e

DAEMON_PATH="/home/phucdnt/workspace/projects/yrmpc/rmpc/target/debug/rmpcd"
SOCKET_PATH="/tmp/yrmpc-yt.sock"
MPV_SOCKET_PATH="/tmp/yrmpc-yt.mpv.sock"
LOG_FILE="/tmp/rmpcd.log"

echo "=== Stopping existing daemon ==="
pkill -f "rmpcd" 2>/dev/null || true

# Check if MPV has existing playlist
MPV_NEEDS_RESTART=false
if [ -S "$MPV_SOCKET_PATH" ]; then
    echo "=== Checking MPV playlist state ==="

    # Query MPV's playlist-count using socat
    PLAYLIST_COUNT=$(echo '{"command": ["get_property", "playlist-count"]}' | \
        socat - "$MPV_SOCKET_PATH" 2>/dev/null | \
        grep -o '"data":[0-9]*' | \
        grep -o '[0-9]*' || echo "0")

    if [ "$PLAYLIST_COUNT" -gt 0 ] 2>/dev/null; then
        echo "⚠ MPV has $PLAYLIST_COUNT tracks in playlist - will restart for clean state"
        MPV_NEEDS_RESTART=true
    else
        echo "✓ MPV playlist is empty - can reuse existing process"
    fi
else
    echo "No MPV socket found - will spawn new process"
fi

# Kill MPV if it needs restart
if [ "$MPV_NEEDS_RESTART" = true ]; then
    echo "=== Killing MPV for clean restart ==="
    pkill -f "mpv.*yrmpc-yt.mpv.sock" 2>/dev/null || true
    sleep 1
    rm -f "$MPV_SOCKET_PATH"
fi

# Remove stale daemon socket
rm -f "$SOCKET_PATH"

echo "=== Starting daemon ==="
echo "Log file: $LOG_FILE"
echo "Press Ctrl+C to stop"
echo ""

# Run with backtrace and log env, output to both terminal and log file
# Use ytx for faster stream extraction (~200ms vs ~3-4s with yt-dlp)
RUST_BACKTRACE=1 RUST_LOG=info "$DAEMON_PATH" --extractor ytx 2>&1 | tee "$LOG_FILE"
