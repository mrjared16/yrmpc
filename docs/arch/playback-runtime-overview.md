# Playback Runtime Overview

Historical baseline command:

```bash
RUST_BACKTRACE=1 RUST_LOG=debug "$DAEMON_PATH" --extractor ytdlp --audio-source passthrough
```

`passthrough` maps to `AudioDeliveryMode::Direct`. No concat, no staging, no prefix download. The daemon resolved a direct URL via ytdlp and handed it straight to MPV.

---

## Historical Baseline

```text
┌─────────────────────────────────────────────────────────────────┐
│                     HISTORICAL BASELINE                         │
│                                                                 │
│   ytdlp extract ──► Direct URL ──► MPV (passthrough)           │
│                                                                 │
│   AudioDeliveryMode::Direct                                     │
│   No preparer. No concat adapter. No prefix cache.             │
└─────────────────────────────────────────────────────────────────┘
```

Single path. No staging tiers. The URL from ytdlp went directly to the player. This is the stable reference behavior that Combined and Relay depart from.

---

## Current Planning Layer

The planner maps delivery mode to a plan tuple:

```text
┌─────────────────────────────────────────────────────────────────┐
│                     PLANNER MAPPING                             │
│                                                                 │
│   Direct  ──► DirectUrl + ResolveOnly + reconnect=true         │
│   Combined ──► Combined + StagePrefix + reconnect=false        │
│   Relay   ──► LocalRelay + StagePrefix + reconnect=true        │
│                                                                 │
│   StagePrefix = download prefix bytes, stage for concat.       │
│   ResolveOnly = resolve URL, no prefix download.               │
└─────────────────────────────────────────────────────────────────┘
```

Combined intentionally introduces concat behavior via `StagePrefix`. Relay also plans `StagePrefix`, and now uses a localhost relay runtime for MPV input delivery.

---

## Current Runtime Handoff

After the preparer runs, the orchestrator calls a single transport-aware boundary in `PlaybackService`:

```text
┌─────────────────────────────────────────────────────────────────┐
│              POST-PREPARATION HANDOFF                           │
│                                                                 │
│   PreparedMedia + track_id                                     │
│       │                                                         │
│       ▼                                                         │
│   PlaybackService::build_runtime_input()                       │
│       │                                                         │
│       ├── transport == LocalRelay                              │
│       │      └── RelayRuntime::register_session()              │
│       │            -> http://127.0.0.1:<port>/relay/...        │
│       │                                                         │
│       └── transport == DirectUrl / Combined                    │
│              └── FfmpegConcatSource::build_from_prepared()     │
│                   -> plain URL (Direct) OR lavf://concat       │
│                      (StagedPrefix)                             │
└─────────────────────────────────────────────────────────────────┘
```

`PlaybackService::build_runtime_input` is now the runtime boundary. `FfmpegConcatSource` remains concat-specific transport code for Combined and direct/fallback pass-through, while `RelayRuntime` serves relay-mode localhost URLs.

---

## Mode Reality Today

```text
┌─────────────────────────────────────────────────────────────────┐
│                  MODE REALITY (CURRENT CODE)                    │
│                                                                 │
│   Direct                                                        │
│   ├── Planner: DirectUrl + ResolveOnly                        │
│   ├── Preparer yields: PreparedMedia::Direct                  │
│   └── Transport: plain URL through FfmpegConcatSource         │
│                                                                 │
│   Combined                                                      │
│   ├── Planner: Combined + StagePrefix                         │
│   ├── Preparer yields: PreparedMedia::StagedPrefix            │
│   └── Transport: lavf://concat:... via FfmpegConcatSource     │
│                                                                 │
│   Relay                                                         │
│   ├── Planner: LocalRelay + StagePrefix                       │
│   ├── Preparer yields: PreparedMedia::StagedPrefix            │
│   ├── Transport: local daemon relay URL via RelayRuntime      │
│   └── Runtime: staged bytes + upstream bytes served over HTTP │
└─────────────────────────────────────────────────────────────────┘
```

Relay runtime is now wired in daemon startup for `LocalRelay` transport and persists with the server lifecycle. Direct fallback still applies for Immediate-tier staging timeout/failure.

---

## What FfmpegConcatSource Is

It is a transport-specific adapter used by non-relay paths after preparation. It is not the architecture. The architecture boundary is `PlaybackService::build_runtime_input`.

For `PreparedMedia::Direct`, it passes through a plain URL. It does not build a one-segment concat. For `PreparedMedia::StagedPrefix`, it either constructs `lavf://concat:...` or returns a local file path when the staged prefix covers the whole content.

The preparer checks cached prefix metadata first and only downloads prefix bytes on a cache miss. The immediate tier may fall back to direct on timeout or failure.

---

## Bottom Line

The old stable baseline was direct passthrough with ytdlp. Combined intentionally adds concat staging. Relay is now a real localhost runtime path that streams staged-prefix bytes followed by upstream bytes. Current code uses one transport-aware post-preparation boundary in `PlaybackService`, with `FfmpegConcatSource` as concat-specific implementation and `RelayRuntime` as relay-specific implementation.
