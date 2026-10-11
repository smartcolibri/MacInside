# Security Policy

## Supported versions

Only the latest release receives security fixes. Please update (MacInside > Check for Updates...) before reporting.

## Reporting a vulnerability

Report privately through GitHub's private vulnerability reporting:
<https://github.com/smartcolibri/MacInside/security/advisories/new>

Please do not open a public issue for security problems. Include the MacInside and macOS versions, a description, and steps to reproduce.

## Scope notes

- MacInside is **not sandboxed**: it reads SMC sensors and enumerates processes; it can terminate, force-quit or lower the priority of processes you own (and others, subject to macOS permissions) after user confirmation.
- Updates are delivered through Sparkle, with EdDSA-signed updates (public key `SUPublicEDKey` in `project.yml`); release DMGs are signed with a Developer ID and notarized by Apple.
