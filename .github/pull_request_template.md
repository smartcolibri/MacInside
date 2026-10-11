## What

<!-- What does this PR change? -->

## Why

<!-- Problem solved or issue closed (e.g. "Closes #123"). -->

## Screenshots

<!-- Required for UI changes (before / after). Delete if not applicable. -->

## Checklist

- [ ] New or changed UI strings are added to `Localizable.xcstrings` in **both French and English**
- [ ] Tests run: `xcodebuild test -project MacInside.xcodeproj -scheme MacInside -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
- [ ] Unsigned build succeeds (`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`)
- [ ] This PR touches process actions (kill / renice) — confirmation dialogs preserved
- [ ] All commits are signed off (DCO): `git commit -s`
