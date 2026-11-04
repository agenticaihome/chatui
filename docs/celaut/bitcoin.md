# Bitcoin wallet and deposits in BTC (issue #92)

Chatui has a Bitcoin wallet next to the Ergo wallet, and it can buy MU from a node with
BTC. This note gives the design, what nodo does, and what nodo can add.

Sources: celaut-project/nodo `dev` (`nodo:docs/BITCOIN.md`,
`nodo:src/payment_system/contracts/bitcoin/interface.py`,
`nodo:src/utils/ledger_descriptors.py`, `nodo:src/payment_system/payment_process.py`).

## 1. Keys: the same words, BIP-84

The Bitcoin wallet uses the seed of the wallet of the app. There is no second seed and
no second backup.

| Chain | Standard | Path | Address |
|---|---|---|---|
| Ergo | EIP-3 | `m/44'/429'/0'/0/i` | P2PK (`9…`) |
| Bitcoin mainnet | BIP-84 | `m/84'/0'/0'/{0,1}/i` | P2WPKH (`bc1q…`) |
| Bitcoin testnet, signet, regtest | BIP-84 | `m/84'/1'/0'/{0,1}/i` | P2WPKH (`tb1q…`, `bcrt1q…`) |

- The paths do not overlap, so no key signs on two chains.
- The BIP-32 master key of a BIP-39 seed is the same for every chain. Thus Sparrow,
  Electrum, BlueWallet and nodo's `explorer` backend open the same Bitcoin funds from the
  same words. A test checks the BIP-84 vector (`bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu`)
  from the seed that the Ergo wallet stores.
- The seed stays in memory from the unlock until the lock (`wallet_create`,
  `wallet_restore`, `wallet_lock`), like the Ergo keys. Nothing about Bitcoin is written to
  disk. The `bdk_wallet` wallet has only public descriptors (`wpkh([fp/84'/c'/0']xpub/0/*)`).
  The master key signs the PSBT, then the wallet finalizes it.
- A separate seed was the other option. It gives a second backup to keep and a second
  unlock, for no gain: the paths already separate the keys.

## 2. Crates and chain access

- `bdk_wallet` 3.2.0 (descriptors, chain graph, coin selection, PSBT). Pinned with `=`.
- No `bdk_esplora` and no `esplora-client`: they bring reqwest 0.12, a second HTTP and
  TLS stack that does not follow the network route of the app. `wallet-btc::esplora` makes
  the Esplora calls with `wallet_net::http` (one reqwest, rustls with ring, the app's
  route, so Tor applies to Bitcoin too). `wallet-btc::scan` is the full scan of
  `bdk_esplora` 0.22.3 on top of it.
- The server is trusted only for what it reports. The app builds each transaction from
  the server's JSON again and refuses it if the bytes do not give the id that the server
  sent. A broadcast must answer the id of the transaction. The chain update starts from a
  block that the wallet and the server share (the genesis block first), so a server of
  another network fails.

## 3. Networks

| Network | Default server | Use |
|---|---|---|
| signet | `https://mempool.space/signet/api` | **Default.** Test coins, no value |
| testnet | `https://mempool.space/testnet/api` | Test coins |
| regtest | none (the user types one) | Local tests |
| mainnet | `https://mempool.space/api` | Real bitcoin, after a warning |

Settings → Bitcoin (the tune icon on the Bitcoin page) keeps the network and one server
per network (`btc_network_v1`, `btc_server_v1_<network>`), as the Ergo part keeps its
nodes and explorer. A change of network or server makes a new wallet and scans again.

## 4. Look

The Bitcoin page and what opens from it show `bitcoinPalette`: a blue-black page under
Bitcoin orange (#F7931A). The Ergo part keeps `ergoPalette` (black under Ergo's
red-orange). Like the Ergo palette, the Bitcoin palette is not in the user's list: the
app shows it while a Bitcoin page is open (`bitcoinThemeActive`, which wins over
`ergoThemeActive`).

## 5. What nodo does

