# yrmpc-jwq.5 — fanout/subscription contract (v1)

## Goal

Define how daemon events are delivered to multiple connected clients without single-consumer loss.

## Event model

1. Producers emit subsystem events (`player`, `playlist`, `options`, `mixer`) into an internal server event queue.
2. A fanout processor reads that queue and publishes each event to all active client subscriptions.
3. Each client session gets its own receiver; sessions do not compete for one shared receiver.

## Subscription lifecycle

1. Register subscription when a client session starts.
2. Use subscription receiver for `Idle` waits in that session.
3. Unregister subscription when session exits.

## Idle behavior (v1)

1. `Idle{subsystems}` waits on the session receiver with bounded timeout.
2. If event matches requested subsystem(s), return it immediately.
3. If no matching event before timeout, return empty idle response.

## Buffering / lag policy

v1 policy:

- per-session channel is bounded.
- if subscriber queue is full or disconnected during publish:
  - drop that subscriber entry (treat as stale/disconnected).
  - continue publishing to other subscribers.

Rationale: prevent unbounded memory growth and avoid one slow client blocking others.

## Naming contract

Use existing subsystem strings already emitted in server code paths:

- `player`
- `playlist`
- `options`
- `mixer`

No protocol-level rename in this bead.

## Non-goals

1. Exactly-once event delivery.
2. Durable replay for missed events.
3. Cross-backend fanout unification.

## Acceptance checks

- Contract is explicit for implementation in `.6` and `.7`.
- Session registration/unregistration and bounded queue behavior are specified.
