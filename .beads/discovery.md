## YtDlpExtractor PO-token refactor discovery

### Runtime findings

- The standalone `po-token.md` flow works when yt-dlp is invoked with:
  - `--ignore-config`
  - `--js-runtimes bun:/home/phucdnt/.local/share/mise/shims/bun`
  - `--cookies /home/phucdnt/.config/rmpc/cookie.txt`
  - `--extractor-args youtube:player-client=mweb`
  - `--extractor-args youtubepot-bgutilhttp:base_url=http://127.0.0.1:4417`
- The current app integration does not yet model the desired degrade path. The extractor currently treats bgutil bootstrap failure as terminal instead of retrying with `-f 251`.

### Code map

- `rmpc/src/backends/youtube/extractor/ytdlp.rs`
  - Actual yt-dlp playback extractor.
  - Currently mixes policy, arg building, JS runtime lookup, provider lifecycle, and command execution.
- `rmpc/src/backends/youtube/extractor/ytx.rs`
  - Primary fast extractor.
- `rmpc/src/backends/youtube/extractor/fallback.rs`
  - Fallback composition from `YtxExtractor` to `YtDlpExtractor`.
- `rmpc/src/backends/youtube/url_resolver.rs`
  - Keeps the stable decorator graph for both direct yt-dlp and ytx+fallback paths.
- `rmpc/src/backends/youtube/config.rs`
  - `YtDlpExtractorConfig` is intentionally narrow again (`cookies_path` only).

### Confirmed constraints

- Keep the public extractor contract unchanged:
  - `Extractor`
  - `CachedExtractor`
  - `FallbackExtractor`
  - `YtxExtractor`
  - `UrlResolver`
- PO-token behavior is extractor-owned, not daemon-CLI-owned.
- Provider lifecycle is lazy:
  - direct yt-dlp path starts on first yt-dlp use
  - ytx fallback path starts only when fallback is actually used
- JS runtime lookup order must be:
  1. env override
  2. `which bun`
  3. `which node`
- Provider URL must be composed from host + port.
- If provider bootstrap fails:
  - emit warning now via logs
  - keep cookies intact
  - retry once with `-f 251`
- User-visible IPC warnings are desired eventually, but protocol/UI plumbing is explicitly deferred from this refactor.

### Architecture review outcome

- Keep the decorator graph unchanged.
- Refactor only inside `YtDlpExtractor` using private helpers:
  - `ProviderEndpoint`
  - `YtDlpPolicy`
  - `YtDlpCommandBuilder`
  - `PoTokenProviderManager`
  - `JsRuntimeResolver`
  - `ExtractorDiagnosticsSink`
- Preserve compatibility while decomplecting logic from I/O.
