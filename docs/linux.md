# The Linux app (issue #153)

The app runs on Ubuntu 24.04 LTS or later, on `amd64` and `arm64`. Each release has one
`.deb` per architecture. There is no other format (no AppImage, Flatpak or Snap), no APT
repository and no signature of the `.deb`: check it with `SHA256SUMS` of the release.

## Install, update, remove

```sh
sha256sum --check --ignore-missing SHA256SUMS
sudo apt install ./chatui_<version>_<arch>.deb    # also to update
sudo apt remove chatui                            # the data of the user stays
```

The app does not update itself on Linux (`UpdateChannel.supported` is Android only).

## What the package installs

| Path | What |
|---|---|
| `/opt/chatui/` | the bundle of `flutter build linux --release` (`chatui`, `lib/`, `data/`) |
| `/opt/chatui/lib/libwallet_ffi.so` | the Rust core, built by `scripts/build_linux.sh` |
| `/usr/bin/chatui` | a link to `/opt/chatui/chatui` |
| `/usr/share/applications/org.celaut.chatui.desktop` | `Exec=chatui %U`; `x-scheme-handler/celaut`, `x-scheme-handler/ergopay`, `application/x-celaut-bee` |
| `/usr/share/mime/packages/org.celaut.chatui.xml` | `application/x-celaut-bee` = `*.celaut.bee` |
| `/usr/share/icons/hicolor/*/apps/org.celaut.chatui.png` | the icon, 64 to 512 px |

dpkg triggers update the caches of the `.desktop` files, of the MIME types and of the
icons: the package has no maintainer script.

The data of the user is in `~/.local/share/org.celaut.chatui/` (`celaut/celaut.db`, the
services in `celaut/packages/`, `shared_preferences.json`). The secrets (the sealed seeds,
their wrap keys and the key of `celaut.db`) are items of the Secret Service, with the
schema `org.celaut.chatui.Secret` and the label `Chatui: <key>`.

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
| `com.argus.wallet/secure_storage` (Keystore) | `secure_storage.cc`: libsecret. No fingerprint or screen lock to ask: the wallet opens as on a phone that has neither; the keyring is unlocked by the session. `setSecureFlag` answers false: X11 and Wayland cannot block a screenshot. |
| `argus/deeplink` (`celaut:`, `ergopay:`) | `links.cc`: the arguments of `chatui`. The app is unique (GApplication): a link that the desktop opens while it runs goes to it and brings its window to the front. |
| `org.celaut.chatui/incoming` (`.celaut.bee` opened in a file manager) | `links.cc`: a path or a `file://` uri on the command line; an http(s) link to a service too |
| `org.celaut.chatui/package` (picker, copy, fd, metered) | `package_channel.cc`: the GTK file chooser, a copy with its progress, a file descriptor, `GNetworkMonitor` |
| Cards sensors and sounds, motion cues | off: no gyroscope (the settings show only what the device has) |
| In-app update | off |
| Foreground service of a conversation | not needed |

Plugins: `flutter_zxing` reads a QR code from an image file (`zx.readBarcodeImagePathString`);
its camera scan uses the `camera` plugin, which has no Linux side, so the scan screen offers
the image at once. `share_plus` shares no file on Linux: the app saves the file with the
file chooser instead (`shareFiles` in `lib/services/linux_app.dart`). A text share opens
the mail program. Notifications go to the notification server of the desktop over D-Bus.

## Build the .deb

On Ubuntu 24.04, `amd64` or `arm64`, with Rust 1.99.0 and Flutter 3.41.2:

```sh
sudo apt install clang lld llvm cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev liblzma-dev \
  dpkg-dev imagemagick
cd app && flutter build linux --release && cd ..
scripts/package_deb.sh dist                # dist/chatui_<version>_<arch>.deb
scripts/check_deb.sh fields dist/chatui_*.deb "$(dpkg --print-architecture)"
docker run --rm -v "$PWD:/src:ro" -w /src ubuntu:24.04 scripts/check_deb.sh install dist/chatui_*.deb
```

The CMake build runs `scripts/build_linux.sh`, which builds `libwallet_ffi.so` for the
architecture of the machine. There is no cross build: CI builds each `.deb` on its own
runner (`.github/workflows/linux.yml`, `ubuntu-24.04` and `ubuntu-24.04-arm`), and
`release.yml` publishes both with their SHA-256.
