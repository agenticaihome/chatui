# iOS (issue #152, phase 1)

The app builds and runs on iOS. Each release has an unsigned `.ipa`. There is no App Store,
no TestFlight and no Apple signing secret in CI: the user signs the app with their own Apple
ID when they install it.

## 1. Install

You need a computer (macOS or Windows) once, an Apple ID, and the `.ipa` of a release:
`chatui-<version>-unsigned.ipa`. Check it first:

```
shasum -a 256 chatui-<version>-unsigned.ipa     # the same line as in SHA256SUMS of the release
```

On iOS 16 or later, turn on **Settings → Privacy & Security → Developer Mode** (the phone
restarts) before you open a sideloaded app.

### AltStore (macOS or Windows)

1. Install AltServer from <https://altstore.io> on the computer, and install AltStore on the
   iPhone from AltServer (the iPhone is connected with a cable, or on the same Wi-Fi with
   Wi-Fi sync on).
2. Copy the `.ipa` to the iPhone (AirDrop, Files, iCloud Drive).
3. In AltStore: **My Apps → +**, choose the `.ipa`, and sign in with your Apple ID.
4. On a free Apple ID, refresh the app at least every **7 days**: AltStore does it by itself
   when AltServer runs on the computer and the iPhone is on the same Wi-Fi, or tap
   **Refresh All**.

### SideStore (no computer after the first setup)

SideStore is AltStore that signs on the iPhone. Follow <https://sidestore.io> to install it
(one time with a computer, to make the pairing file). Then add the `.ipa` in **My Apps → +**.
It refreshes the 7-day signature on the phone, with its VPN app on.

### Sideloadly (macOS or Windows)

1. Install Sideloadly from <https://sideloadly.io> and connect the iPhone.
2. Drop the `.ipa` on Sideloadly, enter your Apple ID, and press **Start**.
3. On the iPhone: **Settings → General → VPN & Device Management**, and trust your Apple ID.
4. Install it again before the 7 days end (Sideloadly can do it over Wi-Fi).

### The 7 days, and your data

- A free Apple ID signs an app for 7 days. A paid Apple Developer account signs it for one
  year. A free account can have 3 sideloaded apps at a time.
- When the signature ends, the app does not open until you refresh or install it again.
  Your data stays: a refresh or a new install over the app keeps it. Deleting the app
  deletes it, and the Keychain items of the app are deleted at the next first start
  (`SecureStoragePlugin.swift`), as on Android.
- Keep the recovery phrase of each wallet. Without it, a deleted app is a lost wallet.

## 2. What iOS does not allow (the warnings of the app)

iOS suspends an app a few seconds after it goes to the background. In this phase the app
uses no background mode, no push notification and no background refresh. So:

- **Conversations do not stay connected** when the app is in the background or closed. The
  instance keeps running on its node, and the messages wait there. When the app opens, it
  reconnects and reads what it missed (section 4).
- **No notification arrives** for a new message while the app is suspended.
- **Automatic top-up (Keep running) does not always work.** `AutoTopUp` runs only while the
  app runs, so on iOS it stops when the app is suspended or closed. When the balance of an
  instance runs out, the node stops the instance.

