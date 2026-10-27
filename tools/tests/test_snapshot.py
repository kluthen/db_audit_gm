"""`gmctl snapshot` (tools/gm/snapshot.py): the hand-over snapshot, each
volume by its brick's method, its copies on their hosts, its refusals and
its record (v0.3 master spec 6.4, 12, 13; capture W1 item 6, W3 item 4;
spec D162, D172). Docker stubbed; the in-node stream into its copy is a
stand-in for `snapshot.pipe`."""

import datetime
import unittest
from unittest import mock

from tools.gm import aging, localimpl, model, snapshot, state
from tools.gm.model import GmError
from tools.tests import FIXTURE_SCENARIO, run_gmctl
from tools.tests.test_aging import AgingGame
from tools.tests.test_inject import DeployedGame

DB_VOLUMES = ["pgdata", "pgconf", "home", "gmstate", "pglog"]


class FakePipe:
    """Stands in for snapshot.pipe: records each stream, answers the
    in-node step with `status[fragment of its script]` (0 by default)
    and the helper with the bytes it stored."""

    def __init__(self):
        self.calls = []
        self.status = {}
        self.target_status = 0

    def __call__(self, source, source_args, script, target, target_args):
        self.calls.append({"source": source, "source_args": source_args, "script": script,
                           "target": target, "target_args": target_args})
        rc = next((v for k, v in self.status.items() if k in script), 0)
        return (rc, f"step said {rc}\n" if rc else "", self.target_status,
                "" if self.target_status else "4096\n",
                "no space left" if self.target_status else "")

    def scripts(self):
        return [c["script"] for c in self.calls]


class TestMethods(unittest.TestCase):
    """Each brick's declared method; `stop` when it declares none; /run never."""

    def setUp(self):
        self.scenario = model.load_scenario(FIXTURE_SCENARIO)

    def test_the_catalog_bricks(self):
        plan = snapshot.node_plan(self.scenario, "db")
        self.assertEqual([v for v, _, _ in plan], DB_VOLUMES)
        self.assertEqual(dict((v, m) for v, _, m in plan)["pgdata"], "pg_basebackup")
        self.assertEqual({m for v, _, m in plan if v != "pgdata"}, {"copy"})
        self.assertEqual(snapshot.node_plan(self.scenario, "bastion"),
                         [("home", "/home/player", "copy"),
                          ("hostkeys", "/var/lib/gm-sshd-keys", "copy")])
        self.assertEqual(snapshot.stopped_services(self.scenario, "db"), ["postgres"])

    def test_a_brick_declaring_nothing_is_stopped(self):
        del self.scenario.bricks["bastion"].data["snapshot"]
        self.assertEqual(snapshot.node_plan(self.scenario, "bastion"),
                         [("home", "/home/player", "stop"),
                          ("hostkeys", "/var/lib/gm-sshd-keys", "stop")])

    def test_the_scripts(self):
        self.assertEqual(snapshot.copy_script("/home/player"),
                         "exec tar --create --file=- --numeric-owner "
                         "--directory='/home/player' .\n")
        self.assertEqual(snapshot.DB_SCRIPT, "exec /usr/local/sbin/gm-snapshot-db\n")
        self.assertIn("/command/s6-svc -wD -T 60000 -d /run/service/grafana\n",
                      snapshot.stop_script(["grafana"]))
        start = snapshot.start_script(["a", "b"])
        self.assertLess(start.index("/run/service/b"), start.index("/run/service/a"))
        self.assertIn("-wu -T 60000 -u /run/service/a || rc=1", start)


class StaticGame(DeployedGame):
    """fixture-audit (no scheduler node) at `injected`, its sealed checks
    present; the stream into each copy a FakePipe."""

    def setUp(self):
        super().setUp()
        self.load_data()
        self.inject()
        self.pipe = FakePipe()
        patcher = mock.patch("tools.gm.snapshot.pipe", self.pipe)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.fake.runs.clear()

    def take(self, **kwargs):
        return snapshot.take(self.scenario, "laptop", docker=self.fake, **kwargs)

    def st(self):
        return localimpl.read_state(self.ldir)

    def copies(self):
        return sorted(n for n, labels in self.fake.objects["volume"].items()
                      if labels.get(snapshot.SNAPSHOT_LABEL) == self.gid)


