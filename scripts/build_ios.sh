#!/usr/bin/env bash
# ─── build_ios.sh ─────────────────────────────────────────────────────────
# Build libwallet_ffi.a, the Rust core, as a static library for iOS: one for
# the devices (aarch64-apple-ios) and one for the simulator, with the simulator
# architectures of the Mac (aarch64-apple-ios-sim on Apple silicon,
# x86_64-apple-ios on Intel) in one file. The Xcode project of app/ios links it
# into the app with -force_load (Flutter/RustCore.xcconfig); Dart finds the
# functions of the bridge in the process (flutter_rust_bridge,
# ExternalLibrary.process).
#
# Needs macOS with Xcode, and rustup (the targets are added when missing).
#
#   scripts/build_ios.sh            device and simulator
#   scripts/build_ios.sh device     aarch64-apple-ios
#   scripts/build_ios.sh simulator  the simulator, for the architecture of this Mac
#   scripts/build_ios.sh xcode      the SDK and the architectures of the Xcode build that
#                                   calls it (the "Build the Rust core" phase of Runner)
#
# Output: rust/target/aarch64-apple-ios/release/libwallet_ffi.a (device) and
#         rust/target/ios-simulator/libwallet_ffi.a (simulator)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$REPO_ROOT/rust"

sim_target() {
  case "$1" in
    arm64) echo aarch64-apple-ios-sim ;;
    x86_64) echo x86_64-apple-ios ;;
    *) echo "no Rust target for the simulator architecture $1" >&2; exit 1 ;;
  esac
}

DEVICE=""
SIM_ARCHS=""
case "${1:-all}" in
  all) DEVICE=1; SIM_ARCHS="$(uname -m)" ;;
  device) DEVICE=1 ;;
  simulator) SIM_ARCHS="$(uname -m)" ;;
  xcode)
    case "${PLATFORM_NAME:-}" in
      iphoneos) mode=device; archs="" ;;
      iphonesimulator) mode=simulator; archs="${ARCHS:-$(uname -m)}" ;;
      *) echo "build_ios.sh xcode: unknown PLATFORM_NAME '${PLATFORM_NAME:-}'" >&2; exit 1 ;;
    esac
    # Xcode gives the script its own environment (SDKROOT of iOS, its compiler flags). The
    # build scripts of the crates are built for the Mac, and fail to link with it: run cargo
    # in a clean environment. It keeps the directories of cargo and rustup: rustup can come
    # from Homebrew, which does not link it into its bin (/opt/homebrew/opt/rustup/bin on
    # Apple silicon, the macos-15 runner).
    rust_path="${CARGO_HOME:-$HOME/.cargo}/bin"
    for tool in rustup cargo; do
      if found="$(command -v "$tool")"; then rust_path="$(dirname "$found"):$rust_path"; fi
    done
    for dir in /opt/homebrew/opt/rustup/bin /usr/local/opt/rustup/bin; do
      if [ -d "$dir" ]; then rust_path="$rust_path:$dir"; fi
    done
    keep=()
    for var in CARGO_HOME RUSTUP_HOME; do
      if [ -n "${!var:-}" ]; then keep+=("$var=${!var}"); fi
    done
    exec env -i HOME="$HOME" USER="${USER:-}" TMPDIR="${TMPDIR:-/tmp}" ${keep[@]+"${keep[@]}"} \
      PATH="$rust_path:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SUPERAPP_SIM_ARCHS="$archs" "$SCRIPT_DIR/build_ios.sh" "$mode"
    ;;
  *) echo "usage: $0 [all|device|simulator|xcode]" >&2; exit 2 ;;
esac
# The architectures that Xcode asked for (xcode mode), instead of this Mac's.
[ -n "$SIM_ARCHS" ] && [ -n "${SUPERAPP_SIM_ARCHS:-}" ] && SIM_ARCHS="$SUPERAPP_SIM_ARCHS"

if [ "$(uname -s)" != Darwin ]; then
  echo "The iOS library builds only on macOS with Xcode." >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo is not installed (https://rustup.rs), or not in PATH=$PATH" >&2
  exit 1
fi

# The same minimum as IPHONEOS_DEPLOYMENT_TARGET in app/ios: the C code of the crates
# (ring, SQLite, zstd) is built for it.
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-13.0}"
# The same path remapping as build_android.sh: no absolute path of the build in the library.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$REPO_ROOT=/argus --remap-path-prefix=$HOME/.cargo=/cargo"

cd "$RUST_DIR"

