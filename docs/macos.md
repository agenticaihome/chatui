# The macOS app

Issue #154. Chatui runs on **macOS 13 or later, on Apple Silicon (M1 or later)**. The
release has an unsigned `.dmg`: `chatui-<version>-macos-arm64.dmg`, with its SHA-256 in
`SHA256SUMS`. There is no Intel build, no universal binary, no Mac App Store and no
notarization.

## Install

1. Download `chatui-<version>-macos-arm64.dmg` from the release. You can check it in the
   Terminal: `shasum -a 256 ~/Downloads/chatui-*-macos-arm64.dmg`, and compare the value
   with the line of `SHA256SUMS`.
2. Open the `.dmg` and drag **Chatui** to **Applications**.
3. Open Chatui from Applications. The app has no Apple signature, so macOS blocks it the
   first time with a message as *"Chatui" Not Opened* or *Apple could not verify "Chatui"*.
   Press **Done** (not *Move to Trash*).
4. Allow the app, in one of two ways:
   - Open **System Settings → Privacy & Security**. Near the end, under *Security*, the
     page says that Chatui was blocked. Press **Open Anyway**, then enter your password.
     Open Chatui again and press **Open Anyway** in the dialog.
   - Or, in the Terminal:

     ```sh
     xattr -dr com.apple.quarantine /Applications/Chatui.app
     ```

   Since macOS 15 (Sequoia), a right-click on the app and **Open** no longer allows it: use
   one of the two ways above.
5. The first time that the app reads its keys, macOS can ask for the password of your
   login keychain for *Chatui*. Press **Always Allow**.

The same steps apply to each new version: the app does not update itself on macOS. Download
the new `.dmg` and replace the app in Applications. The wallets, the Celaut data and the
settings stay (they are in your keychain and in
`~/Library/Application Support/org.celaut.chatui`).

### The keychain after an update

Each build has its own ad-hoc signature, so macOS does not know a new version as the same
app. After an update it asks once more for the password of the login keychain for the item
*Chatui wallet keys*: press **Always Allow**. The app keeps all its keys in this one item,
so it asks once, not once per wallet.

## What works differently on a Mac

- **The app runs while it is open.** macOS does not stop an app in the background, so a
  conversation, a launch and **automatic top-up** go on while Chatui is open, also when its
  window is hidden or behind other windows. While a conversation is open, a service starts
  or a file goes to a node, or an instance has automatic top-up on, the app turns App Nap
  off (`ProcessInfo.beginActivity`) so that its timers keep their pace.
- **Quitting the app (⌘Q, or closing its window) stops everything**, also automatic top-up.
  When the balance of an instance runs out, the node stops the instance. The same happens
  when the Mac sleeps: a launch or a transfer keeps an idle Mac awake, a conversation and
  automatic top-up do not. The app says this where you turn automatic top-up on.
- **QR codes:** the camera plugin of Flutter has no macOS version, so the scan screen asks
  for an image of the code instead (a screenshot: ⇧⌘4). zxing reads it as it reads the
  camera.
- **Block screenshots** (Settings → Security) leaves the window out of screenshots, screen
  recordings and screen sharing (`NSWindow.sharingType`), as `FLAG_SECURE` on Android.
- **Unlock:** Touch ID, or the password of the Mac, opens a wallet (as the fingerprint or
  the screen lock of a phone).
- **Links and files:** `celaut:` and `ergopay:` links open the app. A `.celaut.bee` file
  opens in the app from the Finder (double-click, *Open With*, or a drop on the Dock icon).
- **Not on a Mac:** in-app updates, the foreground service of Android, the motion cues and
  the gyroscope of the cards (no sensors).

## Build

On a Mac with Apple Silicon, Xcode, CocoaPods and rustup:

```sh
cd app
flutter build macos --release
```

The first build phase of the Xcode project ("Build the Rust core") runs
`scripts/build_macos.sh`, which builds `rust/target/aarch64-apple-darwin/release/libwallet_ffi.a`.
`app/macos/Runner/Configs/RustCore.xcconfig` links it into the app with `-force_load`, and
Dart finds the functions of the bridge in the process (`lib/services/rust_library.dart`).
The app is `app/build/macos/Build/Products/Release/Chatui.app`.

CI does the same on a GitHub Apple Silicon runner (`macos-15`):

- `ci.yml`, job `macos`: a debug build runs `integration_test/macos_smoke_test.dart` in the
  app (the Rust core, the keychain, links and files, the package channel, App Nap, zxing,
  the plugins, Tor).
- `release.yml`, job `macos`: the release build, the checks (version and build number,
  `arm64` only, macOS 13, the bridge in the executable, no sandbox, the ad-hoc signature),
  the `.dmg` made with `hdiutil`, then the app from the `.dmg` is installed, refused by
  Gatekeeper while it has the quarantine flag, allowed with `xattr` and started (the
  screenshots and logs are the artifact `macos-smoke-release`). The publish job adds the
  `.dmg` to the release with the APKs.

### Why these choices

- **No App Sandbox.** Without an Apple team the app cannot have the entitlements that a
  sandboxed app needs for the keychain groups, and the sandbox would limit the files that the
  user opens and the Tor client. `Release.entitlements` sets it off; the camera and
  microphone entitlements and the texts of `Info.plist` stay, and macOS asks the user the
  first time.
- **A static library.** The core is linked into the executable, so the bundle has no
  `.dylib` to sign, to find (`@rpath`) or to load at the right time. The release job checks
  that the symbols of the bridge are exported by the executable.
- **The login keychain, one item.** The data protection keychain needs an Apple team. See
  "The keychain after an update".
