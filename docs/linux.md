# The Linux app (issue #153)

The app runs on Ubuntu 24.04 LTS or later, on `amd64` and `arm64`. Each release has one
`.deb` per architecture. There is no other format (no AppImage, Flatpak or Snap), no APT
repository and no signature of the `.deb`: check it with `SHA256SUMS` of the release.

## Install, update, remove

```sh
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install ./superapp-<version>-linux-<arch>.deb   # also to update
sudo apt remove superapp                                 # the data of the user stays
```

The app does not download or install an update on Linux. It has the same opt-in check as
on Android (Settings › About › Check for updates: GitHub's latest release, once a day, or
"Check now"). When a newer release is out, Settings shows the notice, and About shows the
release with a link to its `.deb` for the architecture of the machine
(`superapp-<version>-linux-<arch>.deb`) and the `apt install` command. The browser downloads the
file; check it with `SHA256SUMS` and install it as above. A release with no `.deb` for the
machine gets the link to the releases page instead.

## What the package installs

| Path | What |
|---|---|
| `/usr/lib/superapp/` | the bundle of `flutter build linux --release` (`superapp`, `lib/`, `data/`) |
| `/usr/lib/superapp/lib/libwallet_ffi.so` | the Rust core, built by `scripts/build_linux.sh` |
| `/usr/bin/superapp` | a link to `/usr/lib/superapp/superapp` |
| `/usr/share/applications/org.celaut.superapp.desktop` | `Exec=superapp %U`; `x-scheme-handler/celaut`, `x-scheme-handler/ergopay`, `application/x-celaut-bee` |
| `/usr/share/mime/packages/org.celaut.superapp.xml` | `application/x-celaut-bee` = `*.celaut.bee` |
| `/usr/share/icons/hicolor/*/apps/org.celaut.superapp.png` | the icon, 64 to 512 px |

dpkg triggers update the caches of the `.desktop` files, of the MIME types and of the
icons: the package has no maintainer script.

The data of the user is in `~/.local/share/org.celaut.superapp/` (`celaut/celaut.db`, the
services in `celaut/packages/`, `shared_preferences.json`). The secrets (the sealed seeds,
their wrap keys and the key of `celaut.db`) are items of the Secret Service, with the
schema `org.celaut.superapp.Secret` and the label `Celaut: <key>`.

## Dependencies

`Depends` has the libraries that `dpkg-shlibdeps` finds in the bundle (GTK 3, GLib,
libsecret, libstdc++, and the libraries of the Flutter engine), and two programs that the
app runs:

- `pulseaudio-utils`: `parecord`, the microphone of the `record` plugin. It works with
  PulseAudio and with PipeWire (Ubuntu's default, through `pipewire-pulse`).
- `xdg-desktop-portal`: the file chooser of `file_picker` (attachments, and a QR code in an
  image).

`Recommends`: `gnome-keyring` (a Secret Service; KWallet is one too) and a portal backend.

The list is the same on `amd64` and `arm64`: Ubuntu gives the same package names on both.

## How the Android parts work on Linux

The runner (`app/linux/runner`) has the same method channels as the Kotlin side, with the
same names, methods and answers, so the Dart side is the same:

| Android | Linux |
|---|---|
| `com.argus.wallet/secure_storage` (Keystore) | `secure_storage.cc`: libsecret. No fingerprint or screen lock to ask: the wallet opens as on a phone that has neither; the keyring is unlocked by the session. `setSecureFlag` answers false: X11 and Wayland cannot block a screenshot, so Settings › Security has no "Block screenshots" on Linux, and a screen with a secret says that it cannot block one. Settings › Security names the login keyring as the way the wallet unlocks. |
| `argus/deeplink` (`celaut:`, `ergopay:`) | `links.cc`: the arguments of `superapp`. The app is unique (GApplication): a link that the desktop opens while it runs goes to it and brings its window to the front. |
| `org.celaut.superapp/incoming` (`.celaut.bee` opened in a file manager) | `links.cc`: a path or a `file://` uri on the command line; an http(s) link to a service too |
| `org.celaut.superapp/package` (picker, copy, fd, metered) | `package_channel.cc`: the GTK file chooser, a copy with its progress, a file descriptor, `GNetworkMonitor` |
| Cards sensors and sounds, motion cues | off: no gyroscope (the settings show only what the device has; Settings › Display has no motion cues, as on macOS) |
| Automatic top-up ("Keep running") | runs while the app is open and the computer is awake; where the user turns it on, a warning says so (`TopUpWarning` in `ios_limits.dart`, as on macOS) |
| In-app update (download, signature check, installer) | a notice with the link to the `.deb` of the architecture (`pickDeb` in `update_service.dart`) |
| Foreground service of a conversation | not needed |

Plugins: `flutter_zxing` reads a QR code from an image file (`readQrImage` in
`scan_screen.dart`); its camera scan uses the `camera` plugin, which has no Linux side, so
the scan screen asks for an image of the code at once, as on macOS. `share_plus` shares no file on Linux: the app saves the file with the
file chooser instead (`shareFiles` in `lib/services/linux_app.dart`). A text share opens
the mail program. Notifications go to the notification server of the desktop over D-Bus.

## Build the .deb

On Ubuntu 24.04, `amd64` or `arm64`, with Rust 1.99.0 and Flutter 3.41.2:

```sh
sudo apt install clang lld llvm cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev liblzma-dev \
  dpkg-dev imagemagick
cd app && flutter build linux --release && cd ..
scripts/package_deb.sh dist                # dist/superapp-<version>-linux-<arch>.deb (Package: superapp)
scripts/check_deb.sh fields dist/superapp-*.deb "$(dpkg --print-architecture)"
docker run --rm -v "$PWD:/src:ro" -w /src ubuntu:24.04 scripts/check_deb.sh install dist/superapp-*.deb
```

The CMake build runs `scripts/build_linux.sh`, which builds `libwallet_ffi.so` for the
architecture of the machine. There is no cross build: CI builds each `.deb` on its own
runner (`.github/workflows/linux.yml`, `ubuntu-24.04` and `ubuntu-24.04-arm`), and
`release.yml` publishes both with their SHA-256.
