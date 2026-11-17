"""The fill mode: `python3 -I -m gm_scheduler fill` (v0.6 master spec 9.4
step 5, 9.12; capture W1 items 7, 8 and 9; as built: W1-x).

One process runs every scheduler node of a game on one virtual clock, from
the virtual T0 to the anchor, as fast as the database allows: each node's
streams (their arrivals, timeline changes and concurrency), its jobs (their
times, skips and refusals) and its transformer scripts, through the
program's own repository, builders, generators, random draws, log format
and minute summaries. The real mode (gm_scheduler.runner) is untouched; the
replay guard (tests/unit/test_replay.py) keeps it so.

What differs from the real mode:

  - time is virtual: a heap of events, executed in order, never slept;
  - **P0**, the database's clock: in the SQL the fill sends (keys,
    builders' statements, scripts' statements through the connections it
    opens) `now()`, `current_timestamp` and `current_date` become bound
    parameters holding the virtual instant (`virtualize`); every session
    puts the schema `gm_vclock` (VCLOCK_SQL, created by `gmctl fill` as
    postgres) before `pg_catalog` on its own `search_path` and sets
    `gm.vclock` at each transaction's start, so the server-side functions
    it calls read the virtual instant from `now()`,
    `transaction_timestamp()`, `statement_timestamp()` and
    `clock_timestamp()`. Session settings only: no real-mode session sees
    them. A database without the schema fails the fill;
  - a connection may be pointed elsewhere (`target`: the pooler's database,
    so the pooler's statistics start at the tail) and declared pooled
    (`pool`: the pooler's server connections the queue model shares);
  - a transaction's hold is not slept: its time is the queue model's; a
    read-only snapshot with a hold (a `repeatable read` transaction that
    wrote nothing) is kept open on its own session for its hold in virtual
    time, so vacuum is held back as in a real day;
  - the latencies logged and counted are the queue model's
    (gm_scheduler.queue), never the fill's timings;
  - the log is written at the end, at virtual times, in time order: the
    restart's `state` lines at the virtual T0, the calls' `error` lines, the
    jobs' `run`, `skip` and `error` lines, the scripts' lines, and each
    minute's `summary` and `key` lines up to the anchor; no `reload` line;
  - beside it, the node's metrics record: one JSON object a virtual minute
    from the virtual T0's minute to the anchor, what `/metrics` would have
    served at that minute's end (METRIC_KEYS), read by `gmctl history`;
  - visits: sessions opened at a fixed rate in virtual time as another
    client would (the exporter's, fix 9), each running its statements;
  - pauses: at each pause instant it prints `PAUSE <instant>` on standard
    output and waits for a `GO` line (a fault planted meanwhile); it then
    loads each node's repository and jobs.yaml again.

Standard input: one line, the fill's JSON (FillConfig; it holds the role
passwords, so it is never written to a file), then the `GO` lines.
Standard output: `PAUSE <instant>` lines, then `DONE <json>` (exit 0) or
`FAILED <reason>` (exit 1). Progress goes to standard error. An HTTP
connection is refused: the clinic's fake aging is later.
"""

import datetime
import heapq
import json
import os
import re
import sys
import time

from . import ConfigError, queue
from .jobs import load_jobs
from .metrics import BUCKETS, Stats
from .repository import BuilderResult, load_repository
from .rng import derive
from .schedule import apply_change, apply_past_changes, read_schedule
from .streams import draw_need, next_arrival, rate_function
from .textlog import format_line, script_line
from .timeutil import instant, minute_start, parse_instant

UTC = datetime.timezone.utc
SUMMARY_DELAY = 1.0          # as the runner's
RATE_HORIZON = 3600.0        # as the runner's
RESTART_S = 1.0              # the program's restart at the virtual T0: `stopping`, then `running` a second later
CONNECT_TIMEOUT = 10
REPORT_EVERY = 3600.0        # a progress line every virtual hour
ISOLATION_SQL = {
    "read committed": "BEGIN ISOLATION LEVEL READ COMMITTED",
    "repeatable read": "BEGIN ISOLATION LEVEL REPEATABLE READ",
    "serializable": "BEGIN ISOLATION LEVEL SERIALIZABLE",
}

