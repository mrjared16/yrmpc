# Task Completion Steps

After making any code changes in the **yrmpc** project, follow these steps to ensure the changes are correctly integrated and the project remains healthy:

1. **Run Tests**: `cargo test` – ensures all unit and integration tests pass.
2. **Check Formatting**: `cargo fmt -- --check` – verifies code follows the project's `rustfmt.toml` style.
3. **Run Lints**: `cargo clippy -- -D warnings` – checks for potential bugs and enforces the project's Clippy pedantic rules.
4. **Build Release Binary**: `cargo build --release` – confirms the project compiles without errors.
5. **Manual Run** (optional): `cargo run --release` – start the application to verify runtime behavior.
6. **Update Documentation**: Ensure any new public APIs have appropriate doc comments.
7. **Commit**: Include the formatted code and updated docs, and push to the repository.

These steps constitute the standard workflow for completing a development task in the project.