class TestStaticSnapshot(StaticGame):

    def test_every_volume_copied_by_its_method_on_its_host(self):
        result = self.take()
        self.assertTrue(result.ok, result.text())
        record = self.st()["snapshot"]
        self.assertEqual(record["status"], "taken")
        self.assertEqual(record["game"], self.gid)
        names = [(v["node"], v["volume"]) for v in record["volumes"]]
        self.assertEqual(names, [("bastion", "home"), ("bastion", "hostkeys")]
                         + [("db", v) for v in DB_VOLUMES])
        self.assertEqual({v["copy"] for v in record["volumes"]}, set(self.copies()))
        self.assertIn(f"dbagm-snapshot_{self.gid}_db_pgdata", self.copies())
        for name in self.copies():          # never the game's own labels
            self.assertNotIn(localimpl.LABEL_GAME, self.fake.objects["volume"][name])
        self.assertEqual(record["volumes"][0]["bytes"], 4096)
        self.assertEqual(record["stops"], [])
        pg = next(c for c in self.pipe.calls if c["script"] == snapshot.DB_SCRIPT)
        self.assertEqual(pg["source_args"][:4], ["exec", "-i", "-u", "root"])
        self.assertEqual(pg["source_args"][-2:], ["sh", "-s"])
        target = pg["target_args"]
        for word in ("--rm", "-i", "--pull", "never", "--network", "none",
                     f"dbagm.snapshot={self.gid}", f"dbagm-snapshot_{self.gid}_db_pgdata:/snapshot",
                     self.impl["nodes"]["db"]["image"]):
            self.assertIn(word, target)
        self.assertNotIn(localimpl.LABEL_GAME, " ".join(target))
        self.assertIn("hand-over snapshot taken, 7 volumes", result.text())

    def test_a_copy_reading_a_changing_file_is_a_copy_a_failed_backup_is_not(self):
        self.pipe.status = {"pglog": 1}
        self.assertTrue(self.take().ok)
        self.pipe.status = {"gm-snapshot-db": 1}
        result = self.take()
        self.assertFalse(result.ok)
        record = self.st()["snapshot"]
        self.assertEqual(record["status"], "failed")
        self.assertIn("db pgdata: exit 1: step said 1", record["reason"])
        self.assertEqual(self.copies(), [])                 # its copies removed
        self.assertIn("removed, nothing torn down", result.text())
        self.assertEqual(self.st()["stage"], "injected")
        self.assertTrue(self.fake.objects["service"])       # nothing torn down
        self.assertIn("FAILED hand-over snapshot at ",
                      state.status_text(self.ldir, docker=self.fake).splitlines()[0])

    def test_a_copy_that_cannot_be_stored_fails(self):
        self.pipe.target_status = 1
        result = self.take()
        self.assertFalse(result.ok)
        self.assertIn("could not be stored in", self.st()["snapshot"]["reason"])

    def test_taking_it_again_replaces_the_copies(self):
        self.take()
        first = self.copies()
        result = self.take()
        self.assertTrue(result.ok)
        self.assertEqual(self.copies(), first)
        self.assertIn("The earlier snapshot's 7 copies removed.", result.text())

    def test_not_fitting_copies_nothing(self):
        impl = localimpl.read_implementation(self.ldir)
        impl["snapshot_fit"] = {"fits": False, "why": "host gm-host: disk short by 1G"}
        localimpl.write_implementation(self.ldir, impl)
        result = self.take()
        self.assertTrue(result.ok)
        self.assertEqual(self.st()["snapshot"]["status"], "not-fitting")
        self.assertEqual(self.st()["snapshot"]["why"], "host gm-host: disk short by 1G")
        self.assertEqual(self.pipe.calls, [])
        self.assertEqual(self.copies(), [])
        self.assertIn("does not fit (host gm-host: disk short by 1G)", result.text())
        self.assertIn("a restart has no history", state.status_text(self.ldir, docker=self.fake))

    def test_refused_before_injected_and_once_handed_over(self):
        localimpl.set_stage(self.ldir, "data-loaded")
        with self.assertRaisesRegex(GmError, "snapshot needs stage injected"):
            self.take()
        localimpl.set_stage(self.ldir, "handed-over")
        with self.assertRaisesRegex(GmError, "refused once the game is handed over, when it "
                                             "would capture the players' changes"):
            self.take()
        self.assertNotIn("snapshot", self.st())
        self.assertEqual(self.pipe.calls, [])

    def test_the_hand_over_needs_it(self):
        localimpl.update_state(self.ldir, lambda st: st.update(handover_checks=[
            {"at": localimpl.now_iso(), "passed": True, "failures": []}]))
        with self.assertRaisesRegex(GmError, "snapshot is neither taken"):
            state.set_gm_stage(self.ldir, "handed-over")
        self.take()
        self.assertTrue(state.set_gm_stage(self.ldir, "handed-over"))


