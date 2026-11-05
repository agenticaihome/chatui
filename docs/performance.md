# Performance of navigation

`app/integration_test/navigation_perf_test.dart` times the moves between the pages of
the app on a device or an emulator. `app/test_driver/perf_driver.dart` writes the results.
This note says how to run it and what it found in October 2026.

## 1. What the test does

The test starts the app and makes each move four times (`PERF_ROUNDS`):

| Trace | Moves |
|---|---|
| `tabs_first` | Each tab of the bottom bar, the first time it shows |
| `tabs` | Chats, Wallet, Compute, Settings, again and again |
| `conversation` | A conversation that runs, its info page from the bar, back, back |
| `new_conversation` | The pencil button, back |
| `wallet_page` | The page of the wallet from the Wallet tab, back |
| `compute_pages` | Nodes and Services from the Compute tab, back |
| `settings_pages` | Security, Network and Tor, Nodes and About from the Settings tab, back |
| `launch_rocket` | The rocket of a launch over the Chats tab: it hovers for 2 s, then lifts off. No launch, nothing spent |

Each trace gives a timeline summary: the frames, the build and raster time of each frame,
and the frames over the budget of 16 ms. For each move, the test also takes the time from
the tap to the first frame that has the new page.

The test skips `conversation` when no conversation runs, and `wallet_page` when the app
has no wallet. It reads what the app has: it does not start, stop or delete an instance,
and it does not spend.

## 2. How to run it

Use profile mode: debug mode builds frames much more slowly, so its numbers say little. An
emulator draws with the CPU (SwiftShader), so its raster times are much higher than those
of a phone. Compare two builds on the same device, under the same load.

1. On the device, have one wallet, one node and one conversation that runs.
2. Build the test as an APK:

   ```sh
   cd app
   flutter build apk --profile --target-platform android-x64 \
     --target=integration_test/navigation_perf_test.dart
   ```

   For a phone, use `--target-platform android-arm64`.
3. Run it. `--keep-app-running` matters: without it, `flutter drive` uninstalls the app at
   the end, with its wallet and its Celaut database.

   ```sh
   flutter drive --profile --no-dds --keep-app-running \
     --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
     --driver=test_driver/perf_driver.dart \
     --target=integration_test/navigation_perf_test.dart -d <device>
   ```

   `--no-dds` lets the test connect to the VM service for the timeline.
4. Read `build/<trace>.timeline_summary.json` and `build/navigation_latency.json`.
   `build/<trace>.timeline.json` opens in `chrome://tracing` or Perfetto.

The APK of the test has the same package name and the same debug key as the debug build
of the app, so it installs over the app and keeps its data.

## 3. What it found (October 2026)

The setup: AVD `chatui-x86` (Android 15, x86_64, SwiftShader, 1080 × 2400), profile builds,
the app at 0.1.13, our node on the same host, two runs of each build. On SwiftShader a
frame of a plain page takes about 18 ms to raster, so most frames miss the budget of 16 ms
before and after; the slow frames below are the ones of 0.1 s and more.

**The cause: the scene of the home pages, painted again on each frame.** Build times were
small: under 2 ms on average. Raster times were not. The scene behind the overview, the
Compute tab and the page of the wallet (`HomeScene`) has blurred strokes: the glow of the
eclipse and the light along the crests. Impeller draws each blur in an offscreen render
pass. The traces with the scene had 80 to 500 render passes a frame, and new textures on
many frames; the traces without it had 1 render pass a frame. The scene did not change,
but the page painted it again on each frame of a route transition over it or under it, and
on the switch of a tab. On the emulator, such a frame took 0.7 to 1.1 s. The transition of
450 ms then showed one or two frames, and the next page came after more than a second.

**The fix:** `SceneImagePainter` paints the scene once into an image, for its size and its
look, and then draws the image. The image looks the same: in the render tests, no pixel
differs by more than 6 of 255. The app keeps four images at most, about 6 MB each on a
1080-pixel-wide screen.

| Move: tap to the first frame of the page | Before, median (max) | After, median (max) |
|---|---|---|
| Compute tab | 644 ms (674) | 36 ms (48) |
| Settings tab | 674 ms (707) | 26 ms (41) |
| Compute tab, first time | 1280 ms (1300) | 466 ms (469) |
| Page of the wallet | 659 ms (922) | 29 ms (39) |
| Compute → Nodes | 1370 ms (1453) | 44 ms (53) |
| Compute → Services | 1367 ms (1454) | 50 ms (58) |

The first time the Compute tab shows, the app makes the image: that frame is still slow.

**A conversation opened only once the tunnel to its chat slot was open.** The tap showed
nothing until then. On the emulator the node is on the same host, and the tunnel took 40
to 700 ms; a far node or Tor takes longer. The page now shows at once, with a spinner, and
the conversation follows in place.

