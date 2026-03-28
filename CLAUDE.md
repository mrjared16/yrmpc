# CLAUDE.md

## Repository rules

- Run Cargo commands from `rmpc/`, not from the workspace root.
- Prefer `cargo nextest run` for verification.
- Never run `cargo fmt` unless the user explicitly asks for it.
- Prefer codebase-memory MCP tools for code discovery and fff tools for file search.

## Verification

- Use targeted `cargo nextest run ...` while iterating.
- Use `cargo clippy` when broader verification is needed.
- Do not introduce repo-wide formatting changes unless explicitly requested.
