# Signing + notarizing a macOS app (portable recipe)

Extracted from `tools/sign-notarize.sh`, which ships Night City Menu. Everything here is app-agnostic
except where marked. Written to be handed to another assistant working on a different app.

**No secrets appear in this document or in the script.** Credentials live in the macOS keychain under a
*notary profile name*; the scripts only ever reference that name.

---

## 0. What you need once, ever

A **Developer ID Application** certificate in the login keychain, and a notarytool keychain profile:

```bash
xcrun notarytool store-credentials <PROFILE-NAME> \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"     # appleid.apple.com -> Sign-In and Security -> App-Specific Passwords
```

Two things worth knowing:

- **The profile is per Apple ID / team, NOT per app.** An existing profile is reusable for every app you
  ever sign under that team. On this machine the profile `cyberconsole-notary` already exists and works
  (`xcrun notarytool history --keychain-profile cyberconsole-notary` returns successfully). A different app
  does **not** need a new profile.
- Your signing identity string is the certificate's full common name:

```bash
security find-identity -v -p codesigning     # copy the "Developer ID Application: NAME (TEAMID)" line
```

---

## 1. The order that actually matters

Signing is **inside-out**. Sign every nested Mach-O binary first, then the `.app` bundle last. Signing the
bundle first and the contents after invalidates the outer signature.

```bash
APP="build/Your App.app"
SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)"

# every nested Mach-O, not just *.dylib - bundles often ship helper EXECUTABLES too
find "$APP/Contents/Resources" -type f | while IFS= read -r f; do
  if file "$f" | grep -q "Mach-O"; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$f"
  fi
done

codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
```

`--options runtime` (hardened runtime) and `--timestamp` (secure timestamp) are **both required** for
notarization. Omit either and the upload is rejected with a vague error.

Do **not** use `codesign --deep` for real signing. It is unreliable for nested code and Apple has
deprecated it for this purpose. It is fine for throwaway ad-hoc signing (`-s -`) during development.

---

## 2. Entitlements: only where needed, and only on executables

Entitlements attach to the **executable**, not to dylibs. Add them only to the specific binary that needs
them, not blanket-wide.

The one case in this project: the bundled `nctool` is a self-contained .NET app that JITs. Under hardened
runtime CoreCLR gets SIGKILLed the moment it writes executable memory unless it carries:

```xml
<key>com.apple.security.cs.allow-jit</key><true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
<key>com.apple.security.cs.disable-library-validation</key><true/>
```

```bash
codesign --force --options runtime --timestamp \
  --entitlements /path/to/ents.plist --sign "$SIGN_IDENTITY" "$APP/Contents/Resources/nctool/nctool"
```

Rules of thumb for other apps:
- **JIT runtimes** (.NET, Java, JS engines, Mono, Wine): the three keys above.
- **Loading unsigned/third-party plugins at runtime**: `disable-library-validation`.
- **Injecting into other processes / DYLD_INSERT_LIBRARIES**: `disable-library-validation`, and expect
  extra scrutiny. Apple will notarize it, but users may still see prompts depending on what you do.
- Anything you do **not** need: leave it out. Every entitlement widens your attack surface and some make
  notarization slower to approve.

---

## 3. Notarize, then staple

```bash
ditto -c -k --keepParent "$APP" /tmp/_notarize.zip     # ditto, NOT `zip` - `zip` mangles symlinks/xattrs
xcrun notarytool submit /tmp/_notarize.zip --keychain-profile "<PROFILE-NAME>" --wait
xcrun stapler staple "$APP"
```

- `--wait` blocks until Apple returns a verdict (usually under a few minutes).
- **Stapling is what makes it work offline.** Without it, Gatekeeper has to phone Apple; a user on a bad
  network or an offline machine gets a warning even though the app is notarized.
- On rejection, get the actual reason:

```bash
xcrun notarytool log <submission-id> --keychain-profile "<PROFILE-NAME>"
```

---

## 4. Package the STAPLED app

Order matters again: staple first, then package. Otherwise you ship an unstapled copy.

```bash
ditto -c -k --keepParent "$APP" dist/YourApp.zip      # zip contains the stapled app
```

For a `.dmg`, the disk image must be notarized and stapled **separately** — a stapled app inside an
un-notarized dmg still warns on download:

```bash
STAGE=build/dmg; rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"             # the drag-here shortcut
hdiutil create -volname "Your App" -srcfolder "$STAGE" -format UDZO -ov dist/YourApp.dmg
xcrun notarytool submit dist/YourApp.dmg --keychain-profile "<PROFILE-NAME>" --wait
xcrun stapler staple dist/YourApp.dmg
```

Note: create the dmg **directly from a staging folder**. The classic attach → Finder-style → convert dance
is flaky on recent macOS (deprecated `hdiutil` paths) and can leave numbered stale mounts under `/Volumes`
that make later runs fail with "Resource temporarily unavailable". If you inherit that problem:

```bash
for v in /Volumes/"Your App"*; do hdiutil detach "$v" -force 2>/dev/null; done
```

The tradeoff is you lose the custom icon layout; the `/Applications` symlink still conveys "drag here".

---

## 5. Verifying like a user would

```bash
codesign --verify --deep --strict --verbose=2 "$APP"   # signature valid
xcrun stapler validate "$APP"                          # ticket stapled
spctl -a -vvv -t install "$APP"                        # Gatekeeper verdict: expect "accepted / Notarized Developer ID"
```

The honest end-to-end test is to download the artifact through a browser (so it carries the
`com.apple.quarantine` attribute) and open it on a machine that has never seen it. Copying locally does not
reproduce Gatekeeper behavior.

---

## 6. Failure modes worth knowing up front

| Symptom | Cause |
|---|---|
| Notarization rejected, unhelpful message | Missing `--options runtime` or `--timestamp` on some nested binary. Run `notarytool log <id>` for the real list. |
| App launches for you, "damaged" for users | Not stapled, or you packaged before stapling. |
| .NET / JIT helper dies instantly under hardened runtime | Missing JIT entitlements on that executable (section 2). |
| Signature valid on the bundle but nested code unsigned | Signed outside-in. Redo inside-out. |
| `hdiutil` "Resource temporarily unavailable" | Stale `/Volumes` mounts from an earlier interrupted run. |
| Works locally, warns after download | Quarantine attribute — that is the point of notarizing + stapling. Test with a real download. |

---

## 7. Reference implementation

`tools/sign-notarize.sh` in this repo does all of the above for Night City Menu. Invocation:

```bash
SIGN_IDENTITY="Developer ID Application: NAME (TEAMID)" \
NOTARY_PROFILE="cyberconsole-notary" \
./tools/sign-notarize.sh
```

To adapt it to another app: change `APP`, `DMG`, `ZIP`, and the volume name; drop the `nctool` entitlements
block unless that app also ships a JIT runtime. The signing loop, notarize/staple, and packaging steps are
app-agnostic as written.
