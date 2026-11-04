"""gmctl load-data and inject (tools/gm/inject.py), the FAULT_* environment,
and exec_node's `argv`; Docker stubbed."""

import base64
import hashlib
import hmac
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.gm import deploy, execnode, fit, inject, localimpl, model, render, state, teardown
from tools.gm.model import GmError
from tools.tests import SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl
from tools.tests.test_deploy import RenderedGame
from tools.tests.test_render import MountedCopyTest, V03Rendered, handover_at

F2_ENV = {"FAULT_DATABASE": "shop", "FAULT_TABLE_NAME": "orders",
          "FAULT_COLUMN": "customer_id"}
F2_SCRIPTS = ["inject/10-drop-index.sh", "inject/20-analyze.sh"]


class ScriptedDocker(FakeDocker):
    """FakeDocker whose script runs (`docker exec -i ...`) are recorded in
    `runs` and answered by `reply(run) -> (returncode, stdout, stderr)`;
    each run is a dict: container, user, env, argv, stdin (text)."""

    def __init__(self, reply=None, **kwargs):
        super().__init__(**kwargs)
        self.reply = reply or (lambda run: (0, "", ""))
        self.runs = []
        # load-data's survey (v0.4): node -> [database row as the survey
        # writes it]; a node not here holds no database. `survey_answer`
        # answers the listing and the survey before `reply` is asked.
        self.databases = {}
        # The pg_cron noise fix's two runs (v0.4): the launcher's wait and the
        # log's switch (two JSON lines), then the cleanup script's output.
        self.launcher_answer = (0, json.dumps(LAUNCHER_BEFORE) + "\n"
                                + json.dumps({"file": NEW_LOG}) + "\n", "")
        self.clean_answer = (0, "postgresql-2026-10-31_092656.log: 68\n", "")

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None):
        args = [str(a) for a in args]
        if args[:2] != ["exec", "-i"]:
            return super().run(args, input=input, stdin=stdin, capture=capture, check=check,
                               timeout=timeout)
        self.calls.append(args)
        i, user, env = 2, None, {}
        while args[i].startswith("-"):
            if args[i] == "-u":
                user = args[i + 1]
            elif args[i] == "-e":
                key, _, value = args[i + 1].partition("=")
                env[key] = value
            i += 2
        text = input if input is not None else (stdin.read() if stdin is not None else "")
        if isinstance(text, (bytes, bytearray)):
            text = text.decode()
        run = {"container": args[i], "user": user, "env": env, "argv": args[i + 1:],
               "stdin": text, "timeout": timeout}
        self.runs.append(run)
        rc, out, err = self.survey_answer(run) or self.reply(run)
        return subprocess.CompletedProcess(args, rc, out, err)

    def survey_answer(self, run):
        """The listing's and the survey's output for the run's node, as psql
        -A -t writes them; None for any other run."""
        node = run["container"].rsplit("_", 1)[-1].split(".")[0]
        rows = self.databases.get(node, [])
        if run["stdin"] == inject.DATABASES_SQL:
            return (0, json.dumps([r["database"] for r in rows]) + "\n", "")
        if inject.SURVEY_SQL in run["stdin"]:
            return (0, "".join(json.dumps(r) + "\n" for r in rows), "")
        if run["stdin"] == inject.LAUNCHER_SQL:
            return self.launcher_answer
        if run["stdin"] == inject.CLEAN_SH:
            return self.clean_answer
        return None


OLD_LOG = "/var/log/postgresql/postgresql-2026-10-31_092656.log"
NEW_LOG = "/var/log/postgresql/postgresql-2026-10-31_093112.log"
LAUNCHER_BEFORE = {"launcher": True, "cron_database": "reporting",
                   "data_directory": "/var/lib/postgresql/18/data", "file": OLD_LOG}


def database_row(name, pg_cron=False, servers=0, mappings=()):
    """A survey row (inject.SURVEY_SQL's JSON object)."""
    return {"database": name, "pg_cron": pg_cron, "servers": servers,
            "mappings": [dict(zip(("server", "local_role", "remote_role", "password"), m),
                              public=m[1] == "public") for m in mappings]}


# A fragment of each fixture script, to tell which one a run streamed.
FRAGMENTS = {"10-drop-index": "# Plants fixture-dropped-index",
             "20-analyze": "# Second script of fixture-dropped-index",
             "f2-check": "# Sealed check of fixture-dropped-index",
             "f1-check": "# Sealed check of fixture-random-page-cost"}


def script_name(run):
    for name, fragment in FRAGMENTS.items():
        if fragment in run["stdin"]:
            return name
    return run["stdin"]


class DeployedGame(RenderedGame):
    """A game deployed on a ScriptedDocker; `self.replies` maps a substring
    of the streamed script to (returncode, stdout, stderr)."""

    def setUp(self):
        super().setUp()
        self.replies = {}
        self.fake = ScriptedDocker(reply=self.reply)
        self.fake.add("volume", "registry-data")
        self.deploy(self.fake)
        self.printed = []

    def reply(self, run):
        for fragment, answer in self.replies.items():
            if fragment in run["stdin"]:
                return answer
        return (0, "done\n", "")

    def stage(self):
        return localimpl.read_state(self.ldir)["stage"]

    def load_data(self, **kwargs):
        return inject.load_data(self.scenario, "laptop", docker=self.fake,
                                out=self.printed.append, **kwargs)

    def inject(self, **kwargs):
        return inject.inject(self.scenario, "laptop", docker=self.fake,
                             out=self.printed.append, **kwargs)


class TestFaultEnv(RenderedGame):

    def scenario_f2(self):
        sc = model.load_scenario(self.scenario)
        inst = next(i for i in sc.data["fault_instances"] if i["id"] == "f2")
        return sc.faults["f2"], inst

    def test_instance_value_then_default(self):
        fault, inst = self.scenario_f2()
        self.assertEqual(inject.fault_env(fault, inst), F2_ENV)
        inst["parameters"]["database"] = "archive"
        self.assertEqual(inject.fault_env(fault, inst)["FAULT_DATABASE"], "archive")

    def test_scalars_as_text(self):
        fault, inst = self.scenario_f2()
        inst["parameters"].update(database=True, column=7)
        env = inject.fault_env(fault, inst)
        self.assertEqual((env["FAULT_DATABASE"], env["FAULT_COLUMN"]), ("true", "7"))
        inst["parameters"]["database"] = False
        self.assertEqual(inject.fault_env(fault, inst)["FAULT_DATABASE"], "false")

    def test_no_value_is_not_set_unless_required(self):
        fault, inst = self.scenario_f2()
        fault.data["parameters"]["table-name"]["default"] = None
        self.assertNotIn("FAULT_TABLE_NAME", inject.fault_env(fault, inst))
        inst["parameters"]["column"] = None
        with self.assertRaisesRegex(GmError, "parameter column is required"):
            inject.fault_env(fault, inst)

    def test_list_or_map_refused(self):
        fault, inst = self.scenario_f2()
        inst["parameters"]["column"] = ["a", "b"]
        with self.assertRaisesRegex(GmError, "list or map"):
            inject.fault_env(fault, inst)

    def test_seed_fault_without_parameters(self):
        sc = model.load_scenario(self.scenario)
        inst = sc.data["fault_instances"][0]
        self.assertEqual(inject.fault_env(sc.faults["f1"], inst), {})


class TestExecArgv(DeployedGame):

    def test_argv_replaces_sh(self):
        execnode.exec_node(self.ldir, "db", "postgres", stdin="SELECT 1;",
                           argv=["psql", "-X"], docker=self.fake)
        self.assertEqual(self.fake.runs[-1]["argv"], ["psql", "-X"])
        execnode.exec_node(self.ldir, "db", "root", stdin="true\n", docker=self.fake)
        self.assertEqual(self.fake.runs[-1]["argv"], ["sh", "-s"])


