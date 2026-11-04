"""`gmctl load-data` and `gmctl inject`: the setup steps after deployment.

Master spec 10.1 (data and state faults reach a node through the injection
path), 12 (setup steps 5, "Failures") and 8.1 (script contracts); the
behaviour is fixed by capture W3-A (`specs/versions/v0.1/wave-log.md`):

- `load-data`, at stage `deployed`: for every node with a `data` entry, in
  `nodes` order, its `data/<node>.sql` is streamed into `psql -X -q -v
  ON_ERROR_STOP=1 -d postgres`, run as OS user `postgres` in the node's
  container (local peer authentication). At `data-loaded` or a later
  deployed stage it changes nothing: idempotency is the stage, not the SQL.
  Then (v0.3 chunk 7b; capture W1, item 7) every application role a
  scheduler's schedule names gets its password from its secret
  `role_<role>_password`, the data having created the role: streamed the
  same way into the database node the connection targets (when it
  targets another node, a pooler: every `database` node whose data file
  creates the target database, every `database` node when none does;
  v0.4, a game with two), as a SCRAM
  verifier, with statement logging off for the session, so the password
  is never in a log, a process list or the server's statistics.
  Then (spec D176) on every `database` node whose brick has the GM check
  role (it mounts `gm_check_password`: the role exists), `gm_check` is
  granted `CONNECT` on every database but the templates, the same way, a
  scenario's data possibly having revoked it from `PUBLIC`.
- v0.4 (master spec 14, 7.2, 8.5, 8.6, 11.6; captures W1 items 0 and 8,
  W2-x of `specs/versions/v0.4/wave-log.md`): each data file gets `-v
  customer_timezone=<zone> -v customer_utc_offset=<n>` (render's shift;
  `Etc/GMT` and 0 in a game with none); the passwords are set for the
  roles a node's `crontab_roles` names too, on that node, and (master
  spec 9.7) for every login role a node's data file creates without a
  password of its own, on that node, each from its secret
  `role_<role>_password` (a role the data file gives a password keeps
  it, 16.4); then every
  database of every `database` node is surveyed (`pg_cron`, foreign
  servers, user mappings), each user mapping gets as its `password` option
  its remote role's secret, and where the check role exists it gets, in a
  database holding `pg_cron`, the read policy CHECK_POLICY on `cron.job`
  and `cron.job_run_details`, and in a database holding a foreign server
  the mapping-roles function MAPPING_FUNCTION; then the `CONNECT` grant.
  Last (the `pg_cron` noise fix, wave 3 of v0.4), on every `database` node
  where the survey found `pg_cron` in a database: until the data file has
  created `cron.database_name`, the preloaded launcher exits at each start
  (`database "..." does not exist`, about once a second from boot), lines
  in the file log the players read. load-data waits for the launcher to be
  connected (LAUNCHER_WAIT), has the logging collector switch files
  (`pg_rotate_logfile()`), and removes from the files it closed the failed
  launchers' lines only (CLEAN_SH): each `background worker "pg_cron
  launcher" (PID n) exited with exit code 1` and every line PID n logged
  before it (the `[%p]` of the brick's `log_line_prefix`). Nothing else in
  the log changes; the launcher not connected fails the step.
- v0.5 (master spec 7.1, 11.1, 15; capture W1 item 6 of
  `specs/versions/v0.5/wave-log.md`): **a standby** (a `postgres` node
  with `standby_of: <primary>`) takes no step but its clone: no data file,
  password, survey, mapping, grant or log clean-up runs there, all of them
  reaching it from its primary (a schedule's role naming a standby as its
  target gets its password on the primary). **The clone** is load-data's
  last step, for each standby in topology order: on the primary, the
  replication role `replicator` (`LOGIN REPLICATION`) created or updated
  with the secret `replication_password` as a SCRAM verifier, statement
  logging, pgaudit and statistics off, and an inactive slot of the
  standby's name dropped; then `/usr/local/lib/gm/clone-standby` run as
  root in the standby (pg_basebackup from the primary, the slot created,
  postgres restarted as a standby); then load-data waits, bounded by its
  `--timeout` (STANDBY_WAIT without one), until the primary's
  `pg_stat_replication` shows the slot's sender `streaming`. Any failure
  is a failed setup. The sessions writing a secret (passwords, user
  mappings) turn pgaudit off beside statement logging (G5).
- v0.5, **the composed load** (master spec 8.5, 12.1 item 5, 15, 24;
  formats.md "Composing domains"; capture W2 item 3, spec D358, D360):
  after the nodes' data files, a scenario with `domains:` loads each
  domain in `composition.yaml`'s `order`, read from the catalogue
  (`<catalog>/domains/<id>/`): each `at:` database absent from its node
  created (owner `postgres`, `CONNECT` revoked from `PUBLIC`), then the
  domain's `schema.sql` and `load.sql` run connected to it (`psql -d
  <db>`, the database named in them as `:"DBNAME"`; a several-database
  part in `databases` order), then each of its partner folders'
  `producers/partners/<prefix>/data.sql`, in name order, into the
  partners' database `partners` (on the `postgres` node the
  `third_parties:` entries list). The core's `data/keys.sql`, when it
  ships one, is streamed ahead of every load, partner file and
  derivation of the core and its parts, in the same session, so its
  `pg_temp.core_*` functions vanish with it; a part's own `data/keys.sql`
  (`pg_temp.<its prefix>_*`) after it, ahead of that part's load, partner
  files and derivation (chunk 29's (a)). A partner folder
  `composition.yaml`'s `left_out:` names runs as any other when the
  scenario has a partners' database, and is skipped when it has none
  (chunk 29's (b)). A domain's `data/cron.sql`
  (`cron.schedule_in_database(...)` calls only) runs last of its load, on
  its one node, connected to the node's `cron.database_name` (its seed
  postgresql.conf), unseen, its jobs' databases and roles now there (chunk
  29's (d), spec D405). Then the sanctioned
  derivations (`derive`, in order), then each `purposes:` entry's
  `history` (in list order, in its `target`), each reading its sources
  through foreign schemas `gm_src_<name>` (postgres_fdw, as `gm_check`
  with its secret) created for the session and dropped after, with the
  extension when the session created it; their sessions unseen
  (statement logging, pgaudit and pg_stat_statements off locally;
  `gm_check`'s role settings likewise on every source, set before and
  reset after); one reading `partners` from another node is refused
  (spec D383). Then the coherence check (coherence.py), its record in
  `composition.yaml` and state.yaml, a failing check failing the setup
  as a design error; a check reading `partners` runs in `partners` on the
  partners' node (that source over the node's socket, its other reads
  over TCP; spec D383). Every file load-data runs gets `-v load_epoch=<the
  run's start, UTC, to the minute>` beside the zone and its offset. The
  v0.4 steps (passwords to the `pg_cron` clean-up) follow, then the
  standbys' clone.
- `inject`, at `data-loaded` (or `injected`, to replay the idempotent
  scripts): for every fault instance in `fault_instances` order, a `state`
  fault's `injection.scripts` are streamed in their listed order into `sh
  -s` on the instance's node, as `injection.run_as` (default root), with
  its `FAULT_*` variables; a `seed-file` fault runs nothing. The first
  non-zero exit stops the run. A `parameter` fault (v0.2 capture W1, item
  8) runs nothing either: render planted it. In a game with scheduler
  nodes (v0.3 capture W2, items 2 and 4) only the instances due at T0 are
  planted; the others are planted once the load runs, by `inject --at`
  (`aging`). Recording `injected` writes every instance's `plantings`
  entry. At `load-started` it is refused: re-planting one instance is
  `inject --at now --instance <id>`.

Each step is one `state.setup_step`: any failure, or Ctrl-C, tears the game
down and records `failed` with the reason.
"""

import base64
import hashlib
import hmac
import json
import os
import re
import shutil
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

import yaml

from . import coherence, localimpl, model, render, state, teardown
from .docker import for_local_dir
from .execnode import exec_node
from .model import GmError

DEPLOY_STAGE = "deployed"
DATA_STAGE = "data-loaded"
INJECT_STAGE = "injected"
LOAD_STAGE = "load-started"
T0 = "T0"
DATA_USER = "postgres"
PSQL_ARGV = ("psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-d", "postgres")
DEFAULT_RUN_AS = "root"
STATE_KIND = "state"
DATABASE_ROLE = "database"
SCRAM_ITERATIONS = 4096             # PostgreSQL's scram_iterations default
SCRAM_SALT_BYTES = 16
PARAMETER_KIND = localimpl.PARAMETER_KIND
CHECK_ROLE = "gm_check"             # the GM check role (v0.3 capture W1-x)
CHECK_SECRET = "gm_check_password"  # mounted on a node: its check role exists
# v0.4 (capture W2-x): what load-data gives the check role.
CHECK_POLICY = "gm_check_read"      # its read policy on CRON_TABLES
CRON_TABLES = ("cron.job", "cron.job_run_details")
CHECK_SCHEMA = "gm_check"           # the mapping-roles function's schema
MAPPING_FUNCTION = f"{CHECK_SCHEMA}.user_mapping_roles"
TIMEZONE_VAR, OFFSET_VAR = "customer_timezone", "customer_utc_offset"   # W1 item 0
# The survey's psql: unaligned, tuples only (one JSON value per line).
SURVEY_ARGV = ("psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-d", "postgres")
# Statement logging off, and the "temporary file" lines a big load or
# derivation writes under a seed's `log_temp_files = 0` (superuser-only:
# every session prefixed with it runs as DATA_USER).
NO_LOG_SQL = ("SET log_statement = 'none';", "SET log_min_duration_statement = -1;",
              "SET log_min_error_statement = 'panic';", "SET log_temp_files = -1;")
NO_STATS_SQL = ("SET pg_stat_statements.track = 'none';",)
# pgaudit off for a session writing a secret (v0.5 G5), beside statement
# logging: its `role` class logs the statement's text into the log the
# players' group reads (pgaudit 18.0 redacts a password there; the
# session's other statements stay out too). Accepted whether pgaudit is
# loaded or not (a placeholder setting then).
NO_AUDIT_SQL = ("SET pgaudit.log = 'none';",)
QUIET_SQL = "SET client_min_messages = warning;"    # no "already exists" notices
REDACTED = "<password>"
# The pg_cron noise fix: the launcher's background worker type (its
# pg_stat_activity.backend_type, and the name the postmaster's exit lines
# give it), how long load-data waits for it and for the collector's switch.
LAUNCHER = "pg_cron launcher"
LAUNCHER_WAIT = 60                  # seconds; the launcher restarts once a second
ROTATE_WAIT = 10                    # seconds
# The standby's clone (v0.5 capture W1 item 6).
REPLICATION_ROLE = "replicator"
REPLICATION_SECRET = "replication_password"
CLONE_STANDBY = "/usr/local/lib/gm/clone-standby"
CLONE_RESTORE = "--restore"         # a restart's from the snapshot (capture W2-g item 3)
STANDBY_WAIT = 300                  # seconds, without --timeout: the clone, then streaming
# The composed load (v0.5 capture W2 item 3).
EPOCH_VAR = "load_epoch"            # every file's one reference moment
COMPOSITION_FILE = "composition.yaml"
KEYS_FILE = model.KEYS_FILE         # a core's key functions, pg_temp.core_*; a part's
CRON_FILE = model.CRON_FILE         # a domain's pg_cron jobs (chunk 29's (d))
DERIVE_FILE = "data/derive.sql"
PARTNERS_DB = coherence.PARTNERS    # the partners' database (W2 item 0)
PARTNER_DATA = "data.sql"           # producers/partners/<prefix>/data.sql
SOURCE_PREFIX = "gm_src_"           # load-data's foreign schemas and servers (reserved)
FDW = "postgres_fdw"
SOCKET_DIR = "/run/postgresql"      # a source on the same instance
PG_PORT = 5432
MAX_NAME = 63                       # PostgreSQL's identifier length
# gm_check's role settings on a source while load-data reads it: what the
# local session sets for itself (NO_LOG_SQL, NO_STATS_SQL, NO_AUDIT_SQL).
# Set by postgres, the superuser-only ones (log_temp_files among them)
# apply at gm_check's login, though gm_check could not SET them itself.
CHECK_ROLE_SETTINGS = (("log_statement", "none"), ("log_min_duration_statement", "-1"),
                       ("log_min_error_statement", "panic"), ("log_temp_files", "-1"),
                       ("pg_stat_statements.track", "none"), ("pgaudit.log", "none"))
