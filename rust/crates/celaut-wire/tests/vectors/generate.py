"""Known-answer vectors for celaut-wire, made with the nodo code.

Run from a nodo checkout (nodo working tree of 2026-11-24, celaut.proto sha256 4c48c295):

    cd <nodo> && PYTHONPATH=. venv/bin/python <this file> > wire_vectors.json

The keys, tokens, times and nonces are fixed, and Ed25519 signatures are deterministic
(RFC 8032), so the output is the same on each run. Each vector holds a serialized message
(`*_hex`), the intermediate texts and digests of nodo, and the signature of nodo. The Rust
tests (`tests/nodo_vectors.rs`) decode the message and must give each value, and must verify
each signature. Covered:

- statements: `ledger.movement_hash`, `instance_ref`, `account_ref`, `genesis_hash`,
  `statement_signature.statement_digest`, `node_identity.statement_payload`.
- receipts: `execution_receipt.canonical_receipt`, `receipt_digest`, `receipt_payload`,
  `execution_name`, `execution_name_by_ref`, `envs_digest`, `chain_link`.
- offers: `signed_offer.offer_digest`, `offer_payload` (EstimatedCost).
- proofs: `offchain_proof.pow_base`, `proof_digest`, `pow_bits`, `reputation_proof_payload`
  (ReputationProof with opinions, evidence, ledger_proofs and pow_nonce),
  `fault_proofs.digest`, `node_identity.canonical_contract_message`.
"""
import json

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519

from tests.config_bootstrap import load_example_config

load_example_config()  # a temporary copy of config.example.yaml, nothing is written in nodo

from protos import celaut_pb2
from src.database import ledger
from src.identity import execution_receipt as er
from src.identity import node_identity as ni
from src.identity import statement_signature as ss
from src.reputation_system import fault_proofs, offchain_proof
from src.utils import keyvalue
from src.utils.cost_functions import signed_offer

SEED = bytes(range(32))
OTHER_SEED = bytes([9] * 32)


def keypair(seed):
    key = ed25519.Ed25519PrivateKey.from_private_bytes(seed)
    pub = key.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw).hex()
    return key, pub


KEY, PEER_ID = keypair(SEED)
OTHER_KEY, OTHER_ID = keypair(OTHER_SEED)


def hx(message):
    return message.SerializeToString().hex()


# ---- statements ---------------------------------------------------------------------------

def make_statement(key, peer_id, *, service_id="", instance_ref="", relayed=False,
                   moves=True, from_seq=1, ts=1700001000):
    account = "parent-token-1"
    account_ref = ledger.account_ref(account)
    prev = ledger.genesis_hash(account)
    s = celaut_pb2.BalanceStatement(
        ts=ts, relayed=relayed, account_ref=account_ref, service_id=service_id,
        instance_ref=instance_ref, from_seq=from_seq, retention_days=30, oldest_seq=1)
    rows = (
        (1700000000, 995000, 995000, "credit", "", "{\"actor\":\"operator\"}"),
        (1700000100, -20, 994980, "start", ledger.instance_ref("child-token-1"), ""),
        (1700000200, -10, 994970, "statement_query", "", "{\"rows\":0}"),
        (1700000300, 0, 994970, "stop", "", "{\"reason\":\"stopped\",\"mu\":\"\xe9\"}"),
    )
    seq = 0
    for ts_m, amount, balance, kind, iref, detail in rows:
        seq += 1
        mv = s.movements.add(seq=seq, ts=ts_m, kind=kind, instance_ref=iref, detail=detail,
                             prev_hash=prev)
        mv.amount.n = str(amount)
        mv.balance_after.n = str(balance)
        prev = ledger.movement_hash(prev, seq, ts_m, amount, balance, kind, iref, detail)
    if not moves:
        del s.movements[:]
    s.to_seq = seq if moves else 0
    s.head_seq = 4
    s.head_hash = prev
    s.balance.n = "994970"
    return s


