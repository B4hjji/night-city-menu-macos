# Night City Menu for macOS

[![macOS](https://img.shields.io/badge/macOS-Apple%20Silicon-000000?logo=apple)](https://www.apple.com/macos/)
[![Cyberpunk 2077](https://img.shields.io/badge/Cyberpunk%202077-App%20Store%202.3.3-fcee0c)](https://www.cyberpunk.net/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-experimental-orange.svg)](#project-status)

A native Apple Silicon mod menu, CET-style command console, item browser, and quick-actions overlay for the **Mac App Store build of Cyberpunk 2077 2.3.3**.

Open it in-game with the **`<` key on an ISO/QWERTZ keyboard** or **F1**. Add eddies and development points, spawn items, change movement speed, use temporary flight, teleport, and run compatible console commands without leaving the game.

> [!IMPORTANT]
> This is an experimental, single-player modding tool. Back up your saves before using it. The launcher refuses to inject into an executable that does not match the verified App Store 2.3.3 executable profile.

## Project status

This repository is a focused App Store 2.3.3 port of [ysrdevs/nightcity-console-mac](https://github.com/ysrdevs/nightcity-console-mac), originally released for the native macOS Steam build. It preserves the upstream architecture and credits while isolating the App Store runtime from legacy Steam-only hooks.

| Game build | Status |
|---|---|
| Mac App Store 2.3.3, Apple Silicon | Supported by an exact executable check |
| Steam 2.3.1 | Not supported by this branch; use the upstream project |
| GOG, Windows, Intel Mac, or any other version | Not supported |

Game updates can move internal functions. Unknown executables fail closed instead of receiving stale hooks.

## Features

- Native Metal and Dear ImGui in-game overlay with Console, Items, and Quick tabs.
- Searchable catalog with thousands of Cyberpunk 2077 item IDs and persistent favorites.
- CET-style item commands such as `Game.AddToInventory("Items.Name", 1)`.
- One-click money, healing, god mode, invisibility, infinite ammo, perk points, attribute points, relic points, level 50, and street cred 50.
- Session-only movement multipliers from 0.25× to 10×, including a 5× quick action.
- Temporary camera-relative flight with a safety timer and immediate stop control.
- Time, slow-motion, police, quest-fact, and teleport utilities.
- Automatic game discovery on `/Applications`, `~/Applications`, and mounted external volumes.
- Exact 2.3.3 executable verification before installation or launch.

See the [command reference](docs/COMMANDS.md) for the complete syntax and limitations.

## Install

1. Back up the saves you care about.
2. Download the `.dmg` or `.zip` from this repository's **Releases** page.
3. Move **Night City Menu 2.3.3.app** to `/Applications` and open it.
4. If the game is not detected, click **Browse** and select `Cyberpunk2077.app` or the folder containing it.
5. Click **Install**, then always start the modded session with **Play** in the launcher.
6. Load a save. Press **`<`** or **F1** to show or hide the in-game menu.

For a game installed on an external drive, macOS may require Full Disk Access for the launcher. The app links directly to the correct Privacy & Security pane when this is needed.

### Quick examples

```text
money 100000
level 50
perks 10
attrs 10
relic 10
streetcred 50

speed 2
speed max
speed off

fly 60
fly off

give Items.Preset_Silverhand_3516 1
Game.AddToInventory("Items.MaxDOSE", 5)
```

Flight is temporary and is never written to a save. Close the menu, then use **WASD** to move, **Space** to rise, **Ctrl** to descend, **Shift** to boost, and **Esc** to stop.

## Build from source

Requirements:

- Apple Silicon Mac.
- Xcode Command Line Tools with the macOS SDK.
- A macOS arm64 `FridaGadget.dylib` obtained from the [official Frida releases](https://github.com/frida/frida/releases) or an existing local installation.

```bash
git clone https://github.com/B4hjji/night-city-menu-macos.git
cd night-city-menu-macos

# Copies Frida Gadget from a known local installation when available.
./tools/fetch-deps.sh

# Builds an ad-hoc-signed app in build/.
./launcher/build-app.sh

# Or build and run the launcher directly.
CP2077_DIR="/path/to/folder-containing-Cyberpunk2077.app" ./dev/launch.sh
```

If Frida Gadget is elsewhere:

```bash
FRIDA_GADGET_SOURCE="/absolute/path/FridaGadget.dylib" ./tools/fetch-deps.sh
```

Set the final repository URL while building to enable in-app source links and release checks:

```bash
NCC_REPOSITORY_URL="https://github.com/B4hjji/night-city-menu-macos" ./launcher/build-app.sh
```

Dear ImGui and PUC-Lua are fetched and built on the first overlay build. Generated dependencies and binaries stay ignored by Git; their licenses and the Frida notice are bundled into every app.

## Release packaging

Signed distribution requires an Apple Developer ID and a `notarytool` keychain profile:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="night-city-menu-notary" \
NCC_REPOSITORY_URL="https://github.com/B4hjji/night-city-menu-macos" \
./tools/sign-notarize.sh
```

The script signs nested code, notarizes and staples the app, then creates `.zip` and `.dmg` artifacts in `dist/`. See [the release guide](docs/RELEASING.md) before publishing.

## How it works

The launcher places a Frida script host and a native Metal/ImGui overlay beside the game, then launches the game with both arm64 dynamic libraries injected. The runtime resolves REDengine's live type information and routes typed commands through the game's script executor. The overlay and command engine communicate through a small session-only file channel in `/tmp`.

Frida requires JIT entitlements, so **Install** ad-hoc re-signs the game executable with the minimum runtime entitlements needed by this loader. On its first managed install, the launcher backs up conflicting payload files and restores them with **Uninstall Menu**. Uninstall cannot recreate the store's original game signature; reinstall the game from the App Store to restore the original distribution exactly.

The App Store port activates only the two verified 2.3.3 runtime addresses needed by the console. Historical Steam 2.3.1 experiments remain documented for upstream research but are explicitly skipped by this profile. More detail is in [the App Store port notes](docs/APP-STORE-2.3.3.md).

## Safety and limitations

- Single-player use only. Do not use this with competitive or online services.
- Back up saves before changing quest facts, progression, inventory, or character state.
- The launcher modifies the game executable's code signature and writes the menu payload to `<game>/red4ext/`.
- Flight and speed changes are session-only. Flight stops on its timer, with `fly off`, or with Esc.
- Teleport can be rejected by the game during combat. Teleport bookmarks last only for the current session.
- Quest-gated items may still require the relevant quest state.
- This branch is a command menu, not a general RED4ext/TweakXL/ArchiveXL mod loader.

## Contributing

Bug reports and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and include the game version, distribution, macOS version, Mac model, and the launcher's compatibility message with bug reports.

Please report security issues privately as described in [SECURITY.md](SECURITY.md).

## Credits

- Original NightCity Console project, macOS port, and reverse engineering: [ysrdevs (Yuvraj Singh)](https://github.com/ysrdevs).
- App Store 2.3.3 compatibility profile and menu extensions: this fork's contributors.
- [Dear ImGui](https://github.com/ocornut/imgui) by Omar Cornut.
- [Frida](https://frida.re/) by Ole André Vadla Ravnås and contributors.
- PUC-Lua by the Lua.org team.
- The wider Cyber Engine Tweaks and RED4ext communities, whose command conventions and engine research informed the project.

See [NOTICE.md](NOTICE.md) and [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for attribution and licensing details.

Cyberpunk 2077 is a trademark of CD PROJEKT S.A. This project is unofficial and is not affiliated with or endorsed by CD PROJEKT RED, CD PROJEKT S.A., Apple, Frida, Cyber Engine Tweaks, or RED4ext. It distributes no game files.

## License

MIT. See [LICENSE](LICENSE).
