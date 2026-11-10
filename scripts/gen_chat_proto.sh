#!/usr/bin/env bash
# Make the Dart code of docs/celaut/chat.proto and docs/celaut/cards.proto (which
# imports chat.proto) in app/lib/celaut/chat/gen.
# CI runs this script and then `git diff --exit-code`: the generated files must be
# the output of the pinned tools. It needs protoc (PROTOC_VERSION) on the PATH.
# Run it from any directory. It can run again with no change.
set -euo pipefail

PROTOC_VERSION=3.21.12
PROTOC_PLUGIN_VERSION=25.1.0

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/app/lib/celaut/chat/gen"

version="$(protoc --version | awk '{print $2}')"
if [ "$version" != "$PROTOC_VERSION" ]; then
  echo "protoc $PROTOC_VERSION is needed, found $version" >&2
  exit 1
fi

dart pub global activate protoc_plugin "$PROTOC_PLUGIN_VERSION" > /dev/null
export PATH="$PATH:$HOME/.pub-cache/bin"

rm -rf "$out"
mkdir -p "$out"
protoc -I "$root/docs/celaut" --dart_out=grpc:"$out" \
  "$root/docs/celaut/chat.proto" "$root/docs/celaut/cards.proto"
