## Summary

Describe the user-visible change and why it belongs in the App Store 2.3.3 profile.

## Verification

- [ ] `./tools/check.sh` passes.
- [ ] `NCC_BUILD_OVERLAY=1 ./tools/check.sh` passes if native overlay code changed.
- [ ] Unknown game executables still fail closed.
- [ ] User-facing commands or controls are documented.
- [ ] No personal paths, credentials, game files, or save data are included.

## Save and rollback impact

Explain whether the change is session-only, saved by the game, or writes files to the game installation.