class TestLoadData(DeployedGame):

    def test_streams_the_sql_into_psql_as_postgres(self):
        result = self.load_data()
        self.assertEqual(len(self.fake.runs), 3)        # the data, the survey, the grant
        run = self.fake.runs[0]
        self.assertEqual(run["container"], f"{self.gid}_db.1.ctr")
        self.assertEqual(run["user"], "postgres")
        # no scheduler node: no shift, the customer's zone is UTC (W1 item 0);
        # v0.5 (W2 item 3): the run's start, to the minute, as load_epoch
        self.assertEqual(run["argv"][:9] + run["argv"][-2:],
                         ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
                          "-v", "customer_timezone=Etc/GMT",
                          "-v", "customer_utc_offset=0", "-d", "postgres"])
        self.assertEqual(run["argv"][9], "-v")
        self.assertRegex(run["argv"][10], r"^load_epoch=\d{4}-\d\d-\d\dT\d\d:\d\dZ$")
        self.assertEqual(run["env"], {})
        self.assertEqual(run["stdin"],
                         (self.scenario / "data" / "db.sql").read_text())
        self.assertEqual(self.stage(), "data-loaded")
        self.assertIn("db: data/db.sql", result.text())
        self.assertIn("Stage data-loaded.", result.text())

    def test_already_loaded_changes_nothing(self):
        self.load_data()
        for stage in ("data-loaded", "injected", "handed-over"):
            if stage != "data-loaded":
                localimpl.set_stage(self.ldir, stage)
            before = (self.ldir / "state.yaml").read_bytes()
            result = self.load_data()
            self.assertIn(f"at stage {stage}: the data is already loaded", result.text())
            self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)
        self.assertEqual(len(self.fake.runs), 3)

    def test_needs_a_deployed_game(self):
        teardown.teardown(self.scenario, "laptop", docker=self.fake)
        with self.assertRaisesRegex(GmError, "load-data needs stage deployed"):
            self.load_data()
        self.assertEqual(self.fake.runs, [])

    def test_no_data_entry_loads_nothing(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "db").pop("data"))
        result = self.load_data()
        self.assertEqual([r["stdin"] for r in self.fake.runs],
                         [inject.DATABASES_SQL, inject.grant_sql()])
        self.assertEqual(self.stage(), "data-loaded")
        self.assertIn("no node holds data", result.text())

    def test_failure_is_a_failed_setup(self):
        self.replies["CREATE DATABASE shop"] = (3, "", "ERROR:  role \"shop\" already exists\n")
        with self.assertRaises(state.SetupFailed) as ctx:
            self.load_data()
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"]["stage"], "data-loaded")
        self.assertIn("psql exit 3", st["failure"]["reason"])
        self.assertIn("already exists", st["failure"]["reason"])
        self.assertIn("Teardown of game", str(ctx.exception))
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})
        self.assertEqual(self.fake.names("volume"), ["registry-data"])
        self.assertIn("db data/db.sql (psql as postgres): exit 3", self.printed)

    def test_the_reason_is_psqls_error_not_its_first_line(self):
        # RG-9: a result printed before the error must not hide it
        self.replies["CREATE DATABASE shop"] = (3, " setval \n--------\n      1\n(1 row)\n\n",
                                                "ERROR:  division by zero\n")
        with self.assertRaises(state.SetupFailed) as ctx:
            self.load_data()
        reason = localimpl.read_state(self.ldir)["failure"]["reason"]
        self.assertEqual(reason, "data load of db (data/db.sql): psql exit 3: "
                                 "ERROR: division by zero")         # spaces folded
        self.assertIn("psql exit 3: ERROR: division by zero", str(ctx.exception))
        self.assertIn("     setval", self.printed)

    def test_interruption_is_a_failed_setup(self):
        def interrupt(run):
            raise KeyboardInterrupt
        self.fake.reply = interrupt
        with self.assertRaises(state.SetupFailed):
            self.load_data()
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["failure"]["stage"], "data-loaded")
        self.assertIn("interrupted", st["failure"]["reason"])
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})


class TestInject(DeployedGame):

    def setUp(self):
        super().setUp()
        self.load_data()
        self.fake.runs.clear()

    def test_state_fault_scripts_in_order(self):
        self.replies[FRAGMENTS["10-drop-index"]] = (0, "no index leads with customer_id\n", "")
        result = self.inject()
        self.assertEqual([script_name(r) for r in self.fake.runs],
                         ["10-drop-index", "20-analyze"])
        fault_dir = self.scenario / "faults" / "fixture-dropped-index"
        for run, script in zip(self.fake.runs, F2_SCRIPTS):
            self.assertEqual(run["stdin"], (fault_dir / script).read_text())
            self.assertEqual(run["argv"], ["sh", "-s"])
            self.assertEqual(run["user"], "root")
            self.assertEqual(run["container"], f"{self.gid}_db.1.ctr")
            self.assertEqual(run["env"], F2_ENV)
        self.assertEqual(self.stage(), "injected")
        self.assertEqual(result.scripts, [("f2", s) for s in F2_SCRIPTS])
        self.assertEqual(result.seeded, ["f1"])
        self.assertIn("f2 inject/10-drop-index.sh (db, as root): ok", self.printed)
        self.assertIn("    no index leads with customer_id", self.printed)
        self.assertIn("f1: seed-file fault", result.text())
        self.assertIn("Stage injected.", result.text())

    def test_second_run_replays_and_stage_stays(self):
        self.inject()
        before = (self.ldir / "state.yaml").read_bytes()
        result = self.inject()
        self.assertEqual(len(self.fake.runs), 4)
        self.assertEqual(self.fake.runs[:2], self.fake.runs[2:])
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)
        self.assertIn("again (replay)", result.text())
        self.assertIn("Stage injected (unchanged).", result.text())

    def test_run_as(self):
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["injection"].update(run_as="postgres"))
        self.inject()
        self.assertEqual({r["user"] for r in self.fake.runs}, {"postgres"})

    def test_first_failure_stops_and_fails_the_setup(self):
        self.replies[FRAGMENTS["10-drop-index"]] = (4, "", "psql: error: relation \"orders\" does not exist\n")
        with self.assertRaises(state.SetupFailed):
            self.inject()
        self.assertEqual([script_name(r) for r in self.fake.runs], ["10-drop-index"])
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"]["stage"], "injected")
        self.assertIn("stopped at inject/10-drop-index.sh: exit 4", st["failure"]["reason"])
        self.assertIn("does not exist", st["failure"]["reason"])
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})

    def test_required_parameter_without_value_refused_before_running(self):
        def change(d):
            next(i for i in d["fault_instances"] if i["id"] == "f2")["parameters"]["column"] = None
        self.edit_yaml("scenario.yaml", change)
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, "parameter column is required"):
            self.inject()
        self.assertEqual(self.fake.runs, [])
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)

    def test_refused_after_hand_over(self):
        localimpl.set_stage(self.ldir, "injected")
        localimpl.set_stage(self.ldir, "handed-over")
        with self.assertRaisesRegex(GmError, "inject needs stage data-loaded"):
            self.inject()
        self.assertEqual(self.fake.runs, [])


class TestBeforeDataLoad(DeployedGame):

    def test_inject_refused_at_deployed(self):
        with self.assertRaisesRegex(GmError, "run gmctl load-data"):
            self.inject()
        self.assertEqual(self.fake.runs, [])
        self.assertEqual(self.stage(), "deployed")


class TestCommandLine(RenderedGame):

    def test_refusals_exit_1(self):
        for command in ("load-data", "inject"):
            proc = run_gmctl(command, self.scenario, "--playground", "laptop")
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertIn(f"gmctl {command}: game {self.gid} is at stage rendered",
                          proc.stderr)
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_at_and_instance_go_together(self):
        for extra in (["--at", "now"], ["--instance", "f2"]):
            proc = run_gmctl("inject", self.scenario, "--playground", "laptop", *extra)
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertIn("--at and --instance go together", proc.stderr)

    def test_at_needs_the_load_started(self):
        proc = run_gmctl("inject", self.scenario, "--playground", "laptop", "--at", "now",
                         "--instance", "f2")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("inject --at needs stage load-started", proc.stderr)
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")


class TestMountedGame(MountedCopyTest):
    """fixture-mounted deployed on a ScriptedDocker: f1 a state fault, f2 a
    parameter fault (app left out of the node-health map)."""

    def setUp(self):
        super().setUp()
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        render.render(self.scenario, "laptop")
        self.ldir = self.scenario / "local" / "laptop"
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.fake = ScriptedDocker()
        self.printed = []
        deploy.deploy(self.scenario, "laptop", docker=self.fake, timeout=30,
                      sleep=lambda s: None, clock=lambda: 0.0)

    def test_deploy_creates_the_mounted_configs_once(self):
        gid = self.gid
        self.assertEqual(self.fake.names("config"), sorted([
            f"{gid}_monitor_node-health-1", f"{gid}_monitor_node-health-2",
            f"{gid}_bastion_node-health.conf", f"{gid}_monitor_node-health.conf"]))
        creates = [c[-2] for c in self.fake.called("config", "create")]
        self.assertEqual(len(creates), len(set(creates)))
        for call in self.fake.called("config", "create"):
            self.assertGreater(Path(call[-1]).stat().st_size, 0, call[-2])

    def test_a_parameter_fault_is_reported_as_planted_at_rendering(self):
        inject.load_data(self.scenario, "laptop", docker=self.fake, out=self.printed.append)
        result = inject.inject(self.scenario, "laptop", docker=self.fake,
                               out=self.printed.append)
        self.assertEqual([r["stdin"] for r in self.fake.runs], [
            (self.scenario / "faults/fixture-app-stopped/inject/10-stop.sh").read_text()])
        self.assertEqual(result.scripts, [("f1", "inject/10-stop.sh")])
        self.assertEqual(result.seeded, [])
        self.assertEqual(result.rendered, ["f2"])
        self.assertIn("  f2: parameter fault, planted at rendering; nothing to run",
                      result.text())
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "injected")


# --- v0.3: the application roles' passwords at load-data (chunk 7b) ---------

VERIFIER_RE = re.compile(r"PASSWORD 'SCRAM-SHA-256\$4096:([A-Za-z0-9+/=]+)\$"
                         r"([A-Za-z0-9+/=]+):([A-Za-z0-9+/=]+)'")


class TestPsqlErrorLine(unittest.TestCase):

    @staticmethod
    def line(stdout="", stderr="", returncode=3):
        run = execnode.ExecResult("db", "postgres", "ctr", returncode, stdout, stderr)
        return inject.psql_error_line(run)

    def test_the_first_error_line(self):
        self.assertEqual(self.line(" setval \n--------\n 1\n",
                                   "NOTICE:  skipping\nERROR:  division by zero\n"
                                   "ERROR:  second\n"),
                         "ERROR:  division by zero")

    def test_an_error_line_before_a_psql_one(self):
        self.assertEqual(self.line("", "psql:<stdin>:3: NOTICE:  skipping\n"
                                       "ERROR:  division by zero\n"),
                         "ERROR:  division by zero")

    def test_else_a_fatal_or_psql_line(self):
        self.assertEqual(self.line("x\n", "FATAL:  the database system is starting up\n"),
                         "FATAL:  the database system is starting up")
        self.assertEqual(self.line("x\n", 'psql: error: connection to server on socket '
                                           '"/run/postgresql/.s.PGSQL.5432" failed\n'),
                         'psql: error: connection to server on socket '
                         '"/run/postgresql/.s.PGSQL.5432" failed')

    def test_else_the_first_line(self):
        self.assertEqual(self.line(" setval \n--------\n", "something odd\n"), " setval")
        self.assertEqual(self.line(), "no output")


