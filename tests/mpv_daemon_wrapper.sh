#!/bin/bash
# Wrapper script to manage MPV daemon for testing
# Usage: ./mpv_daemon_wrapper.sh <command_to_run>

set -e

SOCKET_PATH="/tmp/rmpc-test-mpv.sock"
MPV_PID=""

cleanup() {
    if [ -n "$MPV_PID" ]; then
        echo "Stopping MPV daemon (PID $MPV_PID)..."
        kill "$MPV_PID" 2>/dev/null || true
        wait "$MPV_PID" 2>/dev/null || true
    fi
    rm -f "$SOCKET_PATH"
}

trap cleanup EXIT

# Check if MPV is already running on this socket
if [ -S "$SOCKET_PATH" ]; then
    echo "MPV socket already exists at $SOCKET_PATH. Using existing instance."
else
    echo "Starting MPV daemon..."
    # Start MPV in background with IPC socket
    mpv --idle=yes --vo=null --no-terminal --input-ipc-server="$SOCKET_PATH" > /dev/null 2>&1 &
    MPV_PID=$!
    echo "MPV daemon started with PID $MPV_PID"
    
    # Wait for socket to appear
    echo "Waiting for MPV socket..."
    for i in {1..50}; do
        if [ -S "$SOCKET_PATH" ]; then
            break
        fi
        sleep 0.1
    done
    
    if [ ! -S "$SOCKET_PATH" ]; then
        echo "Error: MPV socket failed to appear."
        exit 1
    fi
    echo "MPV daemon ready."
fi

# Run the requested command
echo "Running command: $@"
"$@"
