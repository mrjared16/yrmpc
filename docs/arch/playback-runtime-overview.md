# Playback Runtime Overview

> **Status: Historical baseline + partially stale.** The historical baseline section is accurate. The "Current" sections below are outdated — they omit `StreamAndCache`, coordinator ownership, and tee-prefix promotion. See [playback-flow.md](playback-flow.md) for current behavior.

Historical baseline command:

```bash
RUST_BACKTRACE=1 RUST_LOG=debug "$DAEMON_PATH" --extractor ytdlp --audio-delivery passthrough
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

Single path. No staging tiers. The URL from ytdlp went directly to the player. This is the stable reference behavior that Staged and Relay depart from.

---

## Current Planning Layer

The planner maps delivery mode to a plan tuple:

```text
┌─────────────────────────────────────────────────────────────────┐
│                     PLANNER MAPPING                             │
│                                                                 │
│   Direct  ──► DirectUrl + ResolveOnly + reconnect=true         │
│   Staged  ──► PreparedInput + StagePrefix + reconnect=false    │
│   Relay   ──► LocalRelay + StagePrefix + reconnect=true        │
│                                                                 │
│   StagePrefix = download prefix bytes, stage for concat.       │
│   ResolveOnly = resolve URL, no prefix download.               │
└─────────────────────────────────────────────────────────────────┘
```

Staged intentionally introduces concat behavior via `StagePrefix`. Relay also plans `StagePrefix`, and now uses a localhost relay runtime for MPV input delivery.

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
│       └── transport == DirectUrl / PreparedInput               │
│              └── PreparedMediaInputAdapter::build_from_prepared() │
│                   -> plain URL (Direct) OR lavf://concat       │
│                      (StagedPrefix)                             │
└─────────────────────────────────────────────────────────────────┘
```

`PlaybackService::build_runtime_input` is now the runtime boundary. `PreparedMediaInputAdapter` maps prepared media to MPV inputs for staged and direct/fallback paths, while `RelayRuntime` serves relay-mode localhost URLs.

---

## Mode Reality Today

```text
┌─────────────────────────────────────────────────────────────────┐
│                  MODE REALITY (CURRENT CODE)                    │
│                                                                 │
│   Direct                                                        │
│   ├── Planner: DirectUrl + ResolveOnly                        │
│   ├── Preparer yields: PreparedMedia::Direct                  │
│   └── Transport: plain URL through PreparedMediaInputAdapter  │
│                                                                 │
│   Staged                                                        │
│   ├── Planner: PreparedInput + StagePrefix                    │
│   ├── Preparer yields: PreparedMedia::StagedPrefix            │
│   └── Transport: lavf://concat:... via PreparedMediaInputAdapter │
│                                                                 │
│   Relay                                                         │
│   ├── Planner: LocalRelay + StagePrefix                       │
│   ├── Preparer yields: PreparedMedia::StagedPrefix            │
│   ├── Transport: local daemon relay URL via RelayRuntime      │
│   └── Runtime: staged bytes + upstream bytes served over HTTP │
└─────────────────────────────────────────────────────────────────┘
```

Relay runtime is now wired in daemon startup for `LocalRelay` transport and persists with the server lifecycle. Direct fallback still applies for Immediate-tier staging timeout/failure.

Today `RelayRuntime` streams staged bytes and upstream bytes over localhost, but it still forwards a single upstream `Range` request for each player request. The planned throttling-bypass update keeps the same MPV-visible localhost URL and immediate downstream streaming behavior while splitting the relay -> YouTube request into throttle-safe chunks.

---

## Audio-Delivery CLI Modes and Fallback Behavior

The `--audio-delivery` flag selects the daemon's audio delivery strategy. `--audio-source` remains a compatibility alias. The `--extractor` flag selects how YouTube URLs are resolved.

```text
┌─────────────────────────────────────────────────────────────────┐
│            --audio-delivery MODE SUMMARY                        │
│                                                                 │
│   direct                                                        │
│   ├── No prefix download. No concat. No relay.                 │
│   ├── Resolves URL → hands plain URL to MPV.                   │
│   └── Lowest latency, but no pre-buffering.                    │
│                                                                 │
│   staged                                                        │
│   ├── Downloads prefix bytes first.                            │
│   ├── Concatenates via lavf://concat:... for MPV.              │
│   └── Gapless-ready when prefix is staged in time.             │
│                                                                 │
│   relay                                                         │
│   ├── Downloads prefix bytes first.                            │
│   ├── Serves bytes over local HTTP relay (RelayRuntime).       │
│   └── Streams staged prefix → upstream bytes over localhost.   │
│                                                                 │
│   --extractor values:                                           │
│   ├── ytx   (~200ms, requires ytx binary)                     │
│   └── ytdlp (~3-4s, reliable fallback)                        │
└─────────────────────────────────────────────────────────────────┘
```

### Relay Fallback Behavior

For the currently starting track (`PreloadTier::Immediate`), the relay has a **fallback path**:

```text
┌─────────────────────────────────────────────────────────────────┐
│           RELAY IMMEDIATE-TIER BEHAVIOR                         │
│                                                                 │
│   Immediate track needs preparation                             │
│       │                                                         │
│       ▼                                                         │
│   Relay setup attempt                                           │
│       │                                                         │
│       ├── SUCCESS → PreparedMedia::StagedPrefix                │
│       │               → RelayRuntime::register_session()       │
│       │                                                         │
│       ├── CACHE MISS → PreparedMedia::StreamAndCache           │
│       │                 → relay streams URL, tee-prefix        │
│       │                   downloads cache in background        │
│       │                                                         │
│       └── RELAY SETUP FAIL → TrackOwner::DirectFallback        │
│                               → plain URL to MPV (last resort) │
│                                                                 │
│   Gapless / Eager tracks do NOT have this fallback.            │
│   They require staged-prefix to succeed for seamless playback. │
└─────────────────────────────────────────────────────────────────┘
```

This means: under high demand or slow network, the first track may start via plain URL (like old passthrough mode) while later window tracks still get relay treatment. The fallback is silent and automatic — it does not crash or skip tracks.

### When Each Mode Matters

| Scenario | Recommended Mode | Why |
|----------|-----------------|-----|
| Debugging / log collection | `--audio-delivery relay` | RelayRuntime logs upstream chunks, staging, and fallback decisions |
| Low-bandwidth / testing | `--audio-delivery direct` | No prefix download overhead |
| Seamless playback goal | `--audio-delivery relay` or `staged` | Prefix staging enables gapless handoff |

---

## What PreparedMediaInputAdapter Is

It is a transport-specific adapter used by non-relay paths after preparation. It is not the architecture. The architecture boundary is `PlaybackService::build_runtime_input`.

For `PreparedMedia::Direct`, it passes through a plain URL. It does not build a one-segment concat. For `PreparedMedia::StagedPrefix`, it either constructs `lavf://concat:...` or returns a local file path when the staged prefix covers the whole content.

The preparer checks cached prefix metadata first and only downloads prefix bytes on a cache miss. The immediate tier may fall back to direct on timeout or failure.

---

## Bottom Line

The old stable baseline was direct passthrough with ytdlp. Staged intentionally adds concat staging. Relay is now a real localhost runtime path that streams staged-prefix bytes followed by upstream bytes. After the throttling-bypass transport hardening lands, Relay should keep that same player-facing shape while chunking only the upstream relay -> YouTube leg. Current code uses one transport-aware post-preparation boundary in `PlaybackService`, with `PreparedMediaInputAdapter` for non-relay input mapping and `RelayRuntime` for relay delivery.