_CONNECT_RE = re.compile(r"^\s*\\(c|connect)(\s|$)")


# --- Fault parameters --------------------------------------------------------

def _env_text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def fault_env(fault, instance):
    """The `FAULT_<NAME>` variables of one fault instance (captures W1-D,
    W3-A): each parameter the fault declares, valued by the instance's
    `parameters` entry, else the fault's `default`; a scalar as text
    (booleans `true`/`false`). A parameter with no value is not set, unless
    it is `required`: then GmError, as for a list or map value or an invalid
    name. Nothing else goes into the environment."""
    iid = instance.get("id")
    given = instance.get("parameters") or {}
    env = {}
    for pname, spec in (fault.data.get("parameters") or {}).items():
        spec = spec if isinstance(spec, dict) else {}
        name = model.fault_env_name(pname)
        if name is None:
            raise GmError(f"fault {fault.id}: parameter {pname!r} has no valid environment name")
        value = given.get(pname)
        if value is None:
            value = spec.get("default")
        if value is None:
            if spec.get("required"):
                raise GmError(f"fault instance {iid} ({fault.id}): parameter {pname} is "
                              "required and has no value")
            continue
        if isinstance(value, (list, dict)):
            raise GmError(f"fault instance {iid} ({fault.id}): parameter {pname} is a list "
                          "or map; only a scalar can be passed to a script")
        env[name] = _env_text(value)
    return env


def fault_instances(scenario, impl=None):
    """[(instance, fault definition)] in `fault_instances` order; with the
    game's `impl`, those the test harness left out omitted
    (localimpl.left_out)."""
    out = localimpl.left_out(impl)
    return [(inst, scenario.faults[inst["id"]])
            for inst in scenario.data.get("fault_instances") or [] if inst["id"] not in out]


def node_of(instance, impl):
    """The instance's node, refused unless the game has it."""
    node = instance.get("node")
    if node not in impl["nodes"]:
        raise GmError(f"fault instance {instance.get('id')}: node {node!r} is not a node of "
                      f"game {impl['game_id']}")
    return node


# --- Output ------------------------------------------------------------------

def output_lines(result):
    """The non-empty lines a run printed, stdout first, then stderr."""
    lines = []
    for stream in (result.stdout, result.stderr):
        if isinstance(stream, (bytes, bytearray)):
            stream = stream.decode("utf-8", "replace")
        lines += [line.rstrip() for line in (stream or "").splitlines() if line.strip()]
    return lines


def _first_line(result):
    lines = output_lines(result)
    return lines[0] if lines else "no output"


PSQL_ERROR_PREFIXES = (("ERROR:",), ("FATAL:", "psql:"))


def psql_error_line(result):
    """The line of a failed psql run that says why: the first starting
    with `ERROR:`, else with `FATAL:` or `psql:`, else the first line
    (release-gate finding RG-9: the output's first line may be a result,
    `setval`, printed before the error)."""
    lines = output_lines(result)
    for prefixes in PSQL_ERROR_PREFIXES:
        for line in lines:
            if line.startswith(prefixes):
                return line
    return _first_line(result)


def _print_run(out, heading, result):
    out(f"{heading}: {'ok' if result.ok else f'exit {result.returncode}'}")
    for line in output_lines(result):
        out(f"    {line}")


def _game(scenario_dir, playground):
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    return ldir, st


def _undo(docker, game_id):
    return lambda: teardown.remove_game_objects(docker, game_id).text()


# --- load-data -----------------------------------------------------------------

@dataclass
class LoadResult:
    game_id: str
    already: str = None             # the stage, when the data was already loaded
    loaded: list = field(default_factory=list)     # [(node, file)]
    created: list = field(default_factory=list)    # [(node, database)] a domain's, created
    domains: list = field(default_factory=list)    # [(domain, node, database, what)] run
    partners: list = field(default_factory=list)   # [(domain, prefix, node)]
    derived: list = field(default_factory=list)    # [(domain, node, database)]
    histories: list = field(default_factory=list)  # [(purpose, node, database)]
    coherence: list = field(default_factory=list)  # [coherence.Outcome]
    coherence_result: str = None                   # pass | fail, None without domains:
    passwords: list = field(default_factory=list)  # [(database node, [role])]
    mappings: list = field(default_factory=list)   # [(node, database, [Mapping])]
    policies: list = field(default_factory=list)   # [(node, database)]: CHECK_POLICY
    functions: list = field(default_factory=list)  # [(node, database)]: MAPPING_FUNCTION
    grants: list = field(default_factory=list)     # database nodes: CHECK_ROLE's CONNECT
    standbys: list = field(default_factory=list)   # [(standby, primary, slot)] cloned
    cleaned: list = field(default_factory=list)    # [(node, [(log file, lines removed)]
                                                   #   or None: no file log)]
    warnings: list = field(default_factory=list)   # [text]: a log left as it was

    def text(self):
        if self.already:
            return (f"Game {self.game_id} is at stage {self.already}: the data is already "
                    "loaded; nothing done.")
        out = [f"Game {self.game_id}: data loaded."]
        out += [f"  {node}: {rel}" for node, rel in self.loaded]
        if not self.loaded and not self.domains:
            out.append("  no node holds data")
        out += [f"  {node}/{db}: database created for the domains, CONNECT revoked from PUBLIC"
                for node, db in self.created]
        out += [f"  {node}/{db}: {what}" for _, node, db, what in self.domains]
        out += [f"  {node}/{PARTNERS_DB}: partner {prefix}'s state ({domain})"
                for domain, prefix, node in self.partners]
        out += [f"  {node}/{db}: {domain}'s derivation, unseen" for domain, node, db in self.derived]
        out += [f"  {node}/{db}: purpose {pid}'s history, unseen"
                for pid, node, db in self.histories]
        if self.coherence_result:
            counts = {r: sum(1 for o in self.coherence if o.result == r)
                      for r in (coherence.PASS, coherence.FAIL, coherence.SKIPPED)}
            out.append(f"  coherence check: {self.coherence_result} ({counts['pass']} passed, "
                       f"{counts['fail']} failed, {counts['skipped']} skipped; recorded in "
                       f"{COMPOSITION_FILE})")
            out += [f"    {o.domain} {o.check}: skipped ({o.reason})" for o in self.coherence
                    if o.result == coherence.SKIPPED]
        out += [f"  {node}: password set from its secret for role(s) {', '.join(roles)}"
                for node, roles in self.passwords]
        out += [f"  {node}/{db}: user mapping for {m.local_text} on server {m.server} given "
                f"remote role {m.remote_role}'s password"
                for node, db, mappings in self.mappings for m in mappings]
        out += [f"  {node}/{db}: {CHECK_ROLE} may read every row of {' and '.join(CRON_TABLES)} "
                f"(policy {CHECK_POLICY})" for node, db in self.policies]
        out += [f"  {node}/{db}: {MAPPING_FUNCTION}() created for {CHECK_ROLE}"
                for node, db in self.functions]
        out += [f"  {node}: {CHECK_ROLE} granted CONNECT on every database"
                for node in self.grants]
        out += [f"  {standby}: cloned from {primary}, a standby streaming from slot {slot}"
                for standby, primary, slot in self.standbys]
        for node, files in self.cleaned:
            removed = sum(n for _, n in files or [])
            out.append(f"  {node}: {LAUNCHER} running; " + (
                "no file log (logging_collector off)" if files is None
                else f"{removed} line(s) of its start-up failures removed from the server log "
                f"({', '.join(f for f, _ in files)})" if removed
                else "no start-up failure of it in the server log"))
        out += [f"  warning: {text}" for text in self.warnings]
        out.append(f"Stage {DATA_STAGE}.")
        return "\n".join(out)


def scram_verifier(password, salt=None, iterations=SCRAM_ITERATIONS):
    """PostgreSQL's stored form of a SCRAM-SHA-256 password (RFC 5802,
    7677): `SCRAM-SHA-256$<iterations>:<salt>$<StoredKey>:<ServerKey>`,
    base64. The server stores it as given and authenticates the password
    against it."""
    salt = os.urandom(SCRAM_SALT_BYTES) if salt is None else salt
    salted = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    stored = hashlib.sha256(hmac.new(salted, b"Client Key", hashlib.sha256).digest()).digest()
    server = hmac.new(salted, b"Server Key", hashlib.sha256).digest()

    def b64(raw):
        return base64.b64encode(raw).decode("ascii")
    return f"SCRAM-SHA-256${iterations}:{b64(salt)}${b64(stored)}:{b64(server)}"


def psql_variables(impl):
    """The data load's two psql variables (v0.4 capture W1 item 0): the
    customer's bare zone and its offset from UTC in whole hours, east
    positive, without `+`: render's shift, 0 in a game with none."""
    shift = int(((impl.get(localimpl.TIMELINE) or {}).get("shift")) or 0)
    return {TIMEZONE_VAR: render.zone_name(shift), OFFSET_VAR: str(shift)}


def load_epoch(now=None):
    """The run's one reference moment (W2 item 3): its start, UTC, ISO 8601
    to the minute (`2026-11-04T09:30Z`); a load's "now" is
    `:'load_epoch'::timestamptz`, never `now()`."""
    now = now or datetime.now(timezone.utc)
    return now.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")


def data_argv(variables, database="postgres"):
    """PSQL_ARGV with each variable as `-v <name>=<value>` before `-d`,
    connected to `database`."""
    extra = [arg for name, value in variables.items() for arg in ("-v", f"{name}={value}")]
    return (*PSQL_ARGV[:-2], *extra, PSQL_ARGV[-2], database)


def read_argv(database):
    """SURVEY_ARGV (unaligned, tuples only) connected to `database`."""
    return (*SURVEY_ARGV[:-1], database)


