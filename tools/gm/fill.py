"""`gmctl fill`: a fake game's past run in minutes (v0.6 master spec 9.4
step 5, 9.9 fixes 3, 7 and 9, 9.12; capture W1 items 7, 8 and 9; as built:
W1-x in specs/versions/v0.6/wave-log.md).

At stage `injected`, with the restart record of `render --aging fake`
(`local/<playground>/fake-aging.yaml`, mode `fake`), it runs the scheduler
program's fill mode (`python3 -I -m gm_scheduler fill`, scheduler 0.4.0) in
one scheduler node's container, every scheduler node of the game on one
virtual clock from the virtual T0 to the anchor:

  1. refusals, before anything changes: the stage, a fill already recorded
     (a fill runs once; a failed one is never resumed), the record, an
     anchor already passed, a key without a service time (naming the key
     and its `service-times.yaml`), a connection that is not SQL to a
     `postgres` node (directly or through a `pgbouncer` node), a `pgwatch`
     node (its sessions in the fill are the clinic's, later);
  2. read-only: each scheduler node's program input as its run script
     builds it (the rendered schedule and the role passwords it mounts),
     the `pgbouncer` nodes' live `pgbouncer.ini`, each `postgres` node's
     settings;
  3. `state.yaml` `fill: {started_at, ended_at, outcome, reason, quiet}`,
     then, on each `postgres` node, as postgres, unseen (load-data's
     UNSEEN_SQL): the fill's sessions quieted (fix 3: QUIET_MEANS), the
     autovacuum naptime lowered (fix 7: NAPTIME), the real-clock actors
     off (pg_cron's launches, the cron daemon, archiving), each listed in
     `fill.quiet` with how to restore it; P0's `gm_vclock` schema in each
     database the fill writes;
  4. the program: its JSON on standard input, a `PAUSE <instant>` at each
     `state` fault instance's virtual planting (its inject scripts run
     unchanged on their nodes, recorded under `plantings.<id>`, attempt
     `by: fill` at the real instant with `virtual_at`, `planted_at` the
     virtual instant), then `DONE` or `FAILED`;
  5. the outputs: each node's log lines appended to its
     `/var/log/scheduler/scheduler.log`, its sequences' positions installed
     for the tail's program, its metrics record kept in
     `local/<playground>/fill/<node>.metrics.jsonl` (read by `gmctl
     history`);
  6. P0's schema dropped, the quieting of the sessions and the naptime
     restored; the real-clock actors left off for `clean-restart` (W1 item
     8), `fill.outcome` recorded. A failure drops the schema and restores
     what the end restores, records `failed` with its reason and stops: the
     GM tears the game down.

The stage stays `injected`.
"""

import datetime
import json
import posixpath
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import localimpl, model
from .aging import STATE_KIND, iso, now_utc, parse_instant
from .docker import for_local_dir
from .execnode import exec_node, node_container, node_docker
from .inject import (INJECT_STAGE, NO_AUDIT_SQL, NO_LOG_SQL, NO_STATS_SQL, T0, UNSEEN_SQL,
                     _print_run, fault_instances, inject_plan, output_lines, quote_ident,
                     quote_literal, read_secret)
from .model import GmError

FAKE_MODE = "fake"
FILL_DIR = "fill"                   # local/<playground>/fill/<node>.metrics.jsonl
METRICS_SUFFIX = ".metrics.jsonl"

# In a scheduler node's container (the brick's fixed paths, docs/gm.md).
WORK = "/run/gm-fill"               # the fill's working folder (the root file system is read-only;
                                    # /run a tmpfs), root-only, removed at the end
REPOSITORY = "/srv/scheduler/repository"
JOBS = "/srv/scheduler/jobs"
JOBS_FILE = "jobs.yaml"
SCHEDLOG = "/var/log/scheduler/scheduler.log"
SEQUENCES = "/var/lib/scheduler/sequences.json"
PROGRAM = ("python3", "-I", "-m", "gm_scheduler")
# The program's input as the s6 run script builds it (bricks/scheduler,
# etc/s6-overlay/s6-rc.d/scheduler/run): the framing, the mounted role
# passwords and HTTP credentials, the rendered schedule. Printed to gmctl,
# never written to a file.
INPUT_SCRIPT = r"""set -eu
S=/opt/gm/seed/schedule.yaml
[ -f "$S" ] || { echo "$S is missing" >&2; exit 2; }
printf 'gm-scheduler-input 1\n'
for f in /opt/gm/secrets/role_*_password; do
    [ -f "$f" ] || continue
    r=${f#/opt/gm/secrets/role_}; r=${r%_password}
    printf 'password %s %s\n' "$r" "$(cat "$f")"
done
for f in /opt/gm/secrets/http_*; do
    [ -f "$f" ] || continue
    printf 'credential %s %s\n' "${f#/opt/gm/secrets/http_}" "$(cat "$f")"
done
printf 'schedule\n'
cat "$S"
"""

PGBOUNCER_BRICK = "pgbouncer"
PGBOUNCER_INI = "/etc/pgbouncer/pgbouncer.ini"
PGBOUNCER_DEFAULT_POOL_SIZE = 20    # PgBouncer's own default
EXPORTER_BRICK = "postgres-exporter"
EXPORTER_CONF = "exporter.conf"
EXPORTER_PORT = 9187
PGWATCH_BRICK = "pgwatch"
PROMETHEUS_BRICK = "prometheus"
PROMETHEUS_YML = "prometheus.yml"
PROMETHEUS_DEFAULT_INTERVAL = 60    # seconds: Prometheus' own default scrape interval
MONITORING_SECRET = "monitoring_password"
SERVICE_TIMES_FILE = "service-times.yaml"
QUERIES_FILE = "queries.yaml"
SCHEDULE_FILE = "schedule.yaml"
SQL_DRIVER = "sql/postgresql"

# Fix 7: autovacuum_naptime for the fill (its minimum, PostgreSQL's floor):
# the fill runs a virtual hour in about a real minute, so a naptime of a
# second visits a table about as often per dirtied row as the default
# minute does in a real day. Restored at the fill's end.
NAPTIME = "1s"
# The fill node's container for the fill (the research's figures: the
# program runs every node's work in one process); restored at the end.
FILL_LIMITS = {"cpus": "2", "memory": "768m"}
PAUSE_TIMEOUT = 600                 # seconds an instance's inject script may take at a pause
STEP_TIMEOUT = 300                  # seconds a setup, survey or output step may take