def statement_vector(name, s):
    s.signature = ""
    digest = ss.statement_digest(s)
    payload = ni.statement_payload(PEER_ID, digest)
    s.signature = KEY.sign(payload.encode()).hex()
    assert ss.verify(s, PEER_ID)
    return {
        "name": name, "statement_hex": hx(s), "peer_id": PEER_ID,
        "movement_hashes": [ss.movement_hash(m) for m in s.movements],
        "digest": digest, "payload": payload, "signature": s.signature,
    }


def statements():
    out = []
    out.append(statement_vector("plain", make_statement(KEY, PEER_ID)))
    out.append(statement_vector("relayed", make_statement(KEY, PEER_ID, relayed=True)))
    out.append(statement_vector("full", make_statement(
        KEY, PEER_ID, service_id="cd" * 32, instance_ref=ledger.instance_ref("child-token-1"))))
    out.append(statement_vector("full_relayed", make_statement(
        KEY, PEER_ID, service_id="cd" * 32, instance_ref=ledger.instance_ref("child-token-1"),
        relayed=True)))
    out.append(statement_vector("head_only", make_statement(KEY, PEER_ID, moves=False)))
    return out


# ---- receipts -----------------------------------------------------------------------------

TOKEN = "instance-token-for-vectors"


def base_receipt(kind, ts=1798329600):
    r = celaut_pb2.ExecutionReceipt(kind=kind, ts=ts)
    r.execution_name = er.execution_name(TOKEN, PEER_ID)
    return r


def receipt_vector(name, r, key=KEY):
    er.sign_with(r, key)
    assert er.verify(r)
    return {
        "name": name, "receipt_hex": hx(r), "canonical": er.canonical_receipt(r),
        "digest": er.receipt_digest(r), "payload": er.signed_bytes(r).decode(),
        "signature": r.signature,
    }


