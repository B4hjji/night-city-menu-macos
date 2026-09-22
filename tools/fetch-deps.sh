#!/usr/bin/env bash
# Locate a user-supplied arm64 Frida Gadget and copy it into deps/.
# Third-party binaries are intentionally not committed to this repository.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="$ROOT/deps/FridaGadget.dylib"
mkdir -p "$ROOT/deps"

if [[ -f "$TARGET" ]]; then
  if file "$TARGET" | grep -q 'arm64'; then
    echo "Frida Gadget is already available: $TARGET"
    exit 0
  fi
  echo "error: existing dependency does not contain an arm64 slice: $TARGET" >&2
  exit 1
fi

candidates=()
[[ -n "${FRIDA_GADGET_SOURCE:-}" ]] && candidates+=("$FRIDA_GADGET_SOURCE")
[[ -n "${CP2077_DIR:-}" ]] && candidates+=("$CP2077_DIR/red4ext/FridaGadget.dylib")
candidates+=(
  "/Applications/Night City Menu 2.3.3.app/Contents/Resources/FridaGadget.dylib"
  "$HOME/Applications/Night City Menu 2.3.3.app/Contents/Resources/FridaGadget.dylib"
)

if [[ -d /Volumes ]]; then
  while IFS= read -r volume; do
    candidates+=("$volume/red4ext/FridaGadget.dylib")
  done < <(find /Volumes -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null)
fi

for source in "${candidates[@]}"; do
  if [[ -f "$source" ]]; then
    if ! file "$source" | grep -q 'arm64'; then
      echo "Skipping non-arm64 candidate: $source" >&2
      continue
    fi
    cp "$source" "$TARGET"
    echo "Copied Frida Gadget from: $source"
    exit 0
  fi
done

cat >&2 <<EOF
FridaGadget.dylib was not found.

Download the macOS arm64 Frida Gadget from the official Frida releases page,
decompress it, and place it at:

  $TARGET

You can also point this script at an existing copy:

  FRIDA_GADGET_SOURCE=/absolute/path/FridaGadget.dylib ./tools/fetch-deps.sh

Official releases: https://github.com/frida/frida/releases
EOF
exit 1
