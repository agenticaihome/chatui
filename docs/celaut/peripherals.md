# Peripherals routed to service instances (research, issue #106, 2026-11-05)

This is a research note. It has no code. It answers the questions of issue #106: can the app
give the camera, the microphone, the speaker and the phone of the device to service
instances, and what must the design be. The feature is **optional and off by default**.

Sources: the Android documentation and the AOSP source (links in section 10), nodo `dev` at
`43dfc8ff` (`nodo:docs/TUNNELING.md`, `nodo:docs/PRICING.md`, `nodo:config.example.yaml`), the
benchmark results of celaut-basics/demo-service PR #16 (2026-10-25), the distributed-llama
benchmark (celaut-basics/distributed-llama, 2026-10-30), and these notes: [chat.md](chat.md),
[env-variables.md](env-variables.md) section 3, [receipts.md](receipts.md),
[network.md](network.md).

## 0. Summary

| Question | Answer |
|---|---|
| Is it possible? | Yes for the **microphone, the camera and the speaker**, while the user has the app open or a foreground service that started while the app was in front. **No** for the audio of a phone call: Android gives it only to system apps |
| Phone | The app can **screen** incoming calls (allow, block, silence) with the call screening role, and an instance can make that choice from the number, in 5 seconds. Answer, transcribe or record a cellular call: not possible. The dialer role gives no call audio and asks for a full dialer, so we do not recommend it |
| Transport | gRPC streams on the slot of the chat interface, on a **second** tunnel connection for media. No nodo change is necessary |
| Bandwidth | The tunnel relayed **3.7 MiB/s (about 31 Mbit/s)** in the benchmark. Opus voice is 0.1 % of that. H.264 720p is 6.5 %. MJPEG 720p at 30 frames per second is 77 %: not usable |
| Cost | Defaults: `NET_MU_PER_GIB` 2 000 000 (both directions) and `TUNNEL_OPEN_MU` 10 000. Opus voice costs about **28 000 MU per hour**, which is 0.7 % of the price of a small instance. H.264 720p costs about 1.7 M MU per hour (41 %) |
| Latency | Not measured. Estimate: 100 to 200 ms from the microphone to the instance on a direct route. Tor adds some hundreds of ms. A follow-up issue measures it |
| Access | A global switch (off), then one grant for each instance and each peripheral. The grant ends with the conversation or the instance. The review card of PR #51 (trusted node, red egress, **Deny** first) comes before each first grant |
| Output owner | One owner for each output peripheral. Only the user changes the owner. The app asks before it moves the speaker, and the old owner gets the end of its stream |
| Main risk | The node that runs the instance can read all the media. Encryption does not change that. Only trusted nodes and short grants reduce it |
| Protocol | Proposal for chat.md round 11: `Capabilities.peripherals`, the service `PeripheralService` (`StreamInput`, `StreamOutput`), a request event, and the formats Opus, PCM, JPEG and H.264 |

## 1. Platform APIs and limits (question 1)

### 1.1 Android

