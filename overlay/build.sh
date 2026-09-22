#!/usr/bin/env bash
# Build the NightCity Console in-game overlay dylib (arm64). Clones Dear ImGui on first run.
# Output: build/libcyberconsole_overlay.dylib (ad-hoc signed for dev; release signing is in tools/).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
OUT="$ROOT/build/libcyberconsole_overlay.dylib"
IMGUI="imgui"
IMGUI_TAG="v1.92.9"   # pinned

mkdir -p "$ROOT/build"
if [ ! -d "$IMGUI" ]; then
  echo "Cloning Dear ImGui ($IMGUI_TAG)..."
  git clone --depth 1 --branch "$IMGUI_TAG" https://github.com/ocornut/imgui.git "$IMGUI" 2>/dev/null \
    || { echo "tag $IMGUI_TAG not found; cloning default branch"; git clone --depth 1 https://github.com/ocornut/imgui.git "$IMGUI"; }
fi

# Build PUC-Lua 5.1.5 (arm64, interpreter-only, no JIT, W^X-safe) on first run.
# This is the runtime that hosts CET-style Lua mods. Provides lua-5.1.5/src/{lua.h,...} + liblua5.1.a.
LUA_DIR="lua-5.1.5"
LUA_LIB="$LUA_DIR/src/liblua5.1.a"
if [ ! -f "$LUA_LIB" ]; then
  echo "Building PUC-Lua 5.1.5 (arm64, interpreter-only)..."
  if [ ! -d "$LUA_DIR" ]; then
    LUA_ARCHIVE="$(mktemp -t night-city-menu-lua).tar.gz"
    trap 'rm -f "$LUA_ARCHIVE"' EXIT
    curl --fail --location --silent --show-error https://www.lua.org/ftp/lua-5.1.5.tar.gz -o "$LUA_ARCHIVE"
    tar xzf "$LUA_ARCHIVE" -C .
    rm -f "$LUA_ARCHIVE"
    trap - EXIT
  fi
  LSDK="$(xcrun --sdk macosx --show-sdk-path)"
  ( cd "$LUA_DIR/src"
    for f in *.c; do
      case "$f" in lua.c|luac.c|print.c) continue;; esac   # skip the lua/luac executable mains
      clang -arch arm64 -O2 -DLUA_USE_POSIX -DLUA_DL_DLOPEN -isysroot "$LSDK" -c "$f"
    done
    ar rcs liblua5.1.a *.o )
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
SRC="overlay.mm \
  $IMGUI/imgui.cpp $IMGUI/imgui_draw.cpp $IMGUI/imgui_tables.cpp $IMGUI/imgui_widgets.cpp \
  $IMGUI/backends/imgui_impl_metal.mm"

clang++ -ObjC++ -fobjc-arc -std=c++17 -O2 -arch arm64 -dynamiclib \
  -I "$IMGUI" -I "$IMGUI/backends" -I "$LUA_DIR/src" \
  -isysroot "$SDK" \
  -framework Foundation -framework Metal -framework QuartzCore -framework AppKit \
  -o "$OUT" $SRC "$LUA_LIB"

codesign -s - --force --timestamp=none "$OUT"

# Ship the declarative tabs next to the dylib so the overlay's loadTabsFromDir()
# (which reads overlayDir()/tabs) finds them in a dev build.
if compgen -G "tabs/*.json" >/dev/null; then
  rm -rf "$ROOT/build/tabs"
  cp -R "tabs" "$ROOT/build/tabs"
  echo "copied tabs/ -> $ROOT/build/tabs ($(ls tabs | wc -l | tr -d ' ') files)"
fi

# Ship the Lua mods next to the dylib so the overlay's loadLuaMods() (overlayDir()/mods) finds them.
if [ -d "mods" ]; then
  rm -rf "$ROOT/build/mods"
  cp -R "mods" "$ROOT/build/mods"
  echo "copied mods/ -> $ROOT/build/mods ($(ls mods | wc -l | tr -d ' ') mod dir(s))"
fi

echo "built $OUT"
