#!/usr/bin/env bash
# Build an ad-hoc-signed Night City Menu app for local use.
# Release signing, notarization, and packaging are handled by tools/sign-notarize.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Night City Menu 2.3.3.app"
APP="$ROOT/build/$APP_NAME"
FRIDA_GADGET="${FRIDA_GADGET:-$ROOT/deps/FridaGadget.dylib}"
MODULE_CACHE="${NCC_MODULE_CACHE:-$ROOT/build/module-cache}"

for tool in swiftc clang++ codesign file plutil; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: required tool '$tool' was not found" >&2
    exit 1
  }
done

if [[ ! -f "$FRIDA_GADGET" ]]; then
  echo "error: Frida Gadget was not found at: $FRIDA_GADGET" >&2
  echo "Run ./tools/fetch-deps.sh, or set FRIDA_GADGET=/absolute/path/FridaGadget.dylib." >&2
  exit 1
fi
if ! file "$FRIDA_GADGET" | grep -q 'arm64'; then
  echo "error: Frida Gadget does not contain an arm64 slice: $FRIDA_GADGET" >&2
  exit 1
fi

echo "==> Building overlay"
"$ROOT/overlay/build.sh"

echo "==> Assembling $APP_NAME"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$MODULE_CACHE"
cp "$ROOT/launcher/Info.plist" "$APP/Contents/Info.plist"

if [[ -n "${NCC_REPOSITORY_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :NCCRepositoryURL ${NCC_REPOSITORY_URL}" "$APP/Contents/Info.plist"
fi
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Compiling launcher"
SWIFT_MODULECACHE_PATH="$MODULE_CACHE/swift" \
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE/clang" \
swiftc -O -parse-as-library -target arm64-apple-macos12 \
  -module-cache-path "$MODULE_CACHE/swift" \
  -o "$APP/Contents/MacOS/NightCityConsole" \
  "$ROOT"/launcher/Sources/*.swift

echo "==> Bundling runtime"
cp "$ROOT/runtime/red4ext_hooks.js" \
   "$ROOT/runtime/FridaGadget.config" \
   "$ROOT/runtime/cet_catalog.tsv" \
   "$APP/Contents/Resources/"
cp "$FRIDA_GADGET" "$APP/Contents/Resources/FridaGadget.dylib"
cp "$ROOT/build/libcyberconsole_overlay.dylib" "$APP/Contents/Resources/"

echo "==> Bundling licenses and notices"
LICENSE_DIR="$APP/Contents/Resources/Licenses"
mkdir -p "$LICENSE_DIR"
cp "$ROOT/LICENSE" "$LICENSE_DIR/Night-City-Menu-LICENSE.txt"
cp "$ROOT/NOTICE.md" "$LICENSE_DIR/Night-City-Menu-NOTICE.md"
cp "$ROOT/THIRD_PARTY_LICENSES.md" "$LICENSE_DIR/THIRD-PARTY-NOTICES.md"
cp "$ROOT/overlay/imgui/LICENSE.txt" "$LICENSE_DIR/Dear-ImGui-LICENSE.txt"
cp "$ROOT/overlay/lua-5.1.5/COPYRIGHT" "$LICENSE_DIR/Lua-5.1.5-LICENSE.txt"
cp "$ROOT/third_party/Frida-NOTICE.txt" "$LICENSE_DIR/Frida-NOTICE.txt"

[[ -f "$ROOT/assets/AppIcon.icns" ]] || {
  echo "error: assets/AppIcon.icns is missing" >&2
  exit 1
}
echo "==> Bundling app icon"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc signing"
codesign --sign - --deep --force --timestamp=none "$APP" >/dev/null
codesign --verify --deep --strict "$APP"

echo "Built: $APP"
