"""`gmctl clean-restart`: a fake game's maintenance restart (v0.6 master
spec 9.4 step 6, 9.9 fixes 2, 4 and 8; capture W2 items 8, 10, 11 and 13).

Run once the fill has ended `ok` (W1 item 7), before `start-load`. Its
order, the contract `history` (chunk 10) and the tells (chunk 12) read:

1. every `fill.quiet` item the fill left unrestored that is not left off
   (a cover whose end restore failed, W2 item 13) restored by its
   `restore`, in its `restore.database` (`postgres` when absent) or by its
   root `script`, and `restored_at` set; a leftover `gm_vclock` dropped in
   every database by the checked drop (`fill-sql --drop`). A failure here
   stops it, recorded;
2. on each primary `postgres` node, the WAL padded with
   `pg_logical_emit_message` to a day's worth at the node's measured rate
   (`nodes/<node>/wal-rate.yaml` beside its seed files, never mapped: 24
   times `bytes_per_hour`; a node without one refused, naming the file,
   before anything is done), then `CHECKPOINT` and `pg_switch_wal()`
   twice, so the fill's segments are recycled;
3. the statement statistics (`pg_stat_statements_reset()`) and the shared
   ones (`pg_stat_reset_shared(NULL)`: the archiver, bgwriter,
   checkpointer, IO, recovery prefetch, SLRU and WAL statistics) reset;
   never the table and index statistics (9.9);
4. the hold's and the fill's left-off items restored for the next start
   (their `ALTER SYSTEM`, sent before the stop since it needs the server
   and takes effect at the start; the cron daemon's comes back with the
   fresh container); every service of the game stopped (scaled to zero);
   the PostgreSQL and cron logs removed and the pooler's emptied; each data
   file's modification time set to its last virtual write (virtual_mtime);
   the restart record given `restart` (its story line, its `explains`) and
   the stack file rewritten, the monitoring at one replica again;
5. every service started at one instant (one `docker service scale`, the
   monitoring with them, fresh containers: fresh process namespaces), the
   instant measured and recorded as `restart.at`; then the health wait.

Progress in `state.yaml` `clean_restart` (W2 item 8); the stage stays
`injected` until `start-load`, which requires `clean_restart.outcome: ok`.
"""

import json
import shlex
import time
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import localimpl, model
from .aging import iso, now_utc, parse_instant
from .docker import for_local_dir, running_containers
from .execnode import exec_node
from .model import GmError

INJECT_STAGE = "injected"
WAL_RATE_FILE = "wal-rate.yaml"
DAY_HOURS = 24
PAD_CHUNK = 1048576                     # bytes per pg_logical_emit_message
STOP_TIMEOUT = 180                      # seconds for every container to stop
POLL = 2

POSTGRES_BRICK = "postgres"
PGBOUNCER_BRICK = "pgbouncer"
PG_DATA_VOLUME, PG_DATA_PATH = "pgdata", "/var/lib/postgresql/18/data"
PG_LOG_VOLUME = "pglog"
POOLER_LOG_VOLUME = "pgblog"
HELPER_MOUNT = "/gm-clean"

