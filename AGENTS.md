# AGENTS.md — rules for AI agents working in this repo

Applies to any coding agent (Claude Code, Codex, etc.). Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Build and verify

- After **every** code change, run `xcodegen generate` then the macOS build:
  `xcodebuild -project MacInside.xcodeproj -scheme MacInside -configuration Debug CODE_SIGNING_ALLOWED=NO build`
- Run the tests when logic changes: `xcodebuild test -project MacInside.xcodeproj -scheme MacInside -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.
- Never claim "done" or "it compiles" without having run the commands and read the output.

## Git

- Never push to `main`. Work on a branch and open a PR (squash-merge).
- Conventional commits in English, present tense (`fix: ...`, `feat: ...`, `docs: ...`).
- Sign off every commit: `git commit -s` (DCO, enforced by the `dco` CI job).
- Do not create tags or releases.

## Do not touch

- Never regenerate the Sparkle EdDSA key and never change `SUPublicEDKey` in `project.yml` (it permanently breaks auto-update for installed copies).
- Never change bundle identifiers (`fr.vincentlauriat.macinside`, `fr.vincentlauriat.macinside.widgets`) or App Group identifiers.
- Do not edit `appcast.xml` or `Scripts/release.sh`; releases are the maintainer's job.
- Do not commit secrets, certificates, keychain material or `Local.xcconfig`.

## Code rules

- Every UI string goes in `Localizable.xcstrings` in **French and English**.
- Process actions (kill / renice) must keep their confirmation step.
- The app is not sandboxed; the widget extension is. Do not add new network calls or any telemetry.
- Fix root causes; do not silence warnings or add logging as a workaround. If an approach fails, change strategy rather than iterating on it.
- Keep diffs small and in scope; match existing patterns (see `ARCHITECTURE.md`).
- Decisions that last belong in `docs/decisions/`.
