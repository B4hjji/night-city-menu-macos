# App Store 2.3.3 compatibility profile

This branch targets the native Apple Silicon **Mac App Store release of Cyberpunk 2077 2.3.3**. It is intentionally narrower than the upstream Steam project.

## Verified executable

The profile was derived from an arm64 executable with this SHA-256 digest before local re-signing:

```text
307f437db1e350b07404c9dbc16f69860ad5304444849060cc348d5e3663259e
```

The launcher does not depend on the whole-file digest at runtime because ad-hoc signing changes signature data. Instead, it checks the game version and expected instruction bytes at both functions used by the command bridge:

| Function | Image offset |
|---|---:|
| Script executor | `0x434E444` |
| RTTI registry getter | `0x4363898` |

If either check fails, installation and launch stop before injection.

## Runtime scope

The App Store profile injects only:

- `FridaGadget.dylib`, which hosts `runtime/red4ext_hooks.js`.
- `libcyberconsole_overlay.dylib`, which draws the menu and captures input.

Legacy Steam 2.3.1 archive, Codeware, TweakXL, ArchiveXL, shutdown, and loader hooks are disabled. This profile should therefore be described as an in-game command menu, not as a general macOS mod framework.

## Controls

- Toggle the overlay: ISO/QWERTZ **`<`** key (macOS keycode 10) or **F1**.
- Switch tabs: **Cmd+1**, **Cmd+2**, and **Cmd+3**.
- Console history: **Up/Down**.
- Clipboard and editing: **Cmd+V/C/X/A**.
- Flight: close the overlay, then use **WASD**, **Space**, **Ctrl**, **Shift**, and **Esc**.

## Save and rollback behavior

Speed and flight are session-only and are not deliberately persisted to a save. Inventory, money, level, progression points, and quest-fact commands alter game state and can be saved normally.

The launcher writes its payload to `<game-root>/red4ext/` and ad-hoc re-signs the game executable with JIT-related entitlements. On the first managed install, conflicting payload files are copied to `.night-city-menu-backup`; **Uninstall Menu** removes this menu and restores those files. To restore the original App Store signature, reinstall the game from the store.

Always keep independent save backups before testing a new runtime or game update.
