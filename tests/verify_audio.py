#!/usr/bin/env python3
"""
Audio Playback Verification Script for yrmpc

This script verifies that audio is actually playing through MPV.
It queries the MPV IPC socket to check playback state.

Usage:
    python3 tests/verify_audio.py

Returns:
    0 - Audio is playing
    1 - MPV is idle (nothing loaded)
    2 - MPV is paused
    3 - MPV socket not available
"""

import socket
import json
import sys
import time

SOCKET_PATH = "/tmp/rmpc-mpv.sock"

def mpv_command(cmd):
    """Send command to MPV via IPC socket"""
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2.0)
        sock.connect(SOCKET_PATH)
        sock.sendall((json.dumps({"command": cmd}) + "\n").encode())
        response = sock.recv(4096).decode()
        sock.close()
        return json.loads(response)
    except FileNotFoundError:
        return {"error": "socket_not_found"}
    except ConnectionRefusedError:
        return {"error": "connection_refused"}
    except Exception as e:
        return {"error": str(e)}

def get_property(prop):
    """Get MPV property value"""
    result = mpv_command(["get_property", prop])
    if result.get("error") == "success":
        return result.get("data")
    return None

def check_playback_status():
    """Check if audio is playing"""
    print("=" * 50)
    print("MPV Playback Status Check")
    print("=" * 50)
    
    # Check socket connectivity
    idle = get_property("idle-active")
    if idle is None:
        print("ERROR: Cannot connect to MPV socket")
        print(f"       Socket path: {SOCKET_PATH}")
        print("       Is MPV running?")
        return 3
    
    paused = get_property("pause")
    time_pos = get_property("time-pos")
    duration = get_property("duration")
    media_title = get_property("media-title")
    filename = get_property("filename")
    volume = get_property("volume")
    
    print(f"MPV Socket: Connected")
    print(f"Idle Active: {idle}")
    print(f"Paused: {paused}")
    print(f"Volume: {volume}%")
    print(f"Time Position: {time_pos}")
    print(f"Duration: {duration}")
    print(f"Media Title: {media_title}")
    print(f"Filename: {filename}")
    print()
    
    if idle:
        print("STATUS: IDLE - Nothing loaded")
        print("        No audio file is currently loaded in MPV.")
        print("        Search for music and press Enter to play.")
        return 1
    
    if paused:
        print("STATUS: PAUSED")
        print("        Audio is loaded but paused.")
        print("        Press 'p' in yrmpc to unpause.")
        return 2
    
    if time_pos is not None and time_pos > 0:
        print("STATUS: PLAYING")
        print(f"        Currently at {time_pos:.1f}s of {duration:.1f}s")
        if media_title:
            print(f"        Playing: {media_title}")
        return 0
    
    print("STATUS: UNKNOWN")
    return 1

def wait_for_playback(timeout=30):
    """Wait for playback to start"""
    print(f"\nWaiting for playback to start (timeout: {timeout}s)...")
    start = time.time()
    
    while time.time() - start < timeout:
        idle = get_property("idle-active")
        paused = get_property("pause")
        time_pos = get_property("time-pos")
        
        if not idle and not paused and time_pos is not None and time_pos > 0:
            print(f"Playback started at {time_pos:.1f}s")
            return True
        
        time.sleep(0.5)
        sys.stdout.write(".")
        sys.stdout.flush()
    
    print("\nTimeout waiting for playback")
    return False

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--wait":
        # Wait mode: wait for playback to start
        if wait_for_playback():
            sys.exit(0)
        else:
            sys.exit(1)
    else:
        # Normal mode: just check status
        sys.exit(check_playback_status())
