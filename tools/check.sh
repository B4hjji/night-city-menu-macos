#!/usr/bin/env bash
# Fast local/CI validation. Set NCC_BUILD_OVERLAY=1 to compile the native overlay too.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Shell syntax"
for script in launcher/build-app.sh overlay/build.sh dev/launch.sh tools/*.sh; do
  bash -n "$script"
done

echo "==> Property list"
plutil -lint launcher/Info.plist

echo "==> Swift type check"
mkdir -p build/check-module-cache
SWIFT_MODULECACHE_PATH="$ROOT/build/check-module-cache/swift" \
CLANG_MODULE_CACHE_PATH="$ROOT/build/check-module-cache/clang" \
swiftc -typecheck -parse-as-library -target arm64-apple-macos12 \
  -module-cache-path "$ROOT/build/check-module-cache/swift" \
  launcher/Sources/*.swift

echo "==> Runtime JavaScript syntax"
osascript -l JavaScript -e \
  'ObjC.import("Foundation"); var e=Ref(); var s=$.NSString.stringWithContentsOfFileEncodingError("runtime/red4ext_hooks.js", $.NSUTF8StringEncoding, e); new Function(ObjC.unwrap(s));'

if [[ "${NCC_BUILD_OVERLAY:-0}" == "1" ]]; then
  echo "==> Native overlay build"
  bash ./overlay/build.sh
fi

echo "==> Repository hygiene"
machine_path_pattern='/Users/[[:alnum:]_.-]+|/Volumes/[[:alnum:]_.-]+|local\.[[:alnum:]_.-]+'
if rg -n "$machine_path_pattern" \
    --glob '!overlay/imgui/**' --glob '!overlay/lua-5.1.5/**' .; then
  echo "error: machine-specific path or identifier found" >&2
  exit 1
fi

git diff --check
echo "All checks passed."
