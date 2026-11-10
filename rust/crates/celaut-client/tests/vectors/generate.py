"""Known-answer vectors for celaut-client, made with the nodo code.

Run from a nodo checkout (nodo dev 76dcac3b was used):

    PYTHONPATH=<nodo> python3 generate.py > vectors.json

It needs the nodo requirements (protobuf, cryptography). The keys, the
challenges and the Peer messages are fixed, so the output is the same on each run.
Ed25519 signatures are deterministic (RFC 8032).

- "pow": challenge, difficulty, the solution of `solve_pow`, and the digest of
  `pow_digest`, from src/gateway/client_pow.py.
- "peers": a serialized Peer, and its `canonical_peer_content_digest`,
  `canonical_peer_payload` and signature, from src/identity/node_identity.py.
"""
import json

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519

from protos import celaut_pb2
from src.gateway import client_pow
from src.identity import node_identity as ni
from src.utils import keyvalue

SECRET = bytes(range(32))
IDENTITY_SEED = bytes([7] * 32)
OTHER_SEED = bytes([9] * 32)


def identity(seed):
    key = ed25519.Ed25519PrivateKey.from_private_bytes(seed)
    pub = key.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw
    ).hex()
    return key, pub


def pow_vectors():
    out = []
    for difficulty, nonce in ((1, "00" * 16), (2, "11" * 16), (3, "22" * 16), (4, "33" * 16)):
        client_id = "0123456789abcdef0123456789abcdef"
        challenge = client_pow.make_challenge(client_id, difficulty, SECRET, nonce=nonce)
        solution = client_pow.solve_pow(challenge, difficulty)
        out.append({
            "challenge": challenge,
            "difficulty": difficulty,
            "solution": solution,
            "digest": client_pow.pow_digest(challenge, solution),
        })
    return out


def protocol(msg, tags, prose="", formal=b""):
    msg.tags.extend(tags)
    msg.prose = prose
    msg.formal = formal


def full_peer(pub):
    peer = celaut_pb2.Peer()
    for ip, port, expiry in (("203.0.113.7", 8090, 1790000000), ("node.example.org", 9000, 0)):
        uri = peer.uri.add(ip=ip, port=port, expiry_unix_timestamp=expiry)
        protocol(uri.transport, ["tcp"])
        protocol(uri.protocol_stack.add(), ["tls", "tls1.3"], "TLS 1.3", b"alpn=h2\nsni=celaut-node")
        protocol(uri.protocol_stack.add(), ["grpc"], "gRPC", b"")
    rate = peer.payment_contracts.add()
    rate.mu_per_unit.n = "1"
    rate.contract.ledger.tags.extend(["ergo", "erg"])
    rate.contract.ledger.prose = "Ergo, in nanoERG"
    rate.contract.ledger.formal = b"network=mainnet\nunit=nanoerg"
    keyvalue.from_dict(rate.contract.xattrs, {
        "script": bytes.fromhex("0008cd" + "02" + "ab" * 32),
        "token_id": b"ERG",
    })
    keyvalue.from_dict(peer.mu_per_call, {})
    for key, n in (("tunnel_open_mu", "10000"), ("net_mu_per_gib", "2000000"), ("build_mu", "10000000")):
        entry = peer.mu_per_call.add(key=key)
        entry.value.n = n
    proof = peer.reputation_proofs.add()
    proof.ledger.tags.append("ergo")
    keyvalue.from_dict(proof.xattrs, {"box_id": b"\x01\x02", "empty": b""})
    ni.declare_signature_scheme(peer, prose=True)
    res = peer.resources.add()
    protocol(res.architecture, ["linux/amd64"], "x86-64 Linux")
    res.resources.cpu_period = 100000
    res.resources.cpu_quota = 400000
    res.resources.mem_limit = 8 * 1024 ** 3
    res.resources.disk_space = 0  # present and 0
    keyvalue.from_dict(res.resources.benchmark, {"int_ops_per_sec": 123456789, "flt_ops_per_sec": 0})
    res2 = peer.resources.add()
    protocol(res2.architecture, ["linux/arm64"])
    peer.ts = 1790000123
    peer.public_key = pub
    return peer


