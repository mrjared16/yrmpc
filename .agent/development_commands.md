# Development Commands

## Daemon Management (YouTube Backend)

### Start Debug Daemon
```bash
./restart_daemon_debug.sh
```

### Start Release Daemon
```bash
./restart_daemon.sh
```

### Monitor Daemon Logs
```bash
tail -f /tmp/rmpcd-debug.log
```

### Monitor TUI Logs
```bash
tail -f /tmp/rmpc_1000.log
```

### Check CPU Usage (per thread)
```bash
ps -T -p $(pgrep -f "rmpc.*config") -o pid,spid,%cpu,comm --no-headers
```

---

## Build Commands

### Debug Build
```bash
cd rmpc
cargo build
```

### Release Build
```bash
cd rmpc
cargo build --release
```

### Run Tests
```bash
cd rmpc
cargo test
```

### Run Specific Test
```bash
cd rmpc
cargo test test_name
```

## Tmux Commands

### Start rmpc in tmux
```bash
tmux new-session -d -s rmpc 'rmpc'
```

### Start rmpc with debug logging
```bash
tmux new-session -d -s rmpc 'RUST_LOG=debug rmpc'
```

### Start rmpc with tmux integration disabled
```bash
tmux new-session -d -s rmpc 'RMPC_TMUX_DISABLE=1 rmpc'
```

### Send keys to rmpc session
```bash
tmux send-keys -t rmpc "search query"
```

### Send literal characters (reliable)
```bash
tmux send-keys -l -t rmpc "k"
tmux send-keys -l -t rmpc "i"
tmux send-keys -l -t rmpc "m"
```

### Capture tmux pane content
```bash
tmux capture-pane -t rmpc -p
```

### Kill tmux session
```bash
tmux kill-session -t rmpc
```

## TUI-Test Commands (Recommended E2E Testing)

### Run all TUI tests
```bash
node node_modules/@microsoft/tui-test/index.js "rmpc-tui-test.spec.ts"
```

### Run specific test
```bash
node node_modules/@microsoft/tui-test/index.js "rmpc-tui-test.spec.ts" --grep "MAIN"
```

### Update snapshots
```bash
node node_modules/@microsoft/tui-test/index.js "rmpc-tui-test.spec.ts" -u
```

### Enable traces
```bash
node node_modules/@microsoft/tui-test/index.js "rmpc-tui-test.spec.ts" -t
```

### View trace file
```bash
node node_modules/@microsoft/tui-test/index.js show-trace tui-traces/<trace-file>
```

## Python Test Commands (Legacy - Deprecated)

### Run E2E test
```bash
python3 e2e_playbook_test.py
```

### Run character input test
```bash
python3 test_tmux_minimal.py
```

### Run hybrid test
```bash
python3 simple_hybrid_test.py
```

### Run TDD test
```bash
python3 tdd_implementation_test.py
```

## Debug Commands

### Check rmpc logs
```bash
tail -f /tmp/rmpc_debug.log
```

### Check HTTP errors in logs
```bash
grep -i "http.*400\|error.*400" /tmp/rmpc_debug.log
```

### Monitor YouTube API calls
```bash
RUST_LOG=debug rmpc 2>&1 | grep -i "youtube\|search\|api"
```

## IPC Commands

### Start rmpc with IPC
```bash
rmpc --socket /tmp/rmpc.sock
```

### Send command via IPC
```bash
echo "play" | rmpc remote --socket /tmp/rmpc.sock
```

### Check IPC status
```bash
rmpc remote --socket /tmp/rmpc.sock status
```

## Configuration Commands

### Set YouTube backend
```toml
[player]
backend = "youtube"

[youtube]
auth_file = "/path/to/browser.json"
```

### Enable debug logging
```toml
[debug]
log_level = "debug"
```

## Troubleshooting Commands

### Check tmux integration status
```bash
echo $TMUX $TMUX_PANE $RMPC_TMUX_DISABLE
```

### Test tmux passthrough
```bash
tmux show-option -p allow-passthrough
```

### Check rmpc binary
```bash
ls -la target/release/rmpc
file target/release/rmpc
```

### Verify YouTube cookies
```bash
python3 -c "
import ytmusicapi
ytmusicapi.setup()
print('YouTube cookies valid')
"
```