def receipts():
    out = []
    salt = bytes(range(16))
    envs = {"A": b"1", "B": b"\xff\x00"}
    start = base_receipt("start")
    start.service_id.type = bytes.fromhex("a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
    start.service_id.value = bytes.fromhex("63e5b5a4137cfa77cb9d10adae081d0df082a826d8441721460d5933f5800056")
    start.envs_salt = salt
    start.envs_digest = er.envs_digest(envs, salt)
    start.initial_mu.n = "12345678"
    out.append(receipt_vector("start_minimal", start))

    full = base_receipt("start")
    full.CopyFrom(start)
    full.cpu_period = 100000
    full.cpu_quota = 400000
    full.mem_limit = 8 * 1024 ** 3
    full.disk_space = 100 * 1024 ** 3
    full.kernel = "ab" * 32
    full.devices.extend(["pci:10de:2509+aa:bb", "usb:1234"])
    out.append(receipt_vector("start_with_resources", full))

    cp = base_receipt("checkpoint")
    cp.plane = "tunnel"
    cp.session = "00112233445566778899aabbccddeeff"
    cp.slot = "http"
    cp.seq = 3
    cp.in_events, cp.in_bytes = 2, 15
    cp.in_head = er.chain_link(er.CHAIN_GENESIS, 1, "in", 4, er.payload_digest(b"ping"))
    cp.out_events, cp.out_bytes = 1, 4
    cp.out_head = er.chain_link(er.CHAIN_GENESIS, 1, "out", 4, er.payload_digest(b"pong"))
    cp.mu_charged.n = "70"
    cp.coverage = "client-tunnel"
    out.append(receipt_vector("checkpoint_tunnel", cp))

    close = base_receipt("close")
    close.CopyFrom(cp)
    close.kind = "close"
    close.seq = 4
    out.append(receipt_vector("close_tunnel", close))

    obs = base_receipt("checkpoint")
    obs.plane = "observe"
    obs.session = "aabbccdd"
    obs.seq = 1
    obs.in_events, obs.in_bytes = 5, 500
    obs.in_head = "11" * 32
    obs.out_head = "22" * 32
    obs.coverage = "instance-tap"
    obs.capture_mode = "pcap"
    obs.degraded_reason = "snap l\xe9ngth"
    out.append(receipt_vector("checkpoint_observe", obs))
    return out, envs, salt


# ---- offers -------------------------------------------------------------------------------

def make_offer(**kw):
    o = celaut_pb2.EstimatedCost()
    o.cost.n = "1000000"
    o.init_maintenance_cost.n = "2500"
    o.max_maintenance_cost.n = "9000"
    o.maintenance_seconds_loop = 60
    for key, value in kw.pop("scarcity", (("cpu", 250000), ("mem", 1000000), ("net", 0))):
        o.launch_scarcity.add(key=key, value=value)
    o.price_bounded = kw.pop("bounded", True)
    o.price_volatility = kw.pop("volatility", 0.05)
    o.volatility_period_seconds = kw.pop("period", 3600)
    o.valid_until = kw.pop("valid_until", 1800000000)
    o.closes_at = kw.pop("closes_at", 1800003600)
    o.on_close = kw.pop("on_close", celaut_pb2.ON_CLOSE_HIBERNATE)
    return o


def offer_vector(name, o, sign=True):
    digest = signed_offer.offer_digest(o)
    payload = ni.offer_payload(PEER_ID, digest)
    if sign:
        o.signature = KEY.sign(payload.encode()).hex()
        assert signed_offer.verify(o, PEER_ID)
    return {"name": name, "offer_hex": hx(o), "peer_id": PEER_ID, "digest": digest,
            "payload": payload, "signature": o.signature,
            "committed_until": signed_offer.committed_until(o, PEER_ID)}


def offers():
    out = [offer_vector("full", make_offer())]
    # The load is not in key order, repeats a key (the last wins) and has an unset value.
    o = make_offer(scarcity=(("z", 5), ("a", 1), ("z", 7)), bounded=False, volatility=0.0,
                   on_close=celaut_pb2.ON_CLOSE_STOP)
    o.launch_scarcity.add(key="unset")
    out.append(offer_vector("unsorted_scarcity", o))
    o = make_offer(volatility=0.30000001192092896, valid_until=0, closes_at=0,
                   on_close=celaut_pb2.ON_CLOSE_REFUSE)
    out.append(offer_vector("no_promise_unsigned", o, sign=False))
    # Signed by another key: the signature does not match peer_id.
    o = make_offer()
    d = signed_offer.offer_digest(o)
    o.signature = OTHER_KEY.sign(ni.offer_payload(OTHER_ID, d).encode()).hex()
    v = offer_vector("signed_by_other", o, sign=False)
    v["other_peer_id"] = OTHER_ID
    out.append(v)
    return out


# ---- reputation proofs --------------------------------------------------------------------

def contract(ledger_tag, protocol_tag, xattrs):
    c = celaut_pb2.Contract()
    c.ledger.tags.extend(ledger_tag)
    c.ledger.prose = "Ergo mainnet"
    c.ledger.formal = b"network=mainnet"
    c.protocol.tags.extend(protocol_tag)
    c.protocol.formal = b"kind=p2pk"
    for key, value in xattrs:
        c.xattrs.add(key=key, value=value)
    return c


def proof_vector(name, p, mine_bits=0):
    p.publisher = PEER_ID
    p.signature_scheme.CopyFrom(er.receipt_scheme())
    p.pow_nonce = 0
    if mine_bits:
        assert offchain_proof.mine(p, mine_bits)
    digest = offchain_proof.proof_digest(p)
    payload = ni.reputation_proof_payload(PEER_ID, digest)
    p.signature = KEY.sign(payload.encode()).hex()
    assert offchain_proof.verify(p)
    return {"name": name, "proof_hex": hx(p), "pow_base": offchain_proof.pow_base(p),
            "digest": digest, "pow_bits": offchain_proof.pow_bits(p), "pow_nonce": p.pow_nonce,
            "payload": payload, "signature": p.signature}


def proofs(statement_objects, receipt_objects):
    out = []
    simple = celaut_pb2.ReputationProof(ts=1790000000)
    simple.opinions.add(type="celaut-node", object=OTHER_ID, amount=12, positive=True)
    simple.opinions.add(type="celaut-node", object="b\xe9", amount=3, positive=False,
                        content=b"\x00\xff")
    out.append(proof_vector("scores", simple))

    mined = celaut_pb2.ReputationProof(ts=1790000001)
    mined.opinions.add(type="celaut-node", object=OTHER_ID, amount=1, positive=True)
    out.append(proof_vector("mined_10_bits", mined, mine_bits=10))

    evid = celaut_pb2.ReputationProof(ts=1790000002)
    ev = celaut_pb2.FaultEvidence(reason="equiv|oc\\ation", accused=OTHER_ID)
    ev.statements.extend(statement_objects[:2])
    ev.receipts.extend(receipt_objects[:3])
    op = evid.opinions.add(type="celaut-node", object=OTHER_ID, amount=0, positive=False,
                           content=b'{"account_ref":"x","reason":"r","seq":1}')
    op.evidence.CopyFrom(ev)
    evid.opinions.add(type="celaut-node", object=OTHER_ID, amount=0, positive=False)
    out.append(proof_vector("fault_evidence", evid))
    fault_digest = fault_proofs.digest(ev)

    ptr = celaut_pb2.ReputationProof(ts=1790000003)
    ptr.opinions.add(type="celaut-node", object=OTHER_ID, amount=2, positive=True)
    # Pointers in an order that the digest must sort, and an xattrs list that repeats a key.
    ptr.ledger_proofs.append(contract(["ergo"], ["z"], [("token_id", b"\xaa"), ("script", b"\x01")]))
    ptr.ledger_proofs.append(contract(["btc", "a"], ["p2k"], [("k", b"1"), ("k", b"2"), ("e", b"")]))
    out.append(proof_vector("ledger_proofs", ptr))
    contracts = [
        {"contract_hex": hx(c), "canonical": ni.canonical_contract_message(c)}
        for c in ptr.ledger_proofs
    ]
    empty = celaut_pb2.ReputationProof(ts=0)
    out.append(proof_vector("empty", empty))
    return out, fault_digest, hx(ev), contracts


def main():
    stmts = statements()
    rcpts, envs, salt = receipts()
    stmt_objs = []
    for v in stmts:
        s = celaut_pb2.BalanceStatement()
        s.ParseFromString(bytes.fromhex(v["statement_hex"]))
        stmt_objs.append(s)
    rcpt_objs = []
    for v in rcpts:
        r = celaut_pb2.ExecutionReceipt()
        r.ParseFromString(bytes.fromhex(v["receipt_hex"]))
        rcpt_objs.append(r)
    proof_list, fault_digest, ev_hex, contracts = proofs(stmt_objs, rcpt_objs)
    child = ledger.instance_ref("child-token-1")
    account = ledger.account_ref("parent-token-1")
    doc = {
        "peer_id": PEER_ID, "other_peer_id": OTHER_ID, "token": TOKEN,
        "refs": {
            "instance_ref": child, "account_ref": account,
            "genesis_hash": ledger.genesis_hash("parent-token-1"),
            "execution_name": er.execution_name(TOKEN, PEER_ID),
            "execution_name_by_ref": er.execution_name_by_ref(child, PEER_ID),
        },
        "envs": {"salt_hex": salt.hex(), "canonical": er.canonical_envs({"A": b"1", "B": b"\xff\x00"}),
                 "digest": er.envs_digest({"A": b"1", "B": b"\xff\x00"}, salt)},
        "chain": {"payload": "ping", "digest": er.payload_digest(b"ping"),
                  "link1": er.chain_link(er.CHAIN_GENESIS, 1, "in", 4, er.payload_digest(b"ping"))},
        "statements": stmts, "receipts": rcpts, "offers": offers(), "proofs": proof_list,
        "fault_evidence": {"evidence_hex": ev_hex, "digest": fault_digest},
        "contracts": contracts,
    }
    print(json.dumps(doc, indent=1, sort_keys=True))


main()
