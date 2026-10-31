"""gmctl load-data and inject (tools/gm/inject.py), the FAULT_* environment,
and exec_node's `argv`; Docker stubbed."""

import base64
import hashlib
import hmac
import json
import re
import shutil
import subprocess
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
        return None


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
        # no scheduler node: no shift, the customer's zone is UTC (W1 item 0)
        self.assertEqual(run["argv"], ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
                                       "-v", "customer_timezone=Etc/GMT",
                                       "-v", "customer_utc_offset=0", "-d", "postgres"])
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
        self.assertEqual(lines[:3], ["SET log_statement = 'none';",
                                     "SET log_min_duration_statement = -1;",
                                     "SET log_min_error_statement = 'panic';"])
        sdir = self.ldir / "secrets"
        for line, role in zip(lines[3:], ("shop_app", "shop_reports")):
            self.assertTrue(line.startswith(f'ALTER ROLE "{role}" PASSWORD '), line)
            secret = (sdir / f"role_{role}_password").read_text()
            self.assertEqual(len(secret), deploy.DBA_PASSWORD_LENGTH)
            self.assertNotIn(secret, passwords["stdin"])       # only its verifier
            self.assertTrue(matches(VERIFIER_RE.search(line), secret), role)
        self.assertEqual(len(lines), 5)
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
            ("db", "grant"), ("reporting", "grant")])
        self.assertEqual(result.loaded, [("db", "data/db.sql"),
                                         ("reporting", "data/reporting.sql")])
        self.assertEqual(result.passwords, [("db", ["shop_etl"]),
                                            ("reporting", ["bi_etl", "bi_reader"])])
        self.assertEqual([(n, d, [m.local_text for m in ms]) for n, d, ms in result.mappings],
                         [("reporting", "reporting", ["bi_etl"])])
        self.assertEqual(result.policies, [("reporting", "reporting")])
        self.assertEqual(result.functions, [("reporting", "reporting")])
        self.assertEqual(result.grants, ["db", "reporting"])
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "data-loaded")
        text = result.text()
        for line in ("  db: password set from its secret for role(s) shop_etl",
                     "  reporting: password set from its secret for role(s) bi_etl, bi_reader",
                     "  reporting/reporting: user mapping for bi_etl on server shop_db given "
                     "remote role shop_etl's password",
                     "  reporting/reporting: gm_check may read every row of cron.job and "
                     "cron.job_run_details (policy gm_check_read)",
                     "  reporting/reporting: gm_check.user_mapping_roles() created for gm_check",
                     "  reporting: gm_check granted CONNECT on every database"):
            self.assertIn(line, text)

    def test_every_data_file_gets_the_zone_and_its_offset(self):
        self.load_data()
        data = [r for r in self.fake.runs if step(r) == "data"]
        self.assertEqual(len(data), 2)
        for run in data:
            self.assertEqual(run["argv"], ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
                                           "-v", "customer_timezone=Etc/GMT",
                                           "-v", "customer_utc_offset=0", "-d", "postgres"])

    def test_the_crontab_roles_password_is_set_on_its_node(self):
        sc = model.load_scenario(self.scenario)
        self.assertEqual(inject.password_plan(sc, self.impl)[0],
                         ("db", [("shop_etl", "role_shop_etl_password")]))
        self.load_data()
        run = next(r for r in self.fake.runs if step(r) == "passwords")
        self.assertEqual(self.node_of(run), "db")
        line = run["stdin"].splitlines()[3]
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
            "SET log_min_error_statement = 'panic';",
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
        self.assertEqual((result.mappings, result.policies, result.functions), ([], [], []))

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
                                 ("shop_reports", "role_shop_reports_password")]))
        result = self.load_data()
        self.assertEqual(result.passwords[0], ("db", ["shop_etl", "shop_reports"]))
        run = next(r for r in self.fake.runs if step(r) == "passwords")
        self.assertEqual(self.node_of(run), "db")
        line = run["stdin"].splitlines()[4]
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


class TestDataLoginRoles(unittest.TestCase):
    """The login roles a data file creates (model.data_file_creates)."""

    def test_login_roles_in_file_order(self):
        text = "\n".join([
            "CREATE ROLE owner_role NOLOGIN;",
            "CREATE ROLE app LOGIN;          -- the application",
            "create user reports;",
            "CREATE USER nobody NOLOGIN;",
            "CREATE ROLE etl",
            "  WITH LOGIN PASSWORD 'x';",
            "CREATE ROLE quoted PASSWORD 'login';",
            "CREATE ROLE commented; -- LOGIN",
            "-- CREATE ROLE ghost LOGIN;",
            "CREATE ROLE dba LOGIN;",
            "CREATE ROLE pg_custom LOGIN;",
            "CREATE ROLE app LOGIN;",
            "CREATE DATABASE app OWNER owner_role;"])
        created = model.data_file_creates(text, "data/db.sql")
        self.assertEqual(created.logins, ["app", "reports", "etl", "dba", "pg_custom"])
        self.assertEqual(created.roles, {"owner_role", "app", "reports", "nobody", "etl",
                                         "quoted", "commented", "dba", "pg_custom"})

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