| Peripheral | API | Permission | Limits |
|---|---|---|---|
| Microphone | `AudioRecord` (source `VOICE_COMMUNICATION` or `MIC`), encoder `MediaCodec` | `RECORD_AUDIO` (the app has it for voice messages) | Background: only with a foreground service of type `microphone` (`FOREGROUND_SERVICE_MICROPHONE`), and that service must start while the app is visible. Two ordinary apps never capture at the same time (Android 10 rules). An app with no foreground UI and no foreground service gets silence (Android 9 and later) |
| Camera | CameraX (`Preview`, `ImageAnalysis`, `VideoCapture`) or Camera2 | `CAMERA` (the app has it for the QR scanner) | Background: only with a foreground service of type `camera` (`FOREGROUND_SERVICE_CAMERA`), started while the app is visible. One app has a camera at a time; an app with a higher priority takes it |
| Speaker | `AudioTrack`, `AudioManager.requestAudioFocus(AudioFocusRequest)`, `AudioManager.setCommunicationDevice` (API 31) | None | Audio focus is cooperative: the app must pause or duck when it loses focus (a call, another player). Background play needs a foreground service of type `mediaPlayback` |
| Phone, screening | `CallScreeningService`, role `ROLE_CALL_SCREENING` (`RoleManager`, API 29) | The role. `READ_CONTACTS` is necessary to screen calls from contacts | The service gets the number, the direction and the times only. It must answer within **5 seconds**, else the call rings. It can allow, block, silence, or skip the call log |
| Phone, dialer | `InCallService`, role `ROLE_DIALER` | The role | The app must be a full dialer: in-call UI (`IN_CALL_SERVICE_UI`), `ACTION_DIAL`, emergency calls. The call audio stays closed (below) |
| Phone, call audio | `MediaRecorder.AudioSource.VOICE_CALL`, `Call.enterBackgroundAudioProcessing`, `CallResponse.Builder.setShouldScreenCallViaAudioProcessing` | `CAPTURE_AUDIO_OUTPUT` | **Not available.** The permission is "reserved for use by system components". The two audio processing calls are `@SystemApi` (hidden). This is true for the default dialer too |
| Own voice calls | Self-managed `ConnectionService` or Jetpack `core-telecom` | `MANAGE_OWN_CALLS` (normal permission) | Gives a foreground service of type `phoneCall`, the system call routing (earpiece, Bluetooth, speaker) and the right priority against cellular calls. Useful for a voice session with an instance (section 7, item 9) |

Rules that apply to all peripherals:

- **While in use.** Camera and microphone are while-in-use permissions. On Android 14 and
  later, the system checks the permission when the foreground service starts, and refuses a
  camera or microphone service that starts while the app is in the background. So an
  instance can never wake the camera or the microphone. The user must start the stream with
  the app in front. This is the behaviour that we want.
- **Type of the service.** The app has one foreground service now (`ConversationService`,
  type `specialUse`). A stream needs the types `microphone`, `camera` or `mediaPlayback` too,
  with their `FOREGROUND_SERVICE_*` permissions. A service can have more than one type, and
  the app can add the type only while a stream is open.
- **Indicators.** On Android 12 and later, the status bar shows a green dot while an app uses
  the camera or the microphone, and the Privacy Dashboard keeps a timeline. The Quick
  Settings toggles turn off the camera or the microphone for all apps: the app then gets
  black frames or silence, with no error. The app must show this state, not a broken stream.
- **Codecs.** `MediaCodec` encodes H.264 Baseline on every device (Android 3.0 and later). It
  encodes Opus from Android 10. On older devices the app needs libopus in the Rust core.
  GrapheneOS without Play Services must work (decisions.md): CameraX and `MediaCodec` are
  AndroidX and AOSP, with no Google service.
- **Google Play.** The SMS and Call Log permissions are only for the default SMS, Phone or
  Assistant handler, with a declaration form; caller ID and spam blocking is an accepted
  exception. The app is published on GitHub Releases, not on Play, so this is a limit only if
  that changes. Call screening needs no SMS or Call Log permission.

### 1.2 iOS (no iOS work now)

- Camera and microphone: `AVCaptureSession` and `AVAudioSession`. The microphone can stay on
  in the background with the `audio` background mode. The camera stops in the background.
- Phone: no third-party app gets the audio of a cellular call, and there is no call
  screening role. CallKit gives VoIP calls of the app, and the Call Directory extension gives
  block lists and caller ID from a local list (no instance in the loop at call time).
- Result: microphone, camera and speaker are possible in the same way. The phone part is not.

## 2. Transport, latency, bandwidth and cost (question 2)

### 2.1 Path

```
 phone (Chatui)                              node (nodo)                 instance
┌──────────────────────────┐   TLS, bee-rpc  ┌──────────────┐  TCP, h2c  ┌──────────────────┐
│ capture once             │  ServiceTunnel  │ relay, meter │            │ chat slot         │
│ (AudioRecord / CameraX)  │═══ conn 1 ═════▶│ the bytes,   │──────────▶ │  ChatService      │
│   │ encode (MediaCodec)  │   chat, files   │ sign         │            │  FileService      │
│   ▼                      │═══ conn 2 ═════▶│ receipts     │──────────▶ │  PeripheralService│
│ fan-out: one stream for  │   media only    │              │            │                   │
│ each granted instance    │                 └──────────────┘            └──────────────────┘
│ speaker ◀── one owner    │◀══ conn 2 of the owner instance only ════════ StreamOutput
└──────────────────────────┘
```

