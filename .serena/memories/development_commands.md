# Development Commands

- **Build**: `cargo build --release`
- **Run**: `cargo run --release`
- **Test**: `cargo test`
- **Format**: `cargo fmt -- --check`
- **Lint**: `cargo clippy -- -D warnings`
- **Install dependencies** (system): see `setup.sh` for installing Mopidy, MPD, and related tools.
- **Install Rust toolchain**: `rustup update && rustup component add clippy rustfmt`

These commands cover the typical development workflow for the **yrmpc** project.