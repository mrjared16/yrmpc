## Requirements clarified

| Original need | Clarified decision |
| --- | --- |
| Fix PO-token support | Keep it extractor-owned inside `YtDlpExtractor` |
| JS runtime support | Resolve env override -> `which bun` -> `which node` |
| Provider endpoint | Compose from host + port |
| Provider failure | Warn and retry once with `251` |
| Warning surfacing | Log-first seam now, user-visible IPC later |
| Compatibility | Keep `Extractor`, caching, fallback, and resolver contracts unchanged |

## Key decisions

### 1. Do not change public extractor contracts

- **Context:** Existing decorator chain already works and must remain stable.
- **Options:**
  - Change `Extractor` or decorator wiring
  - Refactor only inside `YtDlpExtractor`
- **Decision:** Refactor only inside `YtDlpExtractor`.
- **Rationale:** Delivers the behavior fix with lower risk.
- **Trade-off:** Some internal helpers remain private instead of being reused elsewhere immediately.

### 2. Split pure policy from imperative provider management

- **Context:** Current `ytdlp.rs` complects decision logic with process spawning.
- **Decision:** Introduce pure helpers for policy and command building, imperative helpers for provider/runtime/process management.
- **Rationale:** Easier to test and reason about degradation behavior.

### 3. Retry exactly once with `251` on provider bootstrap failure

- **Context:** User explicitly requested warn + fallback 251.
- **Decision:** Bootstrap failure degrades once; no wider retry ladder in this refactor.
- **Rationale:** Minimal behavioral change that solves the immediate failure mode.

### 4. Defer protocol/UI warning integration

- **Context:** Current daemon/TUI IPC is request/response oriented and has no clean reverse warning path.
- **Decision:** Add a diagnostics seam in extractor code but keep the default implementation log-only for now.
- **Rationale:** Avoids coupling extractor internals to UI transport during this refactor.

## Assumptions

| Assumption | Impact if wrong | Mitigation |
| --- | --- | --- |
| Existing tests can cover the new helper seams | Reduced confidence in regression safety | Add focused unit tests around policy, builder, and degrade path |
| Provider script path resolution remains valid through env override/default path lookup | Startup may still fail in some environments | Keep clear errors/warnings and preserve degraded 251 retry |
| A log-first warning is enough for this refactor | Warning may not be visible enough to end users | Follow-up bead can add protocol-backed status surfacing |

## Open questions

| Question | Resolution | Resolved by |
| --- | --- | --- |
| Should PO-token config live in daemon CLI? | No, extractor owns it | user feedback + architecture review |
| Should provider failure be terminal? | No, warn and retry `251` | user feedback |
| Should extractor emit UI IPC directly? | No, defer and use seam | architecture review |

## Scope boundaries

### In scope

- Internal `YtDlpExtractor` refactor
- Helper extraction for policy / arg building / provider management
- JS runtime resolution order fix
- Provider endpoint composition
- Warn + retry once with `251`
- Focused tests and validation

### Explicitly out of scope

- daemon auto-start redesign
- new daemon CLI/config surface
- protocol changes for live UI warnings
- broader yt-dlp retry policy beyond provider bootstrap failure