- The app captures each peripheral **once** and copies the encoded frames to each instance
  that has a grant. Android gives the input to one app; inside the app, many consumers are
  free.
- Each instance gets its own streams on its own tunnel. The nodes do not see the other
  instances.
- Media goes on a **second tunnel connection** to the same slot, not on the chat
  connection. One TCP connection has head-of-line blocking: a 4 MiB file upload would stop the
  audio for some seconds. The second connection costs `TUNNEL_OPEN_MU` once (10 000 MU, about
  9 seconds of a small instance). All the media streams of one instance share it.
- A UDP slot gives no gain: through the tunnel, each datagram is a bee-rpc message over
  TCP, with no loss and the same head-of-line blocking (`nodo:docs/TUNNELING.md`,
  Transports). WebRTC is not possible: the instance is reachable only through the tunnel.
- With Tor on, the media goes through Tor as all other traffic ([network.md](network.md)). It
  never goes direct.

### 2.2 Bandwidth and cost

Numbers from the sources:

| Source | Number |
|---|---|
| nodo defaults | `NET_MU_PER_GIB` 2 000 000, counted in both directions; `TUNNEL_OPEN_MU` 10 000 for each connection; billing every 64 MiB (`TUNNEL_CHARGE_INTERVAL_KB`) |
| demo-service PR #16, probe `tunnel` | 64 MiB through a tunnel at **3.7 MiB/s** (live node) and 3.5 MiB/s (clean node), against 1 284 MiB/s direct. Billed 1 999 872 MU/GiB; open charge 10 000 MU |
| demo-service PR #16, probe `delegation_pricing` | A small instance (`tiny`) costs about **1 129 MU/s** at the base prices of the test node: about 4.06 M MU per hour |
| distributed-llama v1 | Between the head and its workers, inside the node: 982 MB of tensors at load and about 78 MB of logits for each answer. Through a tunnel these would cost 1.83 M MU and 145 000 MU |

With these numbers (25 bytes of gRPC, HTTP/2 and protobuf framing for each frame; one
direction; payload sizes are typical values):

| Stream | Rate on the wire | MB per hour | MU per hour | Part of the tunnel (3.7 MiB/s) | Part of the price of `tiny` |
|---|---|---|---|---|---|
| Opus 24 kbit/s mono, 20 ms frames | 34 kbit/s | 15 | 28 500 | 0.1 % | 0.7 % |
| PCM 16 kHz mono, 16 bit | 266 kbit/s | 120 | 223 000 | 0.9 % | 5.5 % |
| PCM 48 kHz stereo, 16 bit | 1.5 Mbit/s | 696 | 1.30 M | 5.0 % | 32 % |
| JPEG 640×480 (40 KB), 1 frame/s | 320 kbit/s | 144 | 268 000 | 1.0 % | 6.6 % |
| JPEG 640×480 (40 KB), 5 frames/s | 1.6 Mbit/s | 721 | 1.34 M | 5.2 % | 33 % |
| H.264 480p30, 0.8 Mbit/s | 0.8 Mbit/s | 363 | 676 000 | 2.6 % | 17 % |
| H.264 720p30, 2 Mbit/s | 2.0 Mbit/s | 903 | 1.68 M | 6.5 % | 41 % |
| MJPEG 720p30 (100 KB a frame) | 24 Mbit/s | 10 800 | 20.1 M | 77 % | 495 % |

Results:

- Voice is cheap: Opus costs less than 1 % of the instance. PCM costs 8 times more for
  the same voice, so Opus is the default.
- Video is possible with H.264 or with JPEG at a low rate. MJPEG at full rate is not: it
  fills the tunnel and costs 5 times the instance.
