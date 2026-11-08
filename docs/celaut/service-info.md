# What a service says about itself (2026-10-22)

The app shows the details of a service and checks, before it starts one, that its interface
is the chat convention of Chatui ([chat.md](chat.md)). Both need the `Service` message of the
service (`celaut.proto`), and most of that message is the filesystem of the container:
hundreds of megabytes (`claude-code.bee` has 536 MB), which the app never uses.

## 1. Reading the Service as a stream

`celaut-client/src/service_info.rs` does not decode the Service as one message. It walks the
protobuf fields of the Service part of the Buffers (`GetService` of a node, or a `.bee` file
through `package::read`), and:

- skips the bytes of `Container.filesystem` without keeping them (the size is kept);
- decodes only the small parts, each as its own message: `prose`, `Container.architecture`,
  `init`, `resources`, `config_declaration`, `node_protocol_stack`, the environment
  variables, `Service.api`, each `network` and each `possible_environment_workload`;
- keeps the memory at one Buffer (up to 1 MiB) and the parts that it kept, whatever the size of
  the service. A part larger than 256 KiB is skipped and counted, never taken for absent: a
  workload that large (it carries a whole service) is counted in `workloads_skipped`, and any
  other part in `parts_skipped`. If the skipped part is the interface, the chat check is
  "unknown", not "unsupported" (`api_skipped`). A list of more than 256 items is refused.
- bounds a node that misbehaves: each Buffer counts at least 16 bytes against the limit, so a
  stream of empty Buffers reaches it, and the reader gives up if no Buffer comes in 30 seconds.

The fields come in the order of their numbers, so the interface and the networks (3 and 4) are
after the container (2), which holds the filesystem. The reader must read the whole Service
part, but it never keeps the filesystem. A file of 536 MB takes about 1.5 seconds.

## 2. Skipping the filesystem on a node

In a package, the filesystem is not loose bytes: it is one top-level block (`buffer.Block`),
with blocks of its own inside it. In `claude-code.bee`, the first chunk of the Service holds
the container, the architecture, and the tag and length of the `filesystem` field; then comes
the marker of a block, with 535 923 139 bytes inside, exactly the length of the field; and
after the end marker one chunk of 496 bytes, which has the variables, the interface and the
networks. What the app needs is outside the block.

bee-rpc lets a receiver ask the sender to drop the rest of a block (`skip`, field 6 of the
Buffer, with the id of the block), and nodo honours it in `GetService`
(`src/gateway/iterables/get_service_iterable.py`: `StreamControl.watch()` on the request,
`respond(control=...)`). So, from a node, the app:

1. calls `GetService` with `block_skip` (`bee-rpc` 0.3.0: `call_raw` with `block_skip`, and
   `RawResponse::request_skip`; `Transport::call_raw_skippable` in `celaut-wire`);
2. reads the Service as before. When it meets the field of the filesystem (a megabyte or more,
   with no byte buffered), the next Buffer is the marker of a block: it asks the node to skip
   that block, ignores what was on the way until the end marker, and counts the field as read,
   because the length of a field that is a block is the length of the block;
3. reads the rest (the variables, the interface, the networks) as usual.

The node drops the Buffers that it has not sent and the markers of the children of the block
(a child that was open when the request arrived closes with its parent), and sends the end
marker of the block once. What was on the way arrives too: a few Buffers, not hundreds of
megabytes. A field that is not a block, a small one, a node that refuses or ignores the
request, and the library file (it is local) are read as before. The limit of 128 MiB is now
for a node that does not skip: after it the reader gives what came before the filesystem, with
`truncated` set.

A package that the user transfers to another node (`celaut_fetch_service`) needs every byte, and
uses `get_service_raw`, which never asks to skip.

## 3. What the app shows

`ServiceInfoScreen` (`app/lib/ui/celaut/service_info_screen.dart`), with a banner on top:

| Banner | When |
|---|---|
| Follows the chat convention | a slot has `tcp`, then `http2`, then `grpc`, and `chat` above them ([chat.md](chat.md), section 3) |
| Chatui does not support its interface | the interface is known and no port follows the convention, or there is no interface |
| The interface could not be read | the service was too large to read from a node, or its interface was too large to decode |

Then, in cards: **About** (prose, architecture, the executable that the node starts, the
configuration file, the size of the filesystem), **Resources** (at the start and at most: cores,
memory, disk, the speed of one core), **Interface** (each slot, numbered, with its stack from bottom to top,
`tcp → http2 → grpc → chat`, a mark on the chat slot, the prices per call), **Networks** (the domains that
the service declares to connect to: the names, the prose, the parameters, the protocols of the
peers, and `*` as every address), **Environment variables**, and **Other** (the protocols that it
expects from the node, and the instances that it can start).