**Checked, and not a cause here:**

- The synchronous calls to the core (`celaut_instances`, `celaut_known_nodes` and the
  others) read the database in memory. They do no I/O.
- The tabs are built the first time they show, then kept. A rebuild of the home screen
  costs about 1 ms.
- The catalog of skills is cached in the core. The list of nodes checks the nodes after it
  shows; the move does not wait for the check.

## 4. The improvements of 2026-10-23

Same setup, two runs of each build: master (`39d8ba8`) and the branch of the improvements
(rocket, robots, filter, Settings in three sections, the wallet without a name). Our node
on the same host, one conversation running, a host load of 6 to 14.

- **No move got slower.** Every trace had the same frames, build and raster times as
  master, within the spread of two runs (for example, `tabs` raster 19.2 → 20.1 ms on
  average, `settings_pages` 19.6 → 19.6 ms; no frame over 100 ms outside `tabs_first`,
  which has the 3 slow frames it had before).
- **The rocket** (`launch_rocket`, new): 270 frames, 1 render pass a frame and one
  texture in the whole trace, raster 19.4 ms on average and 28 to 38 ms at worst. It costs
  what a plain page costs on SwiftShader.

## 4. Web instances: slow or never loading (October 2026)

Pages of web instances (the browser on `127.0.0.1:<port>`, one tunnel stream per TCP
connection) loaded very slowly or not at all, most of all through Tor. The causes, and the
fixes:

1. **The dial limit was 10 s on every route** (`celaut-wire/src/channel.rs`,
   `ConnectOptions::default`). A route through Tor needs a circuit, the TLS handshake and
   the HTTP/2 setup: several round trips of 0.3 to 1 s. The first connection failed, and
   the page with it. Now `default_connect_timeout()` gives 60 s on a SOCKS route and 10 s
   on a direct one.
2. **HTTP/2 windows of 64 KiB** (tonic default). One stream could carry 64 KiB per round
   trip, about 128 KiB/s at an RTT of 0.5 s, and the 64 KiB window of the connection was
   shared by all the streams, so the 6 or more connections of a browser stalled each other
   (head-of-line blocking). Now 4 MiB per stream and 16 MiB per connection.
3. **No HTTP/2 PING.** A connection that died with no FIN or RST (the phone changed from
   Wi-Fi to mobile data, a circuit of Tor closed) stayed "open" until the TCP
   retransmission timeout, minutes later, and every stream on it hung. Now a PING goes
   every 30 s while a call is open, and a connection with no answer in 25 s is dropped;
   tonic then dials again for the next stream. No PING goes on an idle connection.
4. **A stream that failed to open closed the browser connection** (`celaut-client/src/
   local_port.rs`). The first error (no connection, `Unavailable`) reset the page. Now the
   relay opens the stream again, up to 3 times with a wait of 0.25, 0.5 and 0.75 s, and
   sends again the bytes that it already sent (up to 1 MiB), as long as no byte came back.
   Only a stream that never opened is opened again (no connection, a time limit, or a
   failure before any byte of the request went out): an error after the request was sent
   (`Unavailable`, a keepalive that timed out) ends the connection, because the service
   may have run the request. A refusal of the node (token, balance, slot) is not retried.

Not changed: the Dart `TunnelHttp` is only for the chat calls, and the web page opens in
the system browser, so neither limits the page. `SOCKS_CHECK_TIMEOUT` (5 s) is for the
local proxy, not for the circuit.

Unverified here: the real effect through Tor (no Tor or node in the build host). To check:
open a web instance on a node by an onion address and compare the time of the first
paint, before and after. A node that closes a connection for PINGs every 30 s would show
as `Unavailable` in `last_error`; then raise `KEEP_ALIVE_INTERVAL`.

## 5. The keyboard of the chat (November 2026, issue #88)

**How to measure.** Count the frames that the app shows while a script taps keys of the
keyboard of the app in a conversation. SurfaceFlinger keeps the times of the last 128 frames of
each surface:

```sh
L='SurfaceView[org.celaut.chatui/org.celaut.chatui.MainActivity](BLAST)#<id>'  # dumpsys SurfaceFlinger --list
adb shell "dumpsys SurfaceFlinger --latency-clear '$L'"
adb shell 'for i in $(seq 1 10); do input tap <x> <y>; sleep 1; done; sleep 2'
adb shell "dumpsys SurfaceFlinger --latency '$L'"   # one line for each frame
```

Also count the frames with no key for the same time: the cursor blinks twice a second.