class TestScramVerifier(unittest.TestCase):

    def test_rfc_7677_vector(self):
        # RFC 7677, section 3: user "user", password "pencil"; the server's
        # signature and the client's proof check against the verifier's keys.
        salt = base64.b64decode("W22ZaJ0SNY7soEsUEjb6gQ==")
        verifier = inject.scram_verifier("pencil", salt=salt)
        m = re.fullmatch(r"SCRAM-SHA-256\$4096:(.+)\$(.+):(.+)", verifier)
        self.assertEqual(base64.b64decode(m.group(1)), salt)
        stored, server = base64.b64decode(m.group(2)), base64.b64decode(m.group(3))
        nonce = "rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0"
        auth = (f"n=user,r=rOprNGfwEbeRWgbNEkqO,r={nonce},s=W22ZaJ0SNY7soEsUEjb6gQ==,"
                f"i=4096,c=biws,r={nonce}").encode()
        self.assertEqual(base64.b64encode(hmac.new(server, auth, hashlib.sha256).digest()),
                         b"6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=")
        proof = base64.b64decode("dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=")
        signature = hmac.new(stored, auth, hashlib.sha256).digest()
        client_key = bytes(a ^ b for a, b in zip(proof, signature))
        self.assertEqual(hashlib.sha256(client_key).digest(), stored)

    def test_a_fresh_salt_each_time(self):
        self.assertNotEqual(inject.scram_verifier("x"), inject.scram_verifier("x"))


def matches(verifier_match, password):
    """Whether a verifier (VERIFIER_RE's groups) is `password`'s."""
    salt, stored = base64.b64decode(verifier_match.group(1)), verifier_match.group(2)
    again = inject.scram_verifier(password, salt=salt)
    return again.split("$")[2].split(":")[0] == stored


class V03DeployedGame(V03Rendered):
    """fixture-v03-refusals rendered and deployed on a ScriptedDocker."""

    def setUp(self):
        super().setUp()
        self.render(handover_at(16))
        self.replies = {}
        self.fake = ScriptedDocker(reply=self.reply)
        self.clock = [0.0]
        deploy.deploy(self.scenario, "laptop", docker=self.fake, timeout=30,
                      sleep=lambda s: self.clock.__setitem__(0, self.clock[0] + s),
                      clock=lambda: self.clock[0])
        self.printed = []

    def reply(self, run):
        for fragment, answer in self.replies.items():
            if fragment in run["stdin"]:
                return answer
        return (0, "", "")

    def load_data(self):
        return inject.load_data(self.scenario, "laptop", docker=self.fake,
                                out=self.printed.append)


class TestLoadDataPasswords(V03DeployedGame):

    def test_the_roles_passwords_set_after_the_data_load(self):
        result = self.load_data()
        self.assertEqual(len(self.fake.runs), 4)
        data, passwords, survey, grant = self.fake.runs
        self.assertEqual(survey["stdin"], inject.DATABASES_SQL)
        self.assertEqual(grant["stdin"], inject.grant_sql())
        self.assertEqual(data["stdin"], (self.scenario / "data/db.sql").read_text())
        self.assertEqual(passwords["container"], f"{self.gid}_db.1.ctr")
        self.assertEqual(passwords["user"], "postgres")
        self.assertEqual(passwords["argv"], list(inject.PSQL_ARGV))
        lines = passwords["stdin"].splitlines()
        self.assertEqual(lines[:4], ["SET log_statement = 'none';",
                                     "SET log_min_duration_statement = -1;",
                                     "SET log_min_error_statement = 'panic';",
                                     "SET pgaudit.log = 'none';"])
        sdir = self.ldir / "secrets"
        for line, role in zip(lines[4:], ("shop_app", "shop_reports")):
            self.assertTrue(line.startswith(f'ALTER ROLE "{role}" PASSWORD '), line)
            secret = (sdir / f"role_{role}_password").read_text()
            self.assertEqual(len(secret), deploy.DBA_PASSWORD_LENGTH)
            self.assertNotIn(secret, passwords["stdin"])       # only its verifier
            self.assertTrue(matches(VERIFIER_RE.search(line), secret), role)
        self.assertEqual(len(lines), 6)
        self.assertEqual(result.passwords, [("db", ["shop_app", "shop_reports"])])
        self.assertIn("  db: password set from its secret for role(s) shop_app, shop_reports",
                      result.text())
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "data-loaded")
        for secret in sdir.iterdir():
            self.assertNotIn(secret.read_text().strip(), "\n".join(self.printed))

    def test_a_missing_role_fails_the_step(self):
        self.replies["ALTER ROLE"] = (3, "", 'psql:<stdin>:4: ERROR:  role "shop_app" does '
                                             "not exist\n")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("setting the passwords of shop_app, shop_reports on db", str(cm.exception))
        st = localimpl.read_state(self.ldir)
        self.assertEqual((st["stage"], st["failure"]["stage"]), ("failed", "data-loaded"))

    def test_a_pooler_target_sets_them_on_the_database_nodes(self):
        self.edit_yaml("nodes/producer/schedule.yaml",
                       lambda d: d["connections"]["reports"].update(target="bastion:6432/shop"))
        sc = model.load_scenario(self.scenario)
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual(inject.password_plan(sc, impl), [
            ("db", [("shop_app", "role_shop_app_password"),
                    ("shop_reports", "role_shop_reports_password")])])


class TestLoadDataStatic(DeployedGame):
    """A game with no scheduler node whose data file creates no login role
    sets no password."""

    def test_no_password_step(self):
        result = self.load_data()
        self.assertEqual(len(self.fake.runs), 3)        # the data, the survey, the grant
        self.assertEqual(result.passwords, [])
        self.assertNotIn("password", result.text())

    def test_a_login_role_of_the_data_file_gets_its_password(self):
        path = self.scenario / "data" / "db.sql"
        path.write_text(path.read_text().replace(
            "CREATE ROLE shop NOLOGIN;\n",
            "CREATE ROLE shop NOLOGIN;\nCREATE ROLE shop_app LOGIN;\n"))
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.password_plan(sc, self.impl),
                         [("db", [("shop_app", "role_shop_app_password")])])

    def test_a_login_role_with_its_own_password_keeps_it(self):
        path = self.scenario / "data" / "db.sql"
        path.write_text(path.read_text().replace(
            "CREATE ROLE shop NOLOGIN;\n",
            "CREATE ROLE shop NOLOGIN;\nCREATE ROLE shop_app LOGIN PASSWORD 'Pages-and-Co';\n"))
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.password_plan(sc, self.impl), [])
        self.assertNotIn("role_shop_app_password",
                         {sec["secret"] for sec in localimpl.game_secrets(sc)[0]})
        result = self.load_data()
        self.assertEqual(result.passwords, [])
        self.assertFalse([r for r in self.fake.runs if "ALTER ROLE" in r["stdin"]])


# --- v0.3: the GM check role's CONNECT at load-data (spec D176) -------------

class TestLoadDataCheckRoleGrant(DeployedGame):

    def test_granted_after_the_load_on_every_database_but_the_templates(self):
        result = self.load_data()
        data, survey, grant = self.fake.runs
        self.assertEqual(data["stdin"], (self.scenario / "data" / "db.sql").read_text())
        self.assertEqual(survey["stdin"], inject.DATABASES_SQL)
        self.assertEqual(grant["container"], f"{self.gid}_db.1.ctr")
        self.assertEqual(grant["user"], "postgres")
        self.assertEqual(grant["argv"], list(inject.PSQL_ARGV))
        sql = grant["stdin"]
        self.assertEqual(sql, inject.grant_sql())
        self.assertIn("FOR db IN SELECT datname FROM pg_catalog.pg_database", sql)
        self.assertIn("WHERE NOT datistemplate AND datname NOT IN ('template0', 'template1')",
                      sql)
        # each name quoted as an identifier, by the server (format's %I)
        self.assertIn("EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', db, 'gm_check');",
                      sql)
        self.assertEqual(result.grants, ["db"])
        self.assertIn("  db: gm_check granted CONNECT on every database", result.text())
        self.assertIn("db CONNECT for gm_check (psql as postgres): ok", self.printed)
        self.assertEqual(self.stage(), "data-loaded")

    def test_not_issued_on_a_node_without_the_check_role(self):
        declarations = localimpl.node_secret_declarations

        def without_check_role(scenario, node):
            return [sec for sec in declarations(scenario, node)
                    if sec.get("name") != inject.CHECK_SECRET]
        with mock.patch.object(localimpl, "node_secret_declarations", without_check_role):
            result = self.load_data()
        self.assertEqual([r["stdin"] for r in self.fake.runs],
                         [(self.scenario / "data" / "db.sql").read_text(), inject.DATABASES_SQL])
        self.assertEqual(result.grants, [])
        self.assertNotIn("gm_check", result.text())
        self.assertEqual(self.stage(), "data-loaded")

    def test_only_database_nodes(self):
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.grant_plan(sc, self.impl), ["db"])
        everywhere = [{"name": inject.CHECK_SECRET}]
        with mock.patch.object(localimpl, "node_secret_declarations", lambda s, n: everywhere):
            self.assertEqual(inject.grant_plan(sc, self.impl), ["db"])
        self.assertGreater(len(sc.nodes), 1)

    def test_a_failure_fails_the_step(self):
        self.replies["GRANT CONNECT"] = (3, "", "psql:<stdin>:11: ERROR:  role \"gm_check\" "
                                                "does not exist\n")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("granting gm_check CONNECT on the databases of db: psql exit 3",
                      str(cm.exception))
        st = localimpl.read_state(self.ldir)
        self.assertEqual((st["stage"], st["failure"]["stage"]), ("failed", "data-loaded"))
        self.assertIn("does not exist", st["failure"]["reason"])
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})
        self.assertIn("db CONNECT for gm_check (psql as postgres): exit 3", self.printed)


