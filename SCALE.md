# SCALE — Moving MacInside to an industrial, collaborative workflow

Status: **proposal** (2026-10-11, adapted from the Cockpit for Claude version of 2026-10-10). Nothing below has been applied on GitHub yet; it waits for the decisions in section 2.

Context: MacInside is a free, **open-source (MIT)** native macOS system dashboard (window + menu bar + 10 widgets), distributed as a notarized Developer ID DMG with Sparkle auto-update. It is **not sandboxed** (SMC sensors, process enumeration and kill/renice need it), so the Mac App Store is out of scope and Developer ID stays the only distribution channel. The product plan lives in `PLAN.md`; this document covers *how the work is organised*, not *what* is built.

## 1. Current state (checked 2026-10-11, after the transfer to `smartcolibri`)

| Area | Today |
|---|---|
| Code | `smartcolibri/MacInside` (transferred from `vincentlauriat/MacInside`; the old URLs redirect), **public**, MIT license. One collaborator: Vincent |
| Plan | Organization `smartcolibri` on GitHub **Team** → rulesets, required reviews, CODEOWNERS and org-level Projects are available. Org defaults already set: 2FA required, members can create public repos, default permission `read` |
| Workflow | **0 PRs** on GitHub: feature branches are merged locally with `git merge --no-ff` and `main` is pushed directly. Merge commits, squash and rebase merges all allowed; merged branches are **not** auto-deleted |
| `main` | **Not protected**, no ruleset |
| Task tracking | `TODOS.md` + `PLAN.md` (git-ignored). **0 issues**, default labels only, no milestones, no Projects board |
| Project memory | `MEMORY.md`, `CHANGES.md`, `PLAN.md`, `TODOS.md`, `COMMANDS.md` — git-ignored, visible to Vincent only. `ARCHITECTURE.md` and `PRD.md` are tracked |
| Conventions | Repo `CLAUDE.md` is **git-ignored** (as is `.claude/`): a collaborator or their agent gets no conventions from the repo. No `CONTRIBUTING.md`, no `AGENTS.md` |
| Tests / build | 23 unit tests in `MacInsideTests` (formatters, safe deltas, widget snapshot, process filter), run with `xcodebuild test` on Vincent's Mac only — the host app does not terminate after the run, so the final verdict reads `TEST FAILED` even when every case passes. No `.github/` folder, no CI |
| Releases | `Scripts/release.sh <version>` run locally: Developer ID signing, notarization, DMG, staple, Sparkle EdDSA signature, `appcast.xml`. GitHub Releases `v1.0.0`, `v1.1.0`, `v1.2.0` (latest, 2026-08-11) |
| Landing page | GitHub Pages from `docs/` on `main`, now at https://smartcolibri.github.io/MacInside/ — the old `vincentlauriat.github.io/MacInside/` returns **404** since the transfer. Copies: a card on `vincentlauriat.github.io` (separate repo, manual PR) and a reference on `lauriat.fr` (separate repo, deployed with `UploadSite.sh`); both still need to point to the new URL |
| Apple | **Individual** Apple Developer account, team `KFLACS69T9`, shared with Vincent's other Mac apps. "Developer ID Application: Vincent LAURIAT" certificate in Vincent's keychain |
| Sparkle feed | `SUFeedURL` in shipped builds = `raw.githubusercontent.com/vincentlauriat/MacInside/main/appcast.xml`, served today through GitHub's transfer redirect (HTTP 200) |
| Secrets | All on Vincent's Mac: Sparkle EdDSA private key (login keychain, account `MacInside`, dedicated to this app — must never be regenerated), notarytool profile `AppliMacVincentGithub`, signing certificate |

## 2. Decisions needed first

### 2.1 Protecting `main` — sized for one person

Rulesets and branch protection are available (public repo, Team plan). The trap is the same as on any solo project: **a rule requiring one approving review blocks a solo developer**, since GitHub does not let you approve your own PR. It also ends today's habit of merging locally and pushing `main`.

- **Recommended now**: ruleset on `main` — PR required, linear history, green CI required, **0 required approvals**, no force push, no deletion; organization admins may bypass in an emergency.
- **When a second maintainer joins**: raise to 1 approval + CODEOWNERS review.

