# yrmpc-jwq.1 — v1 connection/event semantics

## Goal

Define a minimal, correct contract for YouTube daemon multi-client behavior that unblocks implementation without overdesign.

## Authoritative snapshot boundary

`rmpcd` is the source of truth for backend state.

Snapshot must include at minimum:

1. playback status (state, current song, timing fields available today)
2. queue/playlist view exposed by existing API
3. options (repeat/shuffle/volume and related runtime options currently surfaced)

Clients treat snapshot as authoritative and replace local backend mirrors with snapshot values.

UI-local state (pane/tab/cursor/scroll/modals/search input) remains per-TUI and is **not** daemon-shared.

## Live update delivery model

1. Multiple clients may be connected concurrently.
2. Daemon publishes state-change updates to all subscribed clients.
3. Per-client event order must follow publish order.
4. If a client lags or misses updates, client performs full resync (snapshot) instead of partial replay in v1.

## Reconnect behavior

On disconnect / daemon restart:

1. client detects broken connection
2. client marks backend unhealthy
3. client attempts reconnect
4. on reconnect: resubscribe + request full snapshot
5. client returns to healthy state after successful snapshot

This resolves zombie/stale TUI behavior after daemon restarts.

## Retry safety policy

v1 retry rules:

- **Read-only requests** (status/playlist/options queries): safe to retry.
- **Mutating requests** (play/pause/queue edits/next/prev): do **not** auto-retry blindly.

Reason: without idempotency keys or request IDs, write retries can duplicate side effects.

## Explicit non-goals (v1)

1. exactly-once mutation semantics
2. durable event-log replay across daemon restarts
3. broad cross-backend protocol redesign
4. distributed/multi-daemon coordination

## Acceptance checks for this spike

- Semantics are documented and implementation phases can reference this file.
- Boundaries are explicit enough to implement tests and code in subsequent beads.