# --- v0.4: load-data across instances (chunk 7) -----------------------------

INSTANCES_FIXTURE = Path(__file__).resolve().parent / "fixtures" / "fixture-instances"
BI_MAPPING = ("shop_db", "bi_etl", "shop_etl", False)


class InstancesDeployedGame(V03Rendered):
    """fixture-instances (db seeding a crontab for shop_etl; reporting with
    pg_cron, a foreign server and bi_etl's user mapping to shop_etl; no
    scheduler node) rendered and deployed on a ScriptedDocker whose survey
    answers as the fixture's data would leave the instances."""

    def setUp(self):
        ScenarioCopyTest.setUp(self)
        self.scenario = self.tmp / "fixture-instances"
        shutil.copytree(INSTANCES_FIXTURE, self.scenario)
        self.prepare()
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.ldir = self.scenario / "local" / "laptop"
        self.render()
        self.replies = {}
        self.fake = ScriptedDocker(reply=self.reply)
        self.fake.databases = {
            "db": [database_row("postgres"), database_row("shop")],
            "reporting": [database_row("postgres"),
                          database_row("reporting", pg_cron=True, servers=1,
                                       mappings=[BI_MAPPING])]}
        deploy.deploy(self.scenario, "laptop", docker=self.fake, timeout=30,
                      sleep=lambda s: None, clock=lambda: 0.0)
        self.printed = []

    def prepare(self):
        """Edits the copy before it is fitted; nothing here."""

    def reply(self, run):
        for fragment, answer in self.replies.items():
            if fragment in run["stdin"]:
                return answer
        return (0, "", "")

    def load_data(self):
        return inject.load_data(self.scenario, "laptop", docker=self.fake,
                                out=self.printed.append)

    def secret(self, role):
        return (self.ldir / "secrets" / f"role_{role}_password").read_text().strip()

    def node_of(self, run):
        return run["container"][len(self.gid) + 1:].split(".")[0]


def step(run):
    """What a load-data run is, by its SQL."""
    text = run["stdin"]
    if text == inject.DATABASES_SQL:
        return "list"
    if text == inject.LAUNCHER_SQL:
        return "launcher"
    if text == inject.CLEAN_SH:
        return "clean"
    for kind, marker in (("survey", inject.SURVEY_SQL), ("mappings", "ALTER USER MAPPING"),
                         ("access", "CREATE POLICY"), ("access", "CREATE OR REPLACE FUNCTION"),
                         ("passwords", "ALTER ROLE"), ("grant", "GRANT CONNECT ON DATABASE %I")):
        if marker in text:
            return kind
    return "data"


class TestLoadDataInstances(InstancesDeployedGame):

    def test_each_step_in_order(self):
        result = self.load_data()
        self.assertEqual([(self.node_of(r), step(r)) for r in self.fake.runs], [
            ("db", "data"), ("reporting", "data"),
            ("db", "passwords"), ("reporting", "passwords"),
            ("db", "list"), ("db", "survey"), ("reporting", "list"), ("reporting", "survey"),
            ("reporting", "mappings"),
            ("reporting", "access"),
            ("db", "grant"), ("reporting", "grant"),
            ("reporting", "launcher"), ("reporting", "clean")])
        self.assertEqual(result.loaded, [("db", "data/db.sql"),
                                         ("reporting", "data/reporting.sql")])
        self.assertEqual(result.passwords, [("db", ["shop_etl", "shop_app"]),
                                            ("reporting", ["bi_etl", "bi_reader"])])
        self.assertEqual([(n, d, [m.local_text for m in ms]) for n, d, ms in result.mappings],
                         [("reporting", "reporting", ["bi_etl"])])
        self.assertEqual(result.policies, [("reporting", "reporting")])
        self.assertEqual(result.functions, [("reporting", "reporting")])
        self.assertEqual(result.grants, ["db", "reporting"])
        self.assertEqual(result.cleaned,
                         [("reporting", [("postgresql-2026-10-31_092656.log", 68)])])
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "data-loaded")
        text = result.text()
        for line in ("  db: password set from its secret for role(s) shop_etl",
                     "  reporting: password set from its secret for role(s) bi_etl, bi_reader",
                     "  reporting/reporting: user mapping for bi_etl on server shop_db given "
                     "remote role shop_etl's password",
                     "  reporting/reporting: gm_check may read every row of cron.job and "
                     "cron.job_run_details (policy gm_check_read)",
                     "  reporting/reporting: gm_check.user_mapping_roles() created for gm_check",
                     "  reporting: gm_check granted CONNECT on every database",
                     "  reporting: pg_cron launcher running; 68 line(s) of its start-up "
                     "failures removed from the server log (postgresql-2026-10-31_092656.log)"):
            self.assertIn(line, text)

    def test_every_data_file_gets_the_zone_and_its_offset(self):
        self.load_data()
        data = [r for r in self.fake.runs if step(r) == "data"]
        self.assertEqual(len(data), 2)
        epochs = {run["argv"][10] for run in data}
        self.assertEqual(len(epochs), 1)            # one reference moment per run (W2 item 3)
        for run in data:
            self.assertEqual(run["argv"][:9] + run["argv"][-2:],
                             ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
                              "-v", "customer_timezone=Etc/GMT",
                              "-v", "customer_utc_offset=0", "-d", "postgres"])

    def test_the_crontab_roles_password_is_set_on_its_node(self):
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.password_plan(sc, self.impl)[0],
                         ("db", [("shop_etl", "role_shop_etl_password"),
                                 ("shop_app", "role_shop_app_password")]))
        self.load_data()
        run = next(r for r in self.fake.runs if step(r) == "passwords")
        self.assertEqual(self.node_of(run), "db")
        line = run["stdin"].splitlines()[4]
        self.assertTrue(line.startswith('ALTER ROLE "shop_etl" PASSWORD '), line)
        self.assertTrue(matches(VERIFIER_RE.search(line), self.secret("shop_etl")))
        self.assertNotIn(self.secret("shop_etl"), run["stdin"])

    def test_the_mappings_password_is_its_remote_roles_secret(self):
        self.load_data()
        run = next(r for r in self.fake.runs if step(r) == "mappings")
        self.assertEqual(run["argv"], list(inject.PSQL_ARGV))
        self.assertEqual(run["user"], "postgres")
        secret = self.secret("shop_etl")
        self.assertEqual(run["stdin"].splitlines(), [
            inject.connect_line("reporting"),
            "SET log_statement = 'none';", "SET log_min_duration_statement = -1;",
            "SET log_min_error_statement = 'panic';", "SET pgaudit.log = 'none';",
            "SET pg_stat_statements.track = 'none';",
            f'ALTER USER MAPPING FOR "bi_etl" SERVER "shop_db" OPTIONS (ADD password '
            f"'{secret}');"])
        printed = "\n".join(self.printed)
        self.assertIn("reporting user mapping passwords (psql as postgres): ok", printed)
        for sec in (self.ldir / "secrets").iterdir():
            self.assertNotIn(sec.read_text().strip(), printed)

    def test_a_set_password_and_a_public_mapping(self):
        self.fake.databases["reporting"][1]["mappings"] = [
            dict(server="shop_db", local_role="bi_etl", remote_role="shop_etl", password=True,
                 public=False),
            dict(server="shop_db", local_role="public", remote_role="shop_etl",
                 password=False, public=True)]
        self.load_data()
        lines = next(r for r in self.fake.runs if step(r) == "mappings")["stdin"].splitlines()
        secret = self.secret("shop_etl")
        self.assertEqual(lines[-2:], [
            f"ALTER USER MAPPING FOR \"bi_etl\" SERVER \"shop_db\" OPTIONS (SET password "
            f"'{secret}');",
            f"ALTER USER MAPPING FOR PUBLIC SERVER \"shop_db\" OPTIONS (ADD password "
            f"'{secret}');"])

    def test_the_read_policy_and_the_function_where_they_belong(self):
        self.fake.databases["db"].append(database_row("archive", pg_cron=True))
        self.fake.databases["reporting"].append(database_row("staging", servers=2))
        self.load_data()
        access = {self.node_of(r): r["stdin"] for r in self.fake.runs if step(r) == "access"}
        self.assertEqual(access["db"], inject.connect_line("archive") + "\n"
                         + inject.QUIET_SQL + "\n" + inject.policy_sql())
        self.assertEqual(access["reporting"],
                         inject.connect_line("reporting") + "\n" + inject.QUIET_SQL + "\n"
                         + inject.policy_sql() + inject.function_sql()
                         + inject.connect_line("staging") + "\n" + inject.QUIET_SQL + "\n"
                         + inject.function_sql())

    def test_nothing_more_where_no_database_holds_either(self):
        self.fake.databases = {}
        result = self.load_data()
        self.assertEqual([step(r) for r in self.fake.runs],
                         ["data", "data", "passwords", "passwords", "list", "list", "grant",
                          "grant"])
        self.assertEqual((result.mappings, result.policies, result.functions, result.cleaned),
                         ([], [], [], []))

    def test_no_access_where_the_check_role_does_not_exist(self):
        declarations = localimpl.node_secret_declarations

        def without_check_role(scenario, node):
            return [sec for sec in declarations(scenario, node)
                    if sec.get("name") != inject.CHECK_SECRET]
        with mock.patch.object(localimpl, "node_secret_declarations", without_check_role):
            result = self.load_data()
        self.assertNotIn("access", [step(r) for r in self.fake.runs])
        self.assertIn("mappings", [step(r) for r in self.fake.runs])
        self.assertEqual((result.policies, result.functions, result.grants), ([], [], []))

    def test_a_mapping_naming_no_remote_role_fails_before_the_mappings(self):
        self.fake.databases["reporting"][1]["mappings"][0]["remote_role"] = None
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("reporting/reporting: the user mapping for bi_etl on server shop_db "
                      "names no remote role (option user)", str(cm.exception))
        self.assertNotIn("mappings", [step(r) for r in self.fake.runs])
        st = localimpl.read_state(self.ldir)
        self.assertEqual((st["stage"], st["failure"]["stage"]), ("failed", "data-loaded"))

    def test_a_remote_role_without_a_secret_fails_before_the_mappings(self):
        self.fake.databases["reporting"][1]["mappings"][0]["remote_role"] = "shop_reports"
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("connects as shop_reports, which has no secret "
                      "role_shop_reports_password in game", str(cm.exception))
        self.assertIn("no data file of the scenario creates shop_reports as a login role",
                      str(cm.exception))
        self.assertNotIn("mappings", [step(r) for r in self.fake.runs])

    def test_a_remote_role_created_without_login_fails_before_the_mappings(self):
        self.fake.databases["reporting"][1]["mappings"][0]["remote_role"] = "shop"
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("connects as shop, which has no secret role_shop_password in game",
                      str(cm.exception))
        self.assertNotIn("mappings", [step(r) for r in self.fake.runs])

    def test_the_login_roles_secrets_are_mounted_nowhere_new(self):
        sc = model.load_scenario(self.scenario)
        names = {sec["secret"] for sec in self.impl["secrets"]}
        self.assertTrue({"role_bi_etl_password", "role_bi_reader_password"} <= names)
        mounted = {sec["name"] for node in sc.nodes
                   for sec in localimpl.node_secret_declarations(sc, node)}
        self.assertNotIn("role_bi_etl_password", mounted)
        self.assertNotIn("role_bi_reader_password", mounted)
        stack = (self.ldir / "stack.yml").read_text()
        self.assertNotIn("role_bi_etl_password", stack)
        self.assertNotIn("role_bi_reader_password", stack)

    def test_a_failed_mapping_step_shows_no_password(self):
        secret = self.secret("shop_etl")
        self.replies["ALTER USER MAPPING"] = (
            3, "", f"ERROR:  syntax error\nLINE 1: ... OPTIONS (ADD password '{secret}')\n")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("setting the user mappings' passwords on reporting: psql exit 3: "
                      "ERROR: syntax error", str(cm.exception))
        reason = localimpl.read_state(self.ldir)["failure"]["reason"]
        for text in (str(cm.exception), reason, "\n".join(self.printed)):
            self.assertNotIn(secret, text)
        self.assertIn("    LINE 1: ... OPTIONS (ADD password '<password>')", self.printed)

    def test_a_failed_access_step_fails_the_setup(self):
        self.replies["CREATE POLICY"] = (3, "", 'ERROR:  role "gm_check" does not exist\n')
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("giving gm_check its read policy and mapping-roles function on "
                      "reporting: psql exit 3", str(cm.exception))
        self.assertNotIn("grant", [step(r) for r in self.fake.runs])

    def test_an_unexpected_survey_fails_the_setup(self):
        self.replies[inject.SURVEY_SQL] = (0, "not json\n", "")
        self.fake.survey_answer = lambda run: (
            None if inject.SURVEY_SQL in run["stdin"] else ScriptedDocker.survey_answer(
                self.fake, run))
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("surveying the databases of db: unexpected psql output: not json",
                      str(cm.exception))

    def test_a_restart_with_no_snapshot_runs_the_same_steps(self):
        sc = model.load_scenario(self.scenario)
        plans = inject.load_plans(sc, self.impl)
        result = inject.LoadResult(self.gid)
        inject.load_steps(self.ldir, plans, self.fake, result, out=self.printed.append)
        self.assertEqual(result.policies, [("reporting", "reporting")])
        self.assertEqual(result.mappings[0][:2], ("reporting", "reporting"))