# sysinfo 0.38 (through tor-memquota of arti) calls proc_pidinfo in Process::open_files on
# every Apple system, and the libc crate has it only for macOS: it does not build for iOS.
# sysinfo 0.39 has the fix, but tor-memquota asks for 0.38. Build iOS with a copy of the
# crate of Cargo.lock (checksum checked) where open_files is None on iOS. Cargo.lock is
# restored after the build. Remove this when arti moves to sysinfo >= 0.39.
SYSINFO_VERSION="0.38.4"
SYSINFO_PATCH_DIR="$RUST_DIR/target/ios-patch/sysinfo-$SYSINFO_VERSION"
prepare_sysinfo() {
  local sum crate
  sum="$(awk -v v="$SYSINFO_VERSION" '
    $0 == "name = \"sysinfo\"" { s = 1; next }
    s && $1 == "version" { if ($3 != "\"" v "\"") s = 0; next }
    s && $1 == "checksum" { gsub(/"/, "", $3); print $3; exit }
    /^\[\[package\]\]/ { s = 0 }' Cargo.lock)"
  if [ -z "$sum" ]; then
    echo "Cargo.lock has no sysinfo $SYSINFO_VERSION: check the iOS patch of build_ios.sh." >&2
    exit 1
  fi
  [ -f "$SYSINFO_PATCH_DIR/.patched-$sum" ] && return 0
  cargo fetch --target aarch64-apple-ios >/dev/null
  crate="$(ls "${CARGO_HOME:-$HOME/.cargo}"/registry/cache/*/"sysinfo-$SYSINFO_VERSION.crate" 2>/dev/null | head -1)"
  [ -n "$crate" ] || { echo "sysinfo-$SYSINFO_VERSION.crate is not in the cargo cache" >&2; exit 1; }
  if [ "$(shasum -a 256 "$crate" | awk '{print $1}')" != "$sum" ]; then
    echo "$crate does not have the checksum of Cargo.lock" >&2
    exit 1
  fi
  rm -rf "$SYSINFO_PATCH_DIR"
  mkdir -p "$(dirname "$SYSINFO_PATCH_DIR")"
  tar -xzf "$crate" -C "$(dirname "$SYSINFO_PATCH_DIR")"
  local src="$SYSINFO_PATCH_DIR/src/unix/apple/process.rs"
  perl -0pi -e 's/(\n    )(pub\(crate\) fn open_files\(&self\) -> Option<usize> \{)/$1#[cfg(target_os = "ios")]$1pub(crate) fn open_files(&self) -> Option<usize> {$1    None$1}$1$1#[cfg(not(target_os = "ios"))]$1$2/' "$src"
  if [ "$(grep -c 'fn open_files(&self)' "$src")" != 2 ]; then
    echo "the iOS patch of sysinfo $SYSINFO_VERSION did not apply to $src" >&2
    exit 1
  fi
  touch "$SYSINFO_PATCH_DIR/.patched-$sum"
}
prepare_sysinfo
cp Cargo.lock "$RUST_DIR/target/ios-patch/Cargo.lock.orig"
trap 'cp "$RUST_DIR/target/ios-patch/Cargo.lock.orig" "$RUST_DIR/Cargo.lock"' EXIT

build() {
  local target="$1"
  rustup target list --installed 2>/dev/null | grep -qx "$target" || rustup target add "$target"
  echo "=== Building wallet-ffi for $target ==="
  # Only the static library: the cdylib of the crate is for Android and Linux.
  cargo rustc --release -p wallet-ffi --lib --target "$target" --crate-type staticlib \
    --config "patch.crates-io.sysinfo.path=\"$SYSINFO_PATCH_DIR\""
  local lib="$RUST_DIR/target/$target/release/libwallet_ffi.a"
  [ -s "$lib" ] || { echo "no library at $lib" >&2; exit 1; }
  echo "$target: $(ls -lh "$lib" | awk '{print $5}') $lib"
}

if [ -n "$DEVICE" ]; then
  build aarch64-apple-ios
fi
if [ -n "$SIM_ARCHS" ]; then
  libs=()
  for arch in $SIM_ARCHS; do
    target="$(sim_target "$arch")"
    build "$target"
    libs+=("$RUST_DIR/target/$target/release/libwallet_ffi.a")
  done
  out="$RUST_DIR/target/ios-simulator"
  mkdir -p "$out"
  # One file for the link, with each architecture of the simulator build.
  lipo -create "${libs[@]}" -output "$out/libwallet_ffi.a.tmp"
  mv "$out/libwallet_ffi.a.tmp" "$out/libwallet_ffi.a"
  echo "simulator ($SIM_ARCHS): $out/libwallet_ffi.a"
fi
