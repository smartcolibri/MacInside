# 0003 - Widget data shared as a snapshot through the App Group

- Status: Accepted
- Date: 2026-07-26

## Context

The widget extension is sandboxed and cannot read sensors or processes itself, while the main app is unsandboxed and already collects every metric. Both targets declare an App Group entitlement.

## Decision

The app writes a `WidgetSnapshot` (`MacInside/Shared/`) into the App Group container; widgets only read and render it, with a visible data age. Sections added after the first widgets (storage, network identity, network usage, fans, power, accessories) are optional properties defaulting to `nil`, so a snapshot written by an older version still decodes.

## Consequences

- Updating the app never blanks widgets because of a format change.
- New sections must be optional with a `nil` default; removing or renaming a field breaks older snapshots.
- Widgets show stale data when the app is not running; hence the data-age label.
- The App Group identifier must not change.