class TestLoadDataPgCronNoise(InstancesDeployedGame):
    """The pg_cron noise fix: on a node holding pg_cron, after the other
    steps, the launcher waited for, the file log switched and the failed
    launchers' lines removed from the closed files; nowhere else."""

    def runs(self, kind):
        return [r for r in self.fake.runs if step(r) == kind]

    def test_only_the_node_holding_pg_cron_and_last(self):
        self.load_data()
        self.assertEqual([self.node_of(r) for r in self.runs("launcher")], ["reporting"])
        self.assertEqual([self.node_of(r) for r in self.runs("clean")], ["reporting"])
        self.assertEqual([step(r) for r in self.fake.runs][-2:], ["launcher", "clean"])

    def test_how_each_run_is_made(self):
        self.load_data()
        launcher, = self.runs("launcher")
        self.assertEqual((launcher["user"], launcher["argv"]),
                         ("postgres", list(inject.SURVEY_ARGV)))
        clean, = self.runs("clean")
        self.assertEqual((clean["user"], clean["argv"], clean["env"]),
                         ("postgres", ["sh", "-s"], {"GM_LOG_FILE": NEW_LOG}))
        printed = "\n".join(self.printed)
        self.assertIn("reporting pg_cron launcher and the server log's switch (psql as "
                      "postgres): ok", printed)
        self.assertIn("reporting pg_cron launcher's start-up failures out of the server log "
                      "(sh as postgres): ok", printed)

    def test_the_wait_and_the_switch(self):
        sql = inject.LAUNCHER_SQL
        self.assertEqual(sql.splitlines()[:3], list(inject.NO_LOG_SQL))   # not in the log
        self.assertIn(f"FOR i IN 1..{inject.LAUNCHER_WAIT * 10} LOOP", sql)
        self.assertIn("backend_type = 'pg_cron launcher'", sql)
        self.assertEqual(sql.count("pg_catalog.pg_stat_clear_snapshot()"), 2)
        self.assertLess(sql.index("IF before IS NULL OR NOT EXISTS"),
                        sql.index("pg_catalog.pg_rotate_logfile()"))
        self.assertIn(f"FOR i IN 1..{inject.ROTATE_WAIT * 10} LOOP", sql)

    def test_the_launcher_not_connected_fails_the_setup(self):
        before = dict(LAUNCHER_BEFORE, launcher=False)
        self.fake.launcher_answer = (0, json.dumps(before) + "\n"
                                     + json.dumps({"file": OLD_LOG}) + "\n", "")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("the pg_cron launcher of reporting is not connected 60 s after the data "
                      "load (cron.database_name 'reporting': the data file must create it)",
                      str(cm.exception))
        self.assertEqual(self.runs("clean"), [])
        st = localimpl.read_state(self.ldir)
        self.assertEqual((st["stage"], st["failure"]["stage"]), ("failed", "data-loaded"))

    def test_no_file_log_nothing_to_clean(self):
        before = dict(LAUNCHER_BEFORE, file=None)
        self.fake.launcher_answer = (0, json.dumps(before) + "\n"
                                     + json.dumps({"file": None}) + "\n", "")
        result = self.load_data()
        self.assertEqual(self.runs("clean"), [])
        self.assertEqual(result.cleaned, [("reporting", None)])
        self.assertIn("  reporting: pg_cron launcher running; no file log (logging_collector "
                      "off)", result.text())

    def test_a_log_that_did_not_switch_is_left_with_a_warning(self):
        self.fake.launcher_answer = (0, json.dumps(LAUNCHER_BEFORE) + "\n"
                                     + json.dumps({"file": OLD_LOG}) + "\n", "")
        result = self.load_data()
        self.assertEqual(self.runs("clean"), [])
        self.assertIn(f"  warning: reporting: the server log did not switch files within 10 s "
                      f"({OLD_LOG}); its pg_cron launcher start-up failures are left in it",
                      result.text())

    def test_a_relative_log_directory_is_read_in_the_data_directory(self):
        before = dict(LAUNCHER_BEFORE, file="log/postgresql-a.log")
        self.fake.launcher_answer = (0, json.dumps(before) + "\n"
                                     + json.dumps({"file": "log/postgresql-b.log"}) + "\n", "")
        self.load_data()
        clean, = self.runs("clean")
        self.assertEqual(clean["env"],
                         {"GM_LOG_FILE": "/var/lib/postgresql/18/data/log/postgresql-b.log"})

    def test_nothing_removed(self):
        self.fake.clean_answer = (0, "", "")
        result = self.load_data()
        self.assertEqual(result.cleaned, [("reporting", [])])
        self.assertIn("no start-up failure of it in the server log", result.text())

    def test_a_failed_cleanup_fails_the_setup(self):
        self.fake.clean_answer = (1, "", "mv: cannot move\n")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("removing the pg_cron launcher's start-up failures from the server log "
                      "of reporting: exit 1: mv: cannot move", str(cm.exception))

    def test_unexpected_psql_output_fails_the_setup(self):
        self.fake.launcher_answer = (0, "not json\n", "")
        with self.assertRaises(state.SetupFailed) as cm:
            self.load_data()
        self.assertIn("switching the server log of reporting: unexpected psql output",
                      str(cm.exception))

    def test_a_restart_with_no_snapshot_cleans_too(self):
        sc = model.load_scenario(self.scenario)
        result = inject.LoadResult(self.gid)
        inject.load_steps(self.ldir, inject.load_plans(sc, self.impl), self.fake, result,
                          out=self.printed.append)
        self.assertEqual([n for n, _ in result.cleaned], ["reporting"])


