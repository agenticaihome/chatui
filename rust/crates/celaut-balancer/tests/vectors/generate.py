"""Known-answer vectors for the funding sum and the closing class of celaut-balancer,
made with the nodo code.

Run from a nodo checkout (nodo dev 76dcac3b was used):

    PYTHONPATH=<nodo> python3 generate.py > funding.json

It needs the nodo requirements (protobuf) and a `config.yaml` in the working directory
(a copy of nodo's `config.example.yaml`: `DEFAULT_INITIAL_PERIODS` 360). Every input is
fixed, so the output is the same on each run.

- "funding": `price_bound.funding_sum_mu(init_mu, loop, strict(v, T), n)`, and None
  where it raises OverflowError; "unbounded" is the same with no bound (`init * n`).
- "life": `funded_life.funded_life_seconds(quote, initial_mu)`.
- "class": `interruption.interruption_class(quote, initial_mu, now)`.
- "closed": `architecture_resources.schedule_closed_reason(window, now)` is not None.
"""
import json
import sys
from datetime import datetime

# The nodo modules log to stdout while they load; the vectors alone go to stdout.
OUT, sys.stdout = sys.stdout, sys.stderr

from protos import celaut_pb2
from src.balancers.estimated_cost_sorter.interruption import interruption_class
from src.utils.cost_functions import price_bound
from src.utils.cost_functions.architecture_resources import schedule_closed_reason
from src.utils.cost_functions.funded_life import funded_life_seconds

FUNDING = [
    # init, v, T, loop, n
    (1000, 0.1, 3600, 60, 1),
    (1000, 0.1, 3600, 60, 60),
    (1000, 0.1, 3600, 60, 61),
    (1000, 0.1, 3600, 60, 360),
    (16971, 0.1, 3600, 60, 11),
    (58891, 0.1, 0, 60, 360),
    (7, 0.05, 600, 90, 1000),
    (123456789, 0.333, 86400, 3600, 200),
    (5, 1.5, 60, 60, 40),
    (1, 0.0, 3600, 60, 360),
    (100, 2.0, 1, 1, 100),
    (0, 0.1, 3600, 60, 10),
    (1000, 0.1, 3600, 60, 0),
    (999999999999, 0.25, 7200, 300, 2000),
]


def quote(cost, init, loop, bounded=True, v=0.1, T=3600, on_close=0, closes_at=0):
    q = celaut_pb2.EstimatedCost()
    q.cost.n = str(cost)
    q.init_maintenance_cost.n = str(init)
    q.max_maintenance_cost.n = str(init * 2)
    q.maintenance_seconds_loop = loop
    q.price_bounded = bounded
    q.price_volatility = v
    q.volatility_period_seconds = T
    q.on_close = on_close
    q.closes_at = closes_at
    return q


def fields(q):
    return {
        "cost": q.cost.n, "init": q.init_maintenance_cost.n,
        "loop": q.maintenance_seconds_loop, "bounded": q.price_bounded,
        "v": q.price_volatility, "T": q.volatility_period_seconds,
        "on_close": int(q.on_close), "closes_at": q.closes_at,
    }


def main():
    funding = []
    for init, v, T, loop, n in FUNDING:
        bound = price_bound.strict(v, T)
        try:
            total = price_bound.funding_sum_mu(init, loop, bound, n)
        except OverflowError:
            total = None
        funding.append({"init": init, "v": v, "T": T, "loop": loop, "n": n,
                        "sum": None if total is None else str(total),
                        "unbounded": str(price_bound.funding_sum_mu(init, loop, None, n))})

    quotes = [
        quote(500, 1000, 60),
        quote(0, 16971, 60, v=0.1, T=3600),
        quote(0, 16971, 60, bounded=False),
        quote(10, 7, 90, v=0.05, T=600),
        quote(0, 1000, 0),
        quote(0, 0, 60),
    ]
    starts = [None, 0, 500, 1500, 61000, 10**12]
    life = []
    for q in quotes:
        for m in starts:
            life.append({"quote": fields(q), "initial_mu": None if m is None else str(m),
                         "life": funded_life_seconds(q, m)})

    now = 1_800_000_000
    klass = []
    for on_close in (0, 1, 2, 7):
        for closes_at in (0, now + 30, now + 3600, now + 4 * 86400 + 1):
            for m in (None, 1500, 61000):
                q = quote(500, 1000, 60, on_close=on_close, closes_at=closes_at)
                klass.append({"quote": fields(q), "initial_mu": None if m is None else str(m),
                              "now": now, "class": interruption_class(q, m, now)})

    closed = []
    windows = [
        None, [], [(600, 720)], [(1320, 60)], [(0, 30), (600, 720)],
        [(600, 600)], [(600, 1440)], [(-1, 30)],
    ]
    for spans in windows:
        for minute in (0, 29, 30, 599, 600, 719, 720, 1319, 1320, 1439):
            moment = datetime(2026, 11, 10, minute // 60, minute % 60, 30)
            if spans is None:
                window = None
            else:
                window = celaut_pb2.ActivityWindow()
                for s, e in spans:
                    window.spans.add(start_minute=s, end_minute=e)
            closed.append({"spans": spans, "minute": minute,
                           "closed": schedule_closed_reason(window, moment) is not None})

    json.dump({"funding": funding, "life": life, "class": klass, "closed": closed}, OUT,
              indent=1)
    OUT.write("\n")


main()
