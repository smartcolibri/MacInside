# Changelog

All notable changes to MacInside are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Governance files: contributing guide, security policy, issue and PR templates, code owners, Dependabot configuration, release-notes categories, architecture decision records.

### Changed
- Landing page and README links now point to the `smartcolibri/MacInside` repository.

## [1.2.0] - 2026-08-11

### Added
- Process manager window: sortable, customizable table (name, PID, user, status, CPU, memory, threads, disk I/O, run time, command line...), search with comma-separated terms and regular expressions, numeric and status filters, persistent pinning, and a detail inspector with parent/child navigation.
- Terminate, Force Quit and Lower priority actions available from the process table.
- Six new widgets (Storage, Network identity, Network throughput, Fans, Power, Bluetooth accessories), for ten widgets in total, each showing the age of its data.
- Pause button to freeze all readings; load average in the machine identity header.

### Changed
- Widget snapshot format extended with backward-compatible optional sections, so updating from 1.1.0 does not blank existing widgets.
- Full process collection only runs while the process window is open.
- 23 unit tests.

## [1.1.0] - 2026-07-25

### Added
- Enriched battery card with configurable low/high threshold alerts.
- History mini-graphs and disk throughput.
- Bluetooth accessory battery levels.
- Launch at login.
- Process actions from the dashboard cards.
- Unit tests.
- Drag-and-drop reordering of dashboard cards (animated, insertion before or after the target).
- "Design with love" credit in Settings > About.

### Changed
- Settings window reorganized into tabs (General / Dashboard / Menu bar / Battery / About).
- Battery thresholds set with a slider.

## [1.0.0] - 2026-07-11

### Added
- First public release: native macOS dashboard with machine identity, CPU, memory, storage, network, SMC sensors, GPU and battery cards.
- Menu bar with a combined dropdown or one icon per metric.
- French and English localization.
- Sparkle 2 auto-update, Developer ID signed and notarized DMG.

[Unreleased]: https://github.com/smartcolibri/MacInside/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/smartcolibri/MacInside/releases/tag/v1.2.0
[1.1.0]: https://github.com/smartcolibri/MacInside/releases/tag/v1.1.0
[1.0.0]: https://github.com/smartcolibri/MacInside/releases/tag/v1.0.0
