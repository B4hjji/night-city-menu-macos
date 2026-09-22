# Release guide

## Repository metadata

Recommended GitHub description:

> Native Apple Silicon mod menu and CET-style console for Cyberpunk 2077 2.3.3 from the Mac App Store.

Recommended topics:

```text
cyberpunk-2077 cyberpunk2077 macos apple-silicon mod-menu game-modding
frida dear-imgui swift swiftui qwertz
```

Enable **Issues**, **Discussions** if desired, and **Private vulnerability reporting**. Do not enable GitHub
Pages unless the repository gains a maintained website.

## Pre-release checklist

1. Update `CFBundleShortVersionString`, `CFBundleVersion`, `Const.appVersion`, and `release-notes.md` together.
2. Confirm the supported game version and both guarded instruction sequences on a clean App Store executable.
3. Run the validation suite:

   ```bash
   NCC_BUILD_OVERLAY=1 ./tools/check.sh
   ```

4. Test Install, Play, the `<` and F1 toggles, one item command, `speed 2`, `speed off`, `fly 60`, and Esc.
5. Confirm that Uninstall removes only managed files and restores any first-install payload backups.
6. Search tracked files for usernames, local volume names, secrets, credentials, and copyrighted game data.
7. Build signed artifacts:

   ```bash
   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
   NOTARY_PROFILE="night-city-menu-notary" \
   NCC_REPOSITORY_URL="https://github.com/B4hjji/night-city-menu-macos" \
   ./tools/sign-notarize.sh
   ```

8. Test the stapled `.dmg` on a separate macOS user account or clean Mac when possible.

## Publishing

- Tag releases as `v2.3.3.<revision>` while the game target remains 2.3.3.
- Use `release-notes.md` as the release body, adjusting only verified facts.
- Attach both the notarized `.dmg` and `.zip`.
- Mark the release as a prerelease until it has been tested on more than one compatible Mac.
- Never attach Frida separately, game binaries, save files, signing material, or local debug logs.
