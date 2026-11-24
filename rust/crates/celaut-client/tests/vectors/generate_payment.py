"""Known-answer vectors of the payment side, made with the nodo code.

Run from a nodo checkout (nodo working tree of 2026-11-24):

    cd <nodo> && PYTHONPATH=. venv/bin/python <this file> > payment_vectors.json

It uses a temporary copy of `config.example.yaml` (`tests.config_bootstrap`), nothing is
written in nodo. The vectors are used by:

- `celaut-client/tests/nodo_payment.rs`: the `Contract.ledger` and `Contract.protocol` that a
  node advertises (`ledger_descriptors`) must be read by `ErgPayment` and `BtcPayment`.
- `wallet-btc/tests/nodo_vectors.rs`: the BIP-84 key at index 0 of a mnemonic
  (`signer.derive_wallet_key`): address, scriptPubKey, hash160, and the `OP_RETURN` script of
  the deposit token (`signer.op_return_script`).
- `wallet-core/tests/nodo_vectors.rs`: the BIP-39 seed, and the Ergo key at
  `m/44'/429'/0'/0/0` (`bip_wallet_verification.derive_compressed_pubkey`), its P2PK ErgoTree
  (`ergo_tree.p2pk_proposition_bytes_from_pk`: `0008cd` + key) and its mainnet address.
"""
import hashlib
import json

from tests.config_bootstrap import load_example_config

load_example_config()

from mnemonic import Mnemonic

from protos import celaut_pb2
from src.payment_system.contracts.bitcoin import signer
from src.reputation_system import bip_wallet_verification as bip
from src.payment_system.contracts.ergo import ergo_tree
from src.utils import ledger_descriptors as ld

MNEMONICS = [
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
    "legal winner thank year wave sausage worth useful legal winner thank yellow",
]
B58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def base58(raw):
    n = int.from_bytes(raw, "big")
    out = ""
    while n:
        n, r = divmod(n, 58)
        out = B58[r] + out
    return "1" * (len(raw) - len(raw.lstrip(b"\0"))) + out


def ergo_p2pk_address(pk, prefix=0):
    """The documented Ergo address: base58(head | pk | blake2b256(head | pk)[:4]), with
    head = network prefix + address type 1 (P2PK)."""
    head = bytes([prefix + 1]) + pk
    return base58(head + hashlib.blake2b(head, digest_size=32).digest()[:4])


def wallets():
    out = []
    for phrase in MNEMONICS:
        seed = Mnemonic.to_seed(phrase, passphrase="")
        pk = bip.derive_compressed_pubkey(phrase)
        tree = ergo_tree.p2pk_proposition_bytes_from_pk(pk)
        entry = {
            "mnemonic": phrase,
            "seed_hex": seed.hex(),
            "ergo": {"pubkey": pk.hex(), "ergo_tree": tree.hex(),
                     "address_mainnet": ergo_p2pk_address(pk)},
            "bitcoin": {},
        }
        for network in ("mainnet", "testnet", "signet", "regtest"):
            key = signer.derive_wallet_key(phrase, "", network)
            entry["bitcoin"][network] = {
                "public_key": key.public_key.hex(), "pubkey_hash": key.pubkey_hash.hex(),
                "script_pubkey": key.script_pubkey.hex(), "address": key.address,
            }
        out.append(entry)
    return out


def op_returns():
    out = []
    for data in (b"a", b"deposit-token-0123456789", b"x" * 75, b"y" * 76, b"z" * 80,
                 bytes(range(40))):
        out.append({"data_hex": data.hex(), "script": signer.op_return_script(data).hex()})
    return out


def contract(ledger, protocol, script, token_id, mu):
    rate = celaut_pb2.ContractRate()
    rate.mu_per_unit.n = mu
    rate.contract.ledger.CopyFrom(ledger)
    rate.contract.protocol.CopyFrom(protocol)
    rate.contract.xattrs.add(key="script", value=script)
    rate.contract.xattrs.add(key="token_id", value=token_id)
    return rate.SerializeToString().hex()


def contracts(wallet):
    pk = bytes.fromhex(wallet["ergo"]["pubkey"])
    btc = wallet["bitcoin"]["mainnet"]
    return {
        "ergo_mainnet_erg": contract(
            ld.ergo_payment_ledger(), ld.ergo_payment_protocol(),
            bytes.fromhex(wallet["ergo"]["ergo_tree"]), b"ERG", "1000"),
        "bitcoin_mainnet_btc": contract(
            ld.bitcoin_payment_ledger(), ld.bitcoin_payment_protocol(),
            bytes.fromhex(btc["script_pubkey"]), b"BTC", "5000000"),
        "ergo_script": wallet["ergo"]["ergo_tree"],
        "bitcoin_script": btc["script_pubkey"],
    }


def main():
    w = wallets()
    print(json.dumps({"wallets": w, "op_returns": op_returns(), "contracts": contracts(w[0])},
                     indent=1, sort_keys=True))


main()