VCLOCK_SCHEMA = "gm_vclock"
VCLOCK_SETTING = "gm.vclock"
# P0's shim (W1 item 8): created by `gmctl fill` as postgres in each database
# the fill writes, unseen, and dropped at the fill's end and on failure
# (VCLOCK_DROP; clean-restart drops a leftover). The four functions read the
# session's gm.vclock, which each fill session sets at each transaction's
# start; clock_timestamp() and statement_timestamp() advance with the real
# clock from it. Without the setting they are the real ones.
VCLOCK_SQL = """\
CREATE SCHEMA gm_vclock;
CREATE FUNCTION gm_vclock.now() RETURNS timestamptz LANGUAGE sql STABLE PARALLEL SAFE AS
  $$SELECT coalesce(NULLIF(pg_catalog.current_setting('gm.vclock', true), '')::timestamptz, pg_catalog.now())$$;
CREATE FUNCTION gm_vclock.transaction_timestamp() RETURNS timestamptz LANGUAGE sql STABLE PARALLEL SAFE AS
  $$SELECT gm_vclock.now()$$;
CREATE FUNCTION gm_vclock.statement_timestamp() RETURNS timestamptz LANGUAGE sql STABLE PARALLEL SAFE AS
  $$SELECT gm_vclock.now() OPERATOR(pg_catalog.+)
           (pg_catalog.statement_timestamp() OPERATOR(pg_catalog.-) pg_catalog.transaction_timestamp())$$;
CREATE FUNCTION gm_vclock.clock_timestamp() RETURNS timestamptz LANGUAGE sql VOLATILE PARALLEL SAFE AS
  $$SELECT gm_vclock.now() OPERATOR(pg_catalog.+)
           (pg_catalog.clock_timestamp() OPERATOR(pg_catalog.-) pg_catalog.transaction_timestamp())$$;
GRANT USAGE ON SCHEMA gm_vclock TO PUBLIC;
"""
# The checked drop (capture W2 item 13): it first fails, naming them, when an
# object outside gm_vclock depends on its functions (a column default, a view,
# a BEGIN ATOMIC body bound to the shim when created through it), so the
# CASCADE never reaches a customer object; then drops. Without the schema it
# does nothing. Every drop of the shim uses it (`fill-sql --drop`): the fill's
# end, load-data's, inject's and clean-restart's.
VCLOCK_DROP = """\
DO $gm_drop$
DECLARE
  bound text;
BEGIN
  SELECT pg_catalog.string_agg(DISTINCT pg_catalog.pg_describe_object(d.classid, d.objid, d.objsubid), '; '
                               ORDER BY pg_catalog.pg_describe_object(d.classid, d.objid, d.objsubid))
    INTO bound
    FROM pg_catalog.pg_depend d
    JOIN pg_catalog.pg_proc f ON d.refclassid = 'pg_catalog.pg_proc'::pg_catalog.regclass AND d.refobjid = f.oid
    JOIN pg_catalog.pg_namespace n ON n.oid = f.pronamespace AND n.nspname = 'gm_vclock'
   WHERE d.deptype IN ('n', 'a')
     AND NOT (d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
              AND d.objid IN (SELECT g.oid FROM pg_catalog.pg_proc g WHERE g.pronamespace = n.oid));
  IF bound IS NOT NULL THEN
    RAISE EXCEPTION 'gm_vclock not dropped: % depend(s) on its functions (bound to the fill''s clock: define them again with pg_catalog.now() or its kin, then drop it)', bound;
  END IF;
END $gm_drop$;
DROP SCHEMA IF EXISTS gm_vclock CASCADE;
"""
# P0's cover (master spec 9.4, spec D523; capture W2 item 13): a function or
# procedure with its own `SET search_path` never sees the fill's session
# path, so for the fill's span its setting becomes `gm_vclock`, then
# `pg_catalog` when the path doesn't name it (PostgreSQL searched it
# implicitly), then its own path; its other settings stay. COVER_SQL, run as
# postgres in each database holding the shim (`fill-sql --cover`), lists one
# JSON object a line for every function and procedure whose own settings set
# search_path, outside the system schemas, the temporary ones and every
# `gm_*` schema, and not an extension's member: {kind, signature (qualified:
# the query runs with pg_catalog alone on its path), setting (as proconfig
# holds it), covered (already under a cover), cover (the ALTER), restore (the
# ALTER back to `setting`, guarded: it acts only while the routine exists
# under this cover, so a routine gone or redefined since counts as
# restored)}. The setting is written back as its elements, each as
# proconfig holds it (an identifier), the empty one as '': PostgreSQL stores
# the same text again, entries and order.
COVER_SQL = r"""SET search_path = pg_catalog;
WITH pinned AS (
  SELECT p.prokind, p.oid::regprocedure::text AS signature, substr(c.entry, 13) AS setting
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   CROSS JOIN LATERAL unnest(p.proconfig) AS c(entry)
   WHERE p.prokind IN ('f', 'p')
     AND c.entry LIKE 'search\_path=%'
     AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
     AND n.nspname NOT LIKE 'pg\_temp\_%' AND n.nspname NOT LIKE 'pg\_toast\_temp\_%'
     AND n.nspname NOT LIKE 'gm\_%'
     AND NOT EXISTS (SELECT FROM pg_depend d
                      WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e')
), parsed AS (
  SELECT q.*, CASE q.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS word,
         ARRAY(SELECT t.m[1] FROM regexp_matches(q.setting, '"(?:[^"]|"")*"|[^",[:space:]]+', 'g')
                                  WITH ORDINALITY AS t(m, i) ORDER BY t.i) AS names
    FROM pinned q
), written AS (
  SELECT r.*,
         array_to_string(ARRAY(SELECT CASE WHEN u.x = '""' THEN '''''' ELSE u.x END
                                 FROM unnest(r.names) WITH ORDINALITY AS u(x, i) ORDER BY u.i), ', ') AS path,
         'gm_vclock, ' || CASE WHEN 'pg_catalog' = ANY (r.names) THEN '' ELSE 'pg_catalog, ' END AS head
    FROM parsed r
)
SELECT json_build_object(
         'kind', lower(word), 'signature', signature, 'setting', setting,
         'covered', setting LIKE 'gm\_vclock, %',
         'cover', format('ALTER %s %s SET search_path = %s%s;', word, signature, head, path),
         'restore', format('DO $gm_cover$ BEGIN IF EXISTS (SELECT FROM pg_catalog.pg_proc WHERE oid = '
                           'pg_catalog.to_regprocedure(%L) AND %L = ANY (proconfig)) THEN ALTER %s %s SET '
                           'search_path = %s; END IF; END $gm_cover$;',
                           signature, 'search_path=' || head || setting, word, signature, path))
  FROM written
 ORDER BY signature;
"""

NOW_RE = re.compile(r"\bnow\s*\(\s*\)", re.I)
CTS_RE = re.compile(r"\bcurrent_timestamp\b(?!\s*\()", re.I)
CDATE_RE = re.compile(r"\bcurrent_date\b", re.I)

