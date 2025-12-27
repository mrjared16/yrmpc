# yrmpc

A terminal-based YouTube Music client built with Rust and Ratatui.

## Quick Start

```bash
cd rmpc && cargo build --release
./restart_daemon.sh
./rmpc/target/release/rmpc --config config/rmpc.ron
```

## Documentation

For comprehensive documentation, see **[CLAUDE.md](CLAUDE.md)** - the canonical entry point covering:

- Architecture overview
- Task management with `backlog` CLI
- Key files and module structure
- Development guidelines

## Features

- YouTube Music search and playback
- Queue management with vim-style keybindings
- Repeat (Off/One/All) and Shuffle modes
- MPRIS integration
- Backend-agnostic architecture (MPD support preserved)

## Project Status

See [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) for current state.

## License

Fork of [rmpc](https://github.com/mierak/rmpc). See LICENSE for details.