class TestCleanScript(unittest.TestCase):
    """inject.CLEAN_SH run by sh on a log directory as the brick writes it."""

    BOOT = [
        "2026-10-31 09:26:56 UTC [40]: user=,db=,app=,client= LOG:  database system is ready "
        "to accept connections",
        '2026-10-31 09:26:56 UTC [57]: user=,db=,app=,client= FATAL:  database "reporting" '
        "does not exist",
        '2026-10-31 09:26:56 UTC [40]: user=,db=,app=,client= LOG:  background worker '
        '"pg_cron launcher" (PID 57) exited with exit code 1',
        "2026-10-31 09:26:57 UTC [60]: user=bi,db=reporting,app=[unknown],client=10.0.0.5 "
        'FATAL:  database "reporting" does not exist',
        '2026-10-31 09:26:57 UTC [61]: user=,db=,app=,client= FATAL:  database "reporting" '
        "does not exist",
        '2026-10-31 09:26:57 UTC [61]: user=,db=,app=,client= DETAIL:  a detail',
        "\tits continuation",
        '2026-10-31 09:26:57 UTC [40]: user=,db=,app=,client= LOG:  background worker '
        '"pg_cron launcher" (PID 61) exited with exit code 1',
        "2026-10-31 09:26:58 UTC [70]: user=postgres,db=postgres,app=psql,client=[local] "
        "LOG:  duration: 120.1 ms  statement: SELECT a[57], a[61] FROM t;",
        "\tWHERE b[57] > 0;",
        "2026-10-31 09:26:59 UTC [71]: user=,db=,app=,client= LOG:  pg_cron scheduler started",
        "2026-10-31 09:27:00 UTC [61]: user=x,db=y,app=,client= LOG:  a later process 61",
    ]

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir)
        self.boot = self.dir / "postgresql-2026-10-31_092656.log"
        self.boot.write_text("\n".join(self.BOOT) + "\n")
        self.boot.chmod(0o640)
        os.utime(self.boot, (1_700_000_000, 1_700_000_000))
        self.current = self.dir / "postgresql-2026-10-31_093112.log"
        self.current.write_text(self.BOOT[2] + "\n")
        (self.dir / "cron").mkdir()

    def run_script(self, awk=None):
        """The script under sh; `awk`, the awk it runs (the image's is
        Debian's mawk), else the host's."""
        env = dict(os.environ, GM_LOG_FILE=str(self.current))
        if awk:
            bindir = Path(self.dir.parent) / (self.dir.name + "-bin")
            bindir.mkdir()
            self.addCleanup(shutil.rmtree, bindir)
            (bindir / "awk").symlink_to(awk)
            env["PATH"] = f"{bindir}:{env.get('PATH', '/usr/bin:/bin')}"
        return subprocess.run(["sh", "-s"], input=inject.CLEAN_SH, text=True,
                              capture_output=True, env=env)

    def test_only_the_failed_launchers_lines_go(self):
        run = self.run_script()
        self.assertEqual((run.returncode, run.stderr), (0, ""))
        self.assertEqual(run.stdout, "postgresql-2026-10-31_092656.log: 6\n")
        kept = [self.BOOT[i] for i in (0, 3, 8, 9, 10, 11)]
        self.assertEqual(self.boot.read_text(), "\n".join(kept) + "\n")

    @unittest.skipUnless(shutil.which("mawk"), "no mawk on this host")
    def test_the_same_with_mawk(self):
        run = self.run_script(awk=shutil.which("mawk"))
        self.assertEqual((run.returncode, run.stderr), (0, ""))
        self.assertEqual(run.stdout, "postgresql-2026-10-31_092656.log: 6\n")
        kept = [self.BOOT[i] for i in (0, 3, 8, 9, 10, 11)]
        self.assertEqual(self.boot.read_text(), "\n".join(kept) + "\n")

    def test_the_current_file_its_mode_and_time(self):
        self.run_script()
        self.assertEqual(self.current.read_text(), self.BOOT[2] + "\n")
        self.assertEqual(self.boot.stat().st_mode & 0o777, 0o640)
        self.assertEqual(int(self.boot.stat().st_mtime), 1_700_000_000)
        self.assertEqual(sorted(p.name for p in self.dir.iterdir()),
                         ["cron", self.boot.name, self.current.name])

    def test_a_file_naming_no_failed_launcher_is_left_alone(self):
        self.boot.write_text(self.BOOT[0] + "\n")
        inode = self.boot.stat().st_ino
        run = self.run_script()
        self.assertEqual((run.returncode, run.stdout), (0, ""))
        self.assertEqual(self.boot.stat().st_ino, inode)          # not rewritten
        self.assertEqual(self.boot.read_text(), self.BOOT[0] + "\n")


class TestLoadDataUnscheduledRemoteRole(InstancesDeployedGame):
    """db's data file also creates shop_reports, a login role no schedule
    and no crontab_roles names (as the shop domain's back office); a second
    foreign server on reporting maps bi_etl to it (as f9 plants)."""

    def prepare(self):
        path = self.scenario / "data" / "db.sql"
        path.write_text(path.read_text().replace(
            "CREATE ROLE shop_etl LOGIN;\n",
            "CREATE ROLE shop_etl LOGIN;\nCREATE ROLE shop_reports LOGIN;\n"))

    def setUp(self):
        super().setUp()
        self.fake.databases["reporting"][1]["mappings"].append(
            dict(server="shop_crm_db", local_role="bi_etl", remote_role="shop_reports",
                 password=False, public=False))
        self.fake.databases["reporting"][1]["servers"] = 2

    def test_its_password_is_set_on_the_node_whose_data_creates_it(self):
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.password_plan(sc, self.impl)[0],
                         ("db", [("shop_etl", "role_shop_etl_password"),
                                 ("shop_reports", "role_shop_reports_password"),
                                 ("shop_app", "role_shop_app_password")]))
        result = self.load_data()
        self.assertEqual(result.passwords[0], ("db", ["shop_etl", "shop_reports", "shop_app"]))
        run = next(r for r in self.fake.runs if step(r) == "passwords")
        self.assertEqual(self.node_of(run), "db")
        line = run["stdin"].splitlines()[5]
        self.assertTrue(line.startswith('ALTER ROLE "shop_reports" PASSWORD '), line)
        self.assertTrue(matches(VERIFIER_RE.search(line), self.secret("shop_reports")))
        self.assertNotIn(self.secret("shop_reports"), run["stdin"])

    def test_the_mapping_resolves_to_its_secret(self):
        result = self.load_data()
        run = next(r for r in self.fake.runs if step(r) == "mappings")
        self.assertEqual(run["stdin"].splitlines()[-2:], [
            f'ALTER USER MAPPING FOR "bi_etl" SERVER "shop_db" OPTIONS (ADD password '
            f"'{self.secret('shop_etl')}');",
            f'ALTER USER MAPPING FOR "bi_etl" SERVER "shop_crm_db" OPTIONS (ADD password '
            f"'{self.secret('shop_reports')}');"])
        self.assertIn("  reporting/reporting: user mapping for bi_etl on server shop_crm_db "
                      "given remote role shop_reports's password", result.text())
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "data-loaded")

    def test_its_secret_is_the_games_and_mounted_nowhere(self):
        self.assertIn("role_shop_reports_password",
                      {sec["secret"] for sec in self.impl["secrets"]})
        self.assertTrue((self.ldir / "secrets" / "role_shop_reports_password").is_file())
        self.assertNotIn("role_shop_reports_password", (self.ldir / "stack.yml").read_text())


class TestPasswordPlanThroughAnotherNode(InstancesDeployedGame):
    """Two database nodes (db creating shop, reporting creating reporting):
    a schedule's connection through a node that is no database node (a
    pooler) sets its role on the database nodes whose data file creates the
    target database, else on every database node. Its role, shop_web, is
    one no data file of the fixture creates."""

    def plan(self, target):
        conns = {"web": {"role": "shop_web", "target": target}}
        sc = model.load_scenario(self.scenario)
        first = sc.nodes[0]["name"]
        with mock.patch.object(localimpl, "node_connections",
                               lambda s, node: conns if node["name"] == first else {}):
            return {db: [r for r, _ in roles] for db, roles in inject.password_plan(sc, self.impl)}

    def test_on_the_node_whose_data_creates_the_database(self):
        self.assertEqual(self.plan("bastion:6432/shop"),
                         {"db": ["shop_web", "shop_etl", "shop_app"],
                          "reporting": ["bi_etl", "bi_reader"]})
        self.assertEqual(self.plan("bastion:6432/reporting")["db"], ["shop_etl", "shop_app"])
        self.assertEqual(self.plan("bastion:6432/reporting")["reporting"],
                         ["shop_web", "bi_etl", "bi_reader"])

    def test_on_every_database_node_when_no_data_file_creates_it(self):
        plan = self.plan("bastion:6432/elsewhere")
        self.assertEqual((plan["db"][0], plan["reporting"][0]), ("shop_web", "shop_web"))

    def test_a_database_node_target_is_that_node_alone(self):
        self.assertEqual(self.plan("reporting:5432/shop")["db"], ["shop_etl", "shop_app"])
        self.assertEqual(self.plan("reporting:5432/shop")["reporting"][0], "shop_web")


class TestDataLoginRoles(unittest.TestCase):
    """The login roles a data file creates (model.data_file_creates)."""

    def test_login_roles_in_file_order(self):
        text = "\n".join([
            "CREATE ROLE owner_role NOLOGIN;",
            "CREATE ROLE app LOGIN;          -- the application",
            "create user reports;",
            "CREATE USER nobody NOLOGIN;",
            "CREATE ROLE etl",
            "  WITH LOGIN;",
            "CREATE ROLE fixed LOGIN PASSWORD 'Pages-and-Co-2019';",
            "CREATE USER fixed_user",
            "  ENCRYPTED PASSWORD 'x';",
            "CREATE ROLE unset LOGIN PASSWORD NULL;",
            "CREATE ROLE quoted PASSWORD 'login';",
            "CREATE ROLE commented; -- LOGIN",
            "-- CREATE ROLE ghost LOGIN;",
            "CREATE ROLE dba LOGIN;",
            "CREATE ROLE pg_custom LOGIN;",
            "CREATE ROLE app LOGIN;",
            "CREATE DATABASE app OWNER owner_role;"])
        created = model.data_file_creates(text, "data/db.sql")
        self.assertEqual(created.logins, ["app", "reports", "etl", "unset", "dba", "pg_custom"])
        self.assertEqual(created.roles, {"owner_role", "app", "reports", "nobody", "etl",
                                         "fixed", "fixed_user", "unset", "quoted", "commented",
                                         "dba", "pg_custom"})

    def test_the_games_own_roles_get_no_secret(self):
        scenario = mock.Mock(dir=Path("/nowhere"))
        node = {"name": "db", "data": {"file": "data/db.sql"}}
        created = model.data_file_creates("CREATE ROLE dba LOGIN;\nCREATE ROLE pg_x LOGIN;\n"
                                          "CREATE ROLE app LOGIN;\n", "data/db.sql")
        with mock.patch.object(localimpl, "node_data_file_creates", lambda sdir, n: created):
            self.assertEqual(localimpl.data_login_roles(scenario, node), ["app"])