# Fix 3 (W1 item 8; a choice, for review): the fill's sessions run as
# load-data's, without statement statistics, statement log or pgaudit.
# The settings are superuser-only and the fill's sessions are the roles',
# so they are set, for the fill's span, on each role the fill connects as
# in each database it connects to (ALTER ROLE ... IN DATABASE ... SET:
# the most specific level, above the role's, the database's and the
# server's own), the values load-data's sessions SET (inject.UNSEEN_SQL);
# the role's earlier values in that database are put back at the fill's
# end. `track_counts` stays on (autovacuum and the faults read the table
# statistics); other sessions (the exporter's visits) are untouched.
QUIET_MEANS = ("ALTER ROLE <role> IN DATABASE <database> SET, for each role the fill's "
               "sessions connect as, the settings load-data's sessions SET "
               "(inject.UNSEEN_SQL); restored at the fill's end")
SET_RE = re.compile(r"^SET\s+([a-z_.]+)\s*=\s*(.+?);$")
QUIET_SETTINGS = tuple((m.group(1), m.group(2).strip("'"))
                       for m in (SET_RE.match(s) for s in (*NO_LOG_SQL, *NO_AUDIT_SQL, *NO_STATS_SQL))
                       if m)

# Fix 9: what one scrape of postgres_exporter (0.20.1, the default
# collectors, docs/gm.md of the postgres-exporter brick) asks the database,
# on one session per scrape as the monitoring role; one statement per
# collector, of the same catalog views. `--collector.stat_statements` adds
# the last.
EXPORTER_SQL = (
    "SELECT pg_catalog.pg_postmaster_start_time(), pg_catalog.version()",
    "SELECT datname, pg_catalog.pg_database_size(datname) FROM pg_catalog.pg_database",
    "SELECT datname, mode, count(*) FROM pg_catalog.pg_locks l JOIN pg_catalog.pg_database d "
    "ON d.oid = l.database GROUP BY 1, 2",
    "SELECT pg_catalog.pg_is_in_recovery()",
    "SELECT slot_name, active FROM pg_catalog.pg_replication_slots",
    "SELECT rolname, rolconnlimit FROM pg_catalog.pg_roles",
    "SELECT name, setting, unit, vartype FROM pg_catalog.pg_settings",
    "SELECT datname, state, count(*), max(now() - xact_start) FROM pg_catalog.pg_stat_activity "
    "GROUP BY 1, 2",
    "SELECT * FROM pg_catalog.pg_stat_archiver",
    "SELECT * FROM pg_catalog.pg_stat_bgwriter",
    "SELECT * FROM pg_catalog.pg_stat_checkpointer",
    "SELECT * FROM pg_catalog.pg_stat_database",
    "SELECT * FROM pg_catalog.pg_stat_progress_vacuum",
    "SELECT * FROM pg_catalog.pg_stat_replication",
    "SELECT * FROM pg_catalog.pg_stat_user_tables",
    "SELECT * FROM pg_catalog.pg_statio_user_tables",
    "SELECT * FROM pg_catalog.pg_stat_wal",
)
STAT_STATEMENTS_COLLECTOR = "--collector.stat_statements"
STAT_STATEMENTS_SQL = ("SELECT userid, dbid, queryid, calls, total_exec_time, rows "
                       "FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 100")
EXPORTER_APPLICATION = ""           # postgres_exporter's sessions name none

CRON_SERVICE = "/run/service/cron"
CRON_CHECK = f"/command/s6-svstat -o up {CRON_SERVICE} 2>/dev/null || echo false"
CRON_OFF = f"/command/s6-svc -wD -T 30000 -d {CRON_SERVICE}"
CRON_ON = f"/command/s6-svc -u {CRON_SERVICE}"
PG_CRON_SWITCH = "cron.launch_active_jobs"
ARCHIVE_OFF = "/bin/true"           # archiving off: segments marked done, none archived


# --- Reading the scenario's files ---------------------------------------------

def _seed_text(scenario, playground, node, seed_name):
    """A node's seed file as the game mounts it (the rendered copy for a
    file render rewrites), or None when the node has none of that name."""
    rendered = localimpl.rendered_seed_names(scenario, node)
    for _, name, rel in localimpl.seed_entries(scenario, node):
        if name != seed_name:
            continue
        path = Path(scenario.dir) / (localimpl.rendered_seed_file(playground, node["name"], name)
                                     if name in rendered else rel)
        try:
            return path.read_text(encoding="utf-8")
        except OSError as exc:
            raise GmError(f"{path}: cannot be read: {exc.strerror}") from None
    return None


def _yaml(text, where):
    try:
        doc = yaml.safe_load(text) if text else None
    except yaml.YAMLError as exc:
        raise GmError(f"{where}: not YAML: {' '.join(str(exc).split())}") from None
    return doc if isinstance(doc, dict) else {}


def _nodes(scenario, impl, brick):
    return [n for n in scenario.nodes if scenario.bricks[n["name"]].id == brick
            and n["name"] in impl["nodes"]]


def schedule_keys(schedule, jobs):
    """Every key a scheduler node runs: its streams', its timeline's and
    its jobs'."""
    keys = {s.get("key") for s in schedule.get("streams") or [] if isinstance(s, dict)}
    keys |= {(c.get("set") or {}).get("key") for c in schedule.get("timeline") or []
             if isinstance(c, dict)}
    keys |= {j.get("key") for j in jobs.get("jobs") or [] if isinstance(j, dict)}
    return {k for k in keys if isinstance(k, str) and k}


def read_service_times(scenario, node_name, keys):
    """`nodes/<node>/service-times.yaml`'s keys (W1 item 9), refused when a
    key the node runs has none, naming the keys and the file."""
    rel = f"nodes/{node_name}/{SERVICE_TIMES_FILE}"
    path = Path(scenario.dir) / rel
    doc = {}
    if path.is_file():
        doc = _yaml(path.read_text(encoding="utf-8"), rel)
    times = doc.get("keys") if isinstance(doc.get("keys"), dict) else {}
    missing = sorted(k for k in keys if k not in times)
    if missing:
        raise GmError(f"node {node_name}: no service time for {', '.join(missing)} in {rel} "
                      "(capture W1 item 9: each key's measured median and sigma)")
    return {k: times[k] for k in sorted(keys)}


