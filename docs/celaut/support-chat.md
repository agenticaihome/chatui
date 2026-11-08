# Support chat with the node

Language: ASD-STE100.

The support chat is a thread of text messages between the app, as a client of a node, and
the operator of that node. The user opens it from the node list (the button "Support chat"
of each node) when there is a problem with that node: an instance, a payment, a refund.

It is not the chat of [chat.md](chat.md). That chat is a service in an instance, over gRPC
through the tunnel, with attachments and streaming. The support chat is two RPCs of the
Gateway in `celaut.proto`, over bee-rpc, with no instance and no payment.

## 1. Protocol

The client needs only its `client_id`. A binding of the client to a peer stays possible
and is optional.

| RPC | Input | Output | Authentication |
|---|---|---|---|
| `Chat` | 1 `ChatMessage{client_id, body}` | 1 `ChatAck{stored, reason}` | client-in-message |
| `GetChatThread` | 1 `ChatThreadRequest{after_sequence}`, 2 `Client` | 1 `ChatThread{entries, latest}` | client |

- `Chat` is the RPC that already exists between nodes. A client with no binding to a peer
  is now accepted: the node keeps the message in the thread of the client. A client with a
  binding keeps the old behaviour (the peer is the sender). `conversation_id` and `service`
  are not used by the app.
- `ChatEntry` has `sequence` (from 1, never changes, grows by 1), `ts` (Unix seconds),
  `from_operator` and `body`.
- `GetChatThread` gives the entries with a `sequence` more than `after_sequence`, in order,
  and `latest`, the last `sequence` of the thread (0 if it is empty). A node can cut a long
  thread. `latest` then tells the client that more is left. A node gives only the thread of
  the client in the request. The call is free. An empty `ChatThread` has no bytes.
- A body is not empty and has at most 4096 bytes (`chat.MAX_MESSAGE_BYTES` of nodo). A
  message that the node does not store gives `stored=false` and a `reason`. That is not an
  RPC error.

The messages are in `celaut-proto/protos/celaut.proto` (`ChatEntry`, `ChatThreadRequest`,
`ChatThread`). They are added at the end of the existing numbering and the new RPC is the
last one of the service, so a node that does not know them skips them.

## 2. App

- **Wire:** `celaut-wire/src/gateway.rs`: `chat`, `get_chat_thread`.
- **Session:** `NodeSession::support_send` and `support_thread` (`celaut-client`). They
  give `None` if the node does not know the RPC (a gRPC "unimplemented" or a bee-rpc
  "method not found").
- **FFI:** `celaut_support_thread(node, after_sequence)` and `celaut_support_send(node,
  body)` (`wallet-ffi/src/api/celaut_support.rs`). A node with no support chat gives
  `supported: false`, not an error. The app checks the text before the call: not empty
  after a trim, at most 4096 bytes.
- **Screen:** `SupportChatScreen` (`app/lib/ui/celaut/support_chat_screen.dart`). The
  button is in the card of each node of `KnownNodesScreen`, in the compute settings. The
  screen shows the bubbles of the thread, an input and a send button. It asks the thread
  when it opens, after each send that the node stored, and each 30 seconds while it is
  open, always with `after_sequence` equal to the last message that it has. There is no
  poll in the background and no notification.
- **Storage:** none. The node keeps the thread. A message that the node refused stays in the
  input, with the reason under it.
- **Node with no support chat:** the screen says "This node has no support chat" and has no
  input.
- **Privacy:** the app sends the text and the `client_id` of that node, nothing else. The
  screen says that the operator reads the messages.

## 3. nodo

The node side is in the pull request of nodo that adds the three messages, the RPC, the
storage of the thread of a client and the commands of the operator to read and answer. The
`.proto` of this repository is the same as the one of that pull request. Until a node has
it, the app shows "This node has no support chat" for that node.

## 4. Open questions

- Does nodo keep the thread of a client that is deleted for no credit?
- Does the operator want a notification for a new message of a client?