# The documented limits (master spec 9.10) as the restart record's
# `explains`, kept where they hold in the game (capture W2 item 8): the
# archive's row only with an archiving node, the covered routines' only when
# fill.quiet lists a cover. (when, observation, where, in_world)
EXPLAINS = (
    (None, "the restart itself: the postmaster's start, every container's start, process IDs "
           "counted from it, the statistics' reset time, the logs' first lines",
     "pg_postmaster_start_time(), ps, stats_reset, the log folder",
     "the maintenance restart of the story line"),
    (None, "no log before the restart: PostgreSQL, the pooler, pgaudit, the cron jobs (the "
           "scheduler's own log covers the night)",
     "the log folders", "older logs archived at the maintenance (the story line)"),
    (None, "real-clock actors start at the restart: pg_cron's run history, the crontab's runs, "
           "the pooler's statistics, archiving",
     "cron.job_run_details, the cron log, SHOW STATS, pg_stat_archiver",
     "partly: they were restarted at the maintenance"),
    (None, "the data files' inode change times are the fill's real minutes",
     "pg_stat_file(), stat, ls -lc", "partly: the maintenance touched the files"),
    (None, "last-use times of what only the fill touched fall in the minutes before the restart",
     "pg_stat_user_tables, pg_stat_user_indexes", None),
    (None, "the LSN and WAL volume, if the padding doesn't hold",
     "pg_current_wal_lsn(), segment names", "partly"),
    (None, "time-driven behaviour in the fill is emulated in outcome only (a held snapshot, a "
           "timeout, a lock wait, an out-of-memory kill)",
     "the fill's span in logs and views", None),
    ("archiving", "the archive vault and a standby date from the restart",
     "the vault, pg_stat_replication, a slot's age", "partly: the maintenance"),
    (None, "Prometheus' imported blocks carry their creation time, and Prometheus starts at the "
           "restart",
     "the TSDB's files; Prometheus' runtime info", "the start: the maintenance restart"),
    (None, "the forged past's fine shape: series appearing over the day, rarely called statements",
     "Prometheus", None),
    ("cover", "each routine the fill covered has a new catalog row version from the fill's "
              "minutes, its definition and settings identical",
     "pg_proc's xmin against the other routines'; two updates on pg_proc in "
     "pg_stat_sys_tables", "partly: a change in the maintenance before the restart, not named"),
)


def explains(st):
    """The restart record's `explains` for this game (W2 item 8)."""
    from . import fill
    items = list((st.get("hold") or {}).get("items") or []) + list(
        (st.get("fill") or {}).get("quiet") or [])
    holds = {"archiving": any(i.get("what") == fill.ARCHIVING_WHAT for i in items),
             "cover": any(i.get("routine") for i in items)}
    return [{"observation": obs, "where": where, "in_world": world or "none: not covered by the story"}
            for when, obs, where, world in EXPLAINS if when is None or holds[when]]


def wal_rates(scenario, nodes):
    """{node: bytes_per_hour} from each node's `nodes/<node>/wal-rate.yaml`
    (W2 item 11); GmError naming the first file missing or malformed."""
    rates = {}
    for node in nodes:
        rel = f"nodes/{node}/{WAL_RATE_FILE}"
        path = Path(scenario.dir) / rel
        if not path.is_file():
            raise GmError(f"node {node}: {rel} missing: clean-restart pads the WAL to a day's worth "
                          "at the scenario's measured rate (master spec 9.9 fix 4); write it "
                          "(source, bytes_per_hour) from a real run of the scenario")
        try:
            with open(path, encoding="utf-8") as fh:
                doc = model.strict_load(fh)         # the loader's, duplicate keys refused
        except (yaml.YAMLError, OSError, UnicodeDecodeError) as exc:
            raise GmError(f"node {node}: {rel} cannot be read: {' '.join(str(exc).split())}") from None
        rate = (doc or {}).get("bytes_per_hour")
        if not isinstance(rate, int) or isinstance(rate, bool) or rate <= 0 or not (doc or {}).get("source"):
            raise GmError(f"node {node}: {rel}: needs source and bytes_per_hour, a positive "
                          "whole number of bytes")
        rates[node] = rate
    return rates