# the metrics record's keys (W1 item 9; exact keys: W1-x)
METRIC_KEYS = ("at", "scheduler_calls_total", "scheduler_errors_total", "scheduler_call_duration_seconds",
               "scheduler_job_runs_total", "scheduler_job_skips_total")


class FillError(Exception):
    """The fill cannot go on; the message is the `FAILED` line's."""


def virtualize(sql, params, vt):
    """The statement with `now()`, `current_timestamp` and `current_date`
    replaced by bound parameters holding the virtual instant `vt` (seconds
    since the epoch); unchanged when it has none. A statement that gains
    parameters has its literal `%` doubled (psycopg's placeholders)."""
    if not isinstance(sql, str) or not (NOW_RE.search(sql) or CTS_RE.search(sql) or CDATE_RE.search(sql)):
        return sql, params
    if isinstance(params, (list, tuple)):
        raise FillError("a statement with positional parameters reads the database's clock: the fill binds "
                        "the virtual instant by name, so give its parameters names")
    if not params:
        sql = sql.replace("%", "%%")
    p = dict(params or {})
    p["gm_vnow"] = datetime.datetime.fromtimestamp(vt, UTC)
    sql = NOW_RE.sub("%(gm_vnow)s::timestamptz", sql)
    sql = CTS_RE.sub("%(gm_vnow)s::timestamptz", sql)
    sql = CDATE_RE.sub("(%(gm_vnow)s::timestamptz)::date", sql)
    return sql, p


def vclock_text(vt):
    return datetime.datetime.fromtimestamp(vt, UTC).strftime("%Y-%m-%d %H:%M:%S.%f+00")


def log(text):
    print(f"fill: {text}", file=sys.stderr, flush=True)


# --- the configuration ------------------------------------------------------------

class NodeConfig:
    def __init__(self, name, value, where):
        if not isinstance(value, dict):
            raise ConfigError(f"{where}: a map")
        for k in ("input", "repository", "jobs", "log", "metrics"):
            if not isinstance(value.get(k), str) or not value[k]:
                raise ConfigError(f"{where}.{k}: a string")
        self.name = name
        self.hostname = value.get("hostname") or name
        self.input = value["input"]
        self.repository, self.jobs = value["repository"], value["jobs"]
        self.log, self.metrics = value["log"], value["metrics"]
        self.sequences = value.get("sequences")      # where the sequences' positions go, for the tail; optional
        if self.sequences is not None and (not isinstance(self.sequences, str) or not self.sequences):
            raise ConfigError(f"{where}.sequences: a path")
        conns = value.get("connections") or {}
        if not isinstance(conns, dict):
            raise ConfigError(f"{where}.connections: a map")
        self.targets, self.pools = {}, {}
        for cname, c in conns.items():
            w = f"{where}.connections.{cname}"
            if not isinstance(c, dict) or set(c) - {"target", "pool"}:
                raise ConfigError(f"{w}: {{target: <host>:<port>, pool: {{id, size}}}}, each optional")
            if "target" in c:
                host, sep, port = str(c["target"]).rpartition(":")
                if not sep or not host or not port.isdigit():
                    raise ConfigError(f"{w}.target: <host>:<port>")
                self.targets[cname] = (host, int(port))
            if "pool" in c:
                p = c["pool"]
                if not isinstance(p, dict) or set(p) != {"id", "size"} or not isinstance(p["id"], str) \
                        or not isinstance(p["size"], int) or isinstance(p["size"], bool) or p["size"] < 1:
                    raise ConfigError(f"{w}.pool: {{id: <name>, size: <whole number at least 1>}}")
                self.pools[cname] = (p["id"], p["size"])