- Fan-out multiplies the cost and the **upload of the phone**: three instances with H.264
  720p are 6 Mbit/s up, which many mobile links cannot hold. Each instance pays its own
  bytes.
- With 1 MU = 1 nanoERG (the setting of our node), 2 000 000 MU/GiB is 0.002 ERG for each GiB.
- The heavy traffic of a distributed service (the distributed-llama numbers) must stay
  inside the node. The phone sends small, encoded media, and the service does the rest.

### 2.3 Latency (estimate, not measured)

| Part | Estimate |
|---|---|
| Capture buffer and encoder (one 20 ms Opus frame) | 20 to 30 ms |
| Phone to node, one way | 10 to 60 ms (Wi-Fi or LTE); some hundreds of ms on Tor |
| Relay in the node | Small. Each charge is a database commit, and the relay stops while it runs (93 ms on a spinning disk). At 2 Mbit/s that is one stop every 4.5 minutes; for voice, one stop in hours |
| Jitter buffer in the instance or in the app | 40 to 80 ms |
| Total, microphone to instance | about 100 to 200 ms direct |

A voice dialogue also has the time of the model (speech to text, the answer, text to
speech). Follow-up 8 measures the real numbers on our node.

## 3. Access per instance (question 3)

### 3.1 States

| Level | Default | Where |
|---|---|---|
| Global switch "Peripherals" | **Off**. With it off, the app shows no request and opens no stream, and Android never asks for a new permission | Settings, Compute |
| Android permission | Asked at the first grant only (camera and microphone are already in the manifest) | System |
| Grant: one instance, one peripheral | None | The card of the request; the info page of the instance |

A grant has a lifetime that the user chooses on the card:

| Lifetime | End |
|---|---|
| Once | The end of this stream |
| While the conversation is open (proposed default for input) | The user leaves the conversation, or the app goes to the background with no foreground service of the right type |
| Until the instance stops | Stop, Delete, the instance does not answer, or the user revokes |

A grant never moves to another instance, also not to another instance of the same service:
an instance id is new at each start. There is no "always allow" (decision 3 in section 8).

### 3.2 The review before a grant

The first grant to an instance shows one card, as the review of sensitive values in
[env-variables.md](env-variables.md) section 3.2. Camera and microphone data is always
sensitive.

| Condition | Part | Colour | Buttons |
|---|---|---|---|
| The service has a network of egress (`*`, `pow:`, a host name) | "The service can send what it hears or sees out of the node", with the exits | Red | **Deny** (filled, focused); "Allow" in red text |
| The service has a network on the node | "The service shares networks on the node", with the networks | Text colour | Allow |
| The node is not fully trusted | "This node can read the stream", with its address | Text colour (or red, decision 2) | Allow |
| Always | The peripheral, the format and the rate, the estimate of MU per hour, the purpose that the service gave | Text colour | |

The app reads the networks from `Service.network` (`egressOf`) and the mark of the node
from `NodeRecord.trusted`, as for the variables.

### 3.3 Visible indicators

- The green dot of Android (automatic).
- The notification of the foreground service: "Microphone → 2 instances", with the names and
  one action **Stop all**.
- In the conversation: a bar under the title with the peripheral icon while a stream of this
  instance is open. A tap opens the grants of the instance.
- In the list of chats: a small microphone, camera or speaker mark on the robot of each
  instance that has an open stream.
- The info page of the instance: a "Peripherals" part with the grants, the open streams, the
  bytes, and the buttons to revoke.

### 3.4 Audit log

The app keeps one record for each stream in the Celaut database (one database for the app,
[ui.md](ui.md) section 1): instance, service hash, node, peripheral, format, start, end, why
it ended (user, conversation closed, owner moved, instance stopped, error), the bytes that
the app sent or got, and the `close` receipt of the tunnel when there is one. The info page
shows the records of the instance; Settings, Compute shows all of them. The export goes with
the export of receipts.

