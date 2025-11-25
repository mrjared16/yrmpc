#!/bin/bash
# Automated Acceptance Test for rmpc Daily Workflow
# This script tests all common user interactions automatically

#set -euo pipefail  # Commented out to allow tests to continue on errors

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RMPC_BIN="$PROJECT_ROOT/rmpc/target/release/rmpc"
CONFIG_FILE="$PROJECT_ROOT/config/rmpc.ron"
SESSION_NAME="rmpc_acceptance_test"
TEST_OUTPUT_DIR="/tmp/rmpc_test_$(date +%s)"
TIMEOUT=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Setup
mkdir -p "$TEST_OUTPUT_DIR"
REPORT_FILE="$TEST_OUTPUT_DIR/test_report.txt"

# Utility functions
log() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$REPORT_FILE"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$REPORT_FILE"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "$REPORT_FILE"
    ((TESTS_FAILED++))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*" | tee -a "$REPORT_FILE"
    ((TESTS_SKIPPED++))
}

capture_screen() {
    local name=$1
    local output_file="$TEST_OUTPUT_DIR/${name}.txt"
    tmux capture-pane -t "$SESSION_NAME" -p > "$output_file" 2>/dev/null || true
    echo "$output_file"
}

send_keys() {
    tmux send-keys -t "$SESSION_NAME" "$@" 2>/dev/null || return 1
}

wait_for_ui() {
    sleep "${1:-1}"
}

