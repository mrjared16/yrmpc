# E2E Testing Limitations for crossterm/ratatui TUI Apps

**Date**: 2025-12-03  
**Status**: Known Limitation - No PTY-based Solution Available

## Summary

PTY-based E2E testing (expectrl, tui-test, portable-pty) **does not work** for sending keyboard input to crossterm-based TUI applications. This is a fundamental limitation of how crossterm handles terminal input.

## What Works

| Approach | UI Rendering | Keyboard Input |
|----------|--------------|----------------|
| expectrl | ✅ Can read output | ❌ Input not received |
| tui-test (xterm.js) | ✅ Can read output | ❌ Input not received |
| portable-pty + vt100 | ✅ Can read output | ❌ Input not received |

## Root Cause Analysis

### Initial Hypothesis (Wrong)
- crossterm uses `/dev/tty` directly instead of stdin
- Solution: Disable `use-dev-tty` feature

### Actual Findings
- rmpc uses crossterm **without** `use-dev-tty` feature
- crossterm's mio backend should read from stdin
- PTY input works with simple programs (cat, bash)
- PTY input does NOT reach crossterm's event polling

### Evidence

```bash
# PTY input works with cat
$ cargo test test_pty_input_with_cat  # PASSES

# PTY input works with bash  
$ cargo test test_pty_with_bash  # PASSES

# PTY input does NOT work with crossterm app
$ cargo test test_rmpc_through_bash  # Input not received
```

### Related crossterm Issues
- [#396](https://github.com/crossterm-rs/crossterm/issues/396) - stdin issues with piped input
- [#728](https://github.com/crossterm-rs/crossterm/issues/728) - Request to change input stream
- [#941](https://github.com/crossterm-rs/crossterm/issues/941) - Running crossterm without real terminal

## How Other Projects Handle This

### Helix Editor (Working Solution)
Helix does NOT use PTY for testing. They inject events directly:

```rust
// Helix approach - channel-based event injection
let (tx, rx) = tokio::sync::mpsc::unbounded_channel();
let mut rx_stream = UnboundedReceiverStream::new(rx);

// Send key events through channel
for key_event in parse_macro(in_keys)?.into_iter() {
    tx.send(Ok(Event::Key(KeyEvent::from(key_event))))?;
}

// App reads from channel instead of terminal
app.event_loop_until_idle(&mut rx_stream).await;
```

This requires modifying the application to accept events from a stream rather than reading directly from the terminal.

### ratatui's TestBackend
ratatui provides `TestBackend` for snapshot testing of rendered UI, but this doesn't test keyboard input flow.

## Practical Solutions for rmpc

### Option 1: Manual Testing (Current)
- Run rmpc manually
- Verify features work as expected
- Document test cases for manual execution

### Option 2: Backend Unit Tests (Implemented)
Test backend logic without TUI:
- `youtube_backend_tests.rs` - Tests ID stripping, queue logic
- Does not require terminal interaction

### Option 3: UI Visibility Tests (Implemented)
Using tui-test for what DOES work:
- Verify app starts
- Verify UI elements render
- 3/6 tests pass (UI tests)

### Option 4: Helix-Style Refactor (Not Implemented)
Would require significant changes to rmpc:
1. Create `EventSource` trait
2. Implement `RealEventSource` (crossterm) and `MockEventSource` (channel)
3. Modify app to use trait instead of direct crossterm calls

## Test Files

| File | Purpose | Status |
|------|---------|--------|
| `tests/e2e/rmpc-tui-test.spec.ts` | tui-test E2E tests | 3/6 pass (UI only) |
| `rmpc/tests/youtube_backend_tests.rs` | Backend unit tests | 13/13 pass |
| `rmpc/tests/expectrl_test.rs` | PTY testing experiments | Documents limitation |

## Recommendations

1. **Don't waste time on PTY-based keyboard testing** - It's a known crossterm limitation
2. **Use unit tests for backend logic** - Reliable and fast
3. **Use tui-test for UI rendering verification** - Works for visual tests
4. **Manual testing for keyboard interactions** - Only reliable method currently
5. **Consider Helix-style refactor** if automated E2E is critical

## References

- [Helix Editor Test Helpers](https://github.com/helix-editor/helix/blob/master/helix-term/tests/test/helpers.rs)
- [Integration testing TUI applications in Rust](https://quantonganh.com/2024/01/21/integration-testing-tui-app-in-rust.md)
- [crossterm GitHub Issues](https://github.com/crossterm-rs/crossterm/issues)
- [expectrl Library](https://github.com/zhiburt/expectrl)