The receipts of nodo#419 make the log strong: each message that the app sends on the tunnel
is one event of the `in` chain ([receipts.md](receipts.md), section 2). The node signs the
count and the hash chain of the bytes that it took for this instance. This is evidence of
**how much** media went to **which** instance through **which** node. It is not evidence of
what the instance did with it.

## 4. The owner of an output peripheral (question 4)

Rules:

1. Each output peripheral (speaker, and later the vibrator or the screen) has zero or one
   owner. At the start the owner is none.
2. Only the user gives the owner: on the card of a request, or with "Use the speaker" in
   the info page. The app never gives an output to an instance by itself.
3. If another instance has the output, the card says "Move the speaker from A to B?".
   **Cancel** is the default. On Move, the app ends the stream of A (reason `moved`), then opens
   the stream of B. A is never paused under B: there is no queue of owners.
4. The output goes back to none when the owner stops, does not answer, is deleted, or its
   grant ends. It never goes to another instance by itself.
5. Audio focus: the app asks for focus for the owner. On a loss (a call, another player),
   the app pauses the output and tells the owner (`paused`, reason `focus_lost`); the owner
   must drop the live audio, not queue it. On a gain, the app resumes (`playing`). A transient
   loss with ducking makes the sound lower, with no message.
6. The sounds of the app itself (a voice message in a chat, a notice) take focus as a
   transient. The owner pauses for that time.
7. Routing (earpiece, speaker, Bluetooth) follows the system. In a voice session
   (follow-up 9) the routing is the routing of a call.

Inputs have no owner: each grant is apart, and the app can send the same microphone to
many instances. Proposal: 3 instances at most for each input (decision 4), because of the
upload of the phone (section 2.2).

## 5. Privacy and security (question 5)

| Risk | Reduction |
|---|---|
| The node that runs the instance reads all the media. TLS ends at the node; the instance is in a VM of the node, so the operator can read its memory too. Encryption from end to end does not help here | Trusted nodes only for camera and microphone (decision 2), and the review card of section 3.2 |
| The service sends the media out of the node (egress) | The red part of the review, **Deny** first. The app reads `Service.network` before a grant |
| The service shares the media with other instances on the node (on-node networks) | The grey part of the review, with the network names |
| The service is not the program that its hash says | Not solved: nodo has no attestation. The receipts give evidence of the bytes, not of the program. The reputation of the service in the catalog is the only signal |
| The stream goes on after the user forgets it | Short lifetimes (section 3.1), the bar, the notification with Stop all, the end with the conversation |
| An instance starts the camera or the microphone in the background | Not possible on Android 14 and later (while-in-use), and the app opens a stream only after a grant |
| Too much data: a full video when a picture is enough | Minimisation on the phone: the service asks for the lowest format and rate that it needs, and the app gives the lowest of the request and of the user setting. JPEG at 1 frame/s by default. The app can do preprocessing before the send: voice detection (send audio only when somebody speaks), a smaller image, no sound with the camera |
| Other people near the phone, and the other person in a call | The microphone and the camera hear and see people who did not give consent. The card says it. Call audio is not possible at all (section 1.1) |
| A caller number goes to an instance (call screening) | Only with the screening role and its own grant. Only the number and the direction. The default answer (on a timeout or an error) is "allow" |
| The cost grows with no limit | The estimate on the card, and the stream stops when the instance balance ends (nodo closes the tunnel). A limit of MU for each stream can come later |
| Proof of what was sent | The audit log and the receipts (section 3.4) |

Consent is for each session: a grant of the default lifetime ends with the conversation.

## 6. Protocol proposal (question 6): chat.md round 11

This is a proposal for review. It follows the rules of chat.md section 12: only new
optional fields and a new service, and a service that does not know them keeps the wire of
revision 6. The field numbers are proposals; they can change if another round takes them
first.

### 6.1 Where

The peripheral calls use the slot of the chat interface (`http2`, `grpc`, `chat`), in a new
gRPC service `PeripheralService` (paths `/PeripheralService/<Method>`), on the second
connection of section 2.1. A service that does not offer peripherals answers
`UNIMPLEMENTED`, as for any call that it does not know. The other choice, a separate slot with
the protocol `peripheral`, is decision 1.

