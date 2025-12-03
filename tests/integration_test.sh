#!/bin/bash
# ============================================================================
# WARNING: THIS TEST DOES NOT WORK
# ============================================================================
#
# tmux send-keys cannot properly send keyboard input to raw terminal mode
# applications like ratatui apps. The keys are sent to the terminal buffer
# but the TUI app doesn't receive them properly.
#
# FOR ACTUAL TESTING:
# 1. Manual testing: ./rmpc/target/release/rmpc --config ./config/rmpc.ron
# 2. Rust tests: cd rmpc && cargo test
# 3. MPV state check: python3 tests/verify_audio.py
#
# ============================================================================

echo "ERROR: This integration test does not work."
echo ""
echo "tmux send-keys cannot interact with raw terminal mode TUI apps."
echo ""
echo "For testing, use:"
echo "  1. Manual testing with actual keyboard"
echo "  2. Rust unit/integration tests: cd rmpc && cargo test"
echo "  3. MPV state check: python3 tests/verify_audio.py"
echo ""
exit 1
