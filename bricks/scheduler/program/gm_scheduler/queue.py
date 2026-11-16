"""The queue model (v0.6 master spec 9.4 step 5, 9.7, 9.9 fix 10, 9.12;
capture W1 item 9).

The fill runs a day's calls back to back, so their own timings say nothing
of a real day; the latency of each call it logs, and that the history's
call-duration histograms read, is the model's instead. The model takes the
fill's calls in the order of their virtual instants and gives each one a
latency, deterministically from the game's seed:

  - each key's **service time**, the database's work for one call, drawn
    from a lognormal (`median` seconds, `sigma`), measured in a short real
    run and kept in `service-times.yaml` beside the `queries.yaml` that
    defines the key (`gmctl fill` passes the figures; never a seed file);
  - a key's **transaction hold** (`queries.yaml`'s `transaction.hold`): the
    connection stays held that long after the work, as the program sleeps
    before its COMMIT;
  - **a pooled connection** (one going through a `pgbouncer` node): the
    pooler's server connections for the database and role, `size` of them,
    are one FIFO queue shared by every node and stream using them; a call
    waits for the first one free and holds it for its work and its hold
    (transaction pooling; a session-mode pool is modelled alike). A direct
    connection has no shared queue: each call its own service;
  - **a fault's `queue` entry**, from its planting on (the instant its
    instance is planted, virtual): `service` replaces the key's service
    time (f2, f8); `lock` makes each call of the key hold its locks for a
    drawn time, and a call of a `blocks` key starting its work meanwhile
    waits until they are released (f5);
  - a call that fails ends as soon as it starts its work: its latency is its
    wait and the client's round trip.

Every call's latency adds CLIENT_OVERHEAD, the client's own round trip.
What the model reads from rendered files (a pool's size, a job's time, a
hold) comes from the fill, never from a `queue` entry (W1 item 9).
"""

import heapq
import math

from . import ConfigError

# The client's own round trip, seconds: the research's calibration against
# run R (research/fake-aging 10d1bc6, latency.py, CLIENT_OVERHEAD_S).
CLIENT_OVERHEAD = 0.0004


class ServiceTime:
    """A lognormal service time: `median` seconds, `sigma` the spread of
    its logarithm."""

    def __init__(self, median, sigma):
        self.median, self.sigma = float(median), float(sigma)

    def draw(self, rng):
        return self.median * math.exp(rng.gauss(0.0, self.sigma))

    def __eq__(self, other):
        return isinstance(other, ServiceTime) and (self.median, self.sigma) == (other.median, other.sigma)

    def __repr__(self):
        return f"ServiceTime({self.median!r}, {self.sigma!r})"


def _number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def parse_service_time(value, where):
    if not isinstance(value, dict) or set(value) != {"median", "sigma"}:
        raise ConfigError(f"{where}: {{median: <seconds>, sigma: <number>}}")
    median, sigma = value["median"], value["sigma"]
    if not _number(median) or median <= 0:
        raise ConfigError(f"{where}.median: seconds, a number above 0")
    if not _number(sigma) or sigma < 0:
        raise ConfigError(f"{where}.sigma: a number at least 0")
    return ServiceTime(median, sigma)


def parse_service_times(value, where):
    """{key: {median, sigma}} -> {key: ServiceTime}."""
    if not isinstance(value, dict):
        raise ConfigError(f"{where}: a map of keys to {{median, sigma}}")
    return {str(k): parse_service_time(v, f"{where}.{k}") for k, v in value.items()}


class Effect:
    """A fault instance's `queue` entry, resolved: on `node`'s `key`, from
    `planted_at` (seconds since the epoch, virtual)."""

    def __init__(self, instance, node, key, planted_at, kind, time, blocks=()):
        self.instance, self.node, self.key, self.planted_at = instance, node, key, planted_at
        self.kind, self.time, self.blocks = kind, time, tuple(blocks)


def parse_effect(value, where, planted_at):
    """One `queue` entry as the fill receives it: {instance, node, key,
    service: {median, sigma}} or {..., lock: {median, sigma, blocks: [key]}}."""
    if not isinstance(value, dict):
        raise ConfigError(f"{where}: a map")
    effects = [k for k in ("service", "lock") if k in value]
    if len(effects) != 1:
        raise ConfigError(f"{where}: exactly one of service and lock")
    for name in ("instance", "node", "key"):
        if not isinstance(value.get(name), str) or not value[name]:
            raise ConfigError(f"{where}.{name}: a name")
    kind = effects[0]
    spec = value[kind]
    blocks = ()
    if kind == "lock":
        if not isinstance(spec, dict) or "blocks" not in spec:
            raise ConfigError(f"{where}.lock: {{median, sigma, blocks: [<key>...]}}")
        blocks = spec["blocks"]
        if not isinstance(blocks, list) or not blocks or not all(isinstance(b, str) and b for b in blocks):
            raise ConfigError(f"{where}.lock.blocks: a list of keys")
        spec = {k: v for k, v in spec.items() if k != "blocks"}
    return Effect(value["instance"], value["node"], value["key"], planted_at, kind,
                  parse_service_time(spec, f"{where}.{kind}"), blocks)


class Model:
    """One model for every node of a fill (one clock): `service_times`
    {node: {key: ServiceTime}}, `effects` [Effect], `pools` {pool id:
    size}, `rng` a random.Random (gm_scheduler.rng.derive)."""

    def __init__(self, service_times, effects, pools, rng):
        self.service_times = service_times
        self.effects = sorted(effects, key=lambda e: e.planted_at)
        self.pools = {p: [] for p in pools}          # pool id -> heap of the instants its servers free
        self.sizes = dict(pools)
        self.rng = rng
        self.locks = []                              # (start, end, blocked keys)

    def missing(self, node, keys):
        """The keys of `keys` without a service time on `node`, sorted."""
        have = self.service_times.get(node, {})
        return sorted(k for k in keys if k not in have)

    def _effect(self, node, key, kind, at):
        found = None
        for e in self.effects:
            if e.planted_at > at:
                break
            if e.node == node and e.key == key and e.kind == kind:
                found = e                            # the latest planted wins
        return found

    def call(self, node, key, arrival, hold=0.0, pool=None, error=False):
        """The latency (seconds) of a call of `node`'s `key` reaching the
        client at `arrival` (seconds since the epoch, virtual); `hold` its
        transaction hold (seconds), `pool` the pooled connection's id or
        None, `error` whether the fill's own execution failed."""
        base = self.service_times[node][key]
        changed = self._effect(node, key, "service", arrival)
        service = (changed.time if changed is not None else base).draw(self.rng)
        lock = self._effect(node, key, "lock", arrival)
        lock_hold = lock.time.draw(self.rng) if lock is not None else 0.0
        start = arrival
        free = None
        if pool is not None:
            free = self.pools.setdefault(pool, [])
            size = self.sizes.get(pool, 1)
            if len(free) >= size:
                start = max(arrival, heapq.heappop(free))
        self.locks = [w for w in self.locks if w[1] > arrival]
        wait = max((w[1] - start for w in self.locks if key in w[2] and w[0] <= start < w[1]), default=0.0)
        if error:
            busy = wait
        else:
            busy = wait + lock_hold + service + float(hold or 0.0)
            if lock is not None:
                self.locks.append((start + wait, start + wait + lock_hold, frozenset(lock.blocks)))
        if free is not None:
            heapq.heappush(free, start + busy)
        return (start - arrival) + busy + CLIENT_OVERHEAD
