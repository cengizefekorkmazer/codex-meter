#!/usr/bin/env bash
#
# build_release.sh — produce distributable CodexMeter artifacts (zip + dmg).
#
# Builds a Release configuration of CodexMeter, ad-hoc signs the bundle, and
# packages it as both a .zip (bare .app) and a .dmg (drag-to-Applications).
# Output lands in dist/ (gitignored).
#
# The build is ad-hoc signed and NOT notarized — first launch needs a
# right-click → Open or `xattr -dr com.apple.quarantine`.
#
# Usage:
#   ./scripts/build_release.sh            # zip + dmg
#   SKIP_DMG=1 ./scripts/build_release.sh # zip only
#
set -euo pipefail

# Resolve repo root (this script lives in scripts/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Prefer a full Xcode over Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

DERIVED="build/DerivedData"
APP="$DERIVED/Build/Products/Release/CodexMeter.app"

echo "==> Generating Xcode project (xcodegen)"
xcodegen generate

echo "==> Building Release"
xcodebuild -project CodexMeter.xcodeproj -scheme CodexMeter \
  -configuration Release -derivedDataPath "$DERIVED" \
  build CODE_SIGNING_ALLOWED=NO

VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "==> Built CodexMeter $VER"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

mkdir -p dist

ZIP="dist/CodexMeter-$VER.zip"
echo "==> Packaging $ZIP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [[ "${SKIP_DMG:-0}" != "1" ]]; then
  DMG="dist/CodexMeter-$VER.dmg"
  echo "==> Packaging $DMG"
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  rm -f "$DMG"
  hdiutil create -volname "CodexMeter $VER" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  hdiutil verify "$DMG" >/dev/null && echo "    dmg checksum verified"
fi

echo
echo "==> Done. Artifacts:"
ls -lh dist/CodexMeter-"$VER".* 2>/dev/null
echo
echo "Next: tag (git tag -a v$VER -m \"CodexMeter $VER\"), push, then attach"
echo "the artifacts above to a GitHub Release."
