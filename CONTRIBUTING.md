# Contributing to MacInside

Thanks for your interest! MacInside is a free, open-source (MIT) native macOS system dashboard. Issues and pull requests are welcome.

## Requirements

- macOS 14+ and a stable (non-beta) Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and test

The Xcode project is generated from `project.yml` and is not committed:

```bash
xcodegen generate
xcodebuild -project MacInside.xcodeproj -scheme MacInside -configuration Debug CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project MacInside.xcodeproj -scheme MacInside -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

### Signing with your own team (optional)

Builds with `CODE_SIGNING_ALLOWED=NO` need no Apple account. To run the app and its widgets signed locally, copy `Local.xcconfig.example` to `Local.xcconfig` and set your own `DEVELOPMENT_TEAM`. `Local.xcconfig` is git-ignored.

## Workflow

1. Fork the repo (or branch, if you are a maintainer) and create a branch such as `feat/...`, `fix/...`, `docs/...`.
2. Use [conventional commits](https://www.conventionalcommits.org/) in English, present tense: `fix: correct fan RPM on fanless Macs`.
3. Open a pull request against `main`. Fill in the PR template. PRs are **squash-merged**, so the PR title should itself be a conventional-commit message.
4. Never push directly to `main`.

## Sign your commits (DCO)

Contributions are made under the [Developer Certificate of Origin](https://developercertificate.org/). Every commit must carry a `Signed-off-by` line, which certifies that you wrote the change or have the right to submit it under the project license. Add it with:

```bash
git commit -s -m "fix: your message"
```

A CI check named `dco` rejects pull requests with unsigned commits. To fix existing commits: `git rebase --signoff main` then force-push your branch.

## Localization

MacInside is localized in French and English. Every user-visible string must exist in **both** languages in `MacInside/Localizable.xcstrings` (the same applies to the widget extension strings). The development language is French.

## Privacy and safety

- The app is **not sandboxed** (SMC sensor reads and process enumeration require it). Treat every system call, file access and network request as sensitive; do not add telemetry or network calls without discussion.
- Process actions (Terminate, Force Quit, Lower priority) must always require explicit user confirmation where they do today. Flag any change touching them in your PR.
- Do not change bundle identifiers or App Group identifiers: widgets and the app share data through them.

## Releases

Releases (signing, notarization, DMG, Sparkle signature, `appcast.xml`) are done by the maintainer only, on their machine. Contributors never need Apple credentials or the Sparkle key. Do not modify `SUPublicEDKey` or `appcast.xml` in a PR.

## Security

Please report vulnerabilities privately; see [SECURITY.md](SECURITY.md).
