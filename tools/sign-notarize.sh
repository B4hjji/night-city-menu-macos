#!/usr/bin/env bash
# Build, Developer ID sign, notarize, and package the launcher.
#
# One-time credential setup:
#   xcrun notarytool store-credentials night-city-menu-notary \
#     --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#
# Release build:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="night-city-menu-notary" \
#   NCC_REPOSITORY_URL="https://github.com/B4hjji/night-city-menu-macos" \
#   bash ./tools/sign-notarize.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Night City Menu 2.3.3.app"
DMG="$ROOT/dist/Night-City-Menu-2.3.3-macOS.dmg"
ZIP="$ROOT/dist/Night-City-Menu-2.3.3-macOS.zip"
SUBMISSION_ZIP="$ROOT/dist/.notarization-upload.zip"
STAGE="$ROOT/build/dmg-stage"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity.}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile.}"
: "${NCC_REPOSITORY_URL:?Set NCC_REPOSITORY_URL to the public GitHub URL for this fork.}"

cleanup() {
  rm -f "$SUBMISSION_ZIP"
  rm -rf "$STAGE"
}
trap cleanup EXIT

echo "==> Building app"
bash "$ROOT/launcher/build-app.sh"

echo "==> Signing nested Mach-O files"
while IFS= read -r file; do
  if file "$file" | grep -q "Mach-O"; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$file"
  fi
done < <(find "$APP/Contents" -type f -print)

codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$ROOT/dist"
rm -f "$SUBMISSION_ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$SUBMISSION_ZIP"

echo "==> Notarizing app"
xcrun notarytool submit "$SUBMISSION_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose=2 "$APP"

echo "==> Creating release archives"
rm -f "$ZIP" "$DMG"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Night City Menu 2.3.3" -srcfolder "$STAGE" -format UDZO -ov "$DMG" >/dev/null

echo "==> Notarizing disk image"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "Release artifacts:"
echo "  $DMG"
echo "  $ZIP"