def pad_sql(target):
    """The padding (fix 4): WAL written by non-transactional logical
    messages until `target` bytes past the start, then `CHECKPOINT` and
    `pg_switch_wal()` twice; its last line one JSON object: padded_bytes,
    pg_wal_bytes, seconds."""
    return f"""SET search_path = pg_catalog;
SELECT set_config('gm.pad_start', pg_current_wal_insert_lsn()::text, false),
       set_config('gm.pad_t', clock_timestamp()::text, false) \\g /dev/null
DO $gm_pad$
DECLARE
  chunk text := repeat('x', {PAD_CHUNK});
  start pg_lsn := current_setting('gm.pad_start')::pg_lsn;
BEGIN
  WHILE pg_wal_lsn_diff(pg_current_wal_insert_lsn(), start) < {int(target)} LOOP
    PERFORM pg_logical_emit_message(false, 'gm_pad', chunk);
  END LOOP;
END $gm_pad$;
CHECKPOINT;
SELECT pg_switch_wal() \\g /dev/null
CHECKPOINT;
SELECT pg_switch_wal() \\g /dev/null
SELECT json_build_object(
  'padded_bytes', pg_wal_lsn_diff(pg_current_wal_insert_lsn(), current_setting('gm.pad_start')::pg_lsn)::bigint,
  'pg_wal_bytes', (SELECT sum(size) FROM pg_ls_waldir())::bigint,
  'seconds', round(extract(epoch FROM clock_timestamp() - current_setting('gm.pad_t')::timestamptz), 1));
"""


SHARED_RESET_SQL = "SELECT pg_catalog.pg_stat_reset_shared(NULL) \\g /dev/null\n"
STATEMENTS_RESET_SQL = """DO $gm_reset$
DECLARE s name;
BEGIN
  SELECT n.nspname INTO s FROM pg_catalog.pg_extension e
    JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_stat_statements';
  IF s IS NOT NULL THEN
    EXECUTE pg_catalog.format('SELECT %I.pg_stat_statements_reset()', s);
  END IF;
END $gm_reset$;
"""

LIST_SCRIPT = f"""set -eu
find {HELPER_MOUNT} -path {HELPER_MOUNT}/pg_wal -prune -o -type f ! -name 'postmaster.*' \\
     -printf '%T@ %P\\n'
"""
PG_LOGS_SCRIPT = f"""set -eu
find {HELPER_MOUNT} -mindepth 1 -type f -print -delete | wc -l
"""
# PostgreSQL stopped cleanly (fast: the shutdown checkpoint) before the
# services are scaled to zero, never left to Swarm's ten-second SIGKILL (a
# crash recovery at the start would write the files again); `-O`: s6 does
# not start it again in this container.
PG_STOP_SCRIPT = f"""set -eu
/command/s6-svc -O /run/service/postgres
runuser -u postgres -- /usr/lib/postgresql/18/bin/pg_ctl stop -D {PG_DATA_PATH} -m fast -w -t 300
"""
POOLER_LOGS_SCRIPT = f"""set -eu
n=0
for f in $(find {HELPER_MOUNT} -mindepth 1 -type f); do : > "$f"; n=$((n+1)); done
echo $n
"""


def virtual_mtime(t, fill_span, virtual_span):
    """A data file's last virtual write (fix 8) from its real modification
    time `t` (epoch seconds): before the fill, as far before the virtual T0
    as it was before the fill's start (the deploy, the load); during the
    fill, its instant on the fill's clock, the fill's real span mapped
    linearly onto the virtual T0 to the anchor; after it (the clean-up's
    checkpoints), the anchor."""
    (r0, r1), (v0, v1) = fill_span, virtual_span
    if t < r0:
        return v0 - (r0 - t)
    if t >= r1 or r1 <= r0:
        return v1
    return v0 + (t - r0) * (v1 - v0) / (r1 - r0)


def touch_script(listing, fill_span, virtual_span):
    """The helper's script setting each listed file (`<mtime> <path>` lines,
    paths relative to the volume) to its last virtual write."""
    lines = ["set -eu"]
    for line in listing.splitlines():
        if not line.strip():
            continue
        t, rel = line.split(" ", 1)
        when = virtual_mtime(float(t), fill_span, virtual_span)
        lines.append(f"touch -c -m -d @{when:.6f} -- {shlex.quote(HELPER_MOUNT + '/' + rel)}")
    return "\n".join(lines) + "\n", len(lines) - 1


def leftovers(st):
    """The fill.quiet items the fill left unrestored that are not left off
    (W2 item 13), the covers first."""
    quiet = (st.get("fill") or {}).get("quiet") or []
    return sorted((i for i in quiet if not i.get("left_off") and not i.get("restored_at")),
                  key=lambda i: "routine" not in i)