class FillConfig:
    """The fill's JSON:

        {"vt0": instant, "anchor": instant, "seed": int,
         "pauses": [instant, ...],
         "nodes": {<node>: {"hostname", "input" (the program's standard input:
                   gm-scheduler-input 1, passwords, the rendered schedule),
                   "repository", "jobs", "log", "metrics" (paths),
                   "sequences" (optional: the sequences' state file to hand
                   the tail's program),
                   "connections": {<name>: {"target": "host:port",
                                            "pool": {"id", "size"}}}}},
         "service_times": {<node>: {<key>: {"median", "sigma"}}},
         "queue": [{"instance", "node", "key", "planted_at", "service"|"lock"}],
         "visits": [{"name", "target": "host:port/database", "role",
                     "password", "every": seconds, "sql": [statement, ...]}]}
    """

    def __init__(self, doc):
        if not isinstance(doc, dict):
            raise ConfigError("the fill's input: a JSON object")
        self.vt0 = parse_instant(doc.get("vt0"), "vt0")
        self.anchor = parse_instant(doc.get("anchor"), "anchor")
        if self.anchor <= self.vt0 + RESTART_S:
            raise ConfigError("anchor: after the virtual T0")
        seed = doc.get("seed")
        if not isinstance(seed, int) or isinstance(seed, bool):
            raise ConfigError("seed: an integer")
        self.seed = seed
        self.pauses = sorted(parse_instant(p, f"pauses[{i}]") for i, p in enumerate(doc.get("pauses") or []))
        for p in self.pauses:
            if not self.vt0 <= p < self.anchor:
                raise ConfigError(f"pauses: {instant(p)} is not in [vt0, anchor)")
        nodes = doc.get("nodes")
        if not isinstance(nodes, dict) or not nodes:
            raise ConfigError("nodes: a map of at least one scheduler node")
        self.nodes = {n: NodeConfig(n, v, f"nodes.{n}") for n, v in nodes.items()}
        st = doc.get("service_times") or {}
        if not isinstance(st, dict):
            raise ConfigError("service_times: a map of nodes")
        self.service_times = {n: queue.parse_service_times(v, f"service_times.{n}") for n, v in st.items()}
        self.effects = []
        for i, e in enumerate(doc.get("queue") or []):
            where = f"queue[{i}]"
            if not isinstance(e, dict):
                raise ConfigError(f"{where}: a map")
            planted = parse_instant(e.get("planted_at"), f"{where}.planted_at")
            self.effects.append(queue.parse_effect({k: v for k, v in e.items() if k != "planted_at"}, where,
                                                   planted))
        self.visits = []
        for i, v in enumerate(doc.get("visits") or []):
            where = f"visits[{i}]"
            if not isinstance(v, dict) or set(v) != {"name", "target", "role", "password", "every", "sql"}:
                raise ConfigError(f"{where}: {{name, target, role, password, every, sql}}")
            m = re.match(r"^([A-Za-z0-9.-]+):([0-9]{1,5})/([A-Za-z0-9_$-]+)$", str(v["target"]))
            if not m:
                raise ConfigError(f"{where}.target: <host>:<port>/<database>")
            every = v["every"]
            if not isinstance(every, (int, float)) or isinstance(every, bool) or every < 1:
                raise ConfigError(f"{where}.every: seconds, at least 1")
            sql = v["sql"]
            if not isinstance(sql, list) or not sql or not all(isinstance(s, str) and s.strip() for s in sql):
                raise ConfigError(f"{where}.sql: a list of statements")
            self.visits.append({"name": str(v["name"]), "host": m.group(1), "port": int(m.group(2)),
                                "database": m.group(3), "role": str(v["role"]), "password": str(v["password"]),
                                "every": float(every), "sql": list(sql)})


# --- sessions ---------------------------------------------------------------------

class VCursor:
    """A script's cursor: its statements virtualized at the run's instant."""

    def __init__(self, cur, conn):
        self._cur, self._conn = cur, conn

    def execute(self, query, params=None, **kw):
        q, p = virtualize(query, params, self._conn.gm_vt)
        self._cur.execute(q, p, **kw)
        return self

    def executemany(self, query, params_seq, **kw):
        seq = [virtualize(query, p, self._conn.gm_vt) for p in params_seq]
        if seq:
            self._cur.executemany(seq[0][0], [p for _, p in seq], **kw)
        return self

    def __enter__(self):
        self._cur.__enter__()
        return self

    def __exit__(self, *exc):
        return self._cur.__exit__(*exc)

    def __iter__(self):
        return iter(self._cur)

    def __getattr__(self, name):
        return getattr(self._cur, name)


class VConnection:
    """A script's psycopg connection: `execute` and its cursors' statements
    virtualized at the run's instant (`gm_vt`); everything else psycopg's."""

    def __init__(self, conn, vt):
        self._conn, self.gm_vt = conn, vt

    def execute(self, query, params=None, **kw):
        q, p = virtualize(query, params, self.gm_vt)
        return self._conn.execute(q, p, **kw)

    def cursor(self, *a, **kw):
        return VCursor(self._conn.cursor(*a, **kw), self)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return self._conn.__exit__(*exc)

    def __getattr__(self, name):
        return getattr(self._conn, name)


def _sql_error(exc):
    diag = getattr(exc, "diag", None)
    msg = (getattr(diag, "message_primary", None) if diag is not None else None) or str(exc) or type(exc).__name__
    return getattr(exc, "sqlstate", None) or "-", " ".join(msg.split())


def connect(host, port, database, role, password, application_name, autocommit=True, clock=True):
    """A psycopg connection; with `clock`, `gm_vclock` first on its own
    search_path (FillError when the database lacks it)."""
    import psycopg
    from .drivers.postgresql import KEEPALIVES
    conn = psycopg.connect(host=host, port=port, dbname=database, user=role, password=password,
                           application_name=application_name, connect_timeout=CONNECT_TIMEOUT,
                           autocommit=autocommit, prepare_threshold=None, **KEEPALIVES)
    if clock:
        row = conn.execute("SELECT pg_catalog.to_regnamespace(%s) IS NOT NULL, pg_catalog.current_database()",
                           (VCLOCK_SCHEMA,)).fetchone()
        if not row[0]:
            conn.close()
            raise FillError(f"database {row[1]} has no schema {VCLOCK_SCHEMA}: gmctl fill creates it before the "
                            "fill (P0)")
        conn.execute("SELECT pg_catalog.set_config('search_path', %s || pg_catalog.current_setting('search_path'), "
                     "false)", (f"{VCLOCK_SCHEMA}, pg_catalog, ",))
        if not autocommit:
            conn.commit()
    return conn


def set_clock(conn, vt):
    conn.execute("SELECT pg_catalog.set_config(%s, %s, false)", (VCLOCK_SETTING, vclock_text(vt)))


# --- one node ---------------------------------------------------------------------

class VContext:
    """What generators read (runner.Context's form): the virtual instant and
    the sequences, reserved in blocks in `path` as the program's state file
    (the node's sequences.json for the tail, installed by gmctl fill), or in
    memory."""

    def __init__(self, path=None):
        from .generators import Sequences
        self.sequences = Sequences(path)
        self.vt = 0.0

    def now(self):
        return self.vt