nodo takes BTC on-chain (issue nodo#340):

- The node advertises a `ContractRate` with `ledger.tags[0] = "bitcoin"`, `token_id =
  BTC`, `contract_type = p2wpkh`, and `script` = the P2WPKH scriptPubKey of one fixed
  receiving address. `mu_per_unit` is MU per satoshi (`MU_PER_SATOSHI`). The ledger
  declaration has `chain=bitcoin` and `network=mainnet|testnet|signet|regtest`.
- To pay: one transaction with an output of the amount or more to `script`, and an
  `OP_RETURN` output whose data is the UTF-8 deposit token (80 bytes or less).
- Then `Payable` once. The node accepts it only if a transaction with the token has
  `MIN_CONFIRMATIONS` (default 1) and pays at least `amount / mu_per_sat` satoshi.
- The deposit token lives 6 hours (the maximum of the chains that the node offers).
- Lightning is not implemented (`nodo:docs/BITCOIN.md`, "Lightning … is not
  implemented").

## 6. The deposit in the app

1. Deposit to a node → check the node. If the node advertises BTC on the network of the
   Bitcoin wallet, the screen shows "Pay in BTC". If not, the BTC deposit screen says
   which networks the node takes, and offers nothing (`BtcPayment::of`: chain, network,
   `OP_RETURN` binding, `p2wpkh`, 22-byte script).
2. Prepare: `GenerateDepositToken`, then a transaction with the token in `OP_RETURN`.
   The confirmation sheet shows the amount, the MU, the fee and the total.
3. The fingerprint or the screen lock, then the send. The deposit is "sent" in the
   Celaut database (`btc_deposits`) before the broadcast. A segwit transaction id does
   not change with the signatures, so the id is known before.
4. The app asks the deposit's Esplora server for the confirmations every 15 s.
5. When the transaction has enough confirmations, `Payable` once. Not before: a call
   before the node's depth makes the node refuse the token for good, and the bitcoin
   stays with the node.

A deposit that was sent stays in the list "Deposits that wait" after a restart. The wait
works with the wallet locked: it reads only the server. "Forget" removes only a deposit
whose transaction the server does not know (the broadcast failed).

**How many confirmations.** nodo does not advertise `MIN_CONFIRMATIONS`. The app reads
`payment.min_confirmations=<n>` from the declaration when a node gives it (see 7), and
waits for 6 when it does not. 6 is more than nodo's default 1 and is about one hour, well
inside the 6-hour life of the token. The app never waits for more than 36 (about 6 hours).

## 7. Proposal for nodo

Issue: see the PR body (nodo issue "Bitcoin payments: announce the confirmations").

1. **Announce the depth.** Add `payment.min_confirmations=<MIN_CONFIRMATIONS>` to the
   Bitcoin payment part of the ledger declaration (`_bitcoin_payment()`). Today it says
   only "the payee selects how many confirmations". A payer cannot know the value, and
   two nodes with different values have the same problem: the payer waits for its own
   `MIN_CONFIRMATIONS`, not for the payee's.
2. **Do not consume the token too early.** When a transaction with the token exists but
   has fewer confirmations than `MIN_CONFIRMATIONS`, answer "not yet" and keep the token
   `pending`, instead of `rejected`. Then a payer that calls early can call again.
3. **Lightning later.** A separate payment contract with its own rate, as
   `nodo:docs/BITCOIN.md` says. Lightning makes small deposits from a phone cheap
   (on-chain, a deposit pays a fee of about 140 vB). It needs a Lightning node on the
   node side and an invoice per deposit token, so it is a larger change. The app part is
   not in this PR.

## 8. Tests

- `cargo test -p wallet-btc`: BIP-84 vector, coin type 1, descriptors are public,
  addresses of other networks refused, fee-rate limits, the Esplora parser checks the id.
- `cargo test -p wallet-btc --test regtest -- --ignored` with `BTC_E2E_ESPLORA` and
  `BTC_E2E_CLI` (a regtest bitcoind and Esplora, for example the `blockstream/esplora`
  image with `bitcoin-regtest`): receive a coinbase, send 0.1 BTC with an `OP_RETURN`,
  pending then confirmed on both wallets, send everything back.
- `cargo test -p celaut-client --test deposit_btc`: the contract of a node.
- `cargo test -p wallet-ffi --lib btc`: lock and unlock, settings, fee targets, the
  address of a node's script.
- `flutter test test/bitcoin_wallet_test.dart`: the screens, with a fake wallet.

## 9. End-to-end result (2026-11-04, regtest)

The app (debug APK, Android emulator) against a regtest bitcoind + Esplora
(`blockstream/esplora`, `bitcoin-regtest`) and a nodo node (dev `43dfc8ff`) in a container
with `ledgers.bitcoin` on regtest (`BACKEND: explorer`, `MU_PER_SATOSHI: 1000`):

- Wallet tab → "Bitcoin wallet": signet by default; Settings → regtest and the server.
- Receive: two payments of 0.5 BTC showed "not confirmed", then 1.00 BTC confirmed after
  one block.
- Send 0.1 BTC at 1 sat/vB: fee 141 sat, change back to the wallet; confirmed after one
  block.
- Deposit 10,000 sat: the node advertised BTC on regtest (1,000 MU per sat). The
  transaction had the output to the node and the 36-byte token in `OP_RETURN` (fee
  188 sat). After 6 confirmations the app called `Payable`; the node logged "Bitcoin
  payment for token … verified" and the credit went from 9,000,000 to 19,000,000 MU.