def left_off(st):
    """The hold's items and the fill's left-off ones (W2 item 10)."""
    return list((st.get("hold") or {}).get("items") or []) + [
        i for i in (st.get("fill") or {}).get("quiet") or [] if i.get("left_off")]


def restore_run(nodes, item, include_scripts=True):
    """One item's `restore` run: its SQL as postgres in `restore.database`
    (`postgres` when absent), or its root script. None when it has nothing
    to run here; else the run."""
    from . import fill
    restore = item.get("restore") or {}
    if restore.get("sql"):
        return nodes.run(item["node"], "postgres",
                         stdin=fill.UNSEEN_SQL + "\n".join(restore["sql"]) + "\n",
                         argv=fill.psql_argv(restore.get("database") or "postgres"))
    if restore.get("script") and include_scripts:
        return nodes.run(item["node"], "root", stdin=restore["script"] + "\n")
    return None


def _out(result):
    out = result.stdout
    return out.decode("utf-8", "replace") if isinstance(out, (bytes, bytearray)) else (out or "")


def _why(result):
    from .inject import psql_error_line
    return f"exit {result.returncode}: {psql_error_line(result)}"


@dataclass
class CleanRestartResult:
    game_id: str
    ok: bool = False
    restored: list = field(default_factory=list)
    wal: dict = field(default_factory=dict)
    logs: dict = field(default_factory=dict)
    dated: dict = field(default_factory=dict)
    at: str = None
    services: list = field(default_factory=list)
    reason: str = None

    def text(self):
        out = [f"Game {self.game_id}: clean-restart."]
        if self.restored:
            out.append(f"  restored, left by the fill: {'; '.join(self.restored)}")
        for node, w in self.wal.items():
            out.append(f"  {node}: WAL padded by {w['padded_bytes']} bytes in {w['seconds']} s, "
                       f"pg_wal {w['pg_wal_bytes']} bytes after the checkpoints")
        for node, n in self.logs.items():
            out.append(f"  {node}: {n} log file(s) removed or emptied")
        for node, n in self.dated.items():
            out.append(f"  {node}: {n} data file(s) dated to their last virtual write")
        if self.ok:
            out.append(f"  every service restarted at {self.at} ({len(self.services)} services, the "
                       "monitoring included): the anchor")
            out.append("Next: gmctl start-load.")
        else:
            out.append(f"FAILED: {self.reason}")
        return "\n".join(out)