### 6.2 Declaration

```proto
message Capabilities {
  // ... fields 1 to 6 of revision 6 ...
  // Round 11 (proposal #106). Empty: the service uses no peripheral.
  repeated PeripheralOffer peripherals = 7;
}

enum PeripheralKind {
  PERIPHERAL_KIND_UNSPECIFIED = 0;
  MICROPHONE = 1;   // input
  CAMERA = 2;       // input
  SPEAKER = 3;      // output
}

message PeripheralOffer {
  PeripheralKind kind = 1;
  // Media types, in lower case, with no parameters, best first (section 6.4).
  repeated string mime_types = 2;
  // Why the service needs it, for the user. 1 to 256 bytes, one line.
  string purpose = 3;
}
```

The app shows a peripheral of a service only if it is in `peripherals`. The answer does not
change for the life of the instance (chat.md section 6.7).

### 6.3 Calls and events

```proto
service PeripheralService {
  // Input: the client sends; the first message is the header.
  rpc StreamInput(stream InputMessage) returns (InputSummary);
  // Output: the client opens and controls; the service sends.
  rpc StreamOutput(stream OutputControl) returns (stream OutputMessage);
}

message StreamHeader {
  string stream_id = 1;        // 1 to 64 characters of A-Z, a-z, 0-9, "-", "_"
  PeripheralKind kind = 2;
  string mime_type = 3;
  uint32 sample_rate = 4;      // audio
  uint32 channels = 5;         // audio
  uint32 width = 6;            // video
  uint32 height = 7;           // video
  uint32 max_frames_per_second = 8;
  bytes codec_config = 9;      // H.264: SPS and PPS (Annex B). Opus: empty
  optional string request_id = 10;  // the PeripheralRequest that it answers
}

message MediaFrame {
  uint64 timestamp_us = 1;     // capture time, from the start of the stream
  bytes data = 2;              // one frame (section 6.4); 1 MiB or less
  bool key_frame = 3;          // H.264 IDR, and every JPEG
}

message InputMessage  { oneof part { StreamHeader header = 1; MediaFrame frame = 2; } }
message OutputMessage { oneof part { StreamHeader header = 1; MediaFrame frame = 2; } }
message InputSummary  { uint64 frames = 1; uint64 bytes = 2; }

message OutputControl {
  oneof part {
    OutputOpen open = 1;       // first message, once
    OutputState state = 2;
  }
}
message OutputOpen  { string stream_id = 1; PeripheralKind kind = 2;
                      repeated string mime_types = 3; optional string request_id = 4; }
message OutputState { bool playing = 1; string reason = 2; }  // focus_lost, user

// New events.
// ServerEvent: PeripheralRequest peripheral_request = 10;
// ClientEvent: PeripheralDeclined peripheral_declined = 6;
message PeripheralRequest {
  string request_id = 1;       // 1 to 64 characters, as event_id
  PeripheralKind kind = 2;
  string purpose = 3;          // 1 to 256 bytes
}
message PeripheralDeclined { string request_id = 1; }
```

Rules (the "must" words of chat.md section 1.1):

- The service can ask with `PeripheralRequest` on `Connect`, only for a kind of its
  `peripherals`. The app shows a card in the conversation. The service must not ask again for
  the same kind while a request is open.
- The user can also start a stream from the conversation or the info page, with no request.
- An answer is a stream (`request_id` set) or `PeripheralDeclined`. The app does not say why.
- The client ends an input stream with the end of its message stream, and revokes it with a
  cancel of the call (`CANCELLED`). After a cancel, the service must not use the stream, and
  must not ask again in the same conversation unless the user starts it.
- The client ends an output stream with a cancel too: for a move to another owner, the user
  revoke, or the end of the grant. The service must stop the output at once.
- On `OutputState{playing: false}` the service must drop live media, not queue it.
- The service must accept frames at the rate of the header or lower; the client can send
  fewer frames (voice detection, a slow network). A gap in `timestamp_us` is not an error.
