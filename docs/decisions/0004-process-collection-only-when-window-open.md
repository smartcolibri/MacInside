# 0004 - Full process collection only while the process window is open

- Status: Accepted
- Date: 2026-08-11

## Context

The process manager shows many fields per process (command line, threads, per-process disk I/O, ...), which costs several kernel calls per process on each refresh. The dashboard only needs the top few processes by CPU and memory.

## Decision

`AppModel.isProcessListActive` is true only while the process window is open; the refresh loop calls the full `ProcessListMonitor` snapshot only in that case. Otherwise the dashboard tick uses the lighter `ProcessMonitor` top lists. Environment variables are read on demand when the inspector is opened.

## Consequences

- Dashboard refresh cost is unchanged by the process manager.
- The process list is empty or stale when the window is closed; opening it triggers an immediate snapshot.