class TestStop(StaticGame):
    """`stop` (D147, D162): the services but sshd stopped through s6, the
    stopped volumes copied, the services started again, always; the node's
    other volumes copied first."""

    def setUp(self):
        super().setUp()
        load = model.load_scenario

        def with_stop(*args, **kwargs):
            scenario = load(*args, **kwargs)
            scenario.bricks["db"].data["snapshot"]["pglog"] = "stop"
            return scenario
        patcher = mock.patch("tools.gm.snapshot.model.load_scenario", with_stop)
        patcher.start()
        self.addCleanup(patcher.stop)

    def node_steps(self):
        """The db node's steps in order: copies by volume, stop and start."""
        steps = []
        for call in self.pipe.calls:
            if f"_{'db'}" in " ".join(call["target_args"]):
                vol = next(a for a in call["target_args"] if a.endswith(":/snapshot"))
                steps.append(vol.split("_db_")[1].split(":")[0])
        return steps

    def test_stopped_copied_and_started_in_order(self):
        result = self.take()
        self.assertTrue(result.ok, result.text())
        stops = [r["stdin"] for r in self.fake.runs]
        self.assertEqual(len(stops), 2)
        self.assertIn("-d /run/service/postgres", stops[0])
        self.assertIn("-u /run/service/postgres", stops[1])
        self.assertEqual(self.node_steps(), ["pgdata", "pgconf", "home", "gmstate", "pglog"])
        record = self.st()["snapshot"]
        self.assertEqual(record["stops"][0]["node"], "db")
        self.assertEqual(record["stops"][0]["services"], ["postgres"])
        self.assertTrue(record["stops"][0]["started_at"])
        self.assertEqual(next(v for v in record["volumes"] if v["volume"] == "pglog")["method"],
                         "stop")
        self.assertIn("db: postgres stopped ", result.text())

    def test_started_again_when_the_stopped_copy_fails(self):
        self.pipe.status = {"/var/log/postgresql": 1}       # exit 1 is no copy under a stop
        result = self.take()
        self.assertFalse(result.ok)
        self.assertEqual(len(self.fake.runs), 2)
        self.assertIn("-u /run/service/postgres", self.fake.runs[1]["stdin"])
        self.assertEqual(self.st()["snapshot"]["status"], "failed")
        self.assertEqual(self.copies(), [])

    def test_a_failed_start_is_a_failure(self):
        self.replies["-u /run/service/postgres"] = (1, "", "s6-svc: fatal: timed out\n")
        result = self.take()
        self.assertFalse(result.ok)
        self.assertIn("starting postgres again: exit 1: s6-svc: fatal: timed out",
                      self.st()["snapshot"]["reason"])


class TestAgedSnapshot(AgingGame):
    """A game with scheduler nodes: `load-started` and the earliest hand-over
    reached (master spec 13; access model 7)."""

    def setUp(self):
        super().setUp()
        self.pipe = FakePipe()
        patcher = mock.patch("tools.gm.snapshot.pipe", self.pipe)
        patcher.start()
        self.addCleanup(patcher.stop)

    def take(self, now=None):
        return snapshot.take(self.scenario, "laptop", docker=self.fake, now=now)

    def test_refusals_then_taken(self):
        with self.assertRaisesRegex(GmError, "snapshot needs stage load-started"):
            self.take()
        self.start(test_aging_minimum="1h")
        t0 = aging.parse_instant(self.st()["load"]["t0"])
        with self.assertRaisesRegex(GmError, "waits for the planting of f2"):
            self.take(t0 + datetime.timedelta(days=3))
        self.inject_at("now")
        earliest = aging.parse_instant(self.st()["earliest_handover"]["at"])
        with self.assertRaisesRegex(GmError, r"the earliest hand-over is \S+, in .*refused "
                                             "before it"):
            self.take(earliest - datetime.timedelta(minutes=1))
        self.assertNotIn("snapshot", self.st())
        result = self.take(earliest)
        self.assertTrue(result.ok, result.text())
        self.assertEqual(self.st()["snapshot"]["at"], aging.iso(earliest))
        nodes = {v["node"] for v in self.st()["snapshot"]["volumes"]}
        self.assertIn("producer", nodes)


class TestCommandLine(StaticGame):

    def test_no_game_exits_1(self):
        proc = run_gmctl("snapshot", self.tmp / "nowhere", "--playground", "laptop")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("gmctl snapshot:", proc.stderr)

    def test_refused_through_the_verb(self):
        localimpl.set_stage(self.ldir, "handed-over")
        proc = run_gmctl("snapshot", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("snapshot refused: game ", proc.stderr)
        self.assertIn("nothing done", proc.stderr)


if __name__ == "__main__":
    unittest.main()
