#!/usr/bin/env bash
# Build → sign (Developer ID + Hardened Runtime) → DMG → notarize → staple →
# Sparkle-sign → refresh appcast.xml.
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ SPARKLE SIGNING KEY — DO NOT REGENERATE                                    │
# │                                                                            │
# │ Updates are EdDSA-signed with the private key in the login keychain under  │
# │ account "MacInside" (used by sign_update below) — a key DEDICATED to this  │
# │ app, not shared with any other Vincent app. Its public half is embedded    │
# │ as SUPublicEDKey in project.yml:                                           │
# │     tFXsHOjAq+eXyeVuav0ojm3XQ8SgLVV1HrXvKLJ2U4I=                           │
# │                                                                            │
# │ NEVER run `generate_keys` again for this account, and NEVER change         │
# │ SUPublicEDKey once users have installed a version — it permanently breaks  │
# │ auto-update for everyone already on an older build (happened once on      │
# │ MarkdownViewer). Back this key up somewhere safe:                          │
# │     ./.sparkle-tools/bin/generate_keys -x backup.txt --account MacInside   │
# │ (write backup.txt to a password manager, then delete the local file).      │
# └──────────────────────────────────────────────────────────────────────────┘
#
# Usage:   ./Scripts/release.sh <version>
# Example: ./Scripts/release.sh 1.0.0
#
# Reuses Vincent's shared Apple credentials (same account for all Mac apps):
#   - Developer ID Application: Vincent LAURIAT (KFLACS69T9)
#   - notary keychain profile "AppliMacVincentGithub" (apple-id vincent@lauriat.fr)
# If you ever need to recreate the profile:
#   xcrun notarytool store-credentials "AppliMacVincentGithub" \
#     --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
#
# Overridable via env: APP_NAME, SCHEME, PROJECT, SIGNING_IDENTITY, NOTARY_PROFILE
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: $0 <version>   (e.g. $0 1.0.0)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# xcodebuild exige un vrai Xcode ; sur ce Mac, xcode-select peut pointer sur
# les seuls Command Line Tools (et Xcode s'appeler Xcode-beta.app). Résoudre
# un Xcode complet si DEVELOPER_DIR n'est pas déjà fourni.
if [ -z "${DEVELOPER_DIR:-}" ] && ! xcode-select -p 2>/dev/null | grep -q '\.app/Contents/Developer'; then
  for xc in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$xc/Contents/Developer" ]; then
      export DEVELOPER_DIR="$xc/Contents/Developer"
      echo "▶︎ DEVELOPER_DIR=$DEVELOPER_DIR (xcode-select pointe sur les CLT)"
      break
    fi
  done
fi

# ── Project identity (bootstrap.sh rewrites these when you clone the template) ──
APP_NAME="${APP_NAME:-MacInside}"      # PRODUCT_NAME / .app bundle name
SCHEME="${SCHEME:-MacInside}"           # macOS scheme (see project.yml)
PROJECT="${PROJECT:-MacInside.xcodeproj}"

DMG_SLUG="$(echo "$APP_NAME" | tr -d ' ')"
DMG_VOLNAME="$APP_NAME $VERSION"
RELEASE_DIR="$ROOT/release"
mkdir -p "$RELEASE_DIR"
DMG="$RELEASE_DIR/$DMG_SLUG-$VERSION.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Vincent LAURIAT (KFLACS69T9)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

echo "▶︎ Releasing $APP_NAME $VERSION (build $BUILD_NUMBER)"

# 1. Regenerate the Xcode project from project.yml
echo "▶︎ xcodegen generate"
xcodegen generate >/dev/null

# 2. Build Release. CODE_SIGNING_ALLOWED=NO avoids the macOS Sequoia
#    com.apple.provenance xattr that breaks CLI codesign; we sign manually below.
echo "▶︎ xcodebuild Release"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -derivedDataPath build \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null
APP="$ROOT/build/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "✗ App not found: $APP" >&2; exit 1; }

# 3. Stage to a clean dir, stripping extended attributes
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
STAGING="$STAGING_DIR/$APP_NAME.app"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

# 4. Codesign the app with Hardened Runtime + secure timestamp (retry: Apple TS is flaky)
# $2 (optionnel) : fichier d'entitlements. Indispensable depuis l'ajout des
# widgets — l'App Group partagé app ↔ extension ne vit que dans les entitlements,
# et ce script re-signe à la main (le build tourne en CODE_SIGNING_ALLOWED=NO,
# donc ce que xcodebuild aurait appliqué est écrasé ici).
codesign_ts() {
  local target="$1" entitlements="${2:-}" i
  local args=(--force --options runtime --timestamp --sign "$SIGNING_IDENTITY")
  [ -n "$entitlements" ] && args+=(--entitlements "$entitlements")
  for i in 1 2 3 4 5; do
    if codesign "${args[@]}" "$target"; then
      return 0
    fi
    echo "  …codesign retry $i/5 (timestamp server) in 5s" >&2
    sleep 5
  done
  echo "✗ codesign failed for $target" >&2
  return 1
}
SPARKLE_FW="$STAGING/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
  echo "▶︎ codesign Sparkle.framework nested binaries (deepest first)"
  SPARKLE_VER="$SPARKLE_FW/Versions/B"
  codesign_ts "$SPARKLE_VER/Autoupdate"
  codesign_ts "$SPARKLE_VER/XPCServices/Downloader.xpc"
  codesign_ts "$SPARKLE_VER/XPCServices/Installer.xpc"
  codesign_ts "$SPARKLE_VER/Updater.app"
  codesign_ts "$SPARKLE_FW"
