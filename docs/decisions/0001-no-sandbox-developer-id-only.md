# 0001 - No App Sandbox, Developer ID distribution only

- Status: Accepted
- Date: 2026-07-11

## Context

MacInside reads SMC sensors (temperatures, fans, power) through IOKit, enumerates processes with `libproc`, and offers Terminate / Force Quit / Lower priority. None of this works inside the App Sandbox, and the Mac App Store requires it.

## Decision

The main app ships with `com.apple.security.app-sandbox` disabled (`MacInside/MacInside.entitlements`). It is distributed outside the Mac App Store as a Developer ID signed, Hardened Runtime, notarized and stapled DMG. The widget extension, by contrast, is sandboxed (macOS requires it).

## Consequences

- Mac App Store distribution is out of scope.
- Releases need the maintainer's Developer ID certificate and notarization.
- Updates are delivered with Sparkle (see 0002).
- Code touching system APIs and process actions deserves extra review.
