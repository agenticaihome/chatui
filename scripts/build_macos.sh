#!/usr/bin/env bash
# ─── build_macos.sh ───────────────────────────────────────────────────────
# Build libwallet_ffi.a, the Rust core, as a static library for macOS on Apple
# Silicon (aarch64-apple-darwin). The Xcode project of app/macos links it into
# the app with -force_load (Runner/Configs/RustCore.xcconfig); Dart finds the
# functions of the bridge in the process (lib/services/rust_library.dart).
#
# The first build phase of Runner ("Build the Rust core") runs this script, so
# `flutter build macos` alone is enough, as `flutter build apk` on Android.
#
# Needs macOS with Xcode (the C code of the crates) and rustup:
#   scripts/build_macos.sh          build the library
#   scripts/build_macos.sh xcode    the same, from the Xcode build phase
#
# Output: rust/target/aarch64-apple-darwin/release/libwallet_ffi.a
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$REPO_ROOT/rust"
TARGET=aarch64-apple-darwin

case "${1:-}" in
  "") ;;
  xcode)
    # Xcode gives the script its own environment (its SDK, compiler flags and paths).
    # The build scripts of the crates run on the Mac too: build in a clean environment,
    # with the folder of cargo (rustup) on the PATH.
    cargo_dir=""
    for d in "$(dirname "$(command -v cargo 2>/dev/null || echo /nonexistent/cargo)")" \
      "${CARGO_HOME:-$HOME/.cargo}/bin" "$HOME/.cargo/bin" "$(eval echo "~${USER:-$(id -un)}")/.cargo/bin" \
      /opt/homebrew/bin /usr/local/bin; do
      if [ -x "$d/cargo" ]; then cargo_dir="$d"; break; fi
    done
    if [ -z "$cargo_dir" ]; then
      echo "build_macos.sh: no cargo (HOME=$HOME CARGO_HOME=${CARGO_HOME:-} PATH=$PATH)" >&2
      exit 1
    fi
    exec env -i HOME="$HOME" USER="${USER:-}" TMPDIR="${TMPDIR:-/tmp}" \
      PATH="$cargo_dir:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      ${RUSTUP_TOOLCHAIN:+RUSTUP_TOOLCHAIN="$RUSTUP_TOOLCHAIN"} \
      ${CARGO_HOME:+CARGO_HOME="$CARGO_HOME"} ${RUSTUP_HOME:+RUSTUP_HOME="$RUSTUP_HOME"} \
      "$0"
    ;;
  *) echo "usage: $0 [xcode]" >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Darwin ]; then
  echo "The macOS library builds only on macOS with Xcode." >&2
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is not installed (https://rustup.rs)." >&2
  exit 1
fi

# The same minimum as MACOSX_DEPLOYMENT_TARGET of app/macos: the C code of the crates
# (ring, SQLite, zstd) is built for it, and the linker does not warn about newer objects.
export MACOSX_DEPLOYMENT_TARGET=13.0
# The same path remapping as build_android.sh: no absolute path of the build in the library.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$REPO_ROOT=/argus --remap-path-prefix=$HOME/.cargo=/cargo"

cd "$RUST_DIR"
rustup target list --installed 2>/dev/null | grep -qx "$TARGET" || rustup target add "$TARGET"
echo "=== Building wallet-ffi for $TARGET ==="
# Only the static library: the cdylib of the crate is for Android and Linux.
# --print native-static-libs names the system libraries that the app must link
# (OTHER_LDFLAGS in RustCore.xcconfig).
cargo rustc --release -p wallet-ffi --lib --target "$TARGET" --crate-type staticlib \
  -- --print native-static-libs
lib="$RUST_DIR/target/$TARGET/release/libwallet_ffi.a"
[ -s "$lib" ] || { echo "no library at $lib" >&2; exit 1; }
echo "$TARGET: $(ls -lh "$lib" | awk '{print $5}') $lib"
