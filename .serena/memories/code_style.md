# Code Style and Conventions

## Formatting
- Uses `rustfmt` with configuration in `rustfmt.toml` (max width 100, imports layout, etc.).
- `cargo fmt -- --check` is part of CI.

## Linting
- `clippy` with pedantic rules set to `deny` (see `[lints.clippy]` in `Cargo.toml`).
- Run `cargo clippy -- -D warnings`.

## Naming
- Snake_case for functions and variables, PascalCase for types, SCREAMING_SNAKE for constants.
- Modules are lower‑case, file names match module name.

## Documentation
- Doc comments (`///`) for public items, module‑level docs.
- `#[warn(missing_docs)]` is not enforced, but project aims for good docs.

## Testing
- Unit tests in `tests/` and inline `#[cfg(test)]` modules.
- Integration tests via `tests/` directory.

These conventions are enforced by CI and developers are expected to run `cargo fmt` and `cargo clippy` before committing.
