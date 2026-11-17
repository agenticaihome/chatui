#!/usr/bin/env bash
# ─── package_deb.sh ───────────────────────────────────────────────────────
# Make chatui_<version>_<arch>.deb from the bundle of `flutter build linux
# --release`, for the architecture of this machine (amd64 or arm64).
#
#   cd app && flutter build linux --release && cd .. && scripts/package_deb.sh [OUT_DIR]
#
# The package installs the bundle in /opt/chatui, the command /usr/bin/chatui,
# the .desktop file (links celaut: and ergopay:, files *.celaut.bee), the MIME
# type of a .celaut.bee file and the icons. dpkg-shlibdeps finds the libraries
# that the bundle needs; the programs that the app runs are added by hand.
#
# Prerequisites: dpkg-dev (dpkg-shlibdeps), ImageMagick (the icons).
#
set -euo pipefail
umask 022

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPO_ROOT/app"
PACKAGING="$APP/linux/packaging"
OUT_DIR="${1:-$REPO_ROOT/dist}"
APP_ID=org.celaut.chatui

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *) echo "No .deb for $ARCH: only amd64 and arm64."; exit 1 ;;
esac
BUNDLE="$APP/build/linux/$FLUTTER_ARCH/release/bundle"
if [ ! -x "$BUNDLE/chatui" ] || [ ! -f "$BUNDLE/lib/libwallet_ffi.so" ]; then
  echo "No release bundle in $BUNDLE. Run: cd app && flutter build linux --release"
  exit 1
fi

VERSION="$(sed -n "s/^const appVersion = '\(.*\)';/\1/p" "$APP/lib/build_info.dart")"
[ -n "$VERSION" ] || { echo "No appVersion in app/lib/build_info.dart"; exit 1; }

if command -v magick >/dev/null 2>&1; then CONVERT=(magick); else CONVERT=(convert); fi
command -v "${CONVERT[0]}" >/dev/null 2>&1 || { echo "ImageMagick is not installed."; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ROOT="$WORK/root"

install -d "$ROOT/opt/chatui" "$ROOT/usr/bin" "$ROOT/DEBIAN"
cp -R "$BUNDLE/." "$ROOT/opt/chatui/"
ln -s /opt/chatui/chatui "$ROOT/usr/bin/chatui"
# The jni plugin (path_provider_android, for Android only) builds libdartjni.so when the
# build machine has a JDK. Nothing loads it on Linux, and it needs libjvm.so.
rm -f "$ROOT/opt/chatui/lib/libdartjni.so"
install -Dm644 "$PACKAGING/$APP_ID.desktop" "$ROOT/usr/share/applications/$APP_ID.desktop"
install -Dm644 "$PACKAGING/$APP_ID.xml" "$ROOT/usr/share/mime/packages/$APP_ID.xml"
for size in 64 128 256 512; do
  dir="$ROOT/usr/share/icons/hicolor/${size}x${size}/apps"
  install -d "$dir"
  "${CONVERT[@]}" "$APP/assets/brand/icon.png" -resize "${size}x${size}" -strip "$dir/$APP_ID.png"
done
install -Dm644 "$REPO_ROOT/LICENSE" "$ROOT/usr/share/doc/chatui/copyright"
install -Dm644 "$REPO_ROOT/NOTICE.md" "$ROOT/usr/share/doc/chatui/NOTICE.md"

# The files of the bundle: no write bit for others, executables stay executable.
find "$ROOT" -type d -exec chmod 0755 {} +
find "$ROOT/opt/chatui" -type f -exec chmod u+rw,go+r,go-w {} +
chmod 0755 "$ROOT/opt/chatui/chatui"
find "$ROOT/opt/chatui/lib" -name '*.so' -exec chmod 0644 {} +

# The libraries of the system that the executable and the bundled libraries need. The
# bundled ones (lib/) belong to no package and are left out.
mkdir -p "$WORK/debian"
printf 'Source: chatui\n\nPackage: chatui\nArchitecture: any\n' > "$WORK/debian/control"
SHLIBS="$(cd "$WORK" && dpkg-shlibdeps -O --ignore-missing-info \
  -l"$ROOT/opt/chatui/lib" \
  -e"$ROOT/opt/chatui/chatui" $(find "$ROOT/opt/chatui/lib" -name '*.so' -printf ' -e%p') \
  2>"$WORK/shlibdeps.log" | sed -n 's/^shlibs:Depends=//p')"
if [ -z "$SHLIBS" ]; then
  cat "$WORK/shlibdeps.log"
  echo "dpkg-shlibdeps found no dependency."
  exit 1
fi
rm -rf "$WORK/debian"

# The programs that the app runs, which no library check finds:
#   pulseaudio-utils      parecord, the microphone of the `record` plugin (PulseAudio,
#                         or PipeWire through pipewire-pulse)
#   xdg-desktop-portal    the file chooser of file_picker (attachments, a QR in an image)
# and in Recommends gnome-keyring, a Secret Service for libsecret (KWallet is one too).
DEPENDS="$SHLIBS, pulseaudio-utils, xdg-desktop-portal"
RECOMMENDS="gnome-keyring, xdg-desktop-portal-gtk | xdg-desktop-portal-backend"
SIZE="$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)"

cat > "$ROOT/DEBIAN/control" <<EOF
Package: chatui
Version: $VERSION
Architecture: $ARCH
Maintainer: Celaut project <https://github.com/celaut-project/chatui/issues>
Installed-Size: $SIZE
Depends: $DEPENDS
Recommends: $RECOMMENDS
Section: net
Priority: optional
Homepage: https://github.com/celaut-project/chatui
Description: Celaut light client
 Chatui uses Celaut services without intermediaries: it finds nodes, pays
 them, starts services and talks to them. It is also an Ergo and Bitcoin
 wallet. The keys are kept in the Secret Service of the desktop.
EOF

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/chatui_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB" >/dev/null
echo "$DEB"
dpkg-deb --field "$DEB" Package Version Architecture Depends Recommends
