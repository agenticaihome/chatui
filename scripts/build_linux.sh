#!/usr/bin/env bash
# ─── build_linux.sh ───────────────────────────────────────────────────────
# Build libwallet_ffi.so (rust/crates/wallet-ffi) for the Linux app, for the
# architecture of this machine (x86_64 or aarch64), and copy it to OUT_DIR.
#
#   scripts/build_linux.sh [OUT_DIR]
#
# The CMake build of app/linux runs this script, so `flutter build linux` alone
# is enough. OUT_DIR is then the build folder of CMake, and CMake puts the
# library in the lib folder of the bundle.
#
# Prerequisites: the Rust toolchain of rust/rust-toolchain.toml (or 1.99.0).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUST_DIR="$REPO_ROOT/rust"
OUT_DIR="${1:-${OUT_DIR:-$REPO_ROOT/app/build/linux-native}}"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is not installed. Install Rust from https://rustup.rs"
  exit 1
fi

# Reproducible output, as in build_android.sh: the absolute build path is not
# baked into the library.
export RUSTFLAGS="${RUSTFLAGS:-} --remap-path-prefix=$REPO_ROOT=/argus --remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/cargo"

cd "$RUST_DIR"
echo "=== Building wallet-ffi for $(uname -m)-linux ==="
cargo build --release --locked -p wallet-ffi

TARGET_DIR="${CARGO_TARGET_DIR:-$RUST_DIR/target}"
mkdir -p "$OUT_DIR"
# Copy only when it changed, so that CMake does not install it again for nothing.
if ! cmp -s "$TARGET_DIR/release/libwallet_ffi.so" "$OUT_DIR/libwallet_ffi.so"; then
  cp "$TARGET_DIR/release/libwallet_ffi.so" "$OUT_DIR/libwallet_ffi.so"
fi
echo "$OUT_DIR/libwallet_ffi.so: $(ls -lh "$OUT_DIR/libwallet_ffi.so" | awk '{print $5}')"
