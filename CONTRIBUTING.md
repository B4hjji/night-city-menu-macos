# Contributing

Thanks for helping improve Night City Menu. This branch has one deliberately narrow target: the Apple Silicon
Mac App Store build of Cyberpunk 2077 2.3.3.

## Before opening an issue

- Confirm that the launcher reports a compatible App Store 2.3.3 executable.
- Reproduce the problem after restarting the game from the menu launcher.
- Check the [command reference](docs/COMMANDS.md) and [compatibility notes](docs/APP-STORE-2.3.3.md).
- Remove unrelated mods when possible and test again.

Do not upload saves, game binaries, crash dumps containing personal paths, Apple credentials, signing
certificates, or copyrighted game files. Redact usernames and volume names from logs.

## Bug reports

Include:

- macOS version and Mac model/chip.
- Cyberpunk 2077 version and store distribution.
- Whether the game is installed internally or on an external drive.
- The exact command or quick action used.
- What you expected and what happened.
- The launcher's status text and a minimal, redacted log excerpt if relevant.

## Development setup

```bash
./tools/fetch-deps.sh
./launcher/build-app.sh
./tools/check.sh
```

Use `CP2077_DIR=/path/to/game-root ./dev/launch.sh` for a nonstandard installation. The path must contain
`Cyberpunk2077.app`.

## Pull requests

- Keep the App Store 2.3.3 profile fail-closed. New offsets need instruction-byte guards.
- Do not enable legacy Steam hooks in the App Store profile.
- Keep speed and flight changes session-only unless a proposal explicitly documents save migration and rollback.
- Update user-facing documentation for new commands, controls, dependencies, or compatibility changes.
- Run `./tools/check.sh`; use `NCC_BUILD_OVERLAY=1 ./tools/check.sh` after native overlay changes.
- Preserve upstream attribution and third-party notices.

Small, focused pull requests are easier to review and test safely.