**What it found.** The setup: AVD `chatui-x86-a` (Android 15, x86_64, SwiftShader, 1080 ×
2400), debug builds, a conversation with echo-chat, the build host under load. With no key, the
chat showed 2 frames a second (the cursor). Ten keys, one each second:

| Build | Frames in 12 s | Frames for each key (without the cursor) | Time between frames |
|---|---|---|---|
| Before (master keyboard), run 1 | 104 | about 8 | 155 ms |
| Before (master keyboard), run 2 | 100 | about 7.6 | 120 ms |
| After (this fix) | 36 | about 1.2 | 336 ms (mostly the pauses of the cursor) |

**The cause: each key made about 8 frames, and each frame of the chat is expensive.** Each key
was an `InkWell` in its own `Material`. A tap starts a splash and a highlight, and the two
animations ask for frames for more than one second. A frame of the chat page is not cheap: the
bars at the top and at the bottom blur what is under them, and the list fades at its ends (a
`ShaderMask`). Impeller draws each of them in its own render pass, so a frame of the chat had
13 render passes, and on SwiftShader it took about 100 to 150 ms to raster. With 8 frames for
each key, one key kept the raster thread busy for about one second. A key that came during that
time waited for the frames before it. The build of a frame was small (about 2 ms), so the Dart
code was not the problem. Also, the `InkWell` acted only when the finger went up.

A profile build with an integration test gave the same cost for each frame (13 render passes,
about 100 to 150 ms of raster, 2 ms of build), but not the lag: the binding of the test asks
for a frame on each vsync, so the raster thread is always busy, also with no key. Measure the
keyboard on the app, as above, and not with that binding.

**The fix (`virtual_keyboard.dart`).** A key is a `Listener` with a `DecoratedBox`. It acts when
the finger goes down, and it shows that it is down in one frame: no splash, no highlight. So a
key makes 2 frames (down and up). Backspace repeats as before. The chips of the suggestions
have no splash either. A blur that covers less of the bar was tried, and it did not change the
time of a frame: Impeller pays a full render pass for each blur, whatever its size.

## 6. The import of a service file (November 2026, issue #105)

**How to measure.** Record the timeline of the VM service of a profile build while the app
imports a `.celaut.bee` file, and read the times of the frames (`Animator::BeginFrame` on the
UI thread, `Rasterizer::DoDraw` on the raster thread). The timeline keeps a ring of events,
so read it every 3 seconds and join the parts. Note the time of the VM (`getVMTimelineMicros`)
just before the tap on the file in the picker, and follow the copy of the app with
`adb shell run-as org.celaut.chatui ls -l cache/packages` (the copy grows, then the check moves
it into the library). The VM service needs no tool of its own: `setVMTimelineFlags` with the
streams `Dart`, `Embedder` and `GC`, `clearVMTimeline`, then `getVMTimeline`, over its web
socket (`adb forward` to the port that `adb logcat -s flutter` gives).

**What it found.** The setup: AVD `chatui-x86-a` (Android 15, x86_64, SwiftShader), profile
builds, the files in Downloads, the build host under load (two other emulators and builds):

| File | Build | Card shows after the tap | Frames until the card | Longest time with no frame during the import | Frames during the import |
|---|---|---|---|---|---|
| `bffa09.celaut.bee`, 1.45 GB | Before | 267 s | 5 | 200 s | 56 a second, only during the check |
| | After | under 0.7 s | — | 79 ms | 59 a second (p99 30 ms) |
| `8c6043.celaut.bee` (tiny), 27 MB | Before | 2.9 s | 7 | 2.4 s | 45 a second, only during the check |
| | After | under 0.4 s | — | 39 ms | 59 a second (p99 27 ms) |

The copy itself took 255 s before and 105 s after for the large file: that is the load of the
build host, not the fix. The fix does not make the import shorter; it shows it from the start.

**The cause: the picker copied the file before the app knew that a file was chosen.** The
Android side of the picker answered only after it had copied the whole file into the cache of
the app (on a thread, with a stream). Until then, Flutter had nothing to show, so it drew no
frame: the screen stayed on the list of services. The card with the rocket came after the copy,
with the check. The UI thread was not blocked: during the check, the card had 56 frames a
second, the build of a frame was under 4 ms (p99), and no Dart event took more than 16 ms. The
read, the check and the hash of the blocks already run in Rust, off the UI thread.

**The fix.** The picker answers as soon as the user chose a file, with its uri, name and size
(`pickPackage`). The card shows, then the app asks for the copy (`copyPackage`), which tells
its bytes (`copied`) and can be cancelled (`cancelCopy`). The card says "Reading the service
file…" during the copy and "Checking the service file…" during the check; the rocket rises over
both. The launch (its rocket shows before the first call to a node) and the transfer of a
service to a node (its card shows before the transfer) did not have the problem.