### 2.2 Who the collaborators are (open-source contributors, agents, or both)

- **Agents** (Claude Code sessions, CI bots): need the conventions in the repo (`AGENTS.md`, since `CLAUDE.md` is git-ignored) and a CI that checks their PRs — nothing else.
- **Humans**: since the repo is public and MIT-licensed, anyone can fork and open a PR. This drives three follow-up questions:
  - **Contribution terms** — MIT means inbound = outbound by default; decide whether that is enough or whether a DCO sign-off (`Signed-off-by`) is required. A CLA is heavier and probably not worth it for a free tool.
  - **Apple access** — contributors build unsigned (`CODE_SIGNING_ALLOWED=NO`) or with their own team; only Vincent signs and notarizes releases. Nobody else needs the Apple account as long as releases stay on Vincent's Mac.
  - **Seats** — each human member of `smartcolibri` is a paid Team seat; for an open-source project, outside contributors work through forks and need no seat. Outside collaborators on the repo are the option for occasional maintainers.

### 2.3 Exception to the local-docs rule

The workspace rule (`~/DevApps/CLAUDE.md`, mirrored in `~/Documents/GitHub/CLAUDE.md`) keeps COMMANDS / MEMORY / CHANGES / TODOS / PLAN out of git. With collaborators, the shared part has to move to GitHub (section 3). Either an explicit exception for this project, or an edit to both mirrors. Note that `MEMORY.md` contains personal session notes and must not be published as is.

### 2.4 CI runner

GitHub-hosted runners, macOS included, are **free for public repositories**, so the choice is easy while the repo stays public:
- **GitHub-hosted macOS runner** — recommended: zero maintenance, no cost; keep the job lean (`xcodegen generate` + one `xcodebuild` + tests), cache SwiftPM (Sparkle).
- **Self-hosted runner on Vincent's Mac** — **never on a public repo**: any fork PR could run code on it.
- Prerequisite: fix the `xcodebuild test` exit code (the host app that does not terminate) so CI reports real failures and real passes.

### 2.5 Sparkle feed after the transfer

Every installed copy fetches its updates from `raw.githubusercontent.com/vincentlauriat/MacInside/...`, which works only through GitHub's transfer redirect. The redirect breaks for good if a repository named `MacInside` is ever created again under `vincentlauriat`. Ship a release whose `SUFeedURL` points to `smartcolibri/MacInside` (or to the Pages site), and never recreate the old repo name.

## 3. Mapping local files to GitHub

| Local file | GitHub equivalent |
|---|---|
| `TODOS.md` | **Issues** with area labels (`area:cpu`, `area:memory`, `area:storage`, `area:network`, `area:sensors`, `area:power`, `area:gpu`, `area:battery`, `area:processes`, `area:widgets`, `area:menubar`, `area:l10n`, `area:release`, `area:landing`), a `needs-hardware-test` label for checks that need a specific Mac (Intel vs Apple Silicon, laptop vs desktop, fanless), **milestones** per version, and a **Projects board** (To do / In progress / In review / Done). The board needs `gh auth refresh -s project` first. First issues: the remaining-battery-time bug and the Sparkle local-build downgrade trap from `TODOS.md`. |
| `PLAN.md` | One epic issue per open phase (3.9 energy per app, 3.R charge limiting, 5.5 per-interface network throughput) with sub-issues; detailed specs move to a tracked `docs/specs/`. |
| `CHANGES.md` | Tracked `CHANGELOG.md`, `vX.Y.Z` tags and **GitHub Releases** with notes generated from PR labels (`.github/release.yml`). Sparkle release notes derived from the same notes. |
| `MEMORY.md` | Split: lasting decisions → `docs/decisions/` (one record each: no sandbox / Developer ID only, dedicated Sparkle key, widget snapshot in the App Group with optional sections, process collection only while the window is open…) or `ARCHITECTURE.md`; live status → the Projects board. Personal session notes stay local. |
| `COMMANDS.md` | Stays local — personal log. |