def key_node(scenario, playground, key, scheduler_nodes):
    """The one scheduler node whose queries.yaml has `key` (W1 item 4)."""
    found = [n["name"] for n in scheduler_nodes
             if key in (_yaml(_seed_text(scenario, playground, n, QUERIES_FILE),
                              f"{n['name']}'s {QUERIES_FILE}").get("queries") or {})]
    if len(found) != 1:
        raise GmError(f"a queue entry's key {key} is in the queries.yaml of "
                      f"{', '.join(found) or 'no scheduler node'}: name its node")
    return found[0]


def parse_pgbouncer_ini(text):
    """{"databases": {name: {host, port, dbname, pool_size, pool_mode}},
    "pgbouncer": {setting: value}} from a pgbouncer.ini's text."""
    out = {"databases": {}, "pgbouncer": {}}
    section = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith((";", "#")):
            continue
        m = re.match(r"^\[(\w+)\]$", line)
        if m:
            section = m.group(1).lower()
            continue
        name, sep, value = line.partition("=")
        if not sep:
            continue
        name, value = name.strip(), value.strip()
        if section == "databases":
            out["databases"][name] = dict(p.split("=", 1) for p in value.split() if "=" in p)
        elif section == "pgbouncer":
            out["pgbouncer"][name] = value
    return out


def parse_target(text, where):
    m = re.match(r"^([A-Za-z0-9.-]+):([0-9]{1,5})/([A-Za-z0-9_$-]+)$", str(text or ""))
    if not m:
        raise GmError(f"{where}: target {text!r} is not <host>:<port>/<database>")
    return m.group(1), int(m.group(2)), m.group(3)


def connection_plan(node_name, schedule, pg_nodes, poolers):
    """A scheduler node's connections for the fill: ({name: override}, [(postgres
    node, database, role)]). A connection through a `pgbouncer` node goes
    straight to the database its [databases] entry names (`target`), its
    pool the pooler's server connections for that database and role
    (`pool`, W1 item 9); a direct one needs no override."""
    overrides, sessions = {}, []
    for cname, c in sorted((schedule.get("connections") or {}).items()):
        where = f"node {node_name}, connection {cname}"
        if not isinstance(c, dict) or c.get("driver") != SQL_DRIVER:
            raise GmError(f"{where}: not {SQL_DRIVER}: the fill runs SQL only (the clinic's "
                          "fake aging is later)")
        host, port, database = parse_target(c.get("target"), where)
        role = c.get("role")
        if host in poolers:
            ini = poolers[host]
            entry = ini["databases"].get(database) or ini["databases"].get("*")
            if entry is None:
                raise GmError(f"{where}: pooler {host} has no [databases] entry {database}")
            if entry.get("dbname", database) != database:
                raise GmError(f"{where}: pooler {host} maps {database} to database "
                              f"{entry['dbname']}: the fill connects by the connection's name")
            dhost, dport = entry.get("host"), int(entry.get("port", 5432))
            if dhost not in pg_nodes:
                raise GmError(f"{where}: pooler {host}'s {database} is on {dhost}, not a "
                              "postgres node of the game")
            size = entry.get("pool_size") or ini["pgbouncer"].get("default_pool_size")
            overrides[cname] = {"target": f"{dhost}:{dport}",
                                "pool": {"id": f"{host}/{database}/{role}",
                                         "size": int(size or PGBOUNCER_DEFAULT_POOL_SIZE)}}
            sessions.append((dhost, database, role))
        elif host in pg_nodes:
            sessions.append((host, database, role))
        else:
            raise GmError(f"{where}: {host} is neither a postgres nor a pgbouncer node of the "
                          "game")
    return overrides, sessions


def parse_env_file(text):
    out = {}
    for line in (text or "").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def parse_seconds(text):
    m = re.match(r"^(\d+)(ms|s|m|h)$", str(text or ""))
    if not m:
        return None
    n, unit = int(m.group(1)), m.group(2)
    return {"ms": n / 1000, "s": n, "m": n * 60, "h": n * 3600}[unit]


def scrape_interval(prometheus, target):
    """The scrape interval of the job scraping `target` (seconds), or None
    when no job scrapes it."""
    glob = parse_seconds((prometheus.get("global") or {}).get("scrape_interval")) \
        or PROMETHEUS_DEFAULT_INTERVAL
    for job in prometheus.get("scrape_configs") or []:
        targets = [t for sc in job.get("static_configs") or [] for t in sc.get("targets") or []]
        if target in targets:
            return parse_seconds(job.get("scrape_interval")) or glob
    return None


def exporter_visits(scenario, playground, impl, pg_nodes):
    """Fix 9: each `postgres-exporter` node's sessions at its scrape
    interval, as Prometheus' jobs scrape it, without the password: [{name,
    target, role, every, sql}]. An exporter no Prometheus scrapes opens
    none."""
    proms = [_yaml(_seed_text(scenario, playground, n, PROMETHEUS_YML), PROMETHEUS_YML)
             for n in _nodes(scenario, impl, PROMETHEUS_BRICK)]
    visits = []
    for node in _nodes(scenario, impl, EXPORTER_BRICK):
        conf = parse_env_file(_seed_text(scenario, playground, node, EXPORTER_CONF))
        uri = (conf.get("DATA_SOURCE_URI") or "").split("?", 1)[0]
        host, port, database = parse_target(uri, f"node {node['name']}'s {EXPORTER_CONF}")
        if host not in pg_nodes:
            continue
        every = [s for s in (scrape_interval(p, f"{node['name']}:{EXPORTER_PORT}") for p in proms)
                 if s]
        if not every:
            continue
        sql = list(EXPORTER_SQL)
        if STAT_STATEMENTS_COLLECTOR in (conf.get("COLLECTORS") or "").split():
            sql.append(STAT_STATEMENTS_SQL)
        visits.append({"name": EXPORTER_APPLICATION, "target": f"{host}:{port}/{database}",
                       "role": conf.get("DATA_SOURCE_USER") or "monitoring",
                       "every": min(every), "sql": sql, "node": node["name"]})
    return visits