def password_plan(scenario, impl, catalog_root=model.REPO_ROOT):
    """[(database node, [(role, secret)])]: every role a scheduler node's
    schedule or an `api` node's api.yaml names (spec D345; an HTTP
    connection names none), on the node its connection targets when that node is a
    `database` node, else (through a pooler) on the `database` nodes where
    the target database is created (model.node_creates: the data file, or
    v0.5 a composed domain or a partner `data.sql` from `catalog_root`,
    W2 item 1, spec D360), or on every `database` node when none is; then (v0.4 capture W1
    item 8) every role a node's `crontab_roles` names, on that node; then
    (master spec 9.7) every login role created on a node with no password
    of its own (localimpl.data_login_roles, from the same `catalog_root`:
    its data file's, then its domains' and partner files'), on that node;
    topology order, each role once per node."""
    primaries = {n["name"]: localimpl.standby_of(n) for n in scenario.nodes
                 if localimpl.standby_of(n)}
    databases = [n["name"] for n in scenario.nodes
                 if n.get("role") == DATABASE_ROLE and n["name"] not in primaries]
    created = {n["name"]: model.node_creates(Path(scenario.dir), scenario.data, n, catalog_root)
               for n in scenario.nodes if n["name"] in databases}
    roles_of = {}

    def add(db, role):
        db = primaries.get(db, db)        # a standby's roles are its primary's (v0.5)
        if db not in impl["nodes"]:
            raise GmError(f"node {db} is not a node of game {impl['game_id']}")
        roles = roles_of.setdefault(db, [])
        if role not in roles:
            roles.append(role)
    for node in scenario.nodes:
        for conn in localimpl.sql_connections(scenario, node).values():
            role = conn.get("role")
            m = model.TARGET_RE.match(str(conn.get("target")))
            target, database = (m.group(1), m.group(4)) if m else (None, None)
            holders = [db for db in databases
                       if created[db] is not None and database in created[db].databases]
            for db in [target] if target in databases or target in primaries \
                    else holders or databases:
                add(db, role)
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE:
            continue
        for role in localimpl.crontab_roles(node):
            add(node["name"], role)
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE:
            continue
        for role in localimpl.data_login_roles(scenario, node, catalog_root):
            add(node["name"], role)
    return [(db, [(r, localimpl.role_secret_name(r)) for r in roles_of[db]])
            for db in databases if db in roles_of]


def read_secret(ldir, secret):
    """A password secret's text, from `secrets/`; GmError when unreadable
    or empty."""
    path = localimpl.secrets_dir(ldir) / secret
    try:
        password = path.read_text(encoding="utf-8").strip()
    except OSError:
        raise GmError(f"secret file {path} cannot be read: deploy writes it") from None
    if not password:
        raise GmError(f"secret file {path} is empty")
    return password


def password_sql(ldir, roles):
    """The SQL setting each role's password from its secret file in
    `secrets/`, statement logging and pgaudit off for the session."""
    lines = list(NO_LOG_SQL + NO_AUDIT_SQL)
    for role, secret in roles:
        password = read_secret(ldir, secret)
        lines.append(f'ALTER ROLE "{role}" PASSWORD \'{scram_verifier(password)}\';')
    return "\n".join(lines) + "\n"


def grant_plan(scenario, impl):
    """The `database` nodes whose check role exists (they mount
    CHECK_SECRET), topology order; no standby (read-only, its grants its
    primary's)."""
    plan = []
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE or localimpl.standby_of(node) or not any(
                sec.get("name") == CHECK_SECRET
                for sec in localimpl.node_secret_declarations(scenario, node)):
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append(node["name"])
    return plan


def grant_sql():
    """The SQL granting CHECK_ROLE `CONNECT` on every database but the
    templates, each name quoted as an identifier."""
    return ("DO $gm$\nDECLARE\n  db name;\nBEGIN\n"
            "  FOR db IN SELECT datname FROM pg_catalog.pg_database\n"
            "            WHERE NOT datistemplate AND datname NOT IN ('template0', 'template1')\n"
            "            ORDER BY datname LOOP\n"
            f"    EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', db, '{CHECK_ROLE}');\n"
            "  END LOOP;\nEND\n$gm$;\n")


def data_plan(scenario, impl):
    """[(node, relative file, path)] of every node with a `data` entry, in
    `nodes` order; never a standby's (its data is its primary's clone)."""
    plan = []
    for node in scenario.nodes:
        spec = node.get("data")
        if not isinstance(spec, dict) or not spec.get("file") or localimpl.standby_of(node):
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append((node["name"], spec["file"], scenario.dir / spec["file"]))
    return plan


# --- The composed load: its plan (v0.5 capture W2 item 3) ---------------------

@dataclass
class Source:
    """A database a derivation, a history or a coherence query reads, through
    the foreign schemas gm_src_<name> (its `public`) and gm_src_<name>_<s>."""
    name: str
    node: str
    database: str

    @property
    def server(self):
        return SOURCE_PREFIX + self.name


@dataclass
class FileRun:
    """Files streamed in order into one psql session as `postgres`,
    connected to `database` on `node` (the core's keys first), unseen."""
    what: str                       # as printed: "<domain> data/load.sql"
    node: str
    database: str
    paths: list


@dataclass
class DomainLoad:
    domain: str
    databases: list                 # [(node, database)]: created when absent, in order
    runs: list                      # [FileRun]: each database's schema then load, then
                                    #   the partner files, then data/cron.sql
    partners: list                  # [(prefix, node)]


@dataclass
class SourcedRun:
    """A derivation or a purpose's history: its files run unseen in
    `database`, its sources reachable as gm_src_<name>."""
    kind: str                       # derive | history
    owner: str                      # the domain or the purpose
    what: str
    node: str
    database: str
    paths: list
    sources: list


@dataclass
class CheckRun:
    check: object                   # coherence.Check
    node: str
    database: str
    sources: list
    skipped: str = None             # why it is not run


@dataclass
class ComposedPlan:
    domains: list = field(default_factory=list)       # [DomainLoad], in order
    derivations: list = field(default_factory=list)   # [SourcedRun]
    histories: list = field(default_factory=list)     # [SourcedRun]
    checks: list = field(default_factory=list)        # [CheckRun]
    composition: Path = None        # the record, rewritten after the check

    def reading_nodes(self):
        """{node: [database]} every derivation, history and check run reads."""
        nodes = {}
        for run in self.derivations + self.histories + [c for c in self.checks
                                                        if not c.skipped]:
            for src in run.sources:
                dbs = nodes.setdefault(src.node, [])
                if src.database not in dbs:
                    dbs.append(src.database)
        return nodes