fi

# Les extensions (.appex) se signent AVANT l'app qui les contient : signer l'app
# d'abord scellerait un contenu qui change encore ensuite, et la notarisation
# rejetterait le paquet. Chaque .appex a ses propres entitlements (sandbox +
# App Group), distincts de ceux de l'app (non sandboxée).
if [ -d "$STAGING/Contents/PlugIns" ]; then
  for appex in "$STAGING/Contents/PlugIns/"*.appex; do
    [ -e "$appex" ] || continue
    name="$(basename "$appex" .appex)"
    echo "▶︎ codesign $name.appex"
    codesign_ts "$appex" "$ROOT/$name/$name.entitlements"
  done
fi

echo "▶︎ codesign (Developer ID, Hardened Runtime)"
codesign_ts "$STAGING" "$ROOT/$APP_NAME/$APP_NAME.entitlements"
codesign --verify --strict --deep --verbose=1 "$STAGING"

# 5. Build the DMG with a custom Finder layout
echo "▶︎ build DMG"
DMG_LAYOUT="$STAGING_DIR/dmg-layout"
mkdir -p "$DMG_LAYOUT/.background"
ditto --norsrc --noextattr --noacl "$STAGING" "$DMG_LAYOUT/$APP_NAME.app"
ln -s /Applications "$DMG_LAYOUT/Applications"
"$ROOT/Scripts/make-dmg-background.swift" "$DMG_LAYOUT/.background/background.png" >/dev/null

RW_DMG="$STAGING_DIR/temp.dmg"
hdiutil create -volname "$DMG_VOLNAME" -srcfolder "$DMG_LAYOUT" \
  -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null

MOUNT="$(hdiutil attach -nobrowse -noverify -noautoopen "$RW_DMG" | awk -F '\t' 'END {print $NF}')"
osascript <<APPLESCRIPT >/dev/null || true
tell application "Finder"
    tell disk "$DMG_VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 100, 740, 480}
        set view_options to the icon view options of container window
        set arrangement of view_options to not arranged
        set icon size of view_options to 128
        set background picture of view_options to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {140, 200}
        set position of item "Applications" of container window to {400, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG" >/dev/null

# 6. Notarize + staple
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  cat >&2 <<EOF
✗ Notary profile "$NOTARY_PROFILE" not found.
  Create it once (interactive):
    xcrun notarytool store-credentials "$NOTARY_PROFILE" \\
      --apple-id "vincent@lauriat.fr" --team-id "KFLACS69T9"
  The DMG was built and signed at: $DMG (NOT yet notarized).
EOF
  exit 1
fi
echo "▶︎ notarize (this takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
echo "▶︎ staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 7. Sign the DMG with the Sparkle EdDSA key and refresh appcast.xml so the
#    in-app updater (Sparkle 2) can serve this version.
SPARKLE_VERSION="2.9.1"
SPARKLE_TOOLS="$ROOT/.sparkle-tools"
if [ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]; then
  echo "▶︎ fetching Sparkle $SPARKLE_VERSION tools (one-time setup)"
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS"
fi

echo "▶︎ sign DMG with Sparkle EdDSA key (account: $APP_NAME)"
# `sign_update` prints: sparkle:edSignature="..." length="<bytes>"
# (so we don't add `length=` ourselves on <enclosure> — that would duplicate).
SPARKLE_SIG_LINE="$("$SPARKLE_TOOLS/bin/sign_update" --account "$APP_NAME" "$DMG")"

# Sparkle compares <sparkle:version> against the running app's CFBundleVersion
# (a monotonically increasing build number), NOT the marketing version — read
# the actual value baked into the built .app rather than assuming BUILD_NUMBER.
APP_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$STAGING/Contents/Info.plist")"

echo "▶︎ writing appcast.xml (sparkle:version=$APP_BUILD_NUMBER, shortVersionString=$VERSION)"
PUB_DATE="$(date -R)"
cat > "$ROOT/appcast.xml" <<APPCAST
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>$APP_NAME</title>
    <link>https://raw.githubusercontent.com/vincentlauriat/$APP_NAME/main/appcast.xml</link>
    <description>$APP_NAME release feed</description>
    <language>en</language>
    <item>
      <title>v$VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$APP_BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/vincentlauriat/$APP_NAME/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure
        url="https://github.com/vincentlauriat/$APP_NAME/releases/download/v$VERSION/$DMG_SLUG-$VERSION.dmg"
        type="application/octet-stream"
        $SPARKLE_SIG_LINE />
    </item>
  </channel>
</rss>
APPCAST

SIZE="$(du -h "$DMG" | cut -f1 | tr -d ' ')"
echo
echo "✅ Built, signed, notarized, stapled & Sparkle-signed: $(basename "$DMG") ($SIZE)"
echo "✅ appcast.xml written for v$VERSION"
echo
echo "Publish on GitHub:"
echo "  gh release create v$VERSION \"$DMG\" --title \"v$VERSION\" --generate-notes"
echo "  git add appcast.xml && git commit -m 'docs: appcast for v$VERSION' && git push"
echo
echo "After both, Sparkle clients on older versions will be offered the update on next check."
