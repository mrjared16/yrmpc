# rmpc Acceptance Testing

## Overview

Automated acceptance tests for rmpc daily workflow validation. This test suite simulates real user interactions using tmux automation.

## Prerequisites

- rmpc compiled in release mode: `cd rmpc && cargo build --release`
- tmux installed
- Valid configuration file at `config/rmpc.ron`

## Running Tests

### Quick Start

```bash
./tests/acceptance_test.sh
```

### What It Tests

The acceptance test covers your complete daily workflow:

1. **Application Startup** - Verifies app launches without errors
2. **Tab Navigation** - Tests all 7 tabs (Queue, Directories, Artists, Albums, Playlists, Search, Library)
3. **Library Browsing** - Navigates library, expands categories
4. **Navigation Keys** - Tests j/k, gg, G navigation
5. **Search** - Opens and validates search tab
6. **Queue Management** - Views queue, checks UI rendering
7. **Playback Controls** - Space (play/pause), > (next), < (prev), s (stop)
8. **Volume Controls** - + (increase), - (decrease)
9. **Help Menu** - ? (open), Esc (close)
10. **Performance** - Checks app responsiveness
11. **Graceful Exit** - q (quit)

## Test Output

### Console Output
```
======================================
rmpc Acceptance Test Suite
======================================
[PASS] Binary exists
[PASS] Config exists
[PASS] Application started successfully
[PASS] Navigate to Queue tab (key: 1)
...
======================================
Test Summary
======================================
Passed:  25
Failed:  0
Skipped: 3
Total:   28
```

### Screenshots

All UI states are captured to `/tmp/rmpc_test_<timestamp>/`:
- `01_startup.txt` - Initial launch
- `02_tab_queue.txt` - Queue tab
- `03_library_view.txt` - Library browsing
- `09_help_open.txt` - Help menu
- etc.

### Test Report

Full details saved to `/tmp/rmpc_test_<timestamp>/test_report.txt`

## CI/CD Integration

### GitHub Actions

```yaml
name: Acceptance Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: cd rmpc && cargo build --release
      - name: Install tmux
        run: sudo apt-get install -y tmux
      - name: Run Acceptance Tests
        run: ./tests/acceptance_test.sh
      - name: Upload Screenshots
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-screenshots
          path: /tmp/rmpc_test_*/
```

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## Troubleshooting

### Backend Connection Required

If tests fail with "Failed to connect to backend", you need:

1. **Valid authentication** for YouTube backend
2. **Network connectivity** to YouTube Music
3. **Or** configure MPD/MPV backend instead

### Timeout Issues

Increase timeout in script:
```bash
TIMEOUT=60  # Increase from 30 to 60 seconds
```

### Screenshot Review

Check failed test screenshots:
```bash
ls -la /tmp/rmpc_test_*/
cat /tmp/rmpc_test_*/test_report.txt
```

## Customization

### Add Custom Tests

Edit `tests/acceptance_test.sh` and add:

```bash
log ""
log "Test 12: Custom Feature"
log "-----------------------"

send_keys "custom_key"
wait_for_ui 1
screen_file=$(capture_screen "12_custom_test")

if check_screen_contains "Expected Text" "$screen_file"; then
    success "Custom test passed"
else
    fail "Custom test failed"
fi
```

### Mock Backend (WIP)

For testing without backend connection, consider:
- Mock MPD server
- Offline test mode
- Fixture data loading

## Development

### Test Structure

```
tests/
├── acceptance_test.sh       # Main test script
├── fixtures/                # Test data (planned)
└── README.md               # This file
```

### Helper Functions

- `send_keys <keys>` - Send input to app
- `wait_for_ui <seconds>` - Pause for UI update
- `capture_screen <name>` - Screenshot current state
- `check_screen_contains <pattern> <file>` - Validate output
- `success/fail/skip <message>` - Log test result

## Future Enhancements

- [ ] Visual regression testing
- [ ] Performance benchmarking
- [ ] Network request mocking  
- [ ] Parallel test execution
- [ ] HTML test reports
- [ ] Video recording of test runs
