#!/usr/bin/env bash
# ─── check_deb.sh ─────────────────────────────────────────────────────────
# Checks of a .deb of package_deb.sh.
#
#   check_deb.sh fields <deb> <arch>   the name, the version (appVersion), the
#                                      architecture, the dependencies, the files
#   check_deb.sh install <deb>         as root in a clean Ubuntu 24.04: apt
#                                      installs it, every library is found, the
#                                      links and the MIME type go to the app, and
#                                      the app starts (Xvfb) and runs 20 s
#
# The install check changes the system: run it only in a throwaway container.
#
#   docker run --rm -v "$PWD:/src" -w /src ubuntu:24.04 \
#     scripts/check_deb.sh install dist/superapp-<version>-linux-<arch>.deb
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_ID=org.celaut.superapp

FAIL=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAIL=1; }

fields() {
  local deb="$1" arch="$2" version
  version="$(sed -n "s/^const appVersion = '\(.*\)';/\1/p" "$REPO_ROOT/app/lib/build_info.dart")"
  [ "$(dpkg-deb --field "$deb" Package)" = superapp ] && pass "Package superapp" || fail "Package"
  [ -n "$version" ] && [ "$(dpkg-deb --field "$deb" Version)" = "$version" ] \
    && pass "Version $version" || fail "Version: $(dpkg-deb --field "$deb" Version) != appVersion $version"
  [ "$(dpkg-deb --field "$deb" Architecture)" = "$arch" ] \
    && pass "Architecture $arch" || fail "Architecture: $(dpkg-deb --field "$deb" Architecture) != $arch"
  [ "$(basename "$deb")" = "superapp-${version}-linux-${arch}.deb" ] \
    && pass "file name $(basename "$deb")" || fail "file name $(basename "$deb")"
  local depends
  depends="$(dpkg-deb --field "$deb" Depends)"
  echo "  Depends: $depends"
  echo "  Recommends: $(dpkg-deb --field "$deb" Recommends)"
  local names
  names="$(tr ',|' '\n\n' <<<"$depends" | awk '{print $1}')"
  for want in libc6 libgtk-3-0t64 libglib2.0-0t64 libsecret-1-0 libstdc++6 pulseaudio-utils xdg-desktop-portal; do
    grep -Fqx "$want" <<<"$names" && pass "Depends has $want" || fail "Depends has no $want"
  done
  local files
  files="$(dpkg-deb --contents "$deb" | awk '{print $6}')"
  for want in ./usr/lib/superapp/superapp ./usr/lib/superapp/lib/libwallet_ffi.so ./usr/lib/superapp/lib/libapp.so \
      ./usr/lib/superapp/lib/libflutter_linux_gtk.so ./usr/lib/superapp/data/icudtl.dat ./usr/bin/superapp \
      "./usr/share/applications/$APP_ID.desktop" "./usr/share/mime/packages/$APP_ID.xml" \
      "./usr/share/icons/hicolor/256x256/apps/$APP_ID.png" ./usr/share/doc/superapp/copyright; do
    grep -qx "$want" <<<"$files" && pass "has $want" || fail "has no $want"
  done
  if grep -q '/libdartjni.so$' <<<"$files"; then fail "has libdartjni.so (needs a JVM)"; else pass "no libdartjni.so"; fi
  # Everything under /usr: the bundle in /usr/lib/superapp, nothing in /opt.
  local outside
  outside="$(grep -v -e '^\./$' -e '^\./usr/' <<<"$files")"
  [ -z "$outside" ] && pass "every file is under /usr" || fail "files outside /usr: $outside"
  local machine tmp
  tmp="$(mktemp -d)"
  dpkg-deb --fsys-tarfile "$deb" | tar -x -C "$tmp" ./usr/lib/superapp/lib/libwallet_ffi.so
  # e_machine of the ELF header: 0x3e x86-64, 0xb7 AArch64.
  machine="$(od -An -tx1 -j18 -N2 "$tmp/usr/lib/superapp/lib/libwallet_ffi.so" | tr -d ' ')"
  rm -rf "$tmp"
  case "$arch:$machine" in
    amd64:3e00 | arm64:b700) pass "libwallet_ffi.so is for $arch" ;;
    *) fail "libwallet_ffi.so machine $machine is not $arch" ;;
  esac
}

