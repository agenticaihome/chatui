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
    # in a clean environment.
    exec env -i HOME="$HOME" USER="${USER:-}" TMPDIR="${TMPDIR:-/tmp}" \
      PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      CHATUI_SIM_ARCHS="$archs" "$SCRIPT_DIR/build_ios.sh" "$mode"
    ;;
  *) echo "usage: $0 [all|device|simulator|xcode]" >&2; exit 2 ;;
esac
# The architectures that Xcode asked for (xcode mode), instead of this Mac's.
[ -n "$SIM_ARCHS" ] && [ -n "${CHATUI_SIM_ARCHS:-}" ] && SIM_ARCHS="$CHATUI_SIM_ARCHS"

if [ "$(uname -s)" != Darwin ]; then
  echo "The iOS library builds only on macOS with Xcode." >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is not installed (https://rustup.rs)." >&2
  exit 1
fi

# The same minimum as IPHONEOS_DEPLOYMENT_TARGET in app/ios: the C code of the crates
# (ring, SQLite, zstd) is built for it.
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-13.0}"
# The same path remapping as build_android.sh: no absolute path of the build in the library.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$REPO_ROOT=/argus --remap-path-prefix=$HOME/.cargo=/cargo"

cd "$RUST_DIR"
build() {
  local target="$1"
  rustup target list --installed 2>/dev/null | grep -qx "$target" || rustup target add "$target"
  echo "=== Building wallet-ffi for $target ==="
  # Only the static library: the cdylib of the crate is for Android and Linux.
  cargo rustc --release -p wallet-ffi --lib --target "$target" --crate-type staticlib
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