class Node:
    def __init__(self, cfg):
        self.cfg = cfg
        self.name, self.hostname = cfg.name, cfg.hostname
        self.schedule, self.passwords, credentials = read_schedule(cfg.input)
        for c in self.schedule.connections.values():
            if c.http:
                raise ConfigError(f"node {self.name}: connection {c.name} is HTTP: the fill runs SQL only (the "
                                  "clinic's fake aging is later)")
        self.repo = load_repository(cfg.repository)
        self.jobs = load_jobs(cfg.jobs)
        from .runner import check_references
        problems = check_references(self.schedule, self.repo, self.jobs)
        if problems:
            raise ConfigError(f"node {self.name}: " + "; ".join(problems))
        if cfg.sequences:
            os.makedirs(os.path.dirname(cfg.sequences) or ".", exist_ok=True)
        self.ctx = VContext(cfg.sequences)
        self.started = None
        self.lines = []              # (instant, seq, text)
        self.seq = 0
        self.records = []            # (end instant, seq, kind, payload)
        self.sessions = {}           # connection name -> psycopg connection
        self.held = {}               # connection name -> idle sessions for held snapshots
        self.job_end = {}            # job name -> virtual end of its last run
        self.generation = 0
        self.counts = {"calls": 0, "errors": 0, "runs": 0, "skips": 0}

    def write(self, ts, event, *fields):
        self.seq += 1
        self.lines.append((ts, self.seq, format_line(ts, event, fields)))

    def write_script(self, ts, job, text):
        self.seq += 1
        self.lines.append((ts, self.seq, script_line(ts, job, text)))

    def record(self, key, latency, error, end):
        self.seq += 1
        self.records.append((end, self.seq, "call", (key, latency, error)))
        self.counts["calls"] += 1
        self.counts["errors"] += 1 if error else 0

    def mark(self, ts, kind, payload):
        self.seq += 1
        self.records.append((ts, self.seq, kind, payload))

    def target(self, cname):
        c = self.schedule.connections[cname]
        host, port = self.cfg.targets.get(cname, (c.host, c.port))
        return c, host, port

    def session(self, cname):
        s = self.sessions.get(cname)
        if s is None or s.closed or s.broken:
            c, host, port = self.target(cname)
            s = self.sessions[cname] = connect(host, port, c.database, c.role, self.passwords.get(c.role),
                                               self.hostname)
        return s

    def held_session(self, cname):
        free = self.held.setdefault(cname, [])
        while free:
            s = free.pop()
            if not (s.closed or s.broken):
                return s
        c, host, port = self.target(cname)
        return connect(host, port, c.database, c.role, self.passwords.get(c.role), self.hostname)

    def close(self):
        for s in list(self.sessions.values()) + [x for v in self.held.values() for x in v]:
            try:
                s.close()
            except Exception:  # closing at the end: the server rolls back what was open
                pass


def run_steps(conn, plan, vt):
    """Sets the session's clock, then runs the plan (BEGIN first when it has
    a transaction, no COMMIT); returns (rows, None) or (rows, (sqlstate,
    message)) after a rollback."""
    import psycopg
    rows = 0
    try:
        set_clock(conn, vt)
        if plan.txn:
            conn.execute(ISOLATION_SQL[plan.txn.isolation])
        for sql, params in plan.steps:
            s, p = virtualize(sql, params, vt)
            cur = conn.execute(s, p if p else None)
            rows += len(cur.fetchall()) if cur.description is not None else max(cur.rowcount, 0)
        return rows, None
    except psycopg.Error as exc:
        if plan.txn and not (conn.closed or conn.broken):
            try:
                conn.execute("ROLLBACK")
            except psycopg.Error:
                pass
        return rows, _sql_error(exc)


# --- the fill ---------------------------------------------------------------------

