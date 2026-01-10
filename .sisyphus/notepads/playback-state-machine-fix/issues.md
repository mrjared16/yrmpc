# Issues / Gotchas

- `cargo test -p rmpc` runs doctests; a few examples were failing and needed minor updates (type annotations/imports).
- `bd sync --from-main` fails in this workspace because no git remote is configured.
- There is a local stash in the `rmpc/` submodule (`wip: other playback changes`) containing out-of-scope edits; keep it stashed until the relevant plan step.
- Occasional `GLib-GIO-CRITICAL` warnings show during tests (non-fatal in these runs).