def edge_peer(pub):
    """Presence, order, repeated keys and non-ASCII text."""
    peer = celaut_pb2.Peer()
    # Unsorted URIs, tags and entries; a repeated key (the last wins); an unset
    # limit next to a limit of 0; a benchmark entry with no value.
    for ip, port in (("b.example", 2), ("a.example", 1)):
        uri = peer.uri.add(ip=ip, port=port)
        protocol(uri.transport, ["udp", "tcp"], "xé")
    rate = peer.payment_contracts.add()
    rate.mu_per_unit.n = "250000000000000000000000"
    rate.contract.ledger.tags.extend(["z", "a"])
    rate.contract.ledger.prose = "café ✓"
    for key, value in (("b", b"\x00"), ("a", b"1"), ("b", b"\xff"), ("c", None)):
        entry = rate.contract.xattrs.add(key=key)
        if value is not None:
            entry.value = value
    for key, n in (("z_mu", "5"), ("a_mu", "7"), ("z_mu", "6")):
        peer.mu_per_call.add(key=key).value.n = n
    ni.declare_signature_scheme(peer, prose=False)
    res = peer.resources.add()
    protocol(res.architecture, ["linux/amd64"])
    res.resources.blkio_weight = 0
    res.resources.mem_limit = 18446744073709551615
    entry = res.resources.benchmark.add(key="novalue")
    entry2 = res.resources.benchmark.add(key="zero")
    entry2.value = 0
    entry3 = res.resources.benchmark.add(key="dup")
    entry3.value = 1
    entry4 = res.resources.benchmark.add(key="dup")
    entry4.value = 2
    res_no = peer.resources.add()
    protocol(res_no.architecture, ["linux/riscv64"])
    peer.ts = 9223372036854775807
    peer.public_key = pub
    return peer


def peer_vector(name, peer, key):
    digest = ni.canonical_peer_content_digest(peer)
    payload = ni.canonical_peer_payload(peer.public_key, peer.ts, digest)
    peer.signature = key.sign(payload.encode("utf-8")).hex()
    assert ni.verify_peer_payload(peer.public_key, payload, peer.signature)
    return {
        "name": name,
        "peer_hex": peer.SerializeToString().hex(),
        "public_key": peer.public_key,
        "ts": peer.ts,
        "digest": digest,
        "payload": payload,
        "signature": peer.signature,
    }


def main():
    key, pub = identity(IDENTITY_SEED)
    _, other_pub = identity(OTHER_SEED)
    # The activity window (#344, nodo 7533a177): spans in an order that the digest must
    # sort as text ("1320-60" before "600-720"), a span over midnight, and HIBERNATE; an
    # empty window ("always open"), which is not the same claim as no window at all.
    windowed = full_peer(pub)
    for start, end in ((600, 720), (1320, 60), (0, 30)):
        windowed.activity_window.spans.add(start_minute=start, end_minute=end)
    windowed.activity_window.on_close = celaut_pb2.ON_CLOSE_HIBERNATE
    edge = edge_peer(pub)
    edge.activity_window.SetInParent()
    peers = [
        peer_vector("full", full_peer(pub), key),
        peer_vector("edge", edge, key),
        peer_vector("window", windowed, key),
    ]
    scheme = ni.node_signature_scheme().components[0]
    print(json.dumps({
        "identity_seed_hex": IDENTITY_SEED.hex(),
        "public_key": pub,
        "other_public_key": other_pub,
        "scheme_formal_hex": bytes(scheme.formal).hex(),
        "pow": pow_vectors(),
        "peers": peers,
    }, indent=2))


main()