class TestLoadDataShift(V03DeployedGame):

    def test_the_zone_and_offset_are_renders_shift(self):
        shift = self.impl["timeline"]["shift"]
        self.load_data()
        data = self.fake.runs[0]
        self.assertEqual(data["argv"][5:9], ["-v", f"customer_timezone={render.zone_name(shift)}",
                                             "-v", f"customer_utc_offset={shift}"])


class TestLoadDataSql(unittest.TestCase):

    def test_psql_variables(self):
        self.assertEqual(inject.psql_variables({}),
                         {"customer_timezone": "Etc/GMT", "customer_utc_offset": "0"})
        self.assertEqual(inject.psql_variables({"timeline": {"shift": 2}}),
                         {"customer_timezone": "Etc/GMT-2", "customer_utc_offset": "2"})
        self.assertEqual(inject.psql_variables({"timeline": {"shift": -5}}),
                         {"customer_timezone": "Etc/GMT+5", "customer_utc_offset": "-5"})
        self.assertEqual(inject.psql_variables({"timeline": {"planned_handover": "x"}}),
                         {"customer_timezone": "Etc/GMT", "customer_utc_offset": "0"})

    def test_connect_line_quotes_any_name(self):
        self.assertEqual(inject.connect_line("shop"),
                         "\\connect -reuse-previous=on 'dbname=''shop'''")
        self.assertEqual(inject.connect_line("we'ird=db\\x"),
                         "\\connect -reuse-previous=on 'dbname=''we\\\\''ird=db\\\\\\\\x'''")

    def test_the_read_policy(self):
        self.assertEqual(inject.policy_sql().splitlines(), [
            "DROP POLICY IF EXISTS gm_check_read ON cron.job;",
            "CREATE POLICY gm_check_read ON cron.job AS PERMISSIVE FOR SELECT TO gm_check "
            "USING (true);",
            "DROP POLICY IF EXISTS gm_check_read ON cron.job_run_details;",
            "CREATE POLICY gm_check_read ON cron.job_run_details AS PERMISSIVE FOR SELECT "
            "TO gm_check USING (true);"])

    def test_the_mapping_roles_function(self):
        sql = inject.function_sql()
        for part in ("CREATE SCHEMA IF NOT EXISTS gm_check AUTHORIZATION postgres;",
                     "REVOKE ALL ON SCHEMA gm_check FROM PUBLIC;",
                     "GRANT USAGE ON SCHEMA gm_check TO gm_check;",
                     "CREATE OR REPLACE FUNCTION gm_check.user_mapping_roles()",
                     "RETURNS TABLE (server_name name, local_role name, remote_role text)",
                     "LANGUAGE sql STABLE SECURITY DEFINER",
                     "SET search_path = pg_catalog, pg_temp",
                     "WHERE o.option_name = 'user'",
                     "ALTER FUNCTION gm_check.user_mapping_roles() OWNER TO postgres;",
                     "REVOKE ALL ON FUNCTION gm_check.user_mapping_roles() FROM PUBLIC;",
                     "GRANT EXECUTE ON FUNCTION gm_check.user_mapping_roles() TO gm_check;"):
            self.assertIn(part, sql)
        self.assertNotIn("password", sql)


# --- v0.5 chunk 3a: an api node's connection roles, HTTP connections ----------

class TestApiNodesConnectionRoles(unittest.TestCase):
    """Spec D345, capture W1 items 3 and 5 (specs/versions/v0.5/wave-log.md):
    an `api` node's api.yaml connections name roles as a scheduler node's
    schedule.yaml does, each given its secret role_<role>_password (mounted
    on the node naming it, its password set by load-data on the database
    node its connection targets); a `driver: http` connection, in either
    file, names none."""

    API_YAML = {
        "endpoints": {"orders": {"hosts": ["lab-api"], "credentials": ["interfaces_lab_api"]}},
        "connections": {
            "lab": {"driver": "sql/postgresql", "target": "lab:5432/lab", "role": "lab_api",
                    "pool": {"size": 4}},
            "records": {"driver": "sql/postgresql", "target": "records:5432/portal",
                        "role": "portal_api", "pool": {"size": 2}},
            "xlab-results": {"driver": "http", "target": "lab-api:8000",
                             "credential": "xlab_results", "pool": 1},
        },
    }
    SCHEDULE_YAML = {
        "connections": {
            "clinic": {"driver": "sql/postgresql", "target": "records:5432/clinic",
                       "role": "pms_app", "pool": {"size": 2}},
            "lab-api": {"driver": "http", "target": "lab-api:8000",
                        "credential": "interfaces_lab_api", "pool": 2},
            "careless": {"driver": "http", "target": "lab-api:8000", "role": "not_a_role",
                         "pool": 1},
        },
        "streams": [],
    }

    def setUp(self):
        import types
        import yaml
        self.dir = Path(tempfile.mkdtemp(prefix="gmtest-api-roles."))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        (self.dir / "nodes/lab-api").mkdir(parents=True)
        (self.dir / "nodes/pms").mkdir(parents=True)
        (self.dir / "nodes/lab-api/api.yaml").write_text(yaml.safe_dump(self.API_YAML))
        (self.dir / "nodes/pms/schedule.yaml").write_text(yaml.safe_dump(self.SCHEDULE_YAML))
        def node(name, brick, role, **extra):
            return {"name": name, "brick": {"id": brick, "version": "0.1.0"}, "role": role,
                    **extra}
        self.nodes = [
            node("records", "postgres", "database"),
            node("lab", "postgres", "database"),
            node("pms", "scheduler", "producer",
                 seed_files={"schedule.yaml": "nodes/pms/schedule.yaml"}),
            node("lab-api", "api", "api", seed_files={"api.yaml": "nodes/lab-api/api.yaml"}),
        ]
        bricks = {n["name"]: types.SimpleNamespace(id=n["brick"]["id"], data={"secrets": []})
                  for n in self.nodes}
        self.scenario = types.SimpleNamespace(dir=self.dir, nodes=self.nodes, bricks=bricks,
                                              data={"nodes": self.nodes})
        self.impl = {"game_id": "g", "nodes": {n["name"]: {} for n in self.nodes}}

    def node(self, name):
        return next(n for n in self.nodes if n["name"] == name)

    def test_the_api_nodes_roles_from_its_api_yaml(self):
        self.assertTrue(localimpl.is_api_node(self.node("lab-api")))
        self.assertFalse(localimpl.is_api_node(self.node("pms")))
        self.assertEqual(localimpl.connection_roles(self.scenario, self.node("lab-api")),
                         ["lab_api", "portal_api"])
        self.assertEqual(list(localimpl.sql_connections(self.scenario, self.node("lab-api"))),
                         ["lab", "records"])

    def test_an_http_connection_names_no_role(self):
        self.assertEqual(localimpl.connection_roles(self.scenario, self.node("pms")), ["pms_app"])
        self.assertEqual(list(localimpl.sql_connections(self.scenario, self.node("pms"))),
                         ["clinic"])
        self.assertEqual(set(localimpl.node_connections(self.scenario, self.node("pms"))),
                         {"clinic", "lab-api", "careless"})

    def test_the_secrets_mounted_on_the_api_node(self):
        names = [s["name"] for s in
                 localimpl.node_secret_declarations(self.scenario, self.node("lab-api"))]
        self.assertEqual(names, ["role_lab_api_password", "role_portal_api_password"])
        sec = localimpl.node_secret_declarations(self.scenario, self.node("lab-api"))[0]
        self.assertEqual((sec["path"], sec["uid"], sec["gid"], sec["mode"], sec["kind"]),
                         ("/opt/gm/secrets/role_lab_api_password", 0, 0, "0400", "password"))
        names = [s["name"] for s in
                 localimpl.node_secret_declarations(self.scenario, self.node("pms"))]
        self.assertEqual(names, ["role_pms_app_password"])     # none for an HTTP connection

    def test_the_game_has_their_secrets_and_none_for_http(self):
        secrets = [s["secret"] for s in localimpl.game_secrets(self.scenario)[0]]
        self.assertEqual(secrets, ["role_pms_app_password", "role_lab_api_password",
                                   "role_portal_api_password"])
        self.assertFalse([s for s in secrets if "not_a_role" in s or "None" in s])

    def test_their_passwords_set_on_the_targeted_database_nodes(self):
        self.assertEqual(inject.password_plan(self.scenario, self.impl), [
            ("records", [("pms_app", "role_pms_app_password"),
                         ("portal_api", "role_portal_api_password")]),
            ("lab", [("lab_api", "role_lab_api_password")])])

    def test_a_scheduler_with_only_http_connections_sets_no_password(self):
        import yaml
        doc = dict(self.SCHEDULE_YAML)
        doc["connections"] = {k: v for k, v in doc["connections"].items()
                              if v["driver"] == "http"}
        (self.dir / "nodes/pms/schedule.yaml").write_text(yaml.safe_dump(doc))
        self.nodes.remove(self.node("lab-api"))
        self.assertEqual(inject.password_plan(self.scenario, self.impl), [])
        self.assertEqual(localimpl.connection_roles(self.scenario, self.node("pms")), [])


