#!/usr/bin/env bash
# ─── build_ios.sh ─────────────────────────────────────────────────────────
# Build libwallet_ffi.a, the Rust core, as a static library for iOS: one for
# the devices (aarch64-apple-ios) and one for the simulator on Apple silicon
# (aarch64-apple-ios-sim). The Xcode project of app/ios links it into the app
# with -force_load (Flutter/RustCore.xcconfig); Dart finds the functions of the
# bridge in the process (flutter_rust_bridge, ExternalLibrary.process).
#
# Needs macOS with Xcode, and:
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim
#
#   scripts/build_ios.sh            both targets
#   scripts/build_ios.sh device     aarch64-apple-ios only
#   scripts/build_ios.sh simulator  aarch64-apple-ios-sim only
#   scripts/build_ios.sh xcode      the target of the Xcode build that calls it
#                                   (the "Build the Rust core" phase of Runner)
#
# Output: rust/target/<target>/release/libwallet_ffi.a
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$REPO_ROOT/rust"

case "${1:-all}" in
  all) TARGETS=(aarch64-apple-ios aarch64-apple-ios-sim) ;;
  device) TARGETS=(aarch64-apple-ios) ;;
  simulator) TARGETS=(aarch64-apple-ios-sim) ;;
  xcode)
    case "${PLATFORM_NAME:-}" in
      iphoneos) TARGETS=(aarch64-apple-ios) ;;
      iphonesimulator) TARGETS=(aarch64-apple-ios-sim) ;;
      *) echo "build_ios.sh xcode: unknown PLATFORM_NAME '${PLATFORM_NAME:-}'" >&2; exit 1 ;;
    esac
    # Xcode gives the script its own environment (SDKROOT of iOS, its compiler flags). The
    # build scripts of the crates are built for the Mac, and fail to link with it: run cargo
    # in a clean environment.
    exec env -i HOME="$HOME" USER="${USER:-}" TMPDIR="${TMPDIR:-/tmp}" \
      PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      CHATUI_IOS_FROM_XCODE=1 "$0" "$( [ "${TARGETS[0]}" = aarch64-apple-ios ] && echo device || echo simulator )"
    ;;
  *) echo "usage: $0 [all|device|simulator|xcode]" >&2; exit 2 ;;
esac

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
for target in "${TARGETS[@]}"; do
  rustup target list --installed 2>/dev/null | grep -qx "$target" || rustup target add "$target"
  echo "=== Building wallet-ffi for $target ==="
  # Only the static library: the cdylib of the crate is for Android and Linux.
  cargo rustc --release -p wallet-ffi --lib --target "$target" --crate-type staticlib
  lib="$RUST_DIR/target/$target/release/libwallet_ffi.a"
  [ -s "$lib" ] || { echo "no library at $lib" >&2; exit 1; }
  echo "$target: $(ls -lh "$lib" | awk '{print $5}') $lib"
done