class Fill:
    def __init__(self, cfg, stdin=None, stdout=None):
        self.cfg = cfg
        self.stdin = stdin or sys.stdin
        self.stdout = stdout or sys.stdout
        self.nodes = {n: Node(c) for n, c in cfg.nodes.items()}
        pools = {}
        for node in self.nodes.values():
            for pid, size in node.cfg.pools.values():
                pools[pid] = size
        self.model = queue.Model(cfg.service_times, cfg.effects, pools,
                                 derive(cfg.seed, "gm-fill", "queue-model", cfg.vt0))
        self.check_service_times()
        self.heap = []
        self.hseq = 0
        self.start = cfg.vt0 + RESTART_S
        self.visits = {"sessions": 0, "errors": 0}
        self.paused = []

    def check_service_times(self):
        """Every key a stream or job runs has a service time (W1 item 9)."""
        problems = []
        for node in self.nodes.values():
            keys = set(self.stream_keys(node)) | {j.key for j in node.jobs}
            missing = self.model.missing(node.name, keys)
            if missing:
                problems.append(f"node {node.name}: no service time for {', '.join(missing)}")
        if problems:
            raise ConfigError("; ".join(problems))

    @staticmethod
    def stream_keys(node):
        return node.schedule.keys()

    def push(self, t, kind, payload):
        self.hseq += 1
        heapq.heappush(self.heap, (t, self.hseq, kind, payload))

    # --- streams ---------------------------------------------------------------
    def start_stream(self, node, stream):
        st = {"node": node, "stream": stream, "pools": {},
              "rng": derive(node.schedule.seed, node.hostname, f"stream:{stream.index}:{stream.initial_key}",
                            node.started),
              "rate_at": rate_function(stream, node.schedule.intensity, node.schedule.shapes),
              "pending": apply_past_changes(stream, node.started), "busy": []}
        st["t"] = node.started
        st["need"] = draw_need(st["rng"], stream.arrivals)
        self.plan_arrival(st)

    def plan_arrival(self, st):
        """runner.run_stream's integration: the next arrival, or the next
        timeline change when it comes first."""
        pending, t = st["pending"], st["t"]
        limit = pending[0].at if pending else t + RATE_HORIZON
        at, need = next_arrival(t, st["need"], st["rate_at"], max(limit, t))
        st["need"] = need
        if at < self.cfg.anchor:
            self.push(at, "stream", st)

    def on_stream(self, t, st):
        node, stream = st["node"], st["stream"]
        st["t"] = t
        if st["need"] == 0.0:
            busy = [e for e in st["busy"] if e > t]
            st["busy"] = busy
            if len(busy) >= stream.concurrency:
                st["waiting"] = t
                self.push(min(busy), "slot", st)
                return
            self.stream_call(st, t, t)
        self.after_arrival(st)

    def on_slot(self, now, st):
        at = st.pop("waiting")
        st["busy"] = [e for e in st["busy"] if e > now]
        if now - at > 1.0:
            st["t"] = now                    # every slot was busy: no backlog (as the runner)
        self.stream_call(st, at, now)
        self.after_arrival(st)

    def after_arrival(self, st):
        node, stream = st["node"], st["stream"]
        if st["need"] == 0.0:
            st["need"] = draw_need(st["rng"], stream.arrivals)
        pending = st["pending"]
        while pending and pending[0].at <= st["t"]:
            change = pending.pop(0)
            apply_change(stream, change)
            node.mark(change.at, "touch", (stream.key,))
        self.plan_arrival(st)

    def stream_call(self, st, at, now):
        from .runner import Scheduler
        node, stream = st["node"], st["stream"]
        key = stream.key
        node.ctx.vt = now
        plan, problem = Scheduler.make_plan(node, key, st["rng"], stream.connection)
        if plan is None:
            node.record(key, 0.0, True, now)
            node.write(now, "error", ("key", key), ("sqlstate", "-"), ("message", problem))
            return
        end = self.execute(node, key, stream.connection, plan, now)
        st["busy"].append(end)

    def execute(self, node, key, cname, plan, now, job=None):
        """Runs one call's plan at `now`; records it with the model's
        latency; returns its virtual end. A job's lines are its caller's."""
        import psycopg
        hold = plan.txn.hold if plan.txn else 0
        pool = node.cfg.pools.get(cname, (None, None))[0]
        try:
            if plan.txn and hold and plan.txn.isolation in ("repeatable read", "serializable"):
                rows, err = self.held_call(node, cname, plan, now, hold)
            else:
                sess = node.session(cname)
                rows, err = run_steps(sess, plan, now)
                if plan.txn and err is None:
                    sess.execute("COMMIT")
        except psycopg.Error as exc:
            rows, err = 0, _sql_error(exc)
            node.sessions.pop(cname, None)
        latency = self.model.call(node.name, key, now, hold=hold, pool=pool, error=err is not None)
        end = now + latency
        node.record(key, latency, err is not None, end)
        if job is None and err is not None:
            node.write(end, "error", ("key", key), ("sqlstate", err[0]), ("message", err[1]))
        self.last = (rows, err, latency)
        return end

    def held_call(self, node, cname, plan, now, hold):
        """A snapshot held for `hold` virtual seconds on its own session;
        committed at once if it wrote anything (holding locks would stall
        the fill's next call on them)."""
        import psycopg
        sess = node.held_session(cname)
        rows, err = run_steps(sess, plan, now)
        if err is not None:
            node.held.setdefault(cname, []).append(sess)
            return rows, err
        wrote = sess.execute("SELECT pg_catalog.pg_current_xact_id_if_assigned() IS NOT NULL").fetchone()[0]
        if wrote:
            try:
                sess.execute("COMMIT")
            except psycopg.Error as exc:
                return rows, _sql_error(exc)
            node.held.setdefault(cname, []).append(sess)
        else:
            self.push(now + hold, "release", (node, cname, sess))
        return rows, None

    def on_release(self, t, payload):
        import psycopg
        node, cname, sess = payload
        try:
            sess.execute("COMMIT")
            node.held.setdefault(cname, []).append(sess)
        except psycopg.Error:
            pass

    # --- jobs ------------------------------------------------------------------
    def start_jobs(self, node, after):
        node.generation += 1
        for job in node.jobs:
            self.plan_job(node, job, after, node.generation)

    def plan_job(self, node, job, after, generation):
        nxt = job.cron.next_after(after)
        if nxt is None:
            node.write(after, "job", ("job", job.name), ("key", job.key), ("next", "never"))
        elif nxt < self.cfg.anchor:
            self.push(nxt, "job", (node, job, generation))

    def on_job(self, due, payload):
        node, job, generation = payload
        if generation != node.generation:
            return
        self.plan_job(node, job, due, generation)
        if node.job_end.get(job.name, due) > due:
            node.mark(due, "skip", (job.key, job.name, "still-running"))
            node.counts["skips"] += 1
            node.write(due, "skip", ("job", job.name), ("key", job.key), ("at", instant(due)),
                       ("reason", "still-running"))
            return
        entry = node.repo.get(job.key) if job.key in node.repo else None
        if entry is not None and entry.kind == "script" and job.connections is not None:
            self.script_run(node, job, entry, due)
        else:
            self.job_run(node, job, due)

    def job_run(self, node, job, due):
        import psycopg
        from .runner import Scheduler
        rng = derive(node.schedule.seed, node.hostname, f"job:{job.name}:{int(due)}", node.started)
        node.ctx.vt = due
        plan, problem = Scheduler.make_plan(node, job.key, rng)
        if plan is None:
            node.mark(due, "run", (job.key, job.name))
            node.counts["runs"] += 1
            node.write(due, "run", ("job", job.name), ("key", job.key), ("phase", "start"))
            node.record(job.key, 0.0, True, due)
            node.write(due, "error", ("key", job.key), ("job", job.name), ("sqlstate", "-"), ("message", problem))
            node.write(due, "run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "error"),
                       ("ms", "0.0"))
            return
        try:
            node.session(job.connection)
        except psycopg.Error as exc:
            code, message = _sql_error(exc)
            node.mark(due, "skip", (job.key, job.name, "connection-refused"))
            node.counts["skips"] += 1
            node.write(due, "error", ("key", job.key), ("job", job.name), ("sqlstate", code), ("message", message))
            node.write(due, "skip", ("job", job.name), ("key", job.key), ("at", instant(due)),
                       ("reason", "connection-refused"))
            return
        node.mark(due, "run", (job.key, job.name))
        node.mark(due, "touch", (job.key,))
        node.counts["runs"] += 1
        node.write(due, "run", ("job", job.name), ("key", job.key), ("phase", "start"))
        end = self.execute(node, job.key, job.connection, plan, due, job=job.name)
        rows, err, latency = self.last
        node.job_end[job.name] = end
        ms = f"{latency * 1000:.1f}"
        if err is None:
            node.write(end, "run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "ok"),
                       ("rows", rows), ("ms", ms))
        else:
            node.write(end, "error", ("key", job.key), ("job", job.name), ("sqlstate", err[0]), ("message", err[1]))
            node.write(end, "run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "error"),
                       ("sqlstate", err[0]), ("ms", ms))

    def script_run(self, node, job, entry, due):
        import psycopg
        from . import scripts
        conns = {}
        try:
            for name, cname in job.connections.items():
                c, host, port = node.target(cname)
                conn = connect(host, port, c.database, c.role, node.passwords.get(c.role), node.hostname,
                               autocommit=False)
                set_clock(conn, due)
                conn.commit()
                conns[name] = VConnection(conn, due)
        except (psycopg.Error, FillError) as exc:
            scripts.close_connections(conns)
            if isinstance(exc, FillError):
                raise
            code, message = _sql_error(exc)
            node.mark(due, "skip", (job.key, job.name, "connection-refused"))
            node.counts["skips"] += 1
            node.write(due, "error", ("key", job.key), ("job", job.name), ("sqlstate", code), ("message", message))
            node.write(due, "skip", ("job", job.name), ("key", job.key), ("at", instant(due)),
                       ("reason", "connection-refused"))
            return
        node.mark(due, "run", (job.key, job.name))
        node.mark(due, "touch", (job.key,))
        node.counts["runs"] += 1
        node.write(due, "run", ("job", job.name), ("key", job.key), ("phase", "start"))
        outcome = scripts.call(entry.fn, conns, entry.options, lambda text: node.write_script(due, job.name, text))
        latency = self.model.call(node.name, job.key, due, error=not outcome.ok)
        end = due + latency
        node.record(job.key, latency, not outcome.ok, end)
        node.job_end[job.name] = end
        ms = f"{latency * 1000:.1f}"
        if outcome.ok:
            node.write(end, "run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "ok"),
                       ("rows", outcome.rows), ("ms", ms))
            return
        node.write(end, "error", ("key", job.key), ("job", job.name),
                   ("sqlstate", outcome.value if outcome.field == "sqlstate" else "-"), ("message", outcome.message))
        node.write(end, "run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "error"),
                   (outcome.field, outcome.value), ("ms", ms))

    # --- visits ----------------------------------------------------------------
    def on_visit(self, t, v):
        import psycopg
        try:
            conn = connect(v["host"], v["port"], v["database"], v["role"], v["password"], v["name"], clock=False)
            try:
                for sql in v["sql"]:
                    conn.execute(sql).fetchall()
            finally:
                conn.close()
            self.visits["sessions"] += 1
        except psycopg.Error:
            self.visits["errors"] += 1
        if t + v["every"] < self.cfg.anchor:
            self.push(t + v["every"], "visit", v)

    # --- pauses ----------------------------------------------------------------
    def on_pause(self, t):
        print(f"PAUSE {instant(t)}", file=self.stdout, flush=True)
        line = self.stdin.readline().strip()
        if line != "GO":
            raise FillError(f"stopped at the pause at {instant(t)}: {line or 'end of input'}")
        self.paused.append(instant(t))
        for node in self.nodes.values():
            try:
                repo, jobs = load_repository(node.cfg.repository), load_jobs(node.cfg.jobs)
            except ConfigError as exc:
                raise FillError(f"node {node.name}: after the pause at {instant(t)}: {exc}") from None
            node.repo = repo
            node.jobs = jobs
            self.start_jobs(node, t)
        self.check_service_times()

    # --- the run ---------------------------------------------------------------
    def run(self):
        cfg = self.cfg
        for node in self.nodes.values():
            node.write(cfg.vt0, "state", ("state", "stopping"))
            node.started = self.start
            node.write(self.start, "state", ("state", "running"), ("t0", instant(cfg.vt0)))
            node.mark(self.start, "touch", tuple(s.key for s in node.schedule.streams))
            for stream in node.schedule.streams:
                self.start_stream(node, stream)
            self.start_jobs(node, self.start)
        for v in cfg.visits:
            self.push(self.start, "visit", v)
        for p in cfg.pauses:
            self.push(p, "pause", None)
        real0 = time.monotonic()
        report = cfg.vt0 + REPORT_EVERY
        handlers = {"stream": self.on_stream, "slot": self.on_slot, "release": self.on_release,
                    "job": self.on_job, "visit": self.on_visit}
        while self.heap:
            t, _, kind, payload = heapq.heappop(self.heap)
            if t >= cfg.anchor:
                if kind == "release":
                    self.on_release(t, payload)
                continue
            while t >= report:
                calls = {n: x.counts["calls"] for n, x in self.nodes.items()}
                log(f"virtual {instant(report)}, {time.monotonic() - real0:.0f} s, calls {calls}")
                report += REPORT_EVERY
            if kind == "pause":
                self.on_pause(t)
            else:
                handlers[kind](t, payload)
        return time.monotonic() - real0

    def close(self):
        """Every session, the snapshots still held included."""
        for _, _, kind, payload in self.heap:
            if kind == "release":
                try:
                    payload[2].close()
                except Exception:  # closing at the end: the server rolls back what was open
                    pass
        self.heap = []
        for node in self.nodes.values():
            node.close()

    # --- the outputs -----------------------------------------------------------
    def outputs(self, node):
        """The node's minute summaries (into its lines) and its metrics
        record (a list of dicts), from its calls in end order."""
        cfg = self.cfg
        stats = Stats()
        for key in node.schedule.keys():
            stats.declare(key)
        for job in node.jobs:
            stats.declare(job.key)
        records = sorted(node.records)
        i, out = 0, []
        m = minute_start(cfg.vt0)
        while m < cfg.anchor:
            if m >= minute_start(self.start):
                stats.touch(stream_keys_at(node.schedule, max(m, self.start)), m)
            while i < len(records) and records[i][0] < m + 60:
                ts, _, kind, p = records[i]
                if kind == "call":
                    stats.record(p[0], p[1], p[2], ts)
                elif kind == "run":
                    stats.job_run(p[0], p[1])
                elif kind == "skip":
                    stats.job_skip(p[0], p[1], p[2])
                else:
                    stats.touch(set(p), ts)
                i += 1
            if m >= minute_start(self.start) and m + 60 + SUMMARY_DELAY < cfg.anchor:
                for event, fields in stats.summary(m):
                    node.write(m + 60 + SUMMARY_DELAY, event, *fields)
            out.append(metrics_record(stats, m + 60))
            m += 60
        return out