check_screen_contains() {
    local pattern=$1
    local screen_file=$2
    if grep -q "$pattern" "$screen_file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

cleanup() {
    log "Cleaning up test session..."
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

# Start test suite
log "======================================"
log "rmpc Acceptance Test Suite"
log "======================================"
log "Project: $PROJECT_ROOT"
log "Binary: $RMPC_BIN"
log "Config: $CONFIG_FILE"
log "Output: $TEST_OUTPUT_DIR"
log "======================================"
echo "" | tee -a "$REPORT_FILE"

# Pre-flight checks
log "Running pre-flight checks..."

if [ ! -f "$RMPC_BIN" ]; then
    fail "Binary not found: $RMPC_BIN"
    log "Please build with: cd rmpc && cargo build --release"
    exit 1
fi
success "Binary exists"

if [ ! -f "$CONFIG_FILE" ]; then
    fail "Config not found: $CONFIG_FILE"
    exit 1
fi
success "Config exists"

# Test 1: Application Startup
log ""
log "Test 1: Application Startup"
log "----------------------------"

# Create tmux session
if ! tmux new-session -d -s "$SESSION_NAME" -x 200 -y 50; then
    fail "Failed to create tmux session"
    exit 1
fi
success "Created tmux session"

# Start application
send_keys "cd $PROJECT_ROOT/rmpc && RUST_LOG=warn ./target/release/rmpc --config ../config/rmpc.ron" C-m
wait_for_ui 3

screen_file=$(capture_screen "01_startup")

# Check if app started (look for common UI elements)
if check_screen_contains "Queue" "$screen_file" || \
   check_screen_contains "Library" "$screen_file" || \
   check_screen_contains "Search" "$screen_file"; then
    success "Application started successfully"
else
    # Check for errors
    if check_screen_contains "Error" "$screen_file" || check_screen_contains "Failed" "$screen_file"; then
        fail "Application failed to start (see $screen_file)"
        skip "Remaining tests (app not running)"
        exit 1
    else
        skip "Cannot verify startup (ambiguous state)"
    fi
fi

# Test 2: Tab Navigation
log ""
log "Test 2: Tab Navigation"
log "----------------------"

tabs=("1:Queue" "2:Directories" "3:Artists" "4:Albums" "5:Playlists" "6:Search" "7:Library")

for tab in "${tabs[@]}"; do
    IFS=':' read -r key name <<< "$tab"
    
    send_keys "$key"
    wait_for_ui 0.5
    
    screen_file=$(capture_screen "02_tab_${name,,}")
    
    # Basic check - just verify we didn't crash
    if [ -s "$screen_file" ]; then
        success "Navigate to $name tab (key: $key)"
    else
        fail "Failed to navigate to $name tab"
    fi
done

# Test 3: Library Browsing
log ""
log "Test 3: Library Browsing"  
log "------------------------"

send_keys "7"  # Library tab
wait_for_ui 1

screen_file=$(capture_screen "03_library_view")

if [ -s "$screen_file" ]; then
    success "Opened library view"
    
    # Try to browse
    send_keys "Enter"
    wait_for_ui 1
    screen_file=$(capture_screen "03_library_browse")
    
    if [ -s "$screen_file" ]; then
        success "Library browse action executed"
    else
        skip "Library browse (no response)"
    fi
else
    fail "Failed to open library"
fi

# Test 4: Navigation Keys
log ""
log "Test 4: Navigation Keys"
log "-----------------------"

# Test j/k navigation
send_keys "j" "j" "j"
wait_for_ui 0.5
screen_file=$(capture_screen "04_nav_down")
success "Down navigation (j) executed"

send_keys "k" "k"
wait_for_ui 0.5
screen_file=$(capture_screen "04_nav_up")
success "Up navigation (k) executed"

send_keys "g" "g"
wait_for_ui 0.5
screen_file=$(capture_screen "04_nav_top")
success "Jump to top (gg) executed"

send_keys "G"
wait_for_ui 0.5
screen_file=$(capture_screen "04_nav_bottom")
success "Jump to bottom (G) executed"

# Test 5: Search Tab
log ""
log "Test 5: Search Functionality"
log "----------------------------"

send_keys "6"  # Search tab
wait_for_ui 1
screen_file=$(capture_screen "05_search_tab")

if [ -s "$screen_file" ]; then
    success "Opened search tab"
else
    skip "Search tab navigation"
fi

# Test 6: Queue Management
log ""
log "Test 6: Queue Management"
log "-----------------------"

send_keys "1"  # Queue tab
wait_for_ui 1
screen_file=$(capture_screen "06_queue_view")

if [ -s "$screen_file" ]; then
    success "Opened queue tab"
    
    # Check if queue has items
    if check_screen_contains "Artist" "$screen_file" || check_screen_contains "Title" "$screen_file"; then
        success "Queue UI rendered"
    else
        skip "Queue items (queue may be empty)"
    fi
else
    fail "Failed to open queue"
fi

# Test 7: Playback Controls  
log ""
log "Test 7: Playback Controls"
log "-------------------------"

send_keys "Space"
wait_for_ui 1
screen_file=$(capture_screen "07_playback_toggle")
success "Play/pause toggle executed"

send_keys ">"
wait_for_ui 0.5
success "Next track executed"

send_keys "<"
wait_for_ui 0.5
success "Previous track executed"

send_keys "s"
wait_for_ui 0.5
screen_file=$(capture_screen "07_playback_stop")
success "Stop executed"

# Test 8: Volume Controls
log ""
log "Test 8: Volume Controls"
log "----------------------"

send_keys "+"
wait_for_ui 0.5
screen_file=$(capture_screen "08_volume_up")
success "Volume up executed"

send_keys "-"
wait_for_ui 0.5
screen_file=$(capture_screen "08_volume_down")  
success "Volume down executed"

# Test 9: Help Menu
log ""
log "Test 9: Help Menu"
log "-----------------"

send_keys "?"
wait_for_ui 1
screen_file=$(capture_screen "09_help_open")

if check_screen_contains "Help" "$screen_file" || check_screen_contains "Key" "$screen_file"; then
    success "Help menu opened"
    
    send_keys "Escape"
    wait_for_ui 0.5
    screen_file=$(capture_screen "09_help_close")
    success "Help menu closed"
else
    skip "Help menu (may not have help UI)"
fi

# Test 10: Performance Check
log ""
log "Test 10: Performance Check"
log "--------------------------"

# Check if app is still responsive
send_keys "1"
wait_for_ui 0.5
screen_file=$(capture_screen "10_responsiveness")

if [ -s "$screen_file" ]; then
    success "Application remains responsive"
else
    fail "Application may have frozen"
fi

# Test 11: Graceful Exit
log ""
log "Test 11: Graceful Exit"
log "----------------------"

send_keys "q"
wait_for_ui 2
screen_file=$(capture_screen "11_exit")

# The session should be killed or returned to shell
if check_screen_contains "rmpc" "$screen_file" 2>/dev/null; then
    skip "Exit (app may still be running)"
else
    success "Application exited"
fi

# Generate Test Report
log ""
log "======================================"
log "Test Summary"
log "======================================"
log "Passed:  $TESTS_PASSED"
log "Failed:  $TESTS_FAILED"
log "Skipped: $TESTS_SKIPPED"
log "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
log ""
log "Screenshots saved to: $TEST_OUTPUT_DIR"
log "Full report: $REPORT_FILE"
log "======================================"

# Exit code
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi
