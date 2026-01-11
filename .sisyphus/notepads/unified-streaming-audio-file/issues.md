## Known Gotchas

- Rust-analyzer in this environment may not notice on-disk edits made outside LSP; if diagnostics/symbols look stale, restarting `rust-analyzer` can force a resync.