The app shows the three the first time it opens (`lib/ui/ios_limits.dart`), and the third
one where the user turns the top-up on: Settings → Compute → Keep running
(`auto_top_up_screen.dart`), the launch dialog (`run_confirm_dialog.dart`, "Until I stop
it") and the switch of an instance (`instance_time_section.dart`). The texts are in the
`.arb` files (`iosLimits*`, en and es). Nothing shows on Android.

Out of scope here (later research issues): `BGAppRefresh` checks, the `audio` mode during
calls (#143), background downloads (#151), push notifications, TestFlight, App Store.

## 3. What each Android part is on iOS

The Swift code is in `app/ios/Runner`. Each handler has the channel, the methods and the
answers of its Android version, so the Dart side does not change.

| Android | iOS |
|---|---|
| `SecureStorageHandler.kt` (Keystore, `EncryptedSharedPreferences`) | `SecureStoragePlugin.swift`: the Keychain, `AfterFirstUnlockThisDeviceOnly` (no backup, no other device). Face ID, Touch ID or the passcode opens the wallet (`LAContext`, `.deviceOwnerAuthentication`). The Celaut database is in Application Support, out of the backups |
| `FLAG_SECURE` (`setSecureFlag`) | Not possible on iOS: `setSecureFlag` answers `false`, so the app says that it cannot block screenshots. The app switcher shows a blur instead of the screen (`LifecyclePlugin.swift`) |
| `DeepLinkHandler.kt`, `OpenLinkActivity.kt` (`ergopay:`, `celaut:`) | `LinksPlugin.swift`: the URL schemes `ergopay` and `celaut` of `Info.plist`, from the scene events (cold start and while the app runs). `celaut://import?url=` gives the link to the import, as on Android. Flutter's own deep linking is off (`FlutterDeepLinkingEnabled`), as on Android |
| `IncomingPackageHandler.kt`, `OpenPackageActivity.kt` (open or share a `.celaut.bee` file) | `LinksPlugin.swift`: the document type `org.celaut.bee` (extension `bee`, MIME `application/vnd.celaut.bee`). "Open in Chatui" from Files or another app gives the file to the import. iOS copies it into the inbox of the app, and the import moves it from there (no second copy) |
| `PackageHandler.kt` (pick, copy with progress, file descriptor, metered) | `PackagePlugin.swift`: the Files picker (opened in place, no copy by the picker), the copy with its `copied` progress and `cancelCopy`, `openPackage` with a file descriptor that Rust reads, and `isMetered` from `NWPathMonitor` (cellular or Low Data Mode) |
| `MotionHandler.kt` (vehicle motion cues, GPS speed) | `MotionPlugin.swift`: CoreMotion device motion at 50 Hz in m/s² on the axes of the screen (CoreMotion gives g with the opposite sign, so ×−9.80665), and the GPS speed from Core Location while in use (precise location) |
| `CardsSensorsHandler.kt` (gyroscope, vibration, sound) | `CardsSensorsPlugin` in `MotionPlugin.swift`: the rotation rate of device motion (bias removed, like the calibrated Android gyroscope), haptics on an iPhone, and the short PCM sound on the ambient audio session (silent switch and volume of the phone) |
| `UpdateHandler.kt` (in-app update) | Off: `UpdateChannel.supported` is Android only. Updates come with a new `.ipa` |
| `ConversationService.kt` (foreground service) | Off: iOS has no such service. `ForegroundHolds` does nothing on iOS. `LifecyclePlugin.swift` takes a short background task to close the sessions (section 4) |
| The web interface of a service opens in the browser | It opens in a browser inside the app (`SFSafariViewController`): in another app, iOS would suspend Chatui and its local port |

The plugins: `flutter_zxing` (camera, QR), `record` (microphone), `share_plus`,
`file_picker`, `flutter_local_notifications` (while the app runs; the permission is asked
with the Android one) and `url_launcher` have iOS code, and the CI build links them all.
`Info.plist` has the texts of the camera, microphone, Face ID, location, photo library and
local network permissions. The `objective_c` hook problem of `docs/flutter-toolchain.md` is
not hit: `pubspec.lock` keeps `objective_c 9.5.0` and `code_assets 1.2.1`, and the iOS
build runs the hook with them.

## 4. Background: close, then reconnect fast

`app/lib/celaut/app_suspension.dart` (`AppSuspension`) does nothing on Android.

- When the app goes to the background, `LifecyclePlugin.swift` asks iOS for a short
  background task and calls `suspend` on `org.celaut.chatui/lifecycle`. Each open chat ends
  its `Connect` stream (our side first, so the service ends with `OK`) and shuts its HTTP/2
  connection, so the tunnel stream to the node closes too. The task ends when Dart answers,
  after 8 seconds at most.
- When the app is in front again, each open chat opens its tunnel again (`celautOpenTunnel`
  keeps the port if it still works, or binds a new one: iOS can take back the listening
  socket of a suspended app, and `LocalPort` then ends after 20 failed accepts, iOS only),
  makes a new connection and subscribes at once from its last message. The replay of
  `subscribe` brings what came meanwhile. `AutoTopUp` checks at once.
- A send that was in flight follows section 6.3 of `chat.md` (the `idempotency_key`).

## 5. Can the chat resume after a reconnect?

Yes. The protocol is made for it, and the client already did it after a lost stream; on
iOS the suspension is one more lost stream.

- Each message has a `sequence`. `Connect` starts with `subscribe` and an `after_sequence`:
  the service sends every message after it (the replay), then `SubscriptionReady` with
  `latest`, then the live events with no gap (`chat.md` §6.5).
- The client subscribes from its first open message minus 1, or from its `latest`, and
  replaces each open message with the one of the replay (§6.5, "The client after a lost
  stream"). An answer that the service made while the app was suspended comes whole.
  `GetMessages` with `after_sequence` does the same for a service without `Connect` (§6.2).
- A send that was cut is repaired with its `idempotency_key`: the client reads the history,
  and sends again with the same key only if the message is not there; the service keeps
  the keys for the life of the instance (§6.1 step 6, §6.3).
- Files stay on the service for the life of the instance (§6.4), and the history is kept
  while the instance runs.
- A history the client has that is ahead of the service (the instance was reset) gets
  `bad_request`, and the client reads it all again once (§6.5).

What does not resume: a streamed answer is not paused, it goes on in the service and the
client sees its state at the replay; a real-time call (`chat.md` §6.5, #143) ends; and
nothing comes back if the instance stopped (no balance), which is why the top-up warning
exists.

## 6. Tor (Arti)

`celaut-tor` (Arti 0.47, rustls, bundled SQLite, `onion-service-client`) builds for
`aarch64-apple-ios` and `aarch64-apple-ios-sim` with no change, and keeps its state in the
private folder of the app, next to the Celaut database. The CI job `ios-simulator` runs
`integration_test/ios_tor_test.dart`: Arti bootstraps inside the iOS app, then a connection
goes through its SOCKS5 proxy to a web server through an exit, and to an onion service. It
is not a gate (the Tor network can be slow from a runner).

Limits on iOS: the circuits stop when the app is suspended, and Arti builds new ones when it
comes back; a real iPhone on mobile data is not tested in CI. Memory: an iOS app in front
has far more than Arti needs (tens of MB).

## 7. Build from source

macOS with Xcode, Rust (`rustup`), and Flutter at `FLUTTER_VERSION` of `ci.yml`:

```
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cd app && flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign      # the device app; then scripts/pack_ipa.sh
flutter run -d <simulator>                     # an Apple silicon simulator
```

The "Build the Rust core" phase of the Xcode project runs `scripts/build_ios.sh`, which
builds `libwallet_ffi.a` for the SDK of the build. `app/ios/Flutter/RustCore.xcconfig` links
it with `-force_load`, and Runner keeps its global symbols (`STRIP_STYLE = non-global`):
Dart finds the functions of the bridge in the process (`ExternalLibrary.process`). The
simulator build is arm64 only (no Intel Mac simulator).

CI (`ci.yml`): the `ios` job builds the release app unsigned and packs and checks the `.ipa`
(`scripts/pack_ipa.sh`: arm64, the exports of the bridge, and `release_check.sh ipa`:
version, build number, bundle id `org.celaut.chatui`, unsigned). The `ios-simulator` job
boots a simulator and runs `integration_test/ios_smoke_test.dart` (the app starts, the home
screen and the warnings show, the Rust core loads and opens the Celaut database), the Tor
test, and a screenshot of the first start. `release.yml` builds the `.ipa` for a tag, and
the publish job checks it and adds it to the release and to `SHA256SUMS`.

## 8. Not in this phase

- An http(s) link to a `.celaut.bee` file does not open the app: iOS needs Universal Links
  and a domain for that. `celaut://import?url=` works.
- "Share" to the app from another app needs a Share Extension. "Open in" works.
- Signing in CI, TestFlight, the App Store, and the background work of section 2.
