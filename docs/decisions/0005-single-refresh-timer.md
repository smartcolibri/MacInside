# 0005 - A single refresh loop in AppModel

- Status: Accepted
- Date: 2026-07-11

## Context

Each provider (CPU, memory, network, sensors, ...) could run its own timer, at the cost of desynchronized readings and harder throttling.

## Decision

`AppModel` owns one refresh `Task` that polls every provider each tick, with a user-adjustable interval (1 s by default). Providers are synchronous and fast; the only asynchronous one is the public-address lookup, cached and non-blocking.

## Consequences

- All cards show readings from the same tick.
- Pausing and throttling are handled in one place.
- A slow provider delays the whole tick, so providers must stay fast.