class CleanRestart:
    def __init__(self, scenario, ldir, impl, st, record, nodes, docker, out=print,
                 sleep=time.sleep, clock=time.monotonic):
        self.scenario, self.ldir, self.impl, self.st, self.record = scenario, ldir, impl, st, record
        self.nodes, self.docker, self.out, self.sleep, self.clock = nodes, docker, out, sleep, clock
        self.result = CleanRestartResult(impl["game_id"])

    def record_state(self, **fields):
        def change(st):
            st.setdefault("clean_restart", {}).update(fields)
        localimpl.update_state(self.ldir, change)

    def primaries(self):
        from .deploy import hold_nodes
        return hold_nodes(self.scenario, self.impl)

    def brick_nodes(self, brick):
        return [name for name, node in self.impl["nodes"].items()
                if (node.get("brick") or {}).get("id") == brick]

    # 1. what the fill left
    def restore_leftovers(self):
        at = iso(now_utc())
        items = leftovers(self.st)
        for item in items:
            r = restore_run(self.nodes, item)
            if r is not None and not r.ok:
                raise GmError(f"{item['node']}: {item['what']} not restored: {_why(r)}")
            item["restored_at"] = at
            self.result.restored.append(f"{item['node']}: {item['what']}")
        if items:
            quiet = self.st["fill"]["quiet"]
            localimpl.update_state(self.ldir, lambda st: st["fill"].update(quiet=quiet))
        from . import inject
        clock = inject.clock_plan(self.scenario, self.impl)
        if clock is not None:
            inject.drop_clock(self.ldir, clock, self.docker, out=lambda *a, **k: None)

    # 2. the WAL
    def pad(self, rates):
        from . import fill
        for node in self.primaries():
            r = self.nodes.run(node, "postgres", stdin=fill.UNSEEN_SQL + pad_sql(DAY_HOURS * rates[node]),
                               argv=fill.psql_argv("postgres", tuples=True), timeout=1800)
            if not r.ok:
                raise GmError(f"node {node}: padding the WAL: {_why(r)}")
            self.result.wal[node] = json.loads(_out(r).strip().splitlines()[-1])
            self.record_state(wal=self.result.wal)

    # 3. the statistics
    def reset(self):
        from . import fill, inject
        # `postgres` last, its statement reset and the shared one in one
        # session: every stats_reset the same instant to the millisecond
        for node in self.primaries():
            databases = [d for d in inject._databases(self.ldir, node, self.docker)
                         if d != "postgres"]
            for database in databases + ["postgres"]:
                last = database == "postgres"
                r = self.nodes.run(node, "postgres", stdin=fill.UNSEEN_SQL + STATEMENTS_RESET_SQL
                                   + (SHARED_RESET_SQL if last else ""),
                                   argv=fill.psql_argv(database))
                if not r.ok:
                    what = "the statement and shared statistics" if last else "the statement statistics"
                    raise GmError(f"node {node}: resetting {what} in {database}: {_why(r)}")

    # 4. the actors back for the next start; the stop; the files
    def restore_left_off(self):
        for item in left_off(self.st):
            r = restore_run(self.nodes, item, include_scripts=False)
            if r is not None and not r.ok:
                raise GmError(f"{item['node']}: {item['what']} not restored: {_why(r)}")

    def stop_postgres(self):
        for node in self.primaries():
            r = self.nodes.run(node, "root", stdin=PG_STOP_SCRIPT, timeout=330)
            if not r.ok:
                raise GmError(f"node {node}: stopping PostgreSQL: {_why(r)}")

    def services(self):
        return [node["service"] for node in self.impl["nodes"].values()]

    def scale(self, replicas):
        self.docker.run(["service", "scale", "-d", *(f"{s}={replicas}" for s in self.services())])

    def wait_stopped(self):
        deadline = self.clock() + STOP_TIMEOUT
        while True:
            running = [s for s in self.services() if running_containers(self.docker, s)]
            if not running:
                return
            if self.clock() >= deadline:
                raise GmError(f"services still running {STOP_TIMEOUT} s after the stop: "
                              f"{', '.join(running)}")
            self.sleep(POLL)

    def helper(self, node, volume, script):
        """A helper container of the node's image on its host, the game's
        volume `volume` mounted at HELPER_MOUNT, running `script`."""
        from .restart import volume_name
        host = self.docker.on_host(self.impl["nodes"][node].get("host"))
        r = host.run(["run", "--rm", "-i", "--pull", "never", "--network", "none", "--user", "0:0",
                      "--label", f"{localimpl.LABEL_GAME}={self.impl['game_id']}",
                      "-v", f"{volume_name(self.impl, node, volume)}:{HELPER_MOUNT}",
                      "--entrypoint", "sh", self.impl["nodes"][node]["image"], "-s"],
                     input=script, check=False)
        if r.returncode != 0:
            detail = " ".join((r.stderr or "").split()) or f"exit status {r.returncode}"
            raise GmError(f"node {node}: volume {volume}: {detail}")
        return r.stdout or ""

    def files(self):
        fill_st = self.st.get("fill") or {}
        fill_span = (parse_instant(fill_st["started_at"]).timestamp(),
                     parse_instant(fill_st["ended_at"]).timestamp())
        virtual_span = (parse_instant(self.record["virtual_t0"]).timestamp(),
                        parse_instant(self.record["anchor"]).timestamp())
        for node in self.primaries():
            removed = int(self.helper(node, PG_LOG_VOLUME, PG_LOGS_SCRIPT).strip() or 0)
            self.result.logs[node] = removed
            listing = self.helper(node, PG_DATA_VOLUME, LIST_SCRIPT)
            script, n = touch_script(listing, fill_span, virtual_span)
            self.helper(node, PG_DATA_VOLUME, script)
            self.result.dated[node] = n
        for node in self.brick_nodes(PGBOUNCER_BRICK):
            self.result.logs[node] = int(self.helper(node, POOLER_LOG_VOLUME, POOLER_LOGS_SCRIPT).strip() or 0)

    def rewrite_stack(self):
        from .render import build_stack, dump_stack, story_line
        self.record["restart"] = {"at": None, "story_line": story_line(self.record["anchor"]),
                                  "explains": explains(self.st)}
        localimpl.write_restart_record(self.ldir, self.record)
        localimpl.write_text(Path(self.ldir) / localimpl.STACK_FILE,
                             dump_stack(build_stack(self.scenario, self.impl, False), self.impl["game_id"]))

    # 5. the start
    def start(self):
        from .deploy import wait_healthy
        at = now_utc().replace(microsecond=0)
        self.scale(1)
        self.result.at = iso(at)
        self.result.services = self.services()
        self.record["restart"]["at"] = self.result.at
        localimpl.write_restart_record(self.ldir, self.record)
        wait_healthy(self.docker, self.impl)
        restored = iso(now_utc())

        def change(st):
            for item in left_off(st):
                item["restored_at"] = restored
        localimpl.update_state(self.ldir, change)

    def run(self):
        rates = wal_rates(self.scenario, self.primaries())
        self.record_state(started_at=iso(now_utc()), ended_at=None, outcome=None, reason=None, wal={})
        try:
            self.restore_leftovers()
            self.pad(rates)
            self.reset()
            self.restore_left_off()
            self.stop_postgres()
            self.scale(0)
            self.wait_stopped()
            self.files()
            self.rewrite_stack()
            self.start()
        except GmError as exc:
            self.result.reason = str(exc)
            self.record_state(ended_at=iso(now_utc()), outcome="failed", reason=str(exc))
            return self.result
        self.result.ok = True
        self.record_state(ended_at=iso(now_utc()), outcome="ok", reason=None)
        return self.result


