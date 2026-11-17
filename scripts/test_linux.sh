#!/usr/bin/env bash
# ─── test_linux.sh ────────────────────────────────────────────────────────
# Run app/integration_test/linux_platform_test.dart in the real Linux runner,
# in a session with no display: Xvfb, a D-Bus session bus, GNOME Keyring (the
# Secret Service) and a sound server with a microphone (a 440 Hz tone on
# PulseAudio, silence on PipeWire).
#
#   scripts/test_linux.sh                  # PulseAudio
#   SOUND=pipewire scripts/test_linux.sh   # PipeWire, through pipewire-pulse
#   scripts/test_linux.sh --dart-define=CHATUI_TEST_TOR=true   # and Tor (Internet)
#
# The arguments go to `flutter test`.
#
# Prerequisites (Ubuntu 24.04): xvfb xauth dbus-x11 gnome-keyring
# pulseaudio-utils, and pulseaudio, or pipewire pipewire-pulse wireplumber.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${CHATUI_TEST_SESSION:-}" ]; then
  export CHATUI_TEST_SESSION=1
  exec dbus-run-session -- xvfb-run -a -s "-screen 0 1280x1024x24" "$0" "$@"
fi

if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -w "${XDG_RUNTIME_DIR:-/nonexistent}" ]; then
  XDG_RUNTIME_DIR="$(mktemp -d)"
  export XDG_RUNTIME_DIR
fi
chmod 700 "$XDG_RUNTIME_DIR"

# The Secret Service: the login keyring, made and unlocked with a test password. libsecret
# finds the daemon by its name on the session bus.
printf test | gnome-keyring-daemon --unlock --components=secrets >/dev/null
gnome-keyring-daemon --start --components=secrets >/dev/null

stop_sound=()
case "${SOUND:-pulseaudio}" in
  pulseaudio)
    pulseaudio --daemonize=yes --exit-idle-time=-1 -n \
      --load=module-native-protocol-unix --load=module-null-sink \
      --load="module-sine-source source_name=mic frequency=440"
    pactl set-default-source mic
    stop_sound=(pulseaudio --kill)
    ;;
  pipewire)
    # No Bluetooth: its monitor needs logind, and wireplumber stops without it.
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$(mktemp -d)}"
    mkdir -p "$XDG_CONFIG_HOME/wireplumber/bluetooth.lua.d"
    printf 'bluez_monitor.enabled = false\nbluez_midi_monitor.enabled = false\n' \
      > "$XDG_CONFIG_HOME/wireplumber/bluetooth.lua.d/60-no-bluetooth.lua"
    pipewire & pids=($!)
    sleep 1
    wireplumber & pids+=($!)
    pipewire-pulse & pids+=($!)
    for _ in $(seq 50); do pactl info >/dev/null 2>&1 && break; sleep 0.2; done
    # A virtual source (silence) is the microphone: PipeWire refuses a monitor as default.
    pactl load-module module-null-sink media.class=Audio/Source/Virtual sink_name=mic channel_map=mono >/dev/null
    for _ in $(seq 50); do pactl list short sources | grep -qw mic && break; sleep 0.2; done
    pactl set-default-source mic
    stop_sound=(kill "${pids[@]}")
    ;;
  *) echo "SOUND is pulseaudio or pipewire"; exit 2 ;;
esac
echo "Sound server: $(pactl info | sed -n 's/^Server Name: //p'), microphone $(pactl get-default-source)"

cd "$REPO_ROOT/app"
set +e
flutter test integration_test/linux_platform_test.dart -d linux "$@"
rc=$?
"${stop_sound[@]}" 2>/dev/null
exit "$rc"