def _catalog_yaml(path, label):
    try:
        content = model.strict_load(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise GmError(f"{label}: missing file") from None
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        raise GmError(f"{label}: cannot be read: {' '.join(str(exc).split())}") from None
    if not isinstance(content, dict):
        raise GmError(f"{label}: top level: not a mapping")
    return content


def _load_node(scenario, impl, node, where):
    """`node`, refused unless a primary `database` node of the game (every load
    step skips a standby, W1-x)."""
    found = next((n for n in scenario.nodes if n.get("name") == node), None)
    if found is None or found.get("role") != DATABASE_ROLE:
        raise GmError(f"{where}: {node} is not a database node of the scenario")
    if localimpl.standby_of(found):
        raise GmError(f"{where}: {node} is a standby (standby_of {localimpl.standby_of(found)}): "
                      "it holds only its primary's copy, never a location")
    if node not in impl["nodes"]:
        raise GmError(f"node {node} is not a node of game {impl['game_id']}")
    return node


def _location(value, scenario, impl, where):
    m = model.AT_RE.match(value) if isinstance(value, str) else None
    if m is None:
        raise GmError(f"{where}: {value!r} is not <node>/<database>")
    return _load_node(scenario, impl, m.group(1), where), m.group(3)


def _file(base, rel, where, catalog):
    path = base / rel
    if not path.is_file():
        try:
            shown = path.relative_to(catalog).as_posix()
        except ValueError:
            shown = str(path)
        raise GmError(f"{shown}: missing file ({where})")
    return path


def _check_connected(path, shown, what="a domain's schema and load run connected to their"):
    """A domain's schema or load file, or a partner's data.sql, is run
    connected to its database (W2 items 0 and 3): GmError for one creating
    a database or switching to another."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        for number, line in enumerate(fh, 1):
            if _CONNECT_RE.match(line) or model.data_file_creates(line, shown).databases:
                raise GmError(f"{shown}:{number}: {line.strip()[:80]}: {what} database "
                              "(psql -d <db>, named :\"DBNAME\"), never create one or "
                              "\\connect to one")


def partners_node(scenario, impl=None):
    """The `postgres` node the `third_parties:` entries list (the partners'
    database, W2 item 0), or None; GmError for two."""
    by_name = {n.get("name"): n for n in scenario.nodes}
    found = []
    for entry in scenario.data.get("third_parties") or []:
        for name in (entry.get("nodes") or []) if isinstance(entry, dict) else []:
            node = by_name.get(name)
            if node is not None and node.get("role") == DATABASE_ROLE and name not in found:
                found.append(name)
    if len(found) > 1:
        raise GmError(f"scenario.yaml: third_parties: {len(found)} database nodes "
                      f"({', '.join(found)}); the partners share one, holding {PARTNERS_DB}")
    return found[0] if found else None


@dataclass
class _Domain:
    id: str
    dir: Path
    data: dict
    core: str
    locations: list                 # [(database of the domain or None, node, database)]
    sources: list                   # [Source]

    @property
    def several(self):
        return isinstance(self.data.get("databases"), list)


def _composed_domains(scenario, impl, catalog):
    """{id: _Domain} of every `domains:` entry, in its order."""
    out = {}
    for entry in scenario.data.get("domains") or []:
        did = entry.get("id")
        where = f"scenario.yaml: domains[{did}]"
        ddir = catalog / "domains" / str(did)
        data = _catalog_yaml(ddir / "domain.yaml", f"domains/{did}/domain.yaml")
        requires = data.get("requires")
        core = requires[0] if isinstance(requires, list) and requires else did
        at = entry.get("at")
        base = str(did).replace("-", "_")
        if isinstance(data.get("databases"), list):
            if not (isinstance(at, dict) and set(at) == set(data["databases"])):
                raise GmError(f"{where}.at: not a map from each of {did}'s databases")
            locations = [(db, *_location(at[db], scenario, impl, f"{where}.at.{db}"))
                         for db in data["databases"]]
            sources = [Source(f"{base}_{db}", node, database) for db, node, database in locations]
        else:
            locations = [(None, *_location(at, scenario, impl, f"{where}.at"))]
            sources = [Source(base, locations[0][1], locations[0][2])]
        for src in sources:
            if len(src.server) > MAX_NAME:
                raise GmError(f"{where}: its foreign schema {src.server} is longer than "
                              f"{MAX_NAME} characters")
        out[did] = _Domain(did, ddir, data, core, locations, sources)
    return out


def _keys(domains, catalog, did):
    """The key files streamed ahead of domain `did`'s load, partner files and
    derivation: the core's data/keys.sql, then, for a part, its own (capture
    W3 item 0, chunk 29's (a)); each when shipped."""
    core = domains[did].core
    paths = [catalog / "domains" / core / KEYS_FILE]
    if did != core:
        paths.append(domains[did].dir / KEYS_FILE)
    return [p for p in paths if p.is_file()]


def _cron_run(scenario, impl, d, catalog):
    """The FileRun of domain `d`'s data/cron.sql (capture W3 item 6 (d), spec
    D405), or None when it ships none: run as postgres on the domain's one
    node, connected to the node's cron.database_name, after the domain's
    load; GmError for a domain on several nodes, a node not preloading
    pg_cron, or a file holding more than cron.schedule_in_database calls."""
    path = d.dir / CRON_FILE
    if not path.is_file():
        return None
    shown = f"domains/{d.id}/{CRON_FILE}"
    nodes = list(dict.fromkeys(node for _, node, _ in d.locations))
    if len(nodes) != 1:
        raise GmError(f"{shown}: schedules pg_cron jobs on the domain's node, but its at: names "
                      f"{len(nodes)} nodes ({', '.join(nodes)}); a domain shipping one sits on "
                      "one node")
    node = next(n for n in scenario.nodes if n.get("name") == nodes[0])
    preloaded, database, rel = model.node_pg_cron(node, scenario.dir)
    if not preloaded:
        raise GmError(f"{shown}: schedules pg_cron jobs on node {nodes[0]}, which does not "
                      f"preload pg_cron (its seed postgresql.conf {rel or 'absent'}: "
                      "shared_preload_libraries)")
    problems = model.check_cron_file(path.read_text(encoding="utf-8"), shown)
    if problems:
        raise GmError("; ".join(problems))
    return FileRun(f"{d.id} {CRON_FILE}", nodes[0], database, [path])


def _refuse_partners_from_afar(run, pnode):
    """GmError for a derivation or a history (SourcedRun) reading the
    partners' database from another node (spec D383): `partners-db` has no
    `gm_check` host line, so only a session on that node reaches it."""
    for src in run.sources:
        if src.node == pnode and src.database == PARTNERS_DB and run.node != pnode:
            where = (f"{COMPOSITION_FILE}: derive[{run.owner}]" if run.kind == "derive"
                     else f"scenario.yaml: purposes[{run.owner}]")
            raise GmError(f"{where}: reads {pnode}/{PARTNERS_DB} ({src.server}) from "
                          f"{run.node}: the partners' database admits gm_check over its own "
                          "socket only, never from another node")


def composed_plan(scenario, impl, catalog_root=model.REPO_ROOT):
    """The composed load's ComposedPlan (W2 item 3), every file found and
    every location checked before anything runs; an empty plan for a
    scenario without `domains:`. A coherence check reading `partners` runs
    in that database on the partners' node (spec D383). GmError on a
    refusal."""
    plan = ComposedPlan()
    if not scenario.data.get("domains"):
        return plan
    catalog = Path(catalog_root)
    plan.composition = Path(scenario.dir) / COMPOSITION_FILE
    record = _catalog_yaml(plan.composition, COMPOSITION_FILE)
    domains = _composed_domains(scenario, impl, catalog)
    order = record.get("order")
    if not (isinstance(order, list) and sorted(map(str, order)) == sorted(domains)):
        raise GmError(f"{COMPOSITION_FILE}: order: {order!r} does not list every domain of "
                      "domains: once")
    pnode = partners_node(scenario)
    if pnode is not None:
        _load_node(scenario, impl, pnode, "scenario.yaml: third_parties")
    left_out = model.left_out_of(record)
    for did in order:
        d = domains[did]
        keys = _keys(domains, catalog, did)
        runs = []
        for db, node, database in d.locations:
            folder = Path("data") / db if db else None
            for key in ("schema", "load"):
                rel = folder / f"{key}.sql" if folder else d.data.get(key)
                path = _file(d.dir, str(rel), f"domains/{did}/domain.yaml {key}", catalog)
                shown = f"domains/{did}/{rel}"
                _check_connected(path, shown)
                runs.append(FileRun(f"{did} {rel}", node, database,
                                    (keys if key == "load" else []) + [path]))
        partners = []
        pdir = d.dir / "producers" / "partners"
        for folder in sorted(p for p in pdir.iterdir() if p.is_dir()) if pdir.is_dir() else []:
            path = folder / PARTNER_DATA
            if not path.is_file():
                continue
            if pnode is None and (did, f"partners/{folder.name}") in left_out:
                continue                     # left out (W3 item 0): runs only with partners
            if pnode is None:
                raise GmError(f"domains/{did}/producers/partners/{folder.name}/{PARTNER_DATA}: "
                              "a partner's state, but no third_parties: entry lists a database "
                              f"node holding {PARTNERS_DB}")
            _check_connected(path, f"domains/{did}/producers/partners/{folder.name}/"
                             f"{PARTNER_DATA}",
                             "a partner's data.sql runs connected to the partners'")
            runs.append(FileRun(f"{did} producers/partners/{folder.name}/{PARTNER_DATA}", pnode,
                                PARTNERS_DB, keys + [path]))
            partners.append((folder.name, pnode))
        cron = _cron_run(scenario, impl, d, catalog)
        if cron is not None:
            runs.append(cron)
        plan.domains.append(DomainLoad(did, [(n, db) for _, n, db in d.locations], runs,
                                       partners))
    for i, step in enumerate(record.get("derive") or []):
        did = step.get("domain") if isinstance(step, dict) else None
        where = f"{COMPOSITION_FILE}: derive[{did if isinstance(did, str) else i}]"
        if did not in domains:
            raise GmError(f"{where}: {did!r} is not a domain of domains:")
        d = domains[did]
        if d.several:
            raise GmError(f"{where}: {did} has several databases; a derivation runs in its "
                          "part's one database")
        after = step.get("after") or []
        missing = [a for a in after if a not in domains]
        if missing:
            raise GmError(f"{where}.after: {', '.join(map(str, missing))}: not composed")
        path = _file(d.dir, DERIVE_FILE, f"{where}", catalog)
        _, node, database = d.locations[0]
        plan.derivations.append(SourcedRun(
            "derive", did, f"{did} {DERIVE_FILE}", node, database,
            _keys(domains, catalog, did) + [path],
            [src for a in after for src in domains[a].sources]))
    for entry in scenario.data.get("purposes") or []:
        pid = entry.get("id") if isinstance(entry, dict) else None
        pdir = catalog / "purposes" / str(pid)
        pdata = _catalog_yaml(pdir / "purpose.yaml", f"purposes/{pid}/purpose.yaml")
        history = pdata.get("history")
        if not history:
            continue
        where = f"scenario.yaml: purposes[{pid}]"
        parts = entry.get("parts") if isinstance(entry.get("parts"), dict) else {}
        path = _file(pdir, str(history), f"purposes/{pid}/purpose.yaml history", catalog)
        node, database = _location(parts.get("target"), scenario, impl, f"{where}.parts.target")
        sources = [Source(part, *_location(value, scenario, impl, f"{where}.parts.{part}"))
                   for part, value in parts.items()
                   if part != "target" and isinstance(value, str) and "/" in value]
        plan.histories.append(SourcedRun("history", pid, f"{pid} {history}", node, database,
                                         [path], sources))
    for run in plan.derivations + plan.histories:
        _refuse_partners_from_afar(run, pnode)
    for did in order:
        d = domains[did]
        checks = coherence.read_checks(d.dir / coherence.COHERENCE_FILE, did,
                                       d.data.get("databases") if d.several else None)
        for check in checks:
            if PARTNERS_DB in check.reads and pnode is not None:
                # Spec D383: partners-db admits gm_check over its socket only,
                # so the check runs in partners on the partners' node, its
                # other reads over TCP from there.
                node, database = pnode, PARTNERS_DB
            else:
                _, node, database = next((loc for loc in d.locations
                                          if loc[0] == check.database), d.locations[0])
            run = CheckRun(check, node, database, [])
            for name in check.reads:
                if name == PARTNERS_DB:
                    if pnode is None:
                        run.skipped = f"reads {PARTNERS_DB}: the game has no partners' database"
                    else:
                        run.sources.append(Source(PARTNERS_DB, pnode, PARTNERS_DB))
                elif name in domains:
                    run.sources += domains[name].sources
                elif (catalog / "domains" / name / "domain.yaml").is_file():
                    run.skipped = f"reads {name}, not composed"
                else:
                    raise GmError(f"domains/{did}/{coherence.COHERENCE_FILE}: checks[{check.id}]"
                                  f".reads: {name} is not a domain of the catalogue")
            if run.skipped:
                run.sources = []
            plan.checks.append(run)
    return plan


def survey_plan(scenario, impl):
    """The `database` nodes surveyed after the data load, topology order;
    no standby (what it holds is its primary's)."""
    plan = []
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE or localimpl.standby_of(node):
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append(node["name"])
    return plan


def standby_plan(scenario, impl):
    """[(standby, primary, slot)]: every standby (`standby_of`), in
    topology order (v0.5 capture W1 item 6); GmError for a standby whose
    primary is not a node of the game, or is a standby itself."""
    names = {n["name"]: n for n in scenario.nodes}
    plan = []
    for node in scenario.nodes:
        primary = localimpl.standby_of(node)
        if primary is None:
            continue
        for name in (node["name"], primary):
            if name not in impl["nodes"]:
                raise GmError(f"node {name} is not a node of game {impl['game_id']}")
        if primary not in names or localimpl.standby_of(names[primary]):
            raise GmError(f"node {node['name']}: standby_of {primary} is not a primary of the "
                          "game (a postgres node that is no standby)")
        plan.append((node["name"], primary, localimpl.standby_slot(node["name"])))
    return plan


def replication_sql(ldir, slot):
    """The primary's side of a clone: `replicator` created or updated
    (LOGIN REPLICATION, its secret's password as a SCRAM verifier), an
    inactive slot `slot` left by a previous clone dropped; statement
    logging, pgaudit and statistics off for the session."""
    verifier = scram_verifier(read_secret(ldir, REPLICATION_SECRET))
    role = REPLICATION_ROLE
    return "\n".join([
        *NO_LOG_SQL, *NO_AUDIT_SQL, *NO_STATS_SQL, QUIET_SQL,
        f"DO $gm$BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = "
        f"{quote_literal(role)}) THEN CREATE ROLE {role}; END IF; END$gm$;",
        f"ALTER ROLE {role} WITH LOGIN REPLICATION NOSUPERUSER NOCREATEDB NOCREATEROLE "
        f"PASSWORD {quote_literal(verifier)};",
        "SELECT pg_catalog.pg_drop_replication_slot(slot_name) FROM pg_catalog.pg_replication_slots "
        f"WHERE slot_name = {quote_literal(slot)} AND NOT active;",
    ]) + "\n"


def streaming_sql(slot, wait):
    """Read as psql -A -t on the primary: waits up to `wait` seconds for
    the slot's sender to be `streaming`, then one JSON line, the slot's
    state (`exists`, `active`, `state` of its sender or null)."""
    lit = quote_literal(slot)
    streaming = ("EXISTS (SELECT 1 FROM pg_catalog.pg_replication_slots s JOIN "
                 "pg_catalog.pg_stat_replication r ON r.pid = s.active_pid "
                 f"WHERE s.slot_name = {lit} AND r.state = 'streaming')")
    return f"""{_NO_LOG}
DO $gm$
BEGIN
  FOR i IN 1..{int(wait) * 2} LOOP
    PERFORM pg_catalog.pg_stat_clear_snapshot();
    EXIT WHEN {streaming};
    PERFORM pg_catalog.pg_sleep(0.5);
  END LOOP;
END
$gm$;
SELECT pg_catalog.json_build_object(
  'exists', EXISTS (SELECT 1 FROM pg_catalog.pg_replication_slots WHERE slot_name = {lit}),
  'active', (SELECT active FROM pg_catalog.pg_replication_slots WHERE slot_name = {lit}),
  'state', (SELECT r.state FROM pg_catalog.pg_replication_slots s
              JOIN pg_catalog.pg_stat_replication r ON r.pid = s.active_pid
             WHERE s.slot_name = {lit}));
"""


def clone_standby(ldir, standby, primary, slot, docker, result, timeout=None, out=print,
                  restore=False):
    """The clone of one standby (see the module's docstring), into
    result.standbys; GmError at the first step that fails. `restore`: a
    restart's from the hand-over snapshot (capture W2-g item 3),
    `clone-standby --restore`, keeping the standby's own
    postgresql.auto.conf across the clone."""
    run = exec_node(ldir, primary, DATA_USER, stdin=replication_sql(ldir, slot),
                    timeout=timeout, docker=docker, argv=PSQL_ARGV)
    _print_run(out, f"{primary} replication role {REPLICATION_ROLE} for {standby} "
                    f"(psql as {DATA_USER})", run)
    if not run.ok:
        raise GmError(f"setting the replication role on {primary} for {standby}: psql exit "
                      f"{run.returncode}: {psql_error_line(run)}")
    argv = (CLONE_STANDBY, CLONE_RESTORE) if restore else (CLONE_STANDBY,)
    run = exec_node(ldir, standby, DEFAULT_RUN_AS, timeout=timeout, docker=docker, argv=argv)
    _print_run(out, f"{standby} {' '.join(argv)} (as {DEFAULT_RUN_AS})", run)
    if not run.ok:
        raise GmError(f"cloning the standby {standby} from {primary}: exit {run.returncode}: "
                      f"{_last_line(run)}")
    wait = STANDBY_WAIT if timeout is None else max(int(timeout), 1)
    run = exec_node(ldir, primary, DATA_USER, stdin=streaming_sql(slot, wait),
                    timeout=None if timeout is None else wait + 30, docker=docker,
                    argv=SURVEY_ARGV)
    out(f"{primary} replication slot {slot} streaming (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    what = f"waiting for the standby {standby} to stream from {primary}"
    if not run.ok:
        raise GmError(f"{what}: psql exit {run.returncode}: {psql_error_line(run)}")
    rows = _json_lines(run, what)
    state = rows[-1] if rows and isinstance(rows[-1], dict) else {}
    if state.get("state") != "streaming":
        raise GmError(f"{what}: slot {slot} not streaming after {wait} s (exists "
                      f"{state.get('exists')}, active {state.get('active')}, sender "
                      f"{state.get('state') or 'none'})")
    result.standbys.append((standby, primary, slot))


def _last_line(result):
    lines = output_lines(result)
    errors = [line for line in lines if line.startswith("clone-standby:")]
    return (errors or lines or ["no output"])[-1]


# --- The survey of a node's databases (v0.4) --------------------------------

def quote_ident(name):
    return '"' + name.replace('"', '""') + '"'


def quote_literal(text):
    """A standard SQL string literal (standard_conforming_strings on)."""
    return "'" + text.replace("'", "''") + "'"


def connect_line(database):
    """psql's `\\connect` to `database`, the other connection parameters
    reused: the name as a conninfo `dbname` value (so a name holding `=`
    is no connection string), that quoted as one psql argument."""
    value = "'" + database.replace("\\", "\\\\").replace("'", "\\'") + "'"
    conninfo = f"dbname={value}"
    return "\\connect -reuse-previous=on '" + conninfo.replace("\\", "\\\\").replace("'", "''") + "'"


DATABASES_SQL = ("SELECT pg_catalog.json_agg(datname ORDER BY datname) "
                 "FROM pg_catalog.pg_database WHERE datallowconn AND NOT datistemplate;\n")

SURVEY_SQL = """SELECT pg_catalog.json_build_object(
  'database', pg_catalog.current_database(),
  'pg_cron', EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname = 'pg_cron'),
  'servers', (SELECT pg_catalog.count(*) FROM pg_catalog.pg_foreign_server),
  'mappings', COALESCE((SELECT pg_catalog.json_agg(pg_catalog.json_build_object(
      'server', m.srvname, 'public', m.umuser = 0, 'local_role', m.usename,
      'remote_role', (SELECT o.option_value FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
                       WHERE o.option_name = 'user'),
      'password', EXISTS (SELECT 1 FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
                           WHERE o.option_name = 'password'))
      ORDER BY m.srvname, m.usename) FROM pg_catalog.pg_user_mappings AS m), '[]'));
"""


@dataclass
class Mapping:
    """A user mapping as the survey reads it."""
    server: str
    local_role: str                 # the role name, or `public` for PUBLIC
    public: bool
    remote_role: str                # its `user` option; None when unset
    has_password: bool
    secret: str = None              # the remote role's secret, once planned

    @property
    def local_text(self):
        return "PUBLIC" if self.public else self.local_role


@dataclass
class Database:
    """One database of a node, as the survey reads it."""
    name: str
    pg_cron: bool = False
    servers: int = 0
    mappings: list = field(default_factory=list)


def survey_sql(databases):
    """One JSON line per database: whether it holds `pg_cron`, how many
    foreign servers, its user mappings (server, local role, remote role,
    whether a password is set; read as `postgres`, who sees the options)."""
    return "".join(f"{connect_line(db)}\n{SURVEY_SQL}" for db in databases)


def _json_lines(run, what):
    try:
        return [json.loads(line) for line in output_lines_stdout(run)]
    except ValueError:
        raise GmError(f"{what}: unexpected psql output: {_first_line(run)}") from None


def output_lines_stdout(result):
    stream = result.stdout
    if isinstance(stream, (bytes, bytearray)):
        stream = stream.decode("utf-8", "replace")
    return [line for line in (stream or "").splitlines() if line.strip()]


def survey_node(ldir, node, docker, timeout=None, out=print):
    """[Database] of a node: its databases listed, then each surveyed;
    GmError when psql fails or answers otherwise."""
    run = exec_node(ldir, node, DATA_USER, stdin=DATABASES_SQL, timeout=timeout,
                    docker=docker, argv=SURVEY_ARGV)
    out(f"{node} databases (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    if not run.ok:
        raise GmError(f"listing the databases of {node}: psql exit {run.returncode}: "
                      f"{psql_error_line(run)}")
    rows = _json_lines(run, f"listing the databases of {node}")
    names = rows[0] if len(rows) == 1 and isinstance(rows[0], list) else None
    if names is None or not all(isinstance(n, str) for n in names):
        raise GmError(f"listing the databases of {node}: unexpected psql output: "
                      f"{_first_line(run)}")
    if not names:
        return []
    run = exec_node(ldir, node, DATA_USER, stdin=survey_sql(names), timeout=timeout,
                    docker=docker, argv=SURVEY_ARGV)
    out(f"{node} survey of {', '.join(names)} (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    if not run.ok:
        raise GmError(f"surveying the databases of {node}: psql exit {run.returncode}: "
                      f"{psql_error_line(run)}")
    found = []
    for row in _json_lines(run, f"surveying the databases of {node}"):
        try:
            found.append(Database(row["database"], bool(row["pg_cron"]), int(row["servers"]), [
                Mapping(m["server"], m["local_role"], bool(m["public"]), m["remote_role"],
                        bool(m["password"])) for m in row["mappings"]]))
        except (KeyError, TypeError, ValueError):
            raise GmError(f"surveying the databases of {node}: unexpected psql output: "
                          f"{json.dumps(row)[:200]}") from None
    if [d.name for d in found] != names:
        raise GmError(f"surveying the databases of {node}: {len(found)} answer(s) for "
                      f"{len(names)} database(s)")
    return found


def game_secret_names(impl):
    """The game's secrets by name (`role_<role>_password`, ...)."""
    return {sec.get("secret") for sec in impl.get("secrets") or []}


def plan_mappings(node, databases, game_id, secrets):
    """Each mapping's secret, its remote role's (8.6, 9.7: every login role
    a data file creates has one, as a role a schedule or a `crontab_roles`
    names); GmError, before the mappings' step runs, for a mapping naming
    no remote role or one the game (`secrets`, its secret names) has no
    secret for."""
    for db in databases:
        for m in db.mappings:
            where = (f"{node}/{db.name}: the user mapping for {m.local_text} on server "
                     f"{m.server}")
            if not m.remote_role:
                raise GmError(f"{where} names no remote role (option user): load-data sets a "
                              "mapping's password from its remote role's secret")
            secret = localimpl.role_secret_name(m.remote_role)
            if secret not in secrets:
                raise GmError(f"{where} connects as {m.remote_role}, which has no secret "
                              f"{secret} in game {game_id}: no data file of the scenario "
                              f"creates {m.remote_role} as a login role (CREATE ROLE "
                              f"{m.remote_role} LOGIN), and no schedule's connection or "
                              "node's crontab_roles names it")
            m.secret = secret


def mapping_sql(ldir, databases):
    """`(sql, passwords)`: per database holding a mapping, each mapping's
    `password` option set (ADD, or SET when one is there) to its remote
    role's secret, statement logging, pgaudit and statistics off for each
    session;
    the passwords, to keep them out of anything printed."""
    parts, passwords = [], []
    for db in databases:
        if not db.mappings:
            continue
        parts += [connect_line(db.name), *NO_LOG_SQL, *NO_AUDIT_SQL, *NO_STATS_SQL]
        for m in db.mappings:
            password = read_secret(ldir, m.secret)
            passwords.append(password)
            who = "PUBLIC" if m.public else quote_ident(m.local_role)
            op = "SET" if m.has_password else "ADD"
            parts.append(f"ALTER USER MAPPING FOR {who} SERVER {quote_ident(m.server)} "
                         f"OPTIONS ({op} password {quote_literal(password)});")
    return ("\n".join(parts) + "\n" if parts else ""), passwords


def policy_sql():
    """CHECK_ROLE's read policy on each of CRON_TABLES: permissive, SELECT
    only, every row. `pg_cron` enables row-level security on both (its own
    policies show a role its own jobs); permissive policies add up, so this
    one lets the check role read every job and run, nothing more, narrower
    than BYPASSRLS. Re-created, so a second load leaves one."""
    lines = []
    for table in CRON_TABLES:
        lines += [f"DROP POLICY IF EXISTS {CHECK_POLICY} ON {table};",
                  f"CREATE POLICY {CHECK_POLICY} ON {table} AS PERMISSIVE FOR SELECT "
                  f"TO {CHECK_ROLE} USING (true);"]
    return "\n".join(lines) + "\n"


def function_sql():
    """The mapping-roles function (master spec 11.6): in schema
    CHECK_SCHEMA, owned by `postgres`, SECURITY DEFINER with a fixed
    search_path, executable by CHECK_ROLE only; one row per user mapping of
    the database: its server, its local role (`public` for PUBLIC, as
    pg_user_mappings writes it) and its remote role (the `user` option, NULL
    when unset), never its password."""
    fn = f"{MAPPING_FUNCTION}()"
    return f"""CREATE SCHEMA IF NOT EXISTS {CHECK_SCHEMA} AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA {CHECK_SCHEMA} FROM PUBLIC;
GRANT USAGE ON SCHEMA {CHECK_SCHEMA} TO {CHECK_ROLE};
CREATE OR REPLACE FUNCTION {fn}
  RETURNS TABLE (server_name name, local_role name, remote_role text)
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = pg_catalog, pg_temp
AS $gm$
  SELECT m.srvname, m.usename,
         (SELECT o.option_value FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
           WHERE o.option_name = 'user')
    FROM pg_catalog.pg_user_mappings AS m
   ORDER BY 1, 2
$gm$;
ALTER FUNCTION {fn} OWNER TO postgres;
REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;
GRANT EXECUTE ON FUNCTION {fn} TO {CHECK_ROLE};
"""


def access_sql(databases):
    """`(sql, policies, functions)`: per database, the read policy where it
    holds `pg_cron`, the mapping-roles function where it holds a foreign
    server; the databases each went to."""
    parts, policies, functions = [], [], []
    for db in databases:
        if not (db.pg_cron or db.servers):
            continue
        parts.append(connect_line(db.name) + "\n" + QUIET_SQL + "\n")
        if db.pg_cron:
            parts.append(policy_sql())
            policies.append(db.name)
        if db.servers:
            parts.append(function_sql())
            functions.append(db.name)
    return "".join(parts), policies, functions


def _redacted(text, passwords):
    for password in passwords:
        text = text.replace(password, REDACTED)
    return text


# --- The pg_cron launcher's start-up failures (the noise fix) -----------------

_LAUNCHER_UP = (f"EXISTS (SELECT 1 FROM pg_catalog.pg_stat_activity "
                f"WHERE backend_type = {quote_literal(LAUNCHER)})")

# Read as psql -A -t: two JSON lines, before and after the switch. Statement
# logging off for the session (the waits pass log_min_duration_statement:
# the GM's SQL stays out of the players' log). The wait clears the
# statistics snapshot at each turn (a transaction reads pg_stat_activity
# once otherwise); the switch happens only with the launcher connected and
# a file log, and is waited for (the collector rewrites current_logfiles
# once it has opened the new file).
_NO_LOG = "\n".join(NO_LOG_SQL)
LAUNCHER_SQL = f"""{_NO_LOG}
DO $gm$
BEGIN
  FOR i IN 1..{LAUNCHER_WAIT * 10} LOOP
    PERFORM pg_catalog.pg_stat_clear_snapshot();
    EXIT WHEN {_LAUNCHER_UP};
    PERFORM pg_catalog.pg_sleep(0.1);
  END LOOP;
END
$gm$;
SELECT pg_catalog.json_build_object(
  'launcher', {_LAUNCHER_UP},
  'cron_database', pg_catalog.current_setting('cron.database_name', true),
  'data_directory', pg_catalog.current_setting('data_directory'),
  'file', pg_catalog.pg_current_logfile('stderr'));
DO $gm$
DECLARE
  before text := pg_catalog.pg_current_logfile('stderr');
BEGIN
  PERFORM pg_catalog.pg_stat_clear_snapshot();
  IF before IS NULL OR NOT {_LAUNCHER_UP} THEN
    RETURN;
  END IF;
  PERFORM pg_catalog.pg_rotate_logfile();
  FOR i IN 1..{ROTATE_WAIT * 10} LOOP
    EXIT WHEN pg_catalog.pg_current_logfile('stderr') IS DISTINCT FROM before;
    PERFORM pg_catalog.pg_sleep(0.1);
  END LOOP;
END
$gm$;
SELECT pg_catalog.json_build_object('file', pg_catalog.pg_current_logfile('stderr'));
"""

# Run as postgres, GM_LOG_FILE the collector's file now: every other regular
# stderr-format file of its directory naming a failed launcher is rewritten
# without those lines, its mode and time kept (the directory's setgid keeps
# its group), through a file renamed over it: the collector writes only the
# new file. Prints `<file>: <lines removed>` per file rewritten.
CLEAN_SH = r"""set -eu
umask 027
current=$GM_LOG_FILE
dir=${current%/*}
exited='background worker "pg_cron launcher" (PID [0-9]*) exited with exit code 1'
for f in "$dir"/*; do
    if [ ! -f "$f" ] || [ -L "$f" ] || [ "$f" = "$current" ]; then continue; fi
    case $f in *.csv|*.json) continue ;; esac
    grep -q "$exited" "$f" || continue
    tmp=$(mktemp "$dir/.gm-clean.XXXXXX")
    awk '
    # The first read: each failed launcher PID, and the line of its exit.
    FNR == NR {
        if (match($0, /background worker "pg_cron launcher" \(PID [0-9]+\) exited with exit code 1/)) {
            s = substr($0, RSTART, RLENGTH); sub(/.*\(PID /, "", s); sub(/\).*/, "", s)
            last[s] = FNR
        }
        next
    }
    # The second: those lines out, each with its tab-indented continuations;
    # a PID is read from the prefix only (before the first "<level>:  ").
    /^\t/ { if (!drop) print; next }
    {
        drop = 0
        if ($0 ~ /background worker "pg_cron launcher" \(PID [0-9]+\) exited with exit code 1/) {
            drop = 1; next
        }
        head = $0; k = index(head, ":  "); if (k) head = substr(head, 1, k - 1)
        if (match(head, /\[[0-9]+\]/)) {
            p = substr(head, RSTART + 1, RLENGTH - 2)
            if ((p in last) && FNR <= last[p]) { drop = 1; next }
        }
        print
    }' "$f" "$f" > "$tmp"
    before=$(wc -l < "$f")
    after=$(wc -l < "$tmp")
    chmod --reference="$f" "$tmp"
    touch -r "$f" "$tmp"
    mv -f "$tmp" "$f"
    echo "${f##*/}: $((before - after))"
done
"""


def cron_plan(surveyed):
    """The surveyed nodes holding `pg_cron` in a database, in order."""
    return [node for node, databases in surveyed if any(db.pg_cron for db in databases)]


def _log_path(path, data_directory):
    """A pg_current_logfile() answer as an absolute path (it is relative to
    the data directory when log_directory is)."""
    if not path or path.startswith("/"):
        return path
    return f"{data_directory.rstrip('/')}/{path}"


def clean_launcher_lines(ldir, node, docker, result, timeout=None, out=print):
    """The noise fix on one node (see the module's docstring): the launcher
    waited for, the file log switched, the failed launchers' lines removed
    from the closed files; into result.cleaned, or result.warnings when the
    log cannot be separated. GmError when the launcher is not connected."""
    run = exec_node(ldir, node, DATA_USER, stdin=LAUNCHER_SQL, timeout=timeout,
                    docker=docker, argv=SURVEY_ARGV)
    out(f"{node} {LAUNCHER} and the server log's switch (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    what = f"switching the server log of {node}"
    if not run.ok:
        raise GmError(f"{what}: psql exit {run.returncode}: {psql_error_line(run)}")
    rows = _json_lines(run, what)
    if len(rows) != 2 or not all(isinstance(r, dict) for r in rows):
        raise GmError(f"{what}: unexpected psql output: {_first_line(run)}")
    before, after = rows
    if not before.get("launcher"):
        raise GmError(f"the {LAUNCHER} of {node} is not connected {LAUNCHER_WAIT} s after the "
                      f"data load (cron.database_name {before.get('cron_database')!r}: the "
                      "data file must create it)")
    if not before.get("file"):
        result.cleaned.append((node, None))         # no file log: nothing a player reads
        return
    if after.get("file") == before.get("file"):
        result.warnings.append(f"{node}: the server log did not switch files within "
                               f"{ROTATE_WAIT} s ({before['file']}); its {LAUNCHER} start-up "
                               "failures are left in it")
        result.cleaned.append((node, []))
        return
    current = _log_path(after.get("file"), str(before.get("data_directory") or ""))
    run = exec_node(ldir, node, DATA_USER, stdin=CLEAN_SH, env={"GM_LOG_FILE": current},
                    timeout=timeout, docker=docker)
    _print_run(out, f"{node} {LAUNCHER}'s start-up failures out of the server log "
                    f"(sh as {DATA_USER})", run)
    if not run.ok:
        raise GmError(f"removing the {LAUNCHER}'s start-up failures from the server log of "
                      f"{node}: exit {run.returncode}: {_first_line(run)}")
    files = []
    for line in output_lines_stdout(run):
        name, sep, count = line.rpartition(": ")
        if not sep or not count.strip().isdigit():
            raise GmError(f"removing the {LAUNCHER}'s start-up failures from the server log "
                          f"of {node}: unexpected output: {line}")
        files.append((name, int(count)))
    result.cleaned.append((node, files))


# --- The composed load: its runs (v0.5 capture W2 item 3) ---------------------

UNSEEN_SQL = "\n".join((*NO_LOG_SQL, *NO_AUDIT_SQL, *NO_STATS_SQL, QUIET_SQL)) + "\n"


def stream_files(paths, prelude=""):
    """A temporary file holding `prelude` (text), then `paths`' bytes in
    order, each ended by a newline, at offset 0: one psql session for the
    core's keys and a load (a large load streamed, never read into memory)."""
    fh = tempfile.TemporaryFile()
    if prelude:
        fh.write(prelude.encode("utf-8"))
    for path in paths:
        with open(path, "rb") as src:
            shutil.copyfileobj(src, fh)
        if fh.tell():
            fh.seek(-1, os.SEEK_END)
            if fh.read(1) != b"\n":
                fh.write(b"\n")
    fh.seek(0)
    return fh


def create_database_sql(database):
    """Creates `database` when absent (owner postgres), `CONNECT` revoked from
    `PUBLIC`, and then prints CREATED_MARK (W2 item 3); unseen, as the
    domain's load it opens (master spec 9.2)."""
    return (UNSEEN_SQL + f"SELECT NOT EXISTS (SELECT 1 FROM pg_catalog.pg_database WHERE datname = "
            f"{quote_literal(database)}) AS gm_absent \\gset\n"
            "\\if :gm_absent\n"
            f"CREATE DATABASE {quote_ident(database)} OWNER postgres;\n"
            f"REVOKE CONNECT ON DATABASE {quote_ident(database)} FROM PUBLIC;\n"
            f"\\echo {CREATED_MARK}\n"
            "\\endif\n")


CREATED_MARK = "gm-database-created"


def check_role_sql(databases=(), reset=False):
    """gm_check's role settings on a source (W2 item 3), unseen: set, with
    `CONNECT` on each of `databases` (a database load-data created has it
    revoked from PUBLIC), or reset."""
    lines = [UNSEEN_SQL]
    for name, value in CHECK_ROLE_SETTINGS:
        lines.append(f"ALTER ROLE {CHECK_ROLE} RESET {name};" if reset else
                     f"ALTER ROLE {CHECK_ROLE} SET {name} = {quote_literal(value)};")
    lines += [f"GRANT CONNECT ON DATABASE {quote_ident(db)} TO {CHECK_ROLE};" for db in databases]
    return "\n".join(lines) + "\n"


SCHEMAS_SQL = (UNSEEN_SQL + "SELECT COALESCE(pg_catalog.json_agg(nspname ORDER BY nspname), "
               "'[]') FROM pg_catalog.pg_namespace WHERE nspname !~ '^pg_' AND nspname <> "
               f"'information_schema' AND nspname !~ '^{SOURCE_PREFIX}';\n")


def foreign_schema(source, schema):
    return source.server if schema == "public" else f"{source.server}_{schema}"


def fdw_sql(node, sources, schemas, password):
    """(setup, teardown) of a session reading `sources` from `node`: the
    extension (dropped after only when this session created it), per source
    a server gm_src_<name> (the socket on the same node, <node>:5432 on
    another), postgres's mapping as gm_check, and each of its `schemas`
    ({server: [schema]}) imported, `public` into gm_src_<name>, any other
    <s> into gm_src_<name>_<s>; the teardown drops all of it, cascading."""
    setup = [f"SELECT NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname = "
             f"{quote_literal(FDW)}) AS gm_fdw_absent \\gset",
             f"CREATE EXTENSION IF NOT EXISTS {FDW};"]
    teardown = []
    for src in sources:
        server = quote_ident(src.server)
        host = SOCKET_DIR if src.node == node else src.node
        setup += [f"CREATE SERVER {server} FOREIGN DATA WRAPPER {FDW} OPTIONS (host "
                  f"{quote_literal(host)}, port '{PG_PORT}', dbname {quote_literal(src.database)});",
                  f"CREATE USER MAPPING FOR postgres SERVER {server} OPTIONS (user "
                  f"{quote_literal(CHECK_ROLE)}, password {quote_literal(password)});"]
        names = [src.server] + [foreign_schema(src, s) for s in schemas[src.server]
                                if s != "public"]
        setup += [f"CREATE SCHEMA {quote_ident(n)};" for n in names]
        setup += [f"IMPORT FOREIGN SCHEMA {quote_ident(s)} FROM SERVER {server} INTO "
                  f"{quote_ident(foreign_schema(src, s))};" for s in schemas[src.server]]
        teardown += [f"DROP SCHEMA IF EXISTS {quote_ident(n)} CASCADE;" for n in names]
        teardown.append(f"DROP SERVER IF EXISTS {server} CASCADE;")
    teardown += ["\\if :gm_fdw_absent", f"DROP EXTENSION IF EXISTS {FDW};", "\\endif"]
    return "\n".join(setup) + "\n", "\n".join(teardown) + "\n"


def _exec_sql(ldir, node, sql, argv, docker, timeout, out, heading, what, secrets=()):
    run = exec_node(ldir, node, DATA_USER, stdin=sql, timeout=timeout, docker=docker, argv=argv)
    out(f"{heading} (psql as {DATA_USER}): {'ok' if run.ok else f'exit {run.returncode}'}")
    if not run.ok:
        for line in output_lines(run):
            out(f"    {_redacted(line, secrets)}")
        raise GmError(f"{what}: psql exit {run.returncode}: "
                      f"{_redacted(psql_error_line(run), secrets)}")
    return run


def run_file(ldir, run, variables, docker, timeout=None, out=print):
    """One FileRun: its files streamed into psql -d <database>, unseen
    (UNSEEN_SQL ahead: no statement logging, pgaudit and
    `pg_stat_statements` off; master spec 9.2, spec D265)."""
    with stream_files(run.paths, UNSEEN_SQL) as fh:
        result = exec_node(ldir, run.node, DATA_USER, stdin=fh, timeout=timeout, docker=docker,
                           argv=data_argv(variables, run.database))
    _print_run(out, f"{run.node}/{run.database} {run.what} (psql as {DATA_USER})", result)
    if not result.ok:
        raise GmError(f"load of {run.what} into {run.node}/{run.database}: psql exit "
                      f"{result.returncode}: {psql_error_line(result)}")


def source_schemas(ldir, sources, docker, timeout=None, out=print):
    """{server: [schema]} of each source's database, read unseen."""
    found = {}
    for src in sources:
        if src.server in found:
            continue
        run = _exec_sql(ldir, src.node, SCHEMAS_SQL, read_argv(src.database), docker, timeout,
                        out, f"{src.node}/{src.database} schemas for {src.server}",
                        f"listing the schemas of {src.node}/{src.database}")
        rows = _json_lines(run, f"listing the schemas of {src.node}/{src.database}")
        names = rows[-1] if rows else None
        if not (isinstance(names, list) and all(isinstance(n, str) for n in names)):
            raise GmError(f"listing the schemas of {src.node}/{src.database}: unexpected psql "
                          f"output: {_first_line(run)}")
        for name in names:
            if len(foreign_schema(src, name)) > MAX_NAME:
                raise GmError(f"{src.node}/{src.database}: schema {name}'s foreign schema "
                              f"{foreign_schema(src, name)} is longer than {MAX_NAME} characters")
        found[src.server] = names
    return found


def sourced_session(ldir, node, sources, body, docker, timeout=None, out=print):
    """(sql, password): `body` (bytes or text) between the unseen prelude and
    the FDW setup, and the teardown."""
    password = read_secret(ldir, CHECK_SECRET) if sources else None
    setup, teardown = fdw_sql(node, sources, source_schemas(ldir, sources, docker, timeout, out),
                              password) if sources else ("", "")
    body = body.decode("utf-8") if isinstance(body, (bytes, bytearray)) else body
    if body and not body.endswith("\n"):
        body += "\n"
    return UNSEEN_SQL + setup + body + teardown, password


def run_sourced(ldir, run, variables, docker, timeout=None, out=print):
    """A derivation or a history (SourcedRun), unseen, its sources read."""
    body = b"".join(Path(p).read_bytes().rstrip(b"\n") + b"\n" for p in run.paths)
    sql, password = sourced_session(ldir, run.node, run.sources, body, docker, timeout, out)
    _exec_sql(ldir, run.node, sql, data_argv(variables, run.database), docker, timeout, out,
              f"{run.node}/{run.database} {run.what}, reading "
              f"{', '.join(s.server for s in run.sources) or 'nothing'}",
              f"{run.kind} {run.what} in {run.node}/{run.database}", secrets=[password] if
              password else [])


def run_check(ldir, run, docker, timeout=None, out=print):
    """One CheckRun: its query in a read-only transaction, unseen; an Outcome."""
    c = run.check
    if run.skipped:
        out(f"  coherence {c.domain} {c.id}: skipped ({run.skipped})")
        return coherence.Outcome(c.domain, c.id, c.what, coherence.SKIPPED, reason=run.skipped)
    sql, password = sourced_session(ldir, run.node, run.sources, coherence.query_sql(c),
                                    docker, timeout, out)
    what = f"coherence check {c.domain} {c.id} in {run.node}/{run.database}"
    result = _exec_sql(ldir, run.node, sql, read_argv(run.database), docker, timeout, out,
                       what, what, secrets=[password] if password else [])
    count, rows = coherence.parse_answer(output_lines_stdout(result), what)
    outcome = coherence.Outcome(c.domain, c.id, c.what, coherence.FAIL if count else
                                coherence.PASS, count, rows)
    out(f"  coherence {c.domain} {c.id}: {outcome.result}"
        + (f" ({count} row(s))" if count else ""))
    return outcome


def record_coherence(ldir, plan, run_at, outcomes):
    """The check's record: composition.yaml's `coherence:`, and each check's
    outcome in the game's state.yaml."""
    result = coherence.result_of(outcomes)
    if plan.composition is not None:
        coherence.record_composition(plan.composition, run_at, result)

    def change(st):
        st["coherence"] = {"run_at": run_at, "result": result,
                           "checks": [o.record() for o in outcomes]}
    localimpl.update_state(ldir, change)
    return result


def composed_steps(ldir, plans, docker, result, timeout=None, out=print):
    """The composed load's steps (W2 item 3), into `result`: each domain in
    order (its databases, schema, load and partner files), the derivations,
    the histories, the coherence check and its record; gm_check's role
    settings set on every source before the first read, reset after the
    last; GmError at the first that fails, a failed check included."""
    plan, variables = plans.composed, plans.variables
    for load in plan.domains:
        for node, database in load.databases:
            run = _exec_sql(ldir, node, create_database_sql(database), PSQL_ARGV, docker,
                            timeout, out, f"{node} database {database} for {load.domain}",
                            f"creating database {database} on {node} for {load.domain}")
            if CREATED_MARK in output_lines_stdout(run):
                result.created.append((node, database))
        for run in load.runs:
            run_file(ldir, run, variables, docker, timeout=timeout, out=out)
            result.domains.append((load.domain, run.node, run.database, run.what))
        result.partners += [(load.domain, prefix, node) for prefix, node in load.partners]
    reading = plan.reading_nodes()
    for node, databases in reading.items():
        _exec_sql(ldir, node, check_role_sql(databases), PSQL_ARGV, docker, timeout, out,
                  f"{node} {CHECK_ROLE} unseen, CONNECT on {', '.join(databases)}",
                  f"setting {CHECK_ROLE}'s role settings on {node}")
    for run in plan.derivations + plan.histories:
        run_sourced(ldir, run, variables, docker, timeout=timeout, out=out)
        (result.derived if run.kind == "derive" else result.histories).append(
            (run.owner, run.node, run.database))
    if plan.checks:
        run_at = localimpl.now_iso()
        outcomes = [run_check(ldir, run, docker, timeout=timeout, out=out) for run in plan.checks]
        result.coherence = outcomes
        result.coherence_result = record_coherence(ldir, plan, run_at, outcomes)
        if result.coherence_result == coherence.FAIL:
            raise GmError(coherence.failure_text(outcomes))
    elif plan.composition is not None:
        result.coherence_result = record_coherence(ldir, plan, localimpl.now_iso(), [])
    for node in reading:
        _exec_sql(ldir, node, check_role_sql(reset=True), PSQL_ARGV, docker, timeout, out,
                  f"{node} {CHECK_ROLE}'s role settings reset",
                  f"resetting {CHECK_ROLE}'s role settings on {node}")


@dataclass
class LoadPlans:
    """`load-data`'s plans, read and checked before anything runs."""
    data: list                      # data_plan
    passwords: list                 # password_plan
    surveys: list                   # survey_plan
    grants: list                    # grant_plan: the nodes whose check role exists
    variables: dict                 # psql_variables
    game_id: str
    secrets: set                    # game_secret_names
    standbys: list = field(default_factory=list)   # standby_plan
    composed: ComposedPlan = field(default_factory=ComposedPlan)   # composed_plan


def load_data(scenario_dir, playground, timeout=None, docker=None, out=print,
              catalog_root=model.REPO_ROOT):
    """`gmctl load-data`; returns a LoadResult. Raises GmError on a refusal
    (nothing done) or state.SetupFailed on a failure (torn down, recorded),
    a failed coherence check included."""
    ldir, st = _game(scenario_dir, playground)
    stage = st.get("stage")
    if stage in state.DEPLOYED_STAGES and stage != DEPLOY_STAGE:
        return LoadResult(st.get("game_id"), already=stage)
    if stage != DEPLOY_STAGE:
        raise GmError(f"game {st.get('game_id')} is at stage {stage}; load-data needs stage "
                      f"{DEPLOY_STAGE} (run gmctl deploy)")
    scenario = model.load_scenario(scenario_dir, catalog_root)
    impl = localimpl.read_implementation(ldir)
    steps = load_plans(scenario, impl, catalog_root)
    docker = docker or for_local_dir(ldir)
    result = LoadResult(impl["game_id"])

    with state.setup_step(ldir, DATA_STAGE, undo=_undo(docker, impl["game_id"])):
        load_steps(ldir, steps, docker, result, timeout=timeout, out=out)
    localimpl.set_stage(ldir, DATA_STAGE)
    return result


def load_plans(scenario, impl, catalog_root=model.REPO_ROOT, now=None):
    """`load-data`'s plans (LoadPlans), read and checked before anything
    runs; the domains and the purposes' histories read from the catalogue
    `catalog_root` (W2 item 3); `load_epoch` the run's start (`now`)."""
    return LoadPlans(data_plan(scenario, impl), password_plan(scenario, impl, catalog_root),
                     survey_plan(scenario, impl), grant_plan(scenario, impl),
                     {**psql_variables(impl), EPOCH_VAR: load_epoch(now)}, impl["game_id"],
                     game_secret_names(impl), standby_plan(scenario, impl),
                     composed_plan(scenario, impl, catalog_root))


def load_steps(ldir, plans, docker, result, timeout=None, out=print):
    """`load-data`'s steps, in order, into `result` (a LoadResult): each
    node's data (with the psql variables), the composed load (v0.5:
    composed_steps), the roles' passwords, the survey
    of every database node's databases, the user mappings' passwords, the
    check role's read policy and mapping-roles function, the check role's
    `CONNECT`, the `pg_cron` launcher's start-up failures out of the server
    log, last (v0.5) each standby's clone; GmError at the first that fails.
    Also a restart's with no snapshot (chunk 11, spec D176)."""
    argv = data_argv(plans.variables)
    for node, rel, path in plans.data:
        with open(path, "rb") as fh:
            run = exec_node(ldir, node, DATA_USER, stdin=fh, timeout=timeout,
                            docker=docker, argv=argv)
        _print_run(out, f"{node} {rel} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"data load of {node} ({rel}): psql exit {run.returncode}: "
                          f"{psql_error_line(run)}")
        result.loaded.append((node, rel))
    composed_steps(ldir, plans, docker, result, timeout=timeout, out=out)
    for node, roles in plans.passwords:
        names = ", ".join(r for r, _ in roles)
        run = exec_node(ldir, node, DATA_USER, stdin=password_sql(ldir, roles),
                        timeout=timeout, docker=docker, argv=PSQL_ARGV)
        _print_run(out, f"{node} passwords of {names} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"setting the passwords of {names} on {node} (the data must "
                          f"create these roles): psql exit {run.returncode}: "
                          f"{psql_error_line(run)}")
        result.passwords.append((node, [r for r, _ in roles]))
    surveyed = []
    for node in plans.surveys:
        databases = survey_node(ldir, node, docker, timeout=timeout, out=out)
        plan_mappings(node, databases, plans.game_id, plans.secrets)
        surveyed.append((node, databases))
    for node, databases in surveyed:
        sql, passwords = mapping_sql(ldir, databases)
        if not sql:
            continue
        run = exec_node(ldir, node, DATA_USER, stdin=sql, timeout=timeout, docker=docker,
                        argv=PSQL_ARGV)
        heading = f"{node} user mapping passwords (psql as {DATA_USER})"
        out(f"{heading}: {'ok' if run.ok else f'exit {run.returncode}'}")
        for line in output_lines(run):
            out(f"    {_redacted(line, passwords)}")
        if not run.ok:
            raise GmError(f"setting the user mappings' passwords on {node}: psql exit "
                          f"{run.returncode}: {_redacted(psql_error_line(run), passwords)}")
        result.mappings += [(node, db.name, db.mappings) for db in databases if db.mappings]
    for node, databases in surveyed:
        if node not in plans.grants:
            continue
        sql, policies, functions = access_sql(databases)
        if not sql:
            continue
        run = exec_node(ldir, node, DATA_USER, stdin=sql, timeout=timeout, docker=docker,
                        argv=PSQL_ARGV)
        _print_run(out, f"{node} {CHECK_ROLE}'s read policy and mapping-roles function "
                        f"(psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"giving {CHECK_ROLE} its read policy and mapping-roles function on "
                          f"{node}: psql exit {run.returncode}: {psql_error_line(run)}")
        result.policies += [(node, db) for db in policies]
        result.functions += [(node, db) for db in functions]
    for node in plans.grants:
        run = exec_node(ldir, node, DATA_USER, stdin=grant_sql(), timeout=timeout,
                        docker=docker, argv=PSQL_ARGV)
        _print_run(out, f"{node} CONNECT for {CHECK_ROLE} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"granting {CHECK_ROLE} CONNECT on the databases of {node}: "
                          f"psql exit {run.returncode}: {psql_error_line(run)}")
        result.grants.append(node)
    for node in cron_plan(surveyed):
        clean_launcher_lines(ldir, node, docker, result, timeout=timeout, out=out)
    for standby, primary, slot in plans.standbys:
        clone_standby(ldir, standby, primary, slot, docker, result, timeout=timeout, out=out)


# --- inject --------------------------------------------------------------------

@dataclass
class InjectResult:
    game_id: str
    replay: bool = False
    scripts: list = field(default_factory=list)    # [(instance, script)]
    seeded: list = field(default_factory=list)     # instances planted by their seed files
    rendered: list = field(default_factory=list)   # parameter faults, planted at rendering
    later: list = field(default_factory=list)      # [(instance, plant_at)] planted by inject --at

    def text(self):
        out = [f"Game {self.game_id}: {len(self.scripts)} injection script(s) run"
               + (" again (replay)." if self.replay else ".")]
        for iid in self.seeded:
            out.append(f"  {iid}: seed-file fault, planted by the seed files; nothing to run")
        for iid in self.rendered:
            out.append(f"  {iid}: parameter fault, planted at rendering; nothing to run")
        for iid, plant_at in self.later:
            out.append(f"  {iid}: planted at {plant_at}, once the load runs (gmctl inject --at "
                       f"after gmctl start-load); nothing run now")
        out.append(f"Stage {INJECT_STAGE}" + (" (unchanged)." if self.replay else "."))
        return "\n".join(out)


def inject_plan(scenario, impl):
    """[(instance, fault, node, run_as, env, [(script, text), ...])], every
    instance in order, scripts read; refuses (GmError) before anything runs."""
    plan = []
    for inst, fault in fault_instances(scenario, impl):
        injection = fault.data.get("injection") or {}
        node = node_of(inst, impl)
        env = fault_env(fault, inst)
        scripts = []
        if injection.get("kind") == STATE_KIND:
            for script in injection.get("scripts") or []:
                try:
                    text = (fault.dir / str(script)).read_text(encoding="utf-8")
                except OSError as exc:
                    raise GmError(f"fault {fault.id}: {script}: cannot be read: "
                                  f"{exc.strerror}") from None
                scripts.append((str(script), text))
        plan.append((inst["id"], fault, node, injection.get("run_as") or DEFAULT_RUN_AS,
                     env, scripts))
    return plan


def plant_at_of(scenario, impl, inst):
    """An instance's planting moment: `T0` in a game with no scheduler node
    (D157, D158); otherwise the timeline's (render's), else the scenario's."""
    if not model.has_scheduler_nodes(scenario.data):
        return T0
    entry = ((impl.get(localimpl.TIMELINE) or {}).get("instances") or {}).get(inst["id"]) or {}
    return entry.get("plant_at") or inst.get("plant_at") or T0


def initial_plantings(scenario, impl, at):
    """`plantings` as `inject` records it with `injected` (W2 item 4): a T0
    instance planted at `at`, by inject; any other waiting for its
    `inject --at`, its planned instant from the timeline."""
    timeline = (impl.get(localimpl.TIMELINE) or {}).get("instances") or {}
    out = {}
    for inst, _ in fault_instances(scenario, impl):
        plant_at = plant_at_of(scenario, impl, inst)
        if plant_at == T0:
            out[inst["id"]] = {"plant_at": T0, "planted_at": at, "by": "inject"}
        else:
            out[inst["id"]] = {"plant_at": plant_at,
                               "planned_at": (timeline.get(inst["id"]) or {}).get("planned_at"),
                               "timer": None, "attempts": [], "planted_at": None}
    return out


def inject(scenario_dir, playground, timeout=None, docker=None, out=print):
    """`gmctl inject`; returns an InjectResult. Raises GmError on a refusal
    (nothing run) or state.SetupFailed on a failure (torn down, recorded)."""
    ldir, st = _game(scenario_dir, playground)
    stage = st.get("stage")
    if stage == LOAD_STAGE:
        raise GmError(f"game {st.get('game_id')} is at stage {stage}: inject replays the "
                      "plantings only before the load starts; plant one instance with gmctl "
                      "inject --at now --instance <id>")
    if stage not in (DATA_STAGE, INJECT_STAGE):
        raise GmError(f"game {st.get('game_id')} is at stage {stage}; inject needs stage "
                      f"{DATA_STAGE} (run gmctl load-data), or {INJECT_STAGE} to replay")
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    plan = inject_plan(scenario, impl)
    insts = {inst["id"]: inst for inst, _ in fault_instances(scenario, impl)}
    docker = docker or for_local_dir(ldir)
    result = InjectResult(impl["game_id"], replay=stage == INJECT_STAGE)

    with state.setup_step(ldir, INJECT_STAGE, undo=_undo(docker, impl["game_id"])):
        for iid, fault, node, run_as, env, scripts in plan:
            plant_at = plant_at_of(scenario, impl, insts[iid])
            if plant_at != T0:
                result.later.append((iid, plant_at))
                continue
            if not scripts:
                kind = (fault.data.get("injection") or {}).get("kind")
                (result.rendered if kind == PARAMETER_KIND else result.seeded).append(iid)
                continue
            for script, text in scripts:
                run = exec_node(ldir, node, run_as, stdin=text, env=env, timeout=timeout,
                                docker=docker)
                _print_run(out, f"{iid} {script} ({node}, as {run_as})", run)
                if not run.ok:
                    raise GmError(f"injection of {iid} ({fault.id}) stopped at {script}: exit "
                                  f"{run.returncode}: {_first_line(run)}")
                result.scripts.append((iid, script))
    if stage != INJECT_STAGE:
        at = localimpl.now_iso()

        def record(st):
            localimpl.enter_stage(st, INJECT_STAGE, at)
            st["plantings"] = initial_plantings(scenario, impl, at)
        localimpl.update_state(ldir, record)
    return result