def refusal(st, impl, record, now=None):
    """Why clean-restart cannot run now, or None. Before the planned anchor
    it is refused: the fill's rows run to the anchor and every verb after
    the restart takes `restart.at` as the tail's start, the planned anchor
    before it (capture W2 item 8)."""
    if not localimpl.is_fake(impl) or not record:
        return "not a fake game: clean-restart is a fake game's (gmctl render --aging fake)"
    if (st.get("clean_restart") or {}).get("outcome") == "ok":
        return "already done: the restart is recorded; next, gmctl start-load"
    if (st.get("fill") or {}).get("outcome") != "ok":
        return "the fill has not ended ok: run gmctl fill first"
    anchor = parse_instant(record.get("anchor"))
    now = now_utc() if now is None else now
    if anchor is not None and now < anchor:
        return (f"the anchor {iso(anchor)} has not come: the fill's rows run to it, so the "
                "restart is at or after it; run clean-restart then")
    return None


def clean_restart(scenario_dir, playground, docker=None, nodes=None, out=print):
    """`gmctl clean-restart <scenario-dir> --playground <name>`; returns a
    CleanRestartResult. GmError on a refusal (nothing done, nothing
    recorded); a failure is recorded in `state.yaml` `clean_restart`."""
    from . import fill
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.require_stage(ldir, INJECT_STAGE)
    impl = localimpl.read_implementation(ldir)
    record = localimpl.read_restart_record(ldir)
    why = refusal(st, impl, record, now_utc())
    if why:
        raise GmError(f"clean-restart refused: {why}")
    scenario = model.load_scenario(scenario_dir)
    docker = docker or for_local_dir(ldir)
    nodes = nodes or fill.Nodes(ldir, impl, docker)
    return CleanRestart(scenario, ldir, impl, st, record, nodes, docker, out).run()