def stream_keys_at(schedule, t):
    """Each stream's key at `t`: its first, then the timeline's changes up
    to `t` (the runner touches its streams' current keys every minute)."""
    keys = set()
    for stream in schedule.streams:
        key = stream.initial_key
        for c in stream.changes:
            if c.at <= t and "key" in c.sets:
                key = c.sets["key"]
        keys.add(key)
    return keys


def metrics_record(stats, at):
    """What /metrics serves at `at`, as one JSON object (METRIC_KEYS)."""
    keys = sorted(stats.totals)
    return {
        "at": instant(at),
        "scheduler_calls_total": {k: stats.totals[k].calls for k in keys},
        "scheduler_errors_total": {k: stats.totals[k].errors for k in keys},
        "scheduler_call_duration_seconds": {
            k: {"buckets": dict(zip((repr(b) for b in BUCKETS), stats.totals[k].buckets)),
                "sum": round(stats.totals[k].sum, 6), "count": stats.totals[k].calls} for k in keys},
        "scheduler_job_runs_total": [{"key": k, "job": j, "value": n} for (k, j), n in sorted(stats.job_runs.items())],
        "scheduler_job_skips_total": [{"key": k, "job": j, "reason": r, "value": n}
                                      for (k, j, r), n in sorted(stats.job_skips.items())],
    }


