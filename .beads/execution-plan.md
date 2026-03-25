## Overview

- Epic: `yrmpc-197`
- Title: `[EPIC] YtDlp extractor PO-token refactor`
- Total beads: 4 child tasks
- Estimated duration: 1 focused implementation pass

## Context summary

- The standalone PO-token flow works.
- The current app code already moved PO-token ownership into `YtDlpExtractor`, but the implementation is still too monolithic and still fails terminally when bgutil bootstrap fails.
- The safe path is an internal refactor that preserves the extractor contract and decorator graph.

## Key constraints for execution

- Do not change:
  - `Extractor`
  - `CachedExtractor`
  - `FallbackExtractor`
  - `YtxExtractor`
  - `UrlResolver` composition
- Keep PO-token logic extractor-owned.
- Keep provider startup lazy.
- Resolve JS runtime in order: env override -> `which bun` -> `which node`.
- Compose provider base URL from host + port.
- On provider bootstrap failure, warn and retry exactly once with cookies intact and `-f 251`.
- Defer daemon/TUI warning transport; use log-first diagnostics seam now.

## Dependency graph

- `yrmpc-197.1` -> `yrmpc-197.2` -> `yrmpc-197.3` -> `yrmpc-197.4`

## Execution batches

| Batch | Bead | Worker | Key context |
| --- | --- | --- | --- |
| A | `yrmpc-197.1` | orchestrator | Extract pure helper types and tests first without breaking behavior |
| B | `yrmpc-197.2` | orchestrator | Replace current bgutil manager with provider/runtime manager; keep lazy semantics |
| C | `yrmpc-197.3` | orchestrator | Add diagnostics seam and degraded retry path to `251` |
| D | `yrmpc-197.4` | orchestrator | Run diagnostics/tests and update `po-token.md` only if operator-facing behavior changed |

## Acceptance criteria

- `YtDlpExtractor` stays compatible with existing resolver/caching/fallback composition.
- Internal helper boundaries exist for policy, arg building, runtime resolution, and provider management.
- Provider URL is composed, not duplicated as a base URL constant.
- Runtime resolution follows env -> bun -> node.
- Provider bootstrap failure no longer aborts immediately; it warns and retries once with `251`.
- Focused tests cover the new behavior.

## Risk mitigation

| Risk | Strategy |
| --- | --- |
| Refactor breaks extractor contract indirectly | Keep public signatures unchanged and verify with diagnostics/tests |
| Same-file refactor becomes tangled | Land behavior in small dependency-ordered beads |
| Warning seam grows into protocol work | Keep default implementation log-only |
| Docs drift from behavior | Update `po-token.md` only if user-facing behavior truly changed |
