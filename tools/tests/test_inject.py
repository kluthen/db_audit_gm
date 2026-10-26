"""gmctl load-data and inject (tools/gm/inject.py), the FAULT_* environment,
and exec_node's `argv`; Docker stubbed."""

import base64
import hashlib
import hmac
import re
import subprocess
import unittest
from pathlib import Path
from unittest import mock

from tools.gm import deploy, execnode, fit, inject, localimpl, model, render, state, teardown
from tools.gm.model import GmError
from tools.tests import SUFFICIENT, FakeDocker, run_gmctl
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
        rc, out, err = self.reply(run)
        return subprocess.CompletedProcess(args, rc, out, err)


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
        self.assertEqual(len(self.fake.runs), 2)        # the data, the check role's grant
        run = self.fake.runs[0]
        self.assertEqual(run["container"], f"{self.gid}_db.1.ctr")
        self.assertEqual(run["user"], "postgres")
        self.assertEqual(run["argv"], ["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1",
                                       "-d", "postgres"])
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
        self.assertEqual(len(self.fake.runs), 2)

    def test_needs_a_deployed_game(self):
        teardown.teardown(self.scenario, "laptop", docker=self.fake)
        with self.assertRaisesRegex(GmError, "load-data needs stage deployed"):
            self.load_data()
        self.assertEqual(self.fake.runs, [])

    def test_no_data_entry_loads_nothing(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "db").pop("data"))
        result = self.load_data()
        self.assertEqual([r["stdin"] for r in self.fake.runs], [inject.grant_sql()])
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
        self.assertEqual(len(self.fake.runs), 3)
        data, passwords, grant = self.fake.runs
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
    """A game with no scheduler node sets no password."""

    def test_no_password_step(self):
        result = self.load_data()
        self.assertEqual(len(self.fake.runs), 2)        # the data, the check role's grant
        self.assertEqual(result.passwords, [])
        self.assertNotIn("password", result.text())


# --- v0.3: the GM check role's CONNECT at load-data (spec D176) -------------

class TestLoadDataCheckRoleGrant(DeployedGame):

    def test_granted_after_the_load_on_every_database_but_the_templates(self):
        result = self.load_data()
        data, grant = self.fake.runs
        self.assertEqual(data["stdin"], (self.scenario / "data" / "db.sql").read_text())
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
                         [(self.scenario / "data" / "db.sql").read_text()])
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
