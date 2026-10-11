# 0002 - Dedicated Sparkle EdDSA key, never regenerated

- Status: Accepted
- Date: 2026-07-11

## Context

Sparkle verifies every update against the EdDSA public key embedded in the installed app (`SUPublicEDKey` in `project.yml`). If that key changes, copies already installed can no longer verify updates, and auto-update breaks permanently for them.

## Decision

MacInside uses its own EdDSA key (keychain account `MacInside`), not shared with other apps. The key is never regenerated and `SUPublicEDKey` is never changed once users have installed a version. `Scripts/release.sh` documents this and the backup procedure.

## Consequences

- The private key stays on the maintainer's machine, with a backup in a password manager; it never goes into CI.
- Releases are signed locally by the maintainer.
- Contributors and agents must not touch `SUPublicEDKey` (enforced by CODEOWNERS and AGENTS.md).