- The service must not keep media after the end of the stream unless its `purpose` says so.
  This is a rule that the app cannot check (section 5).
- New reasons (chat.md section 9): `peripheral_not_offered` (`FAILED_PRECONDITION`) and
  `unsupported_media` for a format that the service did not offer.

### 6.4 Media formats

| Kind | Media type | One frame | Must / can |
|---|---|---|---|
| MICROPHONE, SPEAKER | `audio/opus` | One Opus packet (RFC 6716), 48 kHz, mono, 20 ms | A service that offers the kind must accept it |
| MICROPHONE, SPEAKER | `audio/pcm` | Signed 16-bit little-endian samples, interleaved; `sample_rate` and `channels` in the header. This document defines the name | Can |
| CAMERA | `image/jpeg` | One full JPEG (a stream of them is MJPEG) | A service that offers CAMERA must accept it |
| CAMERA | `video/h264` | One access unit, Annex B, Constrained Baseline; SPS and PPS in `codec_config` and before each IDR | Can |

The client sends payloads of 64 KiB or less to the tunnel ([receipts.md](receipts.md)
section 2); a larger frame is one gRPC message in more than one tunnel message, which is
normal.

### 6.5 Tests (for the conformance list)

New tests: a service with no `peripherals` answers `UNIMPLEMENTED`; a header with a type that
is not offered gets `unsupported_media`; a cancel of an input stream stops the use; an output
stream stops at once on a cancel; `playing: false` drops frames; a request for a kind that is
not offered is not sent. The echo service can be the reference: it can play the microphone
back on the speaker after one second.

## 7. Proposed follow-up issues (not created)

| # | Title | Scope |
|---|---|---|
| 1 | chat.md round 11: peripherals (proposal) | `Capabilities.peripherals`, `PeripheralService`, the two events, formats and tests of section 6, in chat.md and chat.proto. echo-chat gets a loopback (microphone back to the speaker) as the reference |
| 2 | Peripheral settings and grants, off by default | Global switch, grants for each instance and peripheral with the 3 lifetimes, records in the Celaut database, the review card that reuses PR #51 (trusted node, red egress, Deny first) |
| 3 | Microphone input stream | Capture once (`AudioRecord`), Opus with `MediaCodec` (libopus in Rust before Android 10), fan-out to the granted instances on the second tunnel connection, foreground service type `microphone` |
| 4 | Camera input stream | CameraX `ImageAnalysis` to JPEG (1 frame/s by default) and H.264 with `MediaCodec`, a visible preview while it streams, foreground service type `camera`, the black-frame state of the system toggle |
| 5 | Speaker owner | One owner, move with a question, audio focus (pause, duck, resume), routing, foreground service type `mediaPlayback`, the end of the stream on stop or revoke |
| 6 | Indicators and audit log | The bar in the conversation, the marks on the list of chats, the notification with Stop all, the "Peripherals" part of the info page, the log with the close receipts, the export with receipts |
| 7 | Call screening by an instance (optional) | `ROLE_CALL_SCREENING` and `CallScreeningService`: number and direction to one granted instance, an answer in 4 seconds or "allow", a record for each call. No dialer role, no call audio |
| 8 | Measure latency and cost on our node | Microphone-to-instance time direct and on Tor, the bytes of each format against the receipts and the bill, the effect of the billing commit and of fan-out to 3 instances |
| 9 | Voice session with an instance as a self-managed call (later) | `core-telecom` or `ConnectionService` with `MANAGE_OWN_CALLS`: microphone and speaker of one instance as a call, with the system routing, Bluetooth buttons and the right priority against cellular calls |

No nodo change is necessary for issues 1 to 8.

## 8. Decisions for Josemi

1. **Where the calls go.** In the chat slot as a new `PeripheralService` (proposed: one slot,
   a chat service can use peripherals with no new declaration), or a separate slot with the
   protocol `peripheral` (a service with no chat could use it).
2. **Untrusted nodes.** Camera and microphone only on fully trusted nodes (a hard rule), or a
   warning as for sensitive variables (the proposal makes the node part red for these).
