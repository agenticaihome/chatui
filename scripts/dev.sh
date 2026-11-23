#!/usr/bin/env bash
# ─── dev.sh ───────────────────────────────────────────────────────────────
# Runs the project's checks inside docker/Dockerfile, which carries the same
# Flutter, Rust, protoc and codegen versions as CI. Nothing is installed locally.
#
#   scripts/dev.sh build            build the image
#   scripts/dev.sh pub-get          flutter pub get --enforce-lockfile
#   scripts/dev.sh analyze          flutter analyze
#   scripts/dev.sh test [args]      flutter test
#   scripts/dev.sh gen              FRB codegen, chat proto, flutter gen-l10n
#   scripts/dev.sh rust-test [args] cargo test --workspace
#   scripts/dev.sh check            pub-get, analyze, test, rust-test, then gen and
#                                   a git diff to prove the bindings are current
#   scripts/dev.sh shell            interactive shell in the container
#   scripts/dev.sh run <cmd...>     any command in the container
#
# DOCKER=podman scripts/dev.sh ... uses podman. Caches (pub, cargo) live in
# named volumes, so repeated runs are fast.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="${DOCKER:-docker}"
IMAGE="${SUPERAPP_DEV_IMAGE:-superapp-dev:latest}"

build() { "$ENGINE" build -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT/docker"; }

ensure_image() {
  "$ENGINE" image inspect "$IMAGE" > /dev/null 2>&1 || build
}

# Runs "$@" in the container, in $WORKDIR (relative to the repo root).
in_container() {
  local workdir="${WORKDIR:-.}"
  local tty=()
  [ -t 0 ] && [ -t 1 ] && tty=(-it)
  local user=(--user "$(id -u):$(id -g)")
  # Rootless podman maps the host user to root inside the container already.
  [ "$ENGINE" = podman ] && user=(--userns=keep-id --user "$(id -u):$(id -g)")
  "$ENGINE" run --rm "${tty[@]}" "${user[@]}" \
    -v "$REPO_ROOT:/work:z" -w "/work/$workdir" \
    -v superapp-pub-cache:/pub-cache \
    -v superapp-cargo-home:/cargo-home \
    -e HOME=/tmp/home \
    "$IMAGE" "$@"
}

at() { local d="$1"; shift; WORKDIR="$d" in_container "$@"; }

gen() {
  at . flutter_rust_bridge_codegen generate
  at . scripts/gen_chat_proto.sh
  at app flutter gen-l10n
}

cmd="${1:-}"; shift || true
case "$cmd" in
  build)     build ;;
  pub-get)   ensure_image; at app flutter pub get --enforce-lockfile ;;
  analyze)   ensure_image; at app flutter pub get --enforce-lockfile; at app flutter analyze ;;
  test)      ensure_image; at app flutter pub get --enforce-lockfile; at app flutter test "$@" ;;
  gen)       ensure_image; at app flutter pub get --enforce-lockfile; gen ;;
  rust-test) ensure_image; at rust cargo test --workspace "$@" ;;
  check)
    ensure_image
    at app flutter pub get --enforce-lockfile
    at app flutter analyze
    at app flutter test
    at rust cargo test --workspace
    gen
    git -C "$REPO_ROOT" diff --exit-code --stat || {
      echo "Generated files differ from the committed ones: commit the result." >&2; exit 1; }
    ;;
  shell)     ensure_image; in_container bash ;;
  run)       ensure_image; in_container "$@" ;;
  *) sed -n '2,22p' "$0"; exit 1 ;;
esac