## 4. Files to add to the repo

- **Issue forms**: bug (macOS version, Mac model and chip, app version, which card / widget / menu bar item), feature request, sensor reading wrong or missing (model, expected value, SMC key if known).
- **PR template**: what, why, screenshots for UI changes, FR/EN strings added to `Localizable.xcstrings`, tests run, "touches process actions (kill / renice)?" checkbox.
- **`CODEOWNERS`**: everything → Vincent; `Scripts/`, `project.yml`, entitlements, `appcast.xml` and `SUPublicEDKey` always reviewed by Vincent.
- **`CONTRIBUTING.md`**: Xcode version, xcodegen, unsigned build command, `Local.xcconfig`, commit and PR conventions, FR/EN localization rule, DCO if chosen (2.2).
- **`AGENTS.md`**: the project-relevant rules from the git-ignored `CLAUDE.md` (build on every change, conventional commits, never push `main`, never regenerate the Sparkle key), so collaborators' agents follow the same conventions.
- **`Local.xcconfig`** (git-ignored, with a tracked `Local.xcconfig.example`): per-person `DEVELOPMENT_TEAM` and signing overrides — today `KFLACS69T9` is hard-coded in `project.yml`.
- **`.github/dependabot.yml`**: SwiftPM (Sparkle) and GitHub Actions updates.

## 5. Automation (GitHub Actions)

1. **Build + tests on every PR** — `xcodegen generate`, `xcodebuild` Debug with `CODE_SIGNING_ALLOWED=NO` (app + widget extension), `xcodebuild test`. Pin the Xcode version explicitly and use a stable (non-beta) Xcode: the same rule as for releases. Required status check in the ruleset (2.1).
2. **Landing page** — nothing to automate in the repo: Pages already publishes `docs/` on merge. Automate the two copies instead (`lauriat.fr` upload, `vincentlauriat.github.io` card), or retire them in favour of the Pages site.
3. **Releases stay local** — signing needs the Developer ID certificate and the Sparkle EdDSA key; neither goes into CI. A workflow can still check, on a `v*` tag, that `appcast.xml` references the new version and that the build number increased (the `CURRENT_PROJECT_VERSION` guard already listed in `TODOS.md`).
4. **Secrets hygiene** — the Sparkle key and the Developer ID certificate stay on Vincent's Mac; keep the Sparkle key backup in a password manager.

## 6. Repository settings

- Auto-delete branches after merge (today: off).
- Squash merge only (today: merge commits and rebase merges are also allowed), PR title in conventional-commit format → linear `main` history.
- Ruleset on `main` as in 2.1.
- Wiki: already disabled; keep issues and projects on. Consider enabling Discussions for user questions.
- Topics: current set is fine (`macos`, `menubar`, `system-monitor`, `sensors`, `hardware-monitoring`, `sparkle`, `swift`, `swiftui`); add `widgetkit`.
- Set the repository website to the new Pages URL (today: empty).
- Organization default: turn off "members can create public repositories" if repos are to be private by default.
- Enable private vulnerability reporting and add a short `SECURITY.md` (the app is unsandboxed and can kill processes).

## 7. Proposed order

0. **Fix the transfer fallout**: release with `SUFeedURL` on `smartcolibri/MacInside` (2.5), new Pages URL in the README, the `vincentlauriat.github.io` card and `lauriat.fr`. **Switch to PRs**, even solo: feature branch → PR → squash-merge, instead of local `--no-ff` merges pushed to `main` (PR #1 is the first).
1. Make the decisions in section 2.
2. Repo settings (section 6), labels, milestones, Projects board; convert `TODOS.md` items and the open `PLAN.md` phases into issues.
3. `.github/` files (forms, PR template, `CODEOWNERS`, `dependabot.yml`), `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`, `Local.xcconfig.example`.
4. Fix the `xcodebuild test` exit code, then CI: build + tests on PRs, made a required check.
5. Release guard workflow (version / build number / appcast consistency).
6. Announce that contributions are welcome only once 2.2 is settled and the CI is green.

Once the decisions are made, the detailed implementation plan goes into `PLAN.md`.