It opens from the confirmation of a launch ("Service details"), from the info page of an
instance, and from the alert below.

## 4. The check before a launch

After the quotes (a quote is free) and before the first start, `RunServiceSection` reads the
service once and:

1. If the interface is **not** the chat convention, an alert says that Chatui does not support
   it and that, if run, the service shows in Compute and there is no conversation. The user runs
   it anyway, or cancels. Details opens the screen above with the info that was read, so the
   service is not read twice.
2. Then the environment variables ([env-variables.md](env-variables.md)), from the same read.

If the app cannot read the service (an error, one too large to read from a node, or an interface
too large to decode), it does not say "unsupported": it says that it cannot tell, and the user
runs it anyway or cancels.

The convention is one function for the service and for the instance: `api_chat_ports(api)` in
`session.rs` (a slot with `tcp`, `http2`, `grpc` and `chat` above them, in this order). `chat_slots(instance)` adds that
the instance has the port, because `ServiceTunnel` accepts only the ports of an instance.

## 5. Code

| Where | What |
|---|---|
| `rust/crates/celaut-client/src/service_info.rs` | The stream reader, `ServiceInfo`, `read_service_info`, `read_service_info_of_file` |
| `rust/crates/celaut-client/src/session.rs` | `api_chat_ports`, `chat_slots` |
| `rust/crates/wallet-ffi/src/api/celaut_service_info.rs` | `celaut_service_info` and the views for the screen |
| `app/lib/ui/celaut/service_info_screen.dart` | The details and the banner |
| `app/lib/ui/celaut/run_service_section.dart` | The check and the alert before a launch |

## 6. Checks

- `service_info.rs`: every part is read after a filesystem of 300 000 bytes in chunks of 1 byte
  to 1 MiB, with a block marker in the middle; a filesystem of 40 MiB does not grow the buffer;
  the limit gives what came first and says so; a workload with a whole service is counted and not
  read; a cut service, a false length, a group wire type and a prose that is not UTF-8 are
  errors, not panics; an interface of more than 256 KiB is counted and is not "unsupported"; a
  stream of empty Buffers reaches the limit and a silent node ends the read after 30 seconds
  (these two came from the review of the first version). `CELAUT_TEST_BEE=<file> cargo test -p celaut-client --lib real_package --
  --ignored --nocapture` reads a real package: `claude-code.bee` gives the architecture
  `linux/arm64`, 535 923 139 bytes of filesystem, one port with the chat convention (8080), one
  network and no variable, in 1.5 seconds.
- `celaut_service_info.rs`: the view has every part and the chat port; a known interface without
  the convention is unsupported and a cut one is unknown; the cores with a missing or zero period.
- `app/test`: `celaut_service_info_test.dart` (the details, the three banners, the empty and the
  cut service, the loader and its retry, info that is not read again, the info page of an
  instance) and `celaut_run_section_test.dart` (the alert: cancel, run anyway then the
  variables, details without a second read, a cut service is not "unsupported", a supported
  interface has no alert).
- `service_info.rs` with a node that honours `skip`: the node is `bee_rpc::skip::SkipFilter` on a
  lazy stream, as the reference sends. With an 8 MiB filesystem in a block with two children,
  the node is asked once, for the block of the filesystem, fewer than 10 Buffers leave it, and the
  variables, the interface, the networks and the workloads after the block are read. Without a
  skipper, with a node that refuses, with a large field that is not a block and with a small field,
  nothing is asked and the result is the same. A child that was open when the request arrived
  closes with its parent. A node that never ends the block is a cut service. At the wire level,
  `bee-rpc` has its own tests of `call_raw` with `block_skip`
  (bee-rpc-over-grpc-rs, `tests/relay.rs`).
- Not checked: a skip request against a real nodo (the in-process node follows its code, not its
  process), `call_raw_skippable` of `celaut-wire` on a TLS channel, and a phone.

## 6.1 Descendants

The slots of a descendant come from the same read of the interface of its service. The app
shows them on the instance info page ([descendants.md](descendants.md), section 12). It
opens only a web slot. A chat slot of a descendant is shown but not opened.

## 7. Open items

- A node that does not honour `skip` sends the whole filesystem. A service of more than 128 MiB
  on such a node, and not in the library, is described only by its prose and its architecture.
  The user can load the file.
- The check looks at the interface that the service declares. A service whose chat slot is
  declared and does not answer is not found here: the conversation shows that.
