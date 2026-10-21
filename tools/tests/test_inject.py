"""gmctl load-data and inject (tools/gm/inject.py), the FAULT_* environment,
and exec_node's `argv`; Docker stubbed."""

import subprocess

from tools.gm import execnode, inject, localimpl, model, state, teardown
from tools.gm.model import GmError
from tools.tests import FakeDocker, run_gmctl
from tools.tests.test_deploy import RenderedGame

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
        self.assertEqual(len(self.fake.runs), 1)
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
        self.assertEqual(len(self.fake.runs), 1)

    def test_needs_a_deployed_game(self):
        teardown.teardown(self.scenario, "laptop", docker=self.fake)
        with self.assertRaisesRegex(GmError, "load-data needs stage deployed"):
            self.load_data()
        self.assertEqual(self.fake.runs, [])

    def test_no_data_entry_loads_nothing(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "db").pop("data"))
        result = self.load_data()
        self.assertEqual(self.fake.runs, [])
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
