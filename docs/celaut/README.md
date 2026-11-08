# Celaut light client: design notes

These notes are the reference for the Celaut part of chatui. The app is an Android
light client of Celaut. It talks to Celaut nodes (celaut-project/nodo) as a client,
never as a peer, and it pays them from its own Ergo wallet.

Sources read for these notes:

- celaut-project/nodo at `b5c1e8a5` (paths below start with `nodo:`).
- bee-rpc-over-grpc-py v0.0.1/v0.0.2 (`bee_rpc:`).
- celaut-project/skills at its `main` branch of 2026-10-11 (`skills:`).

| File | Content |
|---|---|
| [decisions.md](decisions.md) | Product decisions |
| [wire.md](wire.md) | Transport, TLS identity, bee-rpc framing, Gateway RPCs, client lifecycle, deposits, ServiceTunnel |
| [balancer.md](balancer.md) | Execution balancer: candidates, filters, scoring, MU conversion, cache, reputation |
| [catalog.md](catalog.md) | Node directory and service catalog on Ergo (reputation proofs, Skill DB) |
| [ui.md](ui.md) | Wallets (full and read-only), one database for instances, home screen focused on compute |
| [ui-chat-first.md](ui-chat-first.md) | Chat-first UI: the bottom bar (Chats, Wallet, Compute, Settings), the list of conversations, the conversation (messages and files) and the info page of an instance, stop and delete |
| [chat.md](chat.md) | Chat interface (specification in ASD-STE100, revision 6): gRPC over HTTP/2 (h2c) through the tunnel, defined by [chat.proto](chat.proto); history in the service, real time with `Connect`, streamed answers and reasoning, pinned messages, files by SHA3-256 hash in `FileService`, gRPC error mapping, conformance tests, and the migration from revision 5. Each chat service must follow it |
| [network.md](network.md) | The network route and optional Tor (M5): direct, Arti inside the app, or a SOCKS5 proxy, and the rule that Tor on never goes direct |
| [package.md](package.md) | Give a service to a node that does not have it: from a node that has it, or from a `.celaut.bee` file, with cancel markers so that a node never keeps half a service |
| [env-variables.md](env-variables.md) | Environment variables: a container in the app, and one question per variable at a launch (choose, type or skip) |
| [invite.md](invite.md) | The peer invitation of nodo in a QR code: what the app reads, the binary scanner, and how it chooses the address that can work on the route |
| [service-info.md](service-info.md) | The details of a service, read from its Service as a stream that skips the filesystem, and the check of the chat interface before a launch |
| [receipts.md](receipts.md) | The execution receipts of nodo#419: the start receipt, the checkpoints and the close of each tunnel, how the app checks them against what the phone sent and got, what it keeps, the Receipts part of the info page, and the export for `nodo receipt verify` |
| [descendants.md](descendants.md) | The descendants of nodo#631: `GetBalanceStatement` with `instance_ref` and `remaining_hops`, the new statement fields, the digest, the signature and the hash chain with test vectors, the `child_bound` and `stop` movements, `DescendantTunnel`, the cost and the rule that each statement read needs a confirmation of the user with a maximum of MU |
| [bitcoin.md](bitcoin.md) | The Bitcoin wallet (issue #92): the same words on BIP-84, `bdk_wallet` over Esplora, networks (signet by default), the Bitcoin look, deposits in BTC to a node with the token in `OP_RETURN`, and what nodo can add |
