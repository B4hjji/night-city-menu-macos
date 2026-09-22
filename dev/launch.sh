#!/usr/bin/env bash
# Build and run the launcher from source. The launcher performs compatibility checks,
# installs the payload, applies required entitlements, and starts the game.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Night City Menu 2.3.3.app"

bash "$ROOT/launcher/build-app.sh"
exec "$APP/Contents/MacOS/NightCityConsole"