3. **Lifetime of a grant.** The proposed default is "while the conversation is open", with no
   "always allow". Keep a grant for a service hash on trusted nodes?
4. **Fan-out limit.** 3 instances for each input, or no limit.
5. **Phone.** Keep call screening (follow-up 7) or drop the phone part. The dialer role is not
   recommended.
6. **Formats.** Opus and JPEG as the "must" formats; PCM and H.264 as "can".
7. **Audit log.** How long the app keeps the records (proposal: 30 days, or the life of the
   instance record).

## 9. Not feasible, or not recommended

| Item | Why |
|---|---|
| Answer, transcribe, record or filter by voice a cellular call | Not feasible. `VOICE_CALL` needs `CAPTURE_AUDIO_OUTPUT` (system only); `Call.enterBackgroundAudioProcessing` and `setShouldScreenCallViaAudioProcessing` are `@SystemApi` |
| The default dialer role (`ROLE_DIALER`) for this feature | Not recommended. The app must replace the dialer of the phone, with emergency calls, and it still gets no call audio |
| SMS | Out of scope. Only the default SMS app gets the SMS permissions on Play |
| A stream that an instance starts while the app is in the background | Not feasible on Android 14 and later (while-in-use), and not wanted |
| Capture at the same time as another app (for example during a call in another messenger) | Not feasible: two ordinary apps never capture at the same time |
| MJPEG at full rate | Not recommended: 77 % of the measured tunnel and 5 times the price of a small instance |
| WebRTC, RTP or a UDP slot for media | No gain: the instance is reachable only through the tunnel, and datagrams in the tunnel go over TCP |
| Encryption from end to end against the node | No gain: the instance runs on that node |
| Two instances on one output at the same time (mixing) | Not wanted (the issue) |
| Peripherals for delegated instances | The app uses `remaining_hops` 1, so there are none |
| A grant that moves to a new instance of the same service | Not recommended: the user gives consent to one instance on one node |
| iOS | No iOS work now. Camera, microphone and speaker are possible; the phone part is not |

## 10. References

- Foreground service types: https://developer.android.com/develop/background-work/services/fgs/service-types
- Starting foreground services from the background (while-in-use): https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Sharing audio input: https://developer.android.com/media/platform/sharing-audio-input
- Audio focus: https://developer.android.com/media/optimize/audio-focus
- `AudioManager`: https://developer.android.com/reference/android/media/AudioManager
- CameraX: https://developer.android.com/media/camera/camerax
- Supported media formats (Opus encoder from Android 10, H.264 Baseline): https://developer.android.com/media/platform/supported-formats
- `RoleManager`: https://developer.android.com/reference/android/app/role/RoleManager
- `InCallService`: https://developer.android.com/reference/android/telecom/InCallService
- `CallScreeningService`: https://developer.android.com/reference/android/telecom/CallScreeningService
- Telecom and `core-telecom`: https://developer.android.com/develop/connectivity/telecom
- AOSP source of the hidden call audio APIs: `frameworks/base/telecomm/java/android/telecom/Call.java`
  (`enterBackgroundAudioProcessing`), `CallScreeningService.java`
  (`setShouldScreenCallViaAudioProcessing`), `media/java/android/media/MediaRecorder.java`
  (`VOICE_CALL`)
- Privacy indicators: https://source.android.com/docs/core/permissions/privacy-indicators
- Camera and microphone toggles, Privacy Dashboard: https://developer.android.com/training/permissions/explaining-access
- Play policy, SMS and Call Log: https://support.google.com/googleplay/android-developer/answer/10208820
- iOS: https://developer.apple.com/documentation/callkit, https://developer.apple.com/documentation/avfaudio/avaudiosession
- nodo: `docs/TUNNELING.md` (transports, metering, security notes), `docs/PRICING.md`,
  `config.example.yaml` (`pricing.NET_MU_PER_GIB`, `pricing.TUNNEL_OPEN_MU`)
- celaut-basics/demo-service PR #16 (probes `tunnel` and `delegation_pricing`);
  celaut-basics/distributed-llama v1 (README, benchmark)