# --- The plan ---------------------------------------------------------------------

@dataclass
class FillPlan:
    vt0: datetime.datetime
    anchor: datetime.datetime
    seed: int
    fill_node: str                  # the scheduler node whose container runs the program
    nodes: list                     # the scheduler nodes, in scenario order
    pg_nodes: list                  # the postgres nodes the quieting and actors cover
    pauses: dict                    # {virtual instant (iso): [instance id]}
    queue: list                     # the program's `queue` entries
    service_times: dict             # {node: {key: {median, sigma}}}
    overrides: dict                 # {node: {connection: {target, pool}}}
    sessions: dict                  # {(postgres node, database): sorted roles}
    visits: list                    # exporter_visits' entries, no password


def _instant(value, what):
    t = parse_instant(value)
    if t is None:
        raise GmError(f"the restart record has no {what}: gmctl render --aging fake writes it")
    return t


def check_record(record, now):
    """(virtual T0, anchor) from the restart record; GmError when it is
    missing, not a fake game's, or its anchor has passed."""
    if record is None:
        raise GmError(f"no restart record ({localimpl.RESTART_RECORD_FILE}): a fill is a fake "
                      "game's (gmctl render --aging fake)")
    if record.get("mode") != FAKE_MODE:
        raise GmError(f"the restart record's mode is {record.get('mode')!r}, not {FAKE_MODE}: "
                      "a real game has no fill")
    vt0 = _instant(record.get("virtual_t0"), "virtual_t0")
    anchor = _instant(record.get("anchor"), "anchor")
    if anchor <= vt0:
        raise GmError(f"the restart record's anchor {iso(anchor)} is not after its virtual T0 "
                      f"{iso(vt0)}")
    if now >= anchor:
        raise GmError(f"the anchor {iso(anchor)} has passed: the fill runs before it (render a "
                      "later hand-over)")
    return vt0, anchor


def refuse_done(st):
    rec = st.get("fill")
    if not rec:
        return
    if rec.get("outcome") == "ok":
        raise GmError(f"game {st.get('game_id')} was filled ({rec.get('started_at')} to "
                      f"{rec.get('ended_at')}): a fill runs once; gmctl clean-restart is next")
    raise GmError(f"game {st.get('game_id')} has a fill started at {rec.get('started_at')} "
                  f"({rec.get('outcome') or 'never finished'}: {rec.get('reason') or '-'}): a "
                  "failed fill is never resumed, its rows are half a night; tear the game down "
                  "(gmctl teardown) and set it up again")


def pause_plan(scenario, impl, st, vt0, anchor):
    """{instant: [instance]}: the state instances whose planned planting lies
    in [virtual T0, anchor) and is not yet planted (W1 item 7)."""
    timeline = ((impl.get(localimpl.TIMELINE) or {}).get("instances") or {})
    plantings = st.get("plantings") or {}
    pauses = {}
    for inst, fault in fault_instances(scenario, impl):
        if (fault.data.get("injection") or {}).get("kind") != STATE_KIND:
            continue
        entry = timeline.get(inst["id"]) or {}
        if (entry.get("plant_at") or inst.get("plant_at") or T0) == T0:
            continue
        planned = parse_instant(entry.get("planned_at"))
        if planned is None or not vt0 <= planned < anchor:
            continue
        if (plantings.get(inst["id"]) or {}).get("planted_at"):
            continue
        pauses.setdefault(iso(planned), []).append(inst["id"])
    return dict(sorted(pauses.items()))


def queue_plan(scenario, impl, playground, vt0, anchor, pauses, scheduler_nodes):
    """The selection's `queue` entries (W1 item 9) for the fill: an instance
    planted at T0 from the virtual T0, one the fill plants from its
    pause; one planted in the tail has none in the fill."""
    paused = {iid: at for at, iids in pauses.items() for iid in iids}
    selected = {fault.id for _, fault in fault_instances(scenario, impl)}
    timeline = ((impl.get(localimpl.TIMELINE) or {}).get("instances") or {})
    out = []
    for inst, _ in fault_instances(scenario, impl):
        iid = inst["id"]
        plant_at = (timeline.get(iid) or {}).get("plant_at") or inst.get("plant_at") or T0
        if plant_at == T0:
            planted = iso(vt0)
        elif iid in paused:
            planted = paused[iid]
        else:
            continue
        for entry in model.instance_history(scenario, iid) or ():
            if entry.kind != "queue" or set(entry.suppressed_by) & selected:
                continue
            f = entry.fields
            node = f.get("node") or key_node(scenario, playground, f.get("key"), scheduler_nodes)
            item = {"instance": iid, "node": node, "key": f.get("key"), "planted_at": planted}
            for effect in ("service", "lock"):
                if effect in f:
                    item[effect] = f[effect]
            out.append(item)
    return out


def plan_fill(scenario, impl, st, playground, record, poolers, now):
    """The fill's plan from the game's files (and the poolers' live
    pgbouncer.ini, parsed): every refusal before anything changes."""
    vt0, anchor = check_record(record, now)
    timeline = impl.get(localimpl.TIMELINE) or {}
    seed = timeline.get("seed")
    if not isinstance(seed, int) or isinstance(seed, bool):
        raise GmError("implementation.yaml's timeline has no seed: gmctl render writes it")
    for n in scenario.nodes:
        if scenario.bricks[n["name"]].id == PGWATCH_BRICK and n["name"] in impl["nodes"]:
            raise GmError(f"node {n['name']} is a pgwatch node: its sessions in the fill are "
                          "later (the clinic's fake aging)")
    sched = _nodes(scenario, impl, model.SCHEDULER_BRICK)
    if not sched:
        raise GmError("the game has no scheduler node: nothing to fill")
    pg_nodes = [n["name"] for n in _nodes(scenario, impl, model.POSTGRES_BRICK)
                if localimpl.standby_of(n) is None]
    service_times, overrides, sessions = {}, {}, {}
    for n in sched:
        name = n["name"]
        schedule = _yaml(_seed_text(scenario, playground, n, SCHEDULE_FILE), f"{name}'s schedule")
        jobs = _yaml(_seed_text(scenario, playground, n, JOBS_FILE), f"{name}'s {JOBS_FILE}")
        service_times[name] = read_service_times(scenario, name, schedule_keys(schedule, jobs))
        overrides[name], used = connection_plan(name, schedule, pg_nodes, poolers)
        for pg, database, role in used:
            sessions.setdefault((pg, database), set()).add(role)
    pauses = pause_plan(scenario, impl, st, vt0, anchor)
    return FillPlan(
        vt0=vt0, anchor=anchor, seed=seed, fill_node=sched[0]["name"],
        nodes=[n["name"] for n in sched], pg_nodes=pg_nodes, pauses=pauses,
        queue=queue_plan(scenario, impl, playground, vt0, anchor, pauses, sched),
        service_times=service_times, overrides=overrides,
        sessions={k: sorted(v) for k, v in sorted(sessions.items())},
        visits=exporter_visits(scenario, playground, impl, pg_nodes))


def node_paths(plan, node):
    """Where the program reads and writes a node's files in the fill
    node's container: the fill node's own files in place, the others'
    copies under WORK."""
    own = node == plan.fill_node
    repo = REPOSITORY if own else f"{WORK}/nodes/{node}/repository"
    jobs = f"{JOBS}/{JOBS_FILE}" if own else f"{WORK}/nodes/{node}/jobs/{JOBS_FILE}"
    return {"repository": repo, "jobs": jobs, "log": f"{WORK}/out/{node}.log",
            "metrics": f"{WORK}/out/{node}{METRICS_SUFFIX}",
            "sequences": f"{WORK}/state/{node}/sequences.json"}


def program_input(plan, inputs, monitoring_password):
    """The program's JSON (gm_scheduler.fill.FillConfig): it holds the role
    passwords, so it goes on standard input only."""
    nodes = {}
    for node in plan.nodes:
        cfg = {"hostname": node, "input": inputs[node], **node_paths(plan, node)}
        if plan.overrides.get(node):
            cfg["connections"] = plan.overrides[node]
        nodes[node] = cfg
    visits = [{k: v for k, v in visit.items() if k != "node"} | {"password": monitoring_password}
              for visit in plan.visits]
    return {"vt0": iso(plan.vt0), "anchor": iso(plan.anchor), "seed": plan.seed,
            "pauses": list(plan.pauses), "nodes": nodes, "service_times": plan.service_times,
            "queue": plan.queue, "visits": visits}


# --- The database nodes' settings ---------------------------------------------

def survey_sql(sessions):
    """One JSON line: the server-wide settings set in postgresql.auto.conf
    (`auto`), the settings the fill touches as the server reports them
    (`settings`), and the role-in-database settings of the fill's roles
    (`roles`, "<database>/<role>": [name=value])."""
    names = sorted({n for n, _ in QUIET_SETTINGS} | {"autovacuum_naptime", PG_CRON_SWITCH,
                                                      "archive_mode", "archive_command",
                                                      "archive_library"})
    pairs = ", ".join(f"({quote_literal(d)}, {quote_literal(r)})" for d, r in sessions) or "(NULL, NULL)"
    return (UNSEEN_SQL
            + "SELECT pg_catalog.json_build_object("
            "'auto', (SELECT COALESCE(pg_catalog.json_object_agg(name, setting), '{}') "
            "FROM pg_catalog.pg_file_settings WHERE sourcefile LIKE '%/postgresql.auto.conf' "
            "AND error IS NULL), "
            "'settings', (SELECT COALESCE(pg_catalog.json_object_agg(name, setting), '{}') "
            f"FROM pg_catalog.pg_settings WHERE name IN ({', '.join(map(quote_literal, names))})), "
            "'roles', (SELECT COALESCE(pg_catalog.json_object_agg(d.datname || '/' || r.rolname, "
            "s.setconfig), '{}') FROM pg_catalog.pg_db_role_setting s "
            "JOIN pg_catalog.pg_database d ON d.oid = s.setdatabase "
            "JOIN pg_catalog.pg_roles r ON r.oid = s.setrole "
            f"WHERE (d.datname, r.rolname) IN ({pairs})));\n")


def _config_value(config, name):
    for item in config or []:
        k, sep, v = str(item).partition("=")
        if sep and k == name:
            return v
    return None


def _system_restore(auto, name):
    return (f"ALTER SYSTEM SET {name} = {quote_literal(auto[name])};" if name in auto
            else f"ALTER SYSTEM RESET {name};")


def settings_plan(node, survey, sessions):
    """(the SQL quieting `node` for the fill, [quiet item]) from its survey
    (W1 item 8: each item says what was turned off, how, and how to
    restore it; `left_off` items stay off for clean-restart)."""
    auto, settings, roles = survey["auto"], survey["settings"], survey["roles"]
    names = [(n, v) for n, v in QUIET_SETTINGS if n in settings]
    sql, items = [], []
    if sessions:
        restore = []
        for database, role in sessions:
            prior = roles.get(f"{database}/{role}")
            head = f"ALTER ROLE {quote_ident(role)} IN DATABASE {quote_ident(database)}"
            for name, value in names:
                sql.append(f"{head} SET {name} = {quote_literal(value)};")
                old = _config_value(prior, name)
                restore.append(f"{head} SET {name} = {quote_literal(old)};" if old is not None
                               else f"{head} RESET {name};")
        items.append({"node": node, "what": "statement statistics, statement log and pgaudit "
                      "for the fill's sessions (fix 3)",
                      "how": QUIET_MEANS + ": " + ", ".join(f"{d}/{r}" for d, r in sessions)
                      + "; " + ", ".join(f"{n} = {v}" for n, v in names),
                      "left_off": False, "restore": {"user": "postgres", "sql": restore}})
    sql.append(f"ALTER SYSTEM SET autovacuum_naptime = {quote_literal(NAPTIME)};")
    items.append({"node": node, "what": "autovacuum_naptime (fix 7)",
                  "how": f"ALTER SYSTEM SET autovacuum_naptime = {NAPTIME}", "left_off": False,
                  "restore": {"user": "postgres",
                              "sql": [_system_restore(auto, "autovacuum_naptime"),
                                      "SELECT pg_catalog.pg_reload_conf();"]}})
    if PG_CRON_SWITCH in settings:
        sql.append(f"ALTER SYSTEM SET {PG_CRON_SWITCH} = off;")
        items.append({"node": node, "what": "pg_cron's job runs",
                      "how": f"ALTER SYSTEM SET {PG_CRON_SWITCH} = off", "left_off": True,
                      "restore": {"user": "postgres",
                                  "sql": [_system_restore(auto, PG_CRON_SWITCH)]}})
    archiving = settings.get("archive_mode") in ("on", "always") and (
        settings.get("archive_command") not in (None, "", "(disabled)")
        or settings.get("archive_library") not in (None, ""))
    if archiving:
        sql.append(f"ALTER SYSTEM SET archive_command = {quote_literal(ARCHIVE_OFF)};")
        restore = [_system_restore(auto, "archive_command")]
        if settings.get("archive_library"):
            sql.append("ALTER SYSTEM SET archive_library = '';")
            restore.append(_system_restore(auto, "archive_library"))
        items.append({"node": node, "what": "archiving",
                      "how": f"ALTER SYSTEM SET archive_command = '{ARCHIVE_OFF}' (segments "
                             "marked archived, none sent: the archive has the fill's gap)",
                      "left_off": True, "restore": {"user": "postgres", "sql": restore}})
    sql.append("SELECT pg_catalog.pg_reload_conf();")
    return UNSEEN_SQL + "\n".join(sql) + "\n", items


# --- Reaching the nodes ---------------------------------------------------------

class Nodes:
    """The game's nodes as the fill reaches them (tests replace it)."""

    def __init__(self, ldir, impl, docker=None):
        self.ldir, self.impl = ldir, impl
        self.docker = docker or for_local_dir(ldir)

    def run(self, node, user, stdin=None, argv=None, timeout=STEP_TIMEOUT, env=None):
        return exec_node(self.ldir, node, user, stdin=stdin, argv=argv, timeout=timeout,
                         env=env, docker=self.docker)

    def _container(self, node):
        host = node_docker(self.docker, self.impl, node)
        return host, node_container(self.docker, self.impl, node)

    def limits(self, node):
        host, container = self._container(node)
        hc = host.json(["inspect", container])[0]["HostConfig"]
        return {"cpus": str((hc.get("NanoCpus") or 0) / 1e9), "memory": str(hc.get("Memory") or 0),
                "memory-swap": str(hc.get("MemorySwap") or 0)}

    def set_limits(self, node, limits):
        host, container = self._container(node)
        args = ["update"]
        for k in ("cpus", "memory", "memory-swap"):
            if k in limits:
                args += [f"--{k}", limits[k]]
        host.run(args + [container], check=False)

    def spawn(self, node, argv):
        host, container = self._container(node)
        if hasattr(host, "ensure"):
            host.ensure()
        return subprocess.Popen(host.command(["exec", "-i", "-u", "root", container, *argv]),
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)


def _text(result):
    out = result.stdout
    return out.decode("utf-8", "replace") if isinstance(out, (bytes, bytearray)) else (out or "")


def _check(result, what):
    if not result.ok:
        lines = output_lines(result)
        raise GmError(f"{what}: exit {result.returncode}: {lines[-1] if lines else 'no output'}")
    return result


def psql_argv(database, tuples=False):
    return ("psql", "-X", "-q", *(("-A", "-t") if tuples else ()), "-v", "ON_ERROR_STOP=1",
            "-d", database)


# --- The result ---------------------------------------------------------------------

@dataclass
class FillResult:
    game_id: str
    vt0: str = None
    anchor: str = None
    outcome: str = None
    reason: str = None
    wall_s: float = None
    done: dict = None
    planted: list = field(default_factory=list)     # [(instance, virtual instant, real instant)]
    quiet: list = field(default_factory=list)

    @property
    def ok(self):
        return self.outcome == "ok"

    def text(self):
        out = [f"Game {self.game_id}: fill from the virtual T0 {self.vt0} to the anchor "
               f"{self.anchor}: {self.outcome}" + (f" ({self.reason})" if self.reason else "")]
        if self.wall_s is not None:
            out.append(f"  {self.wall_s:.0f} s" + (f" (the program's run {self.done['fill_s']} s)"
                                                   if self.done else ""))
        for iid, virtual, real in self.planted:
            out.append(f"  {iid} planted at virtual {virtual} (real {real})")
        for node, n in sorted(((self.done or {}).get("nodes") or {}).items()):
            out.append(f"  {node}: {n.get('calls')} calls, {n.get('errors')} errors, "
                       f"{n.get('runs')} job runs, {n.get('skips')} skips, {n.get('lines')} log "
                       f"lines, {n.get('minutes')} minutes recorded")
        if self.done and self.done.get("visits"):
            v = self.done["visits"]
            out.append(f"  visits: {v.get('sessions')} sessions, {v.get('errors')} errors")
        for item in self.quiet:
            state = "left off for clean-restart" if item["left_off"] else "restored"
            out.append(f"  {item['node']}: {item['what']}: {state}")
        out.append(f"Stage {INJECT_STAGE} (unchanged)."
                   + (" Next: gmctl clean-restart." if self.ok else
                      " A failed fill is never resumed: tear the game down."))
        return "\n".join(out)


# --- The run ---------------------------------------------------------------------

class FillRun:
    def __init__(self, scenario, scenario_dir, playground, ldir, impl, st, plan, nodes, out):
        self.scenario, self.scenario_dir, self.playground = scenario, scenario_dir, playground
        self.ldir, self.impl, self.st, self.plan = ldir, impl, st, plan
        self.nodes, self.out = nodes, out
        self.result = FillResult(impl["game_id"], iso(plan.vt0), iso(plan.anchor))
        self.quiet = []                 # every item, as recorded
        self.shims = []                 # (postgres node, database) holding gm_vclock
        self.limits = None
        self.proc = None

    # --- recording -------------------------------------------------------------
    def record(self, **fields):
        def change(state):
            state.setdefault("fill", {}).update(fields)
        localimpl.update_state(self.ldir, change)

    def record_planting(self, iid, attempt, virtual):
        timeline = ((self.impl.get(localimpl.TIMELINE) or {}).get("instances") or {}).get(iid) or {}

        def change(state):
            p = state.setdefault("plantings", {}).setdefault(iid, {})
            p.setdefault("plant_at", timeline.get("plant_at"))
            p.setdefault("planned_at", timeline.get("planned_at"))
            p.setdefault("timer", None)
            p.setdefault("attempts", []).append(attempt)
            if attempt["outcome"] == "ok":
                p["planted_at"] = virtual
            p.setdefault("planted_at", None)
        localimpl.update_state(self.ldir, change)

    # --- the steps -------------------------------------------------------------
    def read_inputs(self):
        inputs, sequences = {}, {}
        for node in self.plan.nodes:
            r = _check(self.nodes.run(node, "root", stdin=INPUT_SCRIPT),
                       f"node {node}: its program input")
            inputs[node] = _text(r)
            r = self.nodes.run(node, "root", stdin=f"cat {SEQUENCES} 2>/dev/null || true\n")
            sequences[node] = _text(r) if r.ok else ""
        return inputs, sequences

    def quiet_databases(self):
        for pg in self.plan.pg_nodes:
            sessions = [(d, r) for (n, d), roles in self.plan.sessions.items() if n == pg
                        for r in roles]
            r = _check(self.nodes.run(pg, "postgres", stdin=survey_sql(sessions),
                                      argv=psql_argv("postgres", tuples=True)),
                       f"node {pg}: the settings' survey")
            survey = json.loads(_text(r).strip().splitlines()[-1])
            sql, items = settings_plan(pg, survey, sessions)
            self.quiet += items
            self.record(quiet=self.quiet)
            _check(self.nodes.run(pg, "postgres", stdin=sql, argv=psql_argv("postgres")),
                   f"node {pg}: quieting the fill's sessions, the naptime and the real-clock actors")
            r = self.nodes.run(pg, "root", stdin=CRON_CHECK + "\n")
            if _text(r).strip() == "true":
                item = {"node": pg, "what": "the cron daemon", "how": CRON_OFF, "left_off": True,
                        "restore": {"user": "root", "script": CRON_ON}}
                self.quiet.append(item)
                self.record(quiet=self.quiet)
                _check(self.nodes.run(pg, "root", stdin=CRON_OFF + "\n"), f"node {pg}: {CRON_OFF}")

    def create_shims(self):
        r = _check(self.nodes.run(self.plan.fill_node, "root", argv=(*PROGRAM, "fill-sql")),
                   "the program's fill-sql")
        sql = UNSEEN_SQL + _text(r)
        for pg, database in self.plan.sessions:
            self.shims.append((pg, database))
            _check(self.nodes.run(pg, "postgres", stdin=sql, argv=psql_argv(database)),
                   f"node {pg}: P0's gm_vclock in {database}")

    def drop_sql(self):
        if not hasattr(self, "_drop"):
            r = _check(self.nodes.run(self.plan.fill_node, "root",
                                      argv=(*PROGRAM, "fill-sql", "--drop")),
                       "the program's fill-sql --drop")
            self._drop = _text(r)
        return self._drop

    def stage_files(self, sequences=None):
        """The other scheduler nodes' repository and jobs, copied into WORK on
        the fill node (again before each GO: a planting may change them);
        with `sequences`, the folders and each node's sequences' state."""
        fill = self.plan.fill_node
        if sequences is not None:
            _check(self.nodes.run(fill, "root", stdin=f"set -eu\nrm -rf {WORK}\n"
                                  f"mkdir -p -m 0700 {WORK}\n"
                                  f"mkdir -p {WORK}/out {WORK}/state {WORK}/nodes\n"),
                   f"node {fill}: {WORK}")
            for node, text in sequences.items():
                if not text.strip():
                    continue        # none yet: the program starts every sequence at 0
                d = f"{WORK}/state/{node}"
                _check(self.nodes.run(fill, "root", stdin=text, argv=(
                    "sh", "-c", f"set -eu; mkdir -p {d}; cat > {d}/sequences.json")),
                    f"node {fill}: {node}'s sequences")
        for node in self.plan.nodes:
            if node == fill:
                continue
            r = _check(self.nodes.run(node, "root", stdin=b"", argv=(
                "tar", "-C", posixpath.dirname(REPOSITORY), "-cf", "-", "repository", "jobs")),
                f"node {node}: its repository and jobs")
            dest = f"{WORK}/nodes/{node}"
            _check(self.nodes.run(fill, "root", stdin=r.stdout,
                                  argv=("sh", "-c", f"rm -rf {dest} && mkdir -p {dest} && "
                                                    f"tar -C {dest} -xf -")),
                   f"node {fill}: {node}'s repository and jobs")

    def plant(self, at):
        """The pause at virtual `at`: each instance due there, its inject run
        unchanged (inject's plan), recorded."""
        plan = {p[0]: p for p in inject_plan(self.scenario, self.impl)}
        for iid in self.plan.pauses.get(at, []):
            real = iso(now_utc())
            attempt = {"at": real, "by": "fill", "virtual_at": at, "outcome": "ok"}
            try:
                _, _, _, run_as, env, scripts = plan[iid]
                for script, text, where in scripts:
                    run = self.nodes.run(where, run_as, stdin=text, env=env,
                                         timeout=PAUSE_TIMEOUT)
                    _print_run(self.out, f"{iid} {script} ({where}, as {run_as})", run)
                    if not run.ok:
                        raise GmError(f"{script}: exit {run.returncode}")
            except GmError as exc:
                attempt.update(outcome="failed", reason=" ".join(str(exc).split()))
            self.record_planting(iid, attempt, at)
            if attempt["outcome"] != "ok":
                raise GmError(f"the planting of {iid} at virtual {at} failed: {attempt['reason']}")
            self.result.planted.append((iid, at, real))

    def run_program(self, config):
        self.proc = self.nodes.spawn(self.plan.fill_node, (*PROGRAM, "fill"))
        self.proc.stdin.write(json.dumps(config) + "\n")
        self.proc.stdin.flush()
        done, failed = None, None
        for line in self.proc.stdout:
            line = line.strip()
            if line.startswith("PAUSE "):
                at = line.split(None, 1)[1]
                self.out(f"fill: paused at virtual {at}")
                try:
                    self.plant(at)
                    self.stage_files()
                except GmError as exc:
                    self.proc.stdin.write("STOP\n")
                    self.proc.stdin.flush()
                    failed = str(exc)
                    continue
                self.proc.stdin.write("GO\n")
                self.proc.stdin.flush()
            elif line.startswith("DONE "):
                done = json.loads(line[5:])
            elif line.startswith("FAILED"):
                failed = failed or ("the program: " + line[6:].strip())
        self.proc.stdin.close()
        rc = self.proc.wait()
        self.proc = None
        if failed or done is None:
            raise GmError(failed or f"the program ended (exit {rc}) without DONE")
        return done

    def collect(self):
        fill = self.plan.fill_node
        fdir = Path(self.ldir) / FILL_DIR
        fdir.mkdir(parents=True, exist_ok=True)
        for node in self.plan.nodes:
            paths = node_paths(self.plan, node)
            log = _check(self.nodes.run(fill, "root", argv=("cat", paths["log"])),
                         f"node {fill}: {node}'s fill log")
            _check(self.nodes.run(node, "root", stdin=log.stdout,
                                  argv=("sh", "-c", f"cat >> {SCHEDLOG}")),
                   f"node {node}: appending to {SCHEDLOG}")
            metrics = _check(self.nodes.run(fill, "root", argv=("cat", paths["metrics"])),
                             f"node {fill}: {node}'s metrics record")
            localimpl.write_text(fdir / f"{node}{METRICS_SUFFIX}", _text(metrics))
            seq = self.nodes.run(fill, "root", argv=("cat", paths["sequences"]))
            if seq.ok and _text(seq).strip():
                _check(self.nodes.run(node, "root", stdin=seq.stdout, argv=(
                    "sh", "-c", f"set -eu; cat > {SEQUENCES}.gm-fill; chown scheduler: "
                                f"{SEQUENCES}.gm-fill; chmod 0644 {SEQUENCES}.gm-fill; "
                                f"mv {SEQUENCES}.gm-fill {SEQUENCES}")),
                       f"node {node}: {SEQUENCES}")

    def undo(self):
        """P0's schema dropped and what the end restores restored; the
        left-off items stay off. Returns the problems met (best effort)."""
        problems = []
        for pg, database in self.shims:
            r = self.nodes.run(pg, "postgres", stdin=UNSEEN_SQL + self.drop_sql(),
                               argv=psql_argv(database))
            if not r.ok:
                problems.append(f"{pg}/{database}: gm_vclock not dropped")
        self.shims = []
        at = iso(now_utc())
        for item in self.quiet:
            if item["left_off"] or item.get("restored_at"):
                continue
            r = self.nodes.run(item["node"], "postgres",
                               stdin=UNSEEN_SQL + "\n".join(item["restore"]["sql"]) + "\n",
                               argv=psql_argv("postgres"))
            if r.ok:
                item["restored_at"] = at
            else:
                problems.append(f"{item['node']}: {item['what']} not restored")
        if self.limits is not None:
            self.nodes.set_limits(self.plan.fill_node, self.limits)
            self.limits = None
        self.nodes.run(self.plan.fill_node, "root", stdin=f"rm -rf {WORK}\n")
        return problems

    def run(self):
        started = time.monotonic()
        self.record(started_at=iso(now_utc()), ended_at=None, outcome=None, reason=None, quiet=[])
        try:
            inputs, sequences = self.read_inputs()
            password = read_secret(self.ldir, MONITORING_SECRET) if self.plan.visits else None
            self.quiet_databases()
            self.create_shims()
            self.stage_files(sequences)
            self.limits = self.nodes.limits(self.plan.fill_node)
            self.nodes.set_limits(self.plan.fill_node, {**FILL_LIMITS,
                                                        "memory-swap": FILL_LIMITS["memory"]})
            self.out(f"fill: virtual {iso(self.plan.vt0)} to {iso(self.plan.anchor)}, nodes "
                     f"{', '.join(self.plan.nodes)} in {self.plan.fill_node}'s container, "
                     f"pauses {', '.join(self.plan.pauses) or 'none'}")
            done = self.run_program(program_input(self.plan, inputs, password))
            self.collect()
        except BaseException as exc:
            if self.proc is not None:
                self.proc.kill()
                self.proc.wait()
            reason = " ".join(str(exc).split()) or type(exc).__name__
            problems = self.undo()
            self.result.outcome, self.result.reason = "failed", reason
            self.result.wall_s = time.monotonic() - started
            self.result.quiet = self.quiet
            self.record(ended_at=iso(now_utc()), outcome="failed",
                        reason=reason + (f" (also: {'; '.join(problems)})" if problems else ""),
                        quiet=self.quiet)
            if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                raise
            raise GmError(f"the fill failed: {reason}; recorded in state.yaml. A failed fill is "
                          "never resumed: tear the game down (gmctl teardown)") from None
        problems = self.undo()
        self.result.done = done
        self.result.wall_s = time.monotonic() - started
        self.result.quiet = self.quiet
        outcome = "failed" if problems else "ok"
        self.result.outcome = outcome
        self.result.reason = "; ".join(problems) or None
        self.record(ended_at=iso(now_utc()), outcome=outcome, reason=self.result.reason,
                    quiet=self.quiet)
        return self.result


def fill(scenario_dir, playground, docker=None, nodes=None, out=print, now=None):
    """`gmctl fill <scenario-dir> --playground <name>`; returns a FillResult.
    GmError on a refusal (nothing done, nothing recorded) or a failure
    (recorded in state.yaml)."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.require_stage(ldir, INJECT_STAGE)
    refuse_done(st)
    record = localimpl.read_restart_record(ldir)
    current = now or now_utc()
    check_record(record, current)
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    nodes = nodes or Nodes(ldir, impl, docker)
    poolers = {}
    for n in _nodes(scenario, impl, PGBOUNCER_BRICK):
        r = _check(nodes.run(n["name"], "root", argv=("cat", PGBOUNCER_INI)),
                   f"node {n['name']}: {PGBOUNCER_INI}")
        poolers[n["name"]] = parse_pgbouncer_ini(_text(r))
    plan = plan_fill(scenario, impl, st, playground, record, poolers, current)
    return FillRun(scenario, scenario_dir, playground, ldir, impl, st, plan, nodes, out).run()