def write_outputs(fill):
    summary = {}
    for node in fill.nodes.values():
        record = fill.outputs(node)
        node.lines.sort(key=lambda x: (x[0], x[1]))
        for path in (node.cfg.log, node.cfg.metrics):
            os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with open(node.cfg.log, "w", encoding="utf-8") as f:
            for _, _, text in node.lines:
                f.write(text + "\n")
        with open(node.cfg.metrics, "w", encoding="utf-8") as f:
            for rec in record:
                f.write(json.dumps(rec, sort_keys=True) + "\n")
        summary[node.name] = dict(node.counts, lines=len(node.lines), minutes=len(record))
    return summary


def main(stdin=None, stdout=None):
    stdin = stdin or sys.stdin
    stdout = stdout or sys.stdout
    fill = None
    try:
        first = stdin.readline()
        try:
            doc = json.loads(first)
        except ValueError:
            raise ConfigError("the fill's input: the first line is not JSON") from None
        cfg = FillConfig(doc)
        fill = Fill(cfg, stdin, stdout)
        log(f"virtual {instant(cfg.vt0)} to {instant(cfg.anchor)}, nodes {', '.join(fill.nodes)}, "
            f"pauses {len(cfg.pauses)}")
        seconds = fill.run()
        nodes = write_outputs(fill)
    except (ConfigError, FillError) as exc:
        print(f"FAILED {exc}", file=stdout, flush=True)
        return 1
    except Exception as exc:  # the fill's own failure: reported, never a traceback on the GM's screen only
        print(f"FAILED {type(exc).__name__}: {' '.join(str(exc).split())}", file=stdout, flush=True)
        return 1
    finally:
        if fill is not None:
            fill.close()
    print("DONE " + json.dumps({"fill_s": round(seconds, 1), "pauses": fill.paused, "visits": fill.visits,
                                "nodes": nodes}, sort_keys=True), file=stdout, flush=True)
    return 0
