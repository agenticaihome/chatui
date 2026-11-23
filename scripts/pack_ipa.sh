#!/usr/bin/env bash
# ─── pack_ipa.sh ──────────────────────────────────────────────────────────
# Pack the unsigned release app of `flutter build ios --release --no-codesign` into
# dist/superapp-<version>-unsigned.ipa, check it, and write dist/SHA256SUMS-ipa.
# The user signs the .ipa with AltStore, SideStore or Sideloadly (docs/ios.md).
#
# Checks: the executable is arm64 and exports the entry points of the Rust bridge (Dart
# finds them in the process with dlsym), and release_check.sh ipa (version, build number,
# bundle id, unsigned). macOS only (lipo, nm).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="${1:-$REPO_ROOT/app/build/ios/iphoneos/Runner.app}"
DIST="${DIST:-$REPO_ROOT/dist}"

[ -x "$APP/Runner" ] || { echo "no app at $APP: run flutter build ios --release --no-codesign" >&2; exit 1; }

archs="$(lipo -archs "$APP/Runner")"
echo "architectures: $archs"
[ "$archs" = arm64 ] || { echo "expected arm64 only" >&2; exit 1; }

exports="$(nm -gU "$APP/Runner")"
for sym in frb_pde_ffi_dispatcher_primary frb_pde_ffi_dispatcher_sync frb_get_rust_content_hash \
  frb_init_frb_dart_api_dl store_dart_post_cobject; do
  grep -q " _$sym\$" <<<"$exports" || {
    echo "the executable does not export $sym" >&2
    # Linked but stripped (a large executable), or not linked at all (a small one)?
    echo "executable: $(ls -lh "$APP/Runner" | awk '{print $5}'), $(wc -l <<<"$exports") exported symbols, $(grep -c ' _frb_' <<<"$exports" || true) _frb_" >&2
    exit 1
  }
done
echo "exported bridge functions: $(grep -c ' _frb_' <<<"$exports")"

version="$(sed -n "s/^const appVersion = '\(.*\)';/\1/p" "$REPO_ROOT/app/lib/build_info.dart")"
ipa="superapp-$version-unsigned.ipa"
mkdir -p "$DIST"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/Payload"
cp -R "$APP" "$work/Payload/"
rm -f "$DIST/$ipa"
(cd "$work" && zip -qry "$DIST/$ipa" Payload)
"$SCRIPT_DIR/release_check.sh" ipa "$DIST/$ipa"
(cd "$DIST" && shasum -a 256 "$ipa" | tee SHA256SUMS-ipa)
