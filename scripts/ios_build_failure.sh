#!/usr/bin/env bash
# ─── ios_build_failure.sh ─────────────────────────────────────────────────
# Why did `flutter build ios -v > LOG` fail? Flutter hides the error of xcodebuild
# behind a generic message (CI prints this when the build fails):
#   1. the error lines of the log,
#   2. the output of the "Build the Rust core" phase (scripts/build_ios.sh), without
#      the environment that Xcode prints before each script,
#   3. the end of the log.
#
#   scripts/ios_build_failure.sh LOG
set -u
log="$1"
grep -n -E 'error:|error\[|BUILD FAILED|PhaseScriptExecution|ld: |Undefined symbols|warning: unable' "$log" | head -150
echo "──── the \"Build the Rust core\" phase ────"
awk 'p && /\(in target .* from project / { exit }
     /PhaseScriptExecution Build\\ the\\ Rust\\ core/ { p = 1; print; next }
     p && /Command PhaseScriptExecution failed/ { print; exit }
     p && !/^[[:space:]]*export / { print }' "$log" | tail -250
echo "──── the end of the log ────"
tail -60 "$log"
