## Chosen approach

Refactor `YtDlpExtractor` into a thin orchestration shell while preserving all existing public extractor contracts.

### Internal target shape

- `YtDlpExtractor`
  - orchestrates attempt selection, provider readiness, command execution, result parsing, and diagnostics
- `YtDlpPolicy`
  - pure logic for attempt selection
  - first attempt: HQ `774/141/251` with PO-token provider
  - degraded attempt: `251` with cookies intact
- `YtDlpCommandBuilder`
  - pure conversion from plan -> yt-dlp args
- `ProviderEndpoint`
  - owns `host`, `port`, and `base_url()` composition
- `JsRuntimeResolver`
  - resolves env override -> `which bun` -> `which node`
- `PoTokenProviderManager`
  - imperative shell for reachability checks, child lifecycle, script lookup, and lazy startup
- `ExtractorDiagnosticsSink`
  - log-first warning seam that does not couple extractor code to UI/protocol layers

### Why this is the balance point

- Fixes the real behavior gaps:
  - no more hardcoded duplicated provider URL
  - no more bun-only runtime preference
  - no more terminal failure on provider bootstrap miss
- Avoids risky contract churn:
  - no changes to `Extractor`
  - no new daemon CLI flags
  - no new protocol channel in this refactor
- Aligns with functional-core / imperative-shell guidance:
  - pure policy and arg building separated from I/O and process management

### Deferred explicitly

- daemon -> TUI warning IPC
- generalized retry engine or circuit breaker
- new daemon config plumbing
- decorator graph changes
