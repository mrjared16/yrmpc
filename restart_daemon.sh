#!/bin/bash
# Restart rmpcd daemon with debug output

set -e

DAEMON_PATH="<PROJECT_ROOT>/rmpc/target/release/rmpcd"
SOCKET_PATH="/tmp/yrmpc-yt.sock"
LOG_FILE="/tmp/rmpcd.log"

echo "=== Stopping existing daemon ==="
pkill -f "rmpcd" 2>/dev/null || true
sleep 1

# Remove stale socket
rm -f "$SOCKET_PATH"

echo "=== Starting daemon ==="
echo "Log file: $LOG_FILE"
echo "Press Ctrl+C to stop"
echo ""

# Run with backtrace and log env, output to both terminal and log file
RUST_BACKTRACE=1 RUST_LOG=info "$DAEMON_PATH" 2>&1 | tee "$LOG_FILE"