class TestPasswordsUnaudited(unittest.TestCase):
    """v0.5 G5: pgaudit's `role` class logs a statement's text into the log
    the players' group reads: a session writing a secret turns pgaudit off
    with statement logging."""

    def test_the_password_and_mapping_sessions(self):
        self.assertEqual(inject.NO_AUDIT_SQL, ("SET pgaudit.log = 'none';",))
        with tempfile.TemporaryDirectory() as tmp:
            sdir = Path(tmp) / "secrets"
            sdir.mkdir()
            (sdir / "role_app_password").write_text("s3cret-value")
            sql = inject.password_sql(Path(tmp), [("app", "role_app_password")])
            lines = sql.splitlines()
            self.assertEqual(lines[:4], list(inject.NO_LOG_SQL + inject.NO_AUDIT_SQL))
            self.assertNotIn("s3cret-value", sql)
            db = inject.Database("shop", False, 1, [
                inject.Mapping("srv", "bi", False, "app", False)])
            db.mappings[0].secret = "role_app_password"
            sql, _ = inject.mapping_sql(Path(tmp), [db])
            self.assertIn("SET pgaudit.log = 'none';", sql.splitlines()[:5])


# --- v0.5 chunk 3b: the standby (capture W1 item 6) ----------------------------

class TestStandbyPlans(unittest.TestCase):
    """A standby (`standby_of`) takes no load-data step but its clone: its
    roles are set on its primary; the clone is the last step, one per
    standby in topology order, its slot the standby's name, `-` as `_`."""

    def setUp(self):
        import types
        import yaml
        self.dir = Path(tempfile.mkdtemp(prefix="gmtest-standby."))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        (self.dir / "data").mkdir()
        (self.dir / "data/records.sql").write_text(
            "CREATE DATABASE clinic;\nCREATE ROLE vet_reports LOGIN;\n")
        (self.dir / "nodes/pms").mkdir(parents=True)
        (self.dir / "nodes/pms/schedule.yaml").write_text(yaml.safe_dump({"connections": {
            "clinic": {"driver": "sql/postgresql", "target": "records:5432/clinic",
                       "role": "pms_app", "pool": {"size": 1}},
            "reports": {"driver": "sql/postgresql", "target": "off-site:5432/clinic",
                        "role": "vet_reports", "pool": {"size": 1}}}}))
        def node(name, brick, role, **extra):
            return {"name": name, "brick": {"id": brick, "version": "0.5.0"}, "role": role,
                    **extra}
        self.nodes = [
            node("records", "postgres", "database", data={"file": "data/records.sql"}),
            node("off-site", "postgres", "database", standby_of="records",
                 crontab_roles=["vet_reports"]),
            node("pms", "scheduler", "producer",
                 seed_files={"schedule.yaml": "nodes/pms/schedule.yaml"}),
        ]
        bricks = {n["name"]: types.SimpleNamespace(id=n["brick"]["id"], data={"secrets": []})
                  for n in self.nodes}
        self.scenario = types.SimpleNamespace(dir=self.dir, nodes=self.nodes, bricks=bricks,
                                              data={"nodes": self.nodes})
        self.impl = {"game_id": "g", "nodes": {n["name"]: {} for n in self.nodes}}

    def test_helpers(self):
        self.assertEqual(localimpl.standby_of(self.nodes[1]), "records")
        self.assertIsNone(localimpl.standby_of(self.nodes[0]))
        self.assertEqual(localimpl.standby_slot("off-site"), "off_site")
        self.assertEqual(localimpl.standby_slot("standby"), "standby")

    def test_the_standby_takes_no_step_but_its_clone(self):
        self.nodes[1]["data"] = {"file": "data/records.sql"}     # even with a data entry
        sc, impl = self.scenario, self.impl
        self.assertEqual([n for n, _, _ in inject.data_plan(sc, impl)], ["records"])
        self.assertEqual(inject.survey_plan(sc, impl), ["records"])
        self.assertEqual(inject.standby_plan(sc, impl), [("off-site", "records", "off_site")])

    def test_its_roles_are_set_on_its_primary(self):
        self.assertEqual(inject.password_plan(self.scenario, self.impl), [
            ("records", [("pms_app", "role_pms_app_password"),
                         ("vet_reports", "role_vet_reports_password")])])

    def test_a_primary_that_is_itself_a_standby_is_refused(self):
        self.nodes[0]["standby_of"] = "off-site"
        with self.assertRaises(GmError) as cm:
            inject.standby_plan(self.scenario, self.impl)
        self.assertIn("is not a primary of the game", str(cm.exception))
        self.nodes[0].pop("standby_of")
        self.nodes[1]["standby_of"] = "nowhere"
        with self.assertRaises(GmError):
            inject.standby_plan(self.scenario, self.impl)


class TestCloneStep(unittest.TestCase):
    """clone_standby's three runs (exec_node stubbed): replicator on the
    primary (a SCRAM verifier, logging and pgaudit off, an inactive slot of
    the standby's name dropped), clone-standby as root on the standby, the
    bounded wait for the slot's sender streaming on the primary."""

    def setUp(self):
        self.ldir = Path(tempfile.mkdtemp(prefix="gmtest-clone."))
        self.addCleanup(shutil.rmtree, self.ldir, ignore_errors=True)
        (self.ldir / "secrets").mkdir()
        self.password = "R3pl1cat0r-secret-value"
        (self.ldir / "secrets" / "replication_password").write_text(self.password)
        self.runs = []
        self.replies = []

    def exec_node(self, ldir, node, user, stdin=None, timeout=None, docker=None, argv=None,
                  env=None):
        self.runs.append({"node": node, "user": user, "stdin": stdin, "argv": argv,
                          "timeout": timeout})
        code, out, err = self.replies.pop(0) if self.replies else (0, "", "")
        return execnode.ExecResult(node, user, f"{node}.ctr", code, out, err)

    def clone(self, timeout=None):
        result = inject.LoadResult("g")
        printed = []
        with mock.patch.object(inject, "exec_node", self.exec_node):
            inject.clone_standby(self.ldir, "off-site", "records", "off_site", None, result,
                                 timeout=timeout, out=printed.append)
        return result, printed

    def test_the_three_runs(self):
        self.replies = [(0, "", ""), (0, "clone-standby: standby of records in recovery\n", ""),
                        (0, '{"exists" : true, "active" : true, "state" : "streaming"}\n', "")]
        result, printed = self.clone()
        role, clone, wait = self.runs
        self.assertEqual((role["node"], role["user"], role["argv"]),
                         ("records", "postgres", inject.PSQL_ARGV))
        lines = role["stdin"].splitlines()
        self.assertEqual(lines[:4], list(inject.NO_LOG_SQL + inject.NO_AUDIT_SQL))
        self.assertIn("SET pg_stat_statements.track = 'none';", lines)
        self.assertTrue(any("CREATE ROLE replicator" in l for l in lines))
        alter = next(l for l in lines if l.startswith("ALTER ROLE replicator"))
        self.assertIn("LOGIN REPLICATION", alter)
        self.assertTrue(matches(VERIFIER_RE.search(alter), self.password))
        self.assertNotIn(self.password, role["stdin"])
        self.assertIn("slot_name = 'off_site' AND NOT active", role["stdin"])
        self.assertEqual((clone["node"], clone["user"], clone["argv"]),
                         ("off-site", "root", (inject.CLONE_STANDBY,)))
        self.assertEqual((wait["node"], wait["user"], wait["argv"]),
                         ("records", "postgres", inject.SURVEY_ARGV))
        self.assertIn(f"FOR i IN 1..{inject.STANDBY_WAIT * 2} LOOP", wait["stdin"])
        self.assertIn("s.slot_name = 'off_site' AND r.state = 'streaming'", wait["stdin"])
        self.assertEqual(result.standbys, [("off-site", "records", "off_site")])
        self.assertIn("  off-site: cloned from records, a standby streaming from slot off_site",
                      result.text())
        self.assertNotIn(self.password, "\n".join(printed))

    def test_the_wait_is_bounded_by_the_timeout(self):
        self.replies = [(0, "", ""), (0, "", ""),
                        (0, '{"exists" : true, "active" : true, "state" : "streaming"}\n', "")]
        self.clone(timeout=40)
        self.assertIn("FOR i IN 1..80 LOOP", self.runs[2]["stdin"])
        self.assertEqual(self.runs[2]["timeout"], 70)

    def test_a_failed_clone_fails_the_step(self):
        self.replies = [(0, "", ""), (1, "", "clone-standby: the primary records does not "
                                             "answer on 5432 after 120s\n")]
        with self.assertRaises(GmError) as cm:
            self.clone()
        self.assertIn("cloning the standby off-site from records: exit 1: clone-standby: the "
                      "primary records does not answer", str(cm.exception))
        self.assertEqual(len(self.runs), 2)

    def test_not_streaming_fails_the_step(self):
        self.replies = [(0, "", ""), (0, "", ""),
                        (0, '{"exists" : true, "active" : false, "state" : null}\n', "")]
        with self.assertRaises(GmError) as cm:
            self.clone(timeout=5)
        self.assertIn("slot off_site not streaming after 5 s (exists True, active False, "
                      "sender none)", str(cm.exception))

    def test_a_refused_role_fails_before_the_clone(self):
        self.replies = [(3, "", "psql:<stdin>:7: ERROR:  permission denied\n")]
        with self.assertRaises(GmError):
            self.clone()
        self.assertEqual(len(self.runs), 1)