install_check() {
  local deb="$1"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  # A desktop has these; a clean container does not. They make the caches of the
  # .desktop files and of the MIME types, and xdg-open/xdg-mime read them.
  apt-get install -y -qq --no-install-recommends desktop-file-utils shared-mime-info xdg-utils \
    libglib2.0-bin xvfb xauth dbus >/dev/null
  if apt-get install -y -qq "$(realpath "$deb")" >/tmp/apt.log 2>&1; then
    pass "apt install $(basename "$deb")"
  else
    tail -20 /tmp/apt.log
    fail "apt install $(basename "$deb")"
    return
  fi
  [ -x /usr/bin/superapp ] && pass "/usr/bin/superapp" || fail "/usr/bin/superapp"
  [ "$(readlink -f /usr/bin/superapp)" = /usr/lib/superapp/superapp ] \
    && pass "/usr/bin/superapp -> /usr/lib/superapp/superapp" || fail "/usr/bin/superapp -> $(readlink -f /usr/bin/superapp)"
  local missing
  # The plugins find libflutter_linux_gtk.so through the executable, which loads it first.
  missing="$(LD_LIBRARY_PATH=/usr/lib/superapp/lib ldd /usr/lib/superapp/superapp /usr/lib/superapp/lib/*.so 2>&1 | grep 'not found' | sort -u)"
  [ -z "$missing" ] && pass "every library is found (ldd)" || fail "missing libraries: $missing"
  desktop-file-validate "/usr/share/applications/$APP_ID.desktop" \
    && pass "desktop-file-validate" || fail "desktop-file-validate"
  for scheme in celaut ergopay; do
    grep -q "^x-scheme-handler/$scheme=.*$APP_ID.desktop" /usr/share/applications/mimeinfo.cache \
      && pass "x-scheme-handler/$scheme -> $APP_ID.desktop" || fail "x-scheme-handler/$scheme"
  done
  # GIO (GNOME, and xdg-open through gio) reads the type from the shared MIME database.
  printf 'x' > /tmp/x.celaut.bee
  local type
  type="$(gio info -a standard::content-type /tmp/x.celaut.bee | sed -n 's/.*standard::content-type: //p')"
  [ "$type" = application/x-celaut-bee ] \
    && pass "*.celaut.bee is application/x-celaut-bee" || fail "MIME type of *.celaut.bee: $type"
  grep -q "^application/x-celaut-bee=.*$APP_ID.desktop" /usr/share/applications/mimeinfo.cache \
    && pass "application/x-celaut-bee -> $APP_ID.desktop" || fail "application/x-celaut-bee"
  # The app starts and keeps running: 124 is the exit of timeout.
  local rc
  mkdir -p /tmp/home
  HOME=/tmp/home dbus-run-session -- xvfb-run -a timeout 20 superapp >/tmp/superapp.log 2>&1
  rc=$?
  [ "$rc" = 124 ] && pass "superapp runs 20 s on Xvfb" || { tail -20 /tmp/superapp.log; fail "superapp exited with $rc"; }
}

case "${1:-}" in
  fields) [ $# = 3 ] || { echo "usage: $0 fields <deb> <arch>"; exit 2; }; fields "$2" "$3" ;;
  install) [ $# = 2 ] || { echo "usage: $0 install <deb>"; exit 2; }; install_check "$2" ;;
  *) echo "usage: $0 fields <deb> <arch> | install <deb>"; exit 2 ;;
esac
exit "$FAIL"
