"""`gmctl restart` (tools/gm/restart.py): the whole-game restart, from the
hand-over snapshot or with no history, its refusals, its record, the
secrets' values kept under new objects, two restarts in a row, a failed
restart and its retry, teardown after it (v0.3 master spec 12, 13; access
model 3, 5, 9; spec D163, D176, D182). Docker stubbed; the snapshot's
in-node stream is a FakePipe."""

import datetime
import unittest
from unittest import mock

import yaml

from tools.gm import (aging, deploy, fit, inject, localimpl, render, restart, snapshot, state,
                      teardown)
from tools.gm.model import GmError
from tools.tests import FakeDocker, run_gmctl
from tools.tests.test_aging import AgingGame, FakeSystemd
from tools.tests.test_deploy import MANAGER_NETWORKS, VPS_NETWORKS
from tools.tests.test_inject import FRAGMENTS
from tools.tests.test_render import MANAGER, WORKER, TwoHostScenario
from tools.tests.test_snapshot import FakePipe, StaticGame

WORDS = "Yes, restart the game, we accept losing our changes"


def secret_values(ldir):
    sdir = localimpl.secrets_dir(ldir)
    return {p.name: p.read_bytes() for p in sorted(sdir.iterdir())}


class RestartMixin:
    """Helpers over a game's local implementation and its fake Docker."""

    def st(self):
        return localimpl.read_state(self.ldir)

    def impl_now(self):
        return localimpl.read_implementation(self.ldir)

    def restart(self, words=WORDS, fake=None, **kwargs):
        kwargs.setdefault("timeout", 30)
        return restart.restart(self.scenario, self.playground, words, docker=fake or self.fake,
                               systemd=self.systemd, out=self.printed.append,
                               sleep=self.tick, clock=lambda: self.clock[0], **kwargs)

    def tick(self, seconds):
        self.clock[0] += seconds

    def objects_of(self, kind, gid, fake=None):
        fake = fake or self.fake
        return sorted(n for n in fake.objects[kind] if n.startswith(f"{gid}_"))

    def snapshot_copies(self, fake=None):
        fake = fake or self.fake
        return sorted(n for f in fake.every_host() for n, labels in f.objects["volume"].items()
                      if labels.get(snapshot.SNAPSHOT_LABEL))


class HandedOverStatic(RestartMixin, StaticGame):
    """fixture-audit (no scheduler node) handed over, its snapshot taken
    (or, with `fits=False`, recorded as not fitting)."""

    fits = True
    playground = "laptop"

    def setUp(self):
        super().setUp()
        self.systemd = FakeSystemd(self.tmp)
        if not self.fits:
            impl = localimpl.read_implementation(self.ldir)
            impl["snapshot_fit"] = {"fits": False, "why": "host gm-host: disk short by 1G"}
            localimpl.write_implementation(self.ldir, impl)
        localimpl.update_state(self.ldir, lambda st: st.update(handover_checks=[
            {"at": localimpl.now_iso(), "passed": True, "failures": []}]))
        self.assertTrue(self.take().ok)
        self.assertTrue(state.set_gm_stage(self.ldir, "handed-over"))
        self.first_handover = aging.handover_instant(self.st())
        self.values = secret_values(self.ldir)
        self.fake.runs.clear()
        self.fake.calls.clear()


class TestRefusals(HandedOverStatic):

    def assert_untouched(self, before):
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)
        self.assertFalse(self.fake.called("service", "rm"))
        self.assertTrue(self.objects_of("service", self.gid))

    def test_refused_without_a_confirmation_or_with_a_blank_one(self):
        before = (self.ldir / "state.yaml").read_bytes()
        for words in (None, "", "   \n "):
            with self.assertRaisesRegex(GmError, r"restart refused: no confirmation.*"
                                                 r"--confirmation \"<the player's words>\"; "
                                                 "nothing done"):
                self.restart(words)
        self.assert_untouched(before)

    def test_refused_before_hand_over_and_once_torn_down(self):
        localimpl.set_stage(self.ldir, "injected")
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, "at stage injected: a restart rebuilds a "
                                             "handed-over game.*nothing done"):
            self.restart()
        self.assert_untouched(before)
        localimpl.set_stage(self.ldir, "torn-down")
        with self.assertRaisesRegex(GmError, "is torn down: there is nothing to restart"):
            self.restart()

    def test_allowed_at_final_answer_and_feedback_given(self):
        localimpl.set_stage(self.ldir, "final-answer")
        self.assertIsNone(restart.refusal(self.st()))
        localimpl.set_stage(self.ldir, "feedback-given")
        self.assertIsNone(restart.refusal(self.st()))
        localimpl.set_failed(self.ldir, "deployed", "boom")       # not a restart's failure
        self.assertIn("at stage failed", restart.refusal(self.st()))

    def test_refused_with_a_copy_missing(self):
        copy = self.st()["snapshot"]["volumes"][0]["copy"]
        del self.fake.objects["volume"][copy]
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, f"copies are missing: {copy}"):
            self.restart()
        self.assert_untouched(before)

    def test_refused_with_a_secret_file_missing(self):
        (localimpl.secrets_dir(self.ldir) / "dba_password").unlink()
        with self.assertRaisesRegex(GmError, "secrets/dba_password are missing: a restart keeps "
                                             "every secret's value"):
            self.restart()
        self.assertFalse(self.fake.called("service", "rm"))

    def test_refused_with_an_image_missing(self):
        self.fake.missing.add(self.impl["nodes"]["db"]["image"])
        with self.assertRaisesRegex(GmError, "restart refused: image.*not present"):
            self.restart()
        self.assertNotIn("restarts", self.st())

    def test_refused_through_the_verb_without_the_option(self):
        proc = run_gmctl("restart", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("gmctl restart: restart refused: no confirmation", proc.stderr)
        self.assertNotIn("restarts", self.st())


class TestStaticFromSnapshot(HandedOverStatic):

    def test_rebuilt_under_a_new_id_on_fresh_copies(self):
        old = self.gid
        copies = self.snapshot_copies()
        record = self.st()["snapshot"]
        result = self.restart()
        new = result.to_game
        self.assertNotEqual(new, old)
        st, impl = self.st(), self.impl_now()
        self.assertEqual((st["game_id"], impl["game_id"]), (new, new))
        self.assertEqual(st["stage"], "handed-over")
        self.assertEqual(impl["network"], f"{new}_backend")
        # every object of the old game removed, the new one's created
        for kind in ("service", "config", "secret", "network"):
            self.assertEqual(self.objects_of(kind, old), [], kind)
            self.assertTrue(self.objects_of(kind, new), kind)
        # the snapshot left as it was, for a second restart
        self.assertEqual(self.snapshot_copies(), copies)
        self.assertEqual(st["snapshot"], record)
        # each copied volume created fresh, labelled as Swarm would, and filled
        for vol in record["volumes"]:
            name = f"{new}_{vol['node']}_{vol['volume']}"
            self.assertEqual(self.fake.objects["volume"][name],
                             {localimpl.LABEL_NAMESPACE: new, localimpl.LABEL_GAME: new})
        self.assertEqual(len(self.fake.helpers), len(record["volumes"]))
        db = next(h for h in self.fake.helpers if f"{new}_db_pgdata:/volume" in h)
        self.assertEqual(db, restart.restore_args(impl, "db", "pgdata",
                                                  f"dbagm-snapshot_{old}_db_pgdata"))
        for word in ("--rm", "--pull", "never", "--network", "none", "--numeric-owner",
                     f"dbagm.game={new}", f"dbagm-snapshot_{old}_db_pgdata:/snapshot:ro",
                     impl["nodes"]["db"]["image"]):
            self.assertIn(word, db)
        # restored before the stack is deployed
        order = [c[:2] for c in self.fake.calls]
        self.assertLess(order.index(["volume", "create"]), order.index(["stack", "deploy"]))
        # nothing loaded or planted: the data and the faults are in the copies
        self.assertEqual(self.fake.runs, [])
        self.assertIn("restarted from the hand-over snapshot", result.text())

    def test_every_secret_value_kept_under_new_objects(self):
        result = self.restart()
        self.assertEqual(secret_values(self.ldir), self.values)
        created = {c[-2]: c[-1] for c in self.fake.called("secret", "create")}
        impl = self.impl_now()
        self.assertEqual(sorted(created), sorted(s["name"] for s in impl["secrets"]))
        for sec in impl["secrets"]:
            self.assertTrue(sec["name"].startswith(f"{result.to_game}_"))
            path = created[sec["name"]]
            self.assertEqual(localimpl.Path(path).read_bytes(),
                             self.values[localimpl.Path(sec["file"]).name], sec["name"])

    def test_the_record_and_the_stage(self):
        result = self.restart()
        st = self.st()
        entry = st["restarts"][-1]
        self.assertEqual({k: entry[k] for k in ("from_game", "to_game", "from_snapshot",
                                                 "confirmation", "status")},
                         {"from_game": self.gid, "to_game": result.to_game,
                          "from_snapshot": True, "confirmation": WORDS,
                          "status": "completed"})
        self.assertTrue(entry["at"] <= entry["finished_at"])
        self.assertEqual(st["history"][-1]["stage"], "handed-over")
        self.assertEqual(aging.handover_instant(st), self.first_handover)   # the four hours
        text = state.status_text(self.ldir, docker=self.fake)
        self.assertIn(f"restart 1: {entry['at']}, game {self.gid} -> {result.to_game}, from the "
                      f"snapshot, completed; confirmed: \"{WORDS}\"", text)

    def test_two_restarts_in_a_row(self):
        first = self.restart()
        second = self.restart("Restart it again please, yes")
        self.assertEqual(second.from_game, first.to_game)
        self.assertNotIn(second.to_game, (self.gid, first.to_game))
        st = self.st()
        self.assertEqual([e["status"] for e in st["restarts"]], ["completed", "completed"])
        self.assertEqual(self.objects_of("service", first.to_game), [])
        # the second restart restored from the same copies, the first game's
        self.assertEqual(len(self.fake.helpers), 2 * len(self.st()["snapshot"]["volumes"]))
        self.assertTrue(all(f"dbagm-snapshot_{self.gid}_" in " ".join(h)
                            for h in self.fake.helpers))
        self.assertEqual(st["snapshot"]["game"], self.gid)
        self.assertEqual(secret_values(self.ldir), self.values)
        self.assertEqual(aging.handover_instant(st), self.first_handover)

    def test_teardown_after_a_restart_removes_the_snapshot(self):
        self.restart()
        self.restart("again, yes")
        report = teardown.teardown(self.scenario, "laptop", docker=self.fake,
                                   systemd=self.systemd, sleep=self.tick,
                                   clock=lambda: self.clock[0])
        self.assertEqual(self.snapshot_copies(), [])
        self.assertEqual(teardown.leftovers(self.fake, self.st()["game_id"], [self.gid]), {})
        self.assertIn("nothing carrying its label is left", report.text())


class TestFailedRestart(HandedOverStatic):

    def test_a_failure_tears_down_what_it_deployed_and_a_retry_rebuilds(self):
        self.fake.fail[("run",)] = "tar: Unexpected EOF in archive"
        with self.assertRaises(state.SetupFailed) as caught:
            self.restart()
        self.assertIn("restoring bastion home", str(caught.exception))
        st = self.st()
        new = st["restarts"][-1]["to_game"]
        self.assertEqual(st["game_id"], new)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"]["stage"], "handed-over")
        self.assertEqual(st["restarts"][-1]["status"], "failed")
        self.assertIn("Unexpected EOF", st["restarts"][-1]["reason"])
        for gid in (self.gid, new):
            self.assertEqual(teardown.leftovers(self.fake, gid), {})
        self.assertTrue(self.snapshot_copies())                # the snapshot stays
        # the GM may run it again
        del self.fake.fail[("run",)]
        result = self.restart("try again, yes")
        st = self.st()
        self.assertEqual(st["stage"], "handed-over")
        self.assertIsNone(st["failure"])
        self.assertEqual([e["status"] for e in st["restarts"]], ["failed", "completed"])
        self.assertEqual(result.from_game, new)
        self.assertEqual(aging.handover_instant(st), self.first_handover)

    def test_after_a_failed_restart_teardown_then_fit_start_a_new_game(self):
        self.fake.fail[("stack", "deploy")] = "boom"
        with self.assertRaises(state.SetupFailed):
            self.restart()
        teardown.teardown(self.scenario, "laptop", docker=self.fake, systemd=self.systemd,
                          sleep=self.tick, clock=lambda: self.clock[0])
        self.assertEqual(self.snapshot_copies(), [])
        with self.assertRaisesRegex(GmError, "is torn down"):
            self.restart()
        self.assertIsNone(fit._game_to_keep(self.ldir, "fixture-audit"))


class TestStaticNoHistory(HandedOverStatic):
    """The snapshot did not fit: the data loaded with the check role's
    grants, every fault planted at once (D176; master spec 12)."""

    fits = False

    def test_loaded_and_planted_from_nothing(self):
        self.assertEqual(self.st()["snapshot"]["status"], "not-fitting")
        result = self.restart()
        self.assertFalse(result.from_snapshot)
        self.assertEqual(self.fake.helpers, [])
        names = [r["argv"] for r in self.fake.runs]
        self.assertIn(["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-d", "postgres"], names)
        scripts = [r["stdin"] for r in self.fake.runs]
        self.assertTrue(any(FRAGMENTS["10-drop-index"] in s for s in scripts))
        self.assertTrue(any("CONNECT" in s and "gm_check" in s for s in scripts))
        st = self.st()
        self.assertEqual(st["stage"], "handed-over")
        self.assertFalse(st["restarts"][-1]["from_snapshot"])
        self.assertEqual({p["by"] for p in st["plantings"].values()}, {"restart"})
        self.assertNotIn("previous_t0", st["restarts"][-1])
        self.assertIn("with no history", result.text())
        self.assertEqual(secret_values(self.ldir), self.values)


class HandedOverAged(RestartMixin, AgingGame):
    """fixture-v03-refusals (a scheduler node) handed over: its load
    started (override 1h), f2 planted, the snapshot taken (or not fitting)."""

    fits = True
    playground = "laptop"

    def setUp(self):
        super().setUp()
        self.pipe = FakePipe()
        patcher = mock.patch("tools.gm.snapshot.pipe", self.pipe)
        patcher.start()
        self.addCleanup(patcher.stop)
        if not self.fits:
            impl = localimpl.read_implementation(self.ldir)
            impl["snapshot_fit"] = {"fits": False, "why": "short"}
            localimpl.write_implementation(self.ldir, impl)
        self.start(test_aging_minimum="1h")
        self.inject_at("now")
        earliest = aging.parse_instant(self.st()["earliest_handover"]["at"])
        self.assertTrue(snapshot.take(self.scenario, "laptop", docker=self.fake,
                                      now=earliest).ok)
        localimpl.set_stage(self.ldir, "handed-over")
        self.first_handover = aging.handover_instant(self.st())
        self.old_impl = self.impl_now()
        self.old_units = self.systemd.files()
        self.replies["status did not read running"] = (0, f"running {localimpl.now_iso()}\n", "")
        self.fake.runs.clear()

    def schedule(self):
        return yaml.safe_load((self.ldir / "rendered" / "producer" / "schedule.yaml").read_text())


class TestAgedFromSnapshot(HandedOverAged):

    def test_the_schedulers_resume_with_a_new_seed_and_t0_kept(self):
        t0 = self.st()["load"]["t0"]
        result = self.restart()
        st, impl = self.st(), self.impl_now()
        old_tl, tl = self.old_impl["timeline"], impl["timeline"]
        for key in ("planned_handover", "shift", "customer_timezone", "instances"):
            self.assertEqual(tl[key], old_tl[key], key)
        self.assertNotEqual(tl["seed"], old_tl["seed"])
        self.assertEqual(self.schedule()["seed"], tl["seed"])
        self.assertEqual(st["load"]["t0"], t0)
        self.assertIn(aging.OVERRIDE_KEY, st)                # the harness's override kept
        resumed = [r for r in self.fake.runs if r["stdin"] == restart.RESUME_SCRIPT]
        self.assertEqual(len(resumed), 1)
        self.assertEqual(resumed[0]["container"], f"{result.to_game}_producer.1.ctr")
        self.assertFalse(any(aging.MARKER in r["stdin"] for r in self.fake.runs))
        # the old game's timers gone, none recorded for the new one
        self.assertTrue(self.old_units)
        self.assertEqual(self.systemd.files(), set())
        self.assertIsNone(st["early_check"]["timer"])
        self.assertEqual(st["stage"], "handed-over")
        self.assertEqual(aging.handover_instant(st), self.first_handover)
        self.assertIn("producer: resumed from its marker", result.text())

    def test_a_scheduler_that_does_not_resume_fails_the_restart(self):
        self.replies["status did not read running"] = (1, "status did not read running "
                                                          "within 60 s (last: idle)\n", "")
        with self.assertRaisesRegex(state.SetupFailed, "did not resume: producer: status did "
                                                       "not read running"):
            self.restart()
        self.assertEqual(self.st()["restarts"][-1]["status"], "failed")


class TestAgedNoHistory(HandedOverAged):

    fits = False

    def test_the_load_started_at_once_under_a_new_t0_every_fault_planted(self):
        # the game's T0 an hour back, so the new one differs within one second
        old_t0 = aging.iso(aging.parse_instant(self.st()["load"]["t0"])
                           - datetime.timedelta(hours=1))
        localimpl.update_state(self.ldir, lambda st: st["load"].update(t0=old_t0))
        result = self.restart()
        st = self.st()
        starts = [r for r in self.fake.runs if aging.MARKER in r["stdin"]]
        self.assertEqual(len(starts), 1)
        self.assertEqual(starts[0]["env"], {"GM_T0": result.t0})
        self.assertEqual(st["load"]["t0"], result.t0)
        self.assertNotEqual(result.t0, old_t0)
        self.assertEqual(st["restarts"][-1]["previous_t0"], old_t0)
        self.assertEqual(st["load"]["attempts"][-1]["by"], "restart")
        # f2, due during the aging, planted at once by the restart, before the load
        scripts = [r["stdin"] for r in self.fake.runs]
        planted = [i for i, s in enumerate(scripts) if FRAGMENTS["10-drop-index"] in s]
        self.assertTrue(planted)
        self.assertLess(planted[-1], scripts.index(starts[0]["stdin"]))
        f2 = st["plantings"]["f2"]
        self.assertEqual((f2["by"], f2["attempts"][-1]["outcome"]), ("restart", "ok"))
        self.assertEqual(aging.status_head(self.impl_now(), st, aging.now_utc())[1:], [])
        self.assertEqual(st["stage"], "handed-over")
        self.assertEqual(aging.handover_instant(st), self.first_handover)
        self.assertIn("load started at once", result.text())

    def test_status_reads_the_load_since_the_restarts_t0(self):
        result = self.restart()
        st, impl = self.st(), self.impl_now()
        later = aging.parse_instant(result.t0) + datetime.timedelta(minutes=25)
        lines = aging.status_aging(impl, st, later)
        self.assertIn(f"  aging: T0 {result.t0}, the load restarted with no history after the "
                      f"first hand-over at {aging.iso(self.first_handover)} (the four hours "
                      "count from it); running 25m since T0", lines)
        self.assertFalse(any("ran 0m" in line for line in lines), lines)
        self.assertEqual(aging.handover_instant(st), self.first_handover)


class TestTwoHostRestart(RestartMixin, TwoHostScenario):
    """A game on two hosts: its overlay's subnet kept across the restart,
    the outgoing game's network left out of the re-check while Swarm
    still holds it on the worker (D182); each copy restored on its host."""

    playground = "duo"

    def setUp(self):
        super().setUp()
        self.fit()
        render.render(self.scenario, "duo")
        self.clock = [0.0]
        self.printed = []
        self.systemd = FakeSystemd(self.tmp)
        self.pipe = FakePipe()
        patcher = mock.patch("tools.gm.snapshot.pipe", self.pipe)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.fake = FakeDocker.cluster(MANAGER, {WORKER: {"networks": VPS_NETWORKS}},
                                       networks=MANAGER_NETWORKS)
        deploy.deploy(self.scenario, "duo", docker=self.fake, timeout=30, sleep=self.tick,
                      clock=lambda: self.clock[0])
        inject.load_data(self.scenario, "duo", docker=self.fake, out=self.printed.append)
        inject.inject(self.scenario, "duo", docker=self.fake, out=self.printed.append)
        localimpl.update_state(self.ldir, lambda st: st.update(handover_checks=[
            {"at": localimpl.now_iso(), "passed": True, "failures": []}]))
        self.assertTrue(snapshot.take(self.scenario, "duo", docker=self.fake).ok)
        self.assertTrue(state.set_gm_stage(self.ldir, "handed-over"))
        self.old = self.impl_now()

    def test_the_subnet_kept_and_each_copy_restored_on_its_host(self):
        subnet = self.old[localimpl.OVERLAY]["subnet"]
        # Swarm still holds the outgoing overlay on the worker
        worker = self.fake.on_host(WORKER)
        worker.add("network", self.old["network"])
        worker.subnets[self.old["network"]] = [subnet]
        result = self.restart()
        impl = self.impl_now()
        self.assertEqual(impl[localimpl.OVERLAY], {"subnet": subnet})
        stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        self.assertEqual(stack["networks"]["backend"]["ipam"], {"config": [{"subnet": subnet}]})
        self.assertIn(f"overlay subnet: {subnet} (as recorded, still free, inside 10.20.0.0/16, "
                      "the default range)", result.text())
        db_vols = [v for v in self.st()["snapshot"]["volumes"] if v["node"] == "db"]
        self.assertEqual({v["host"] for v in db_vols}, {WORKER})
        self.assertEqual(len(worker.helpers), len(db_vols))
        for vol in db_vols:
            self.assertIn(f"{result.to_game}_db_{vol['volume']}", worker.objects["volume"])
        self.assertTrue(self.fake.helpers)                  # the bastion's, on the manager
        self.assertTrue(all("_bastion_" in " ".join(h) for h in self.fake.helpers))

    def test_another_network_on_the_subnet_refuses_before_anything(self):
        subnet = self.old[localimpl.OVERLAY]["subnet"]
        worker = self.fake.on_host(WORKER)
        worker.add("network", "late")
        worker.subnets["late"] = [subnet]
        with self.assertRaisesRegex(GmError, f"now overlaps network late"):
            self.restart()
        self.assertNotIn("restarts", self.st())
        self.assertFalse(self.fake.called("service", "rm"))


    # --- The overlay's range in force (capture W3-b, D183) ----------------

    def test_the_run_option_picks_again_outside_the_recorded_subnet(self):
        old = self.old[localimpl.OVERLAY]["subnet"]
        result = self.restart(overlay_range="10.40.0.0/16")
        self.assertEqual(self.impl_now()[localimpl.OVERLAY], {"subnet": "10.40.0.0/24"})
        stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        self.assertEqual(stack["networks"]["backend"]["ipam"],
                         {"config": [{"subnet": "10.40.0.0/24"}]})
        self.assertIn(f"  overlay subnet: 10.40.0.0/24 (picked from 10.40.0.0/16, given with "
                      f"--overlay-range; the recorded {old} lies outside it)\n", result.text())
        self.assertNotIn(localimpl.OVERLAY_RANGE, localimpl.read_playground(self.ldir))

    def test_the_playgrounds_range_is_the_one_in_force(self):
        pg = localimpl.read_playground(self.ldir)
        localimpl.write_playground(self.ldir, dict(pg, overlay_range="192.168.40.0/22"))
        result = self.restart()
        self.assertEqual(self.impl_now()[localimpl.OVERLAY], {"subnet": "192.168.40.0/24"})
        self.assertIn("(picked from 192.168.40.0/22, playground duo's overlay_range; the "
                      "recorded", result.text())

    def test_a_record_now_overlapping_is_refused_naming_the_restarts_way_out(self):
        subnet = self.old[localimpl.OVERLAY]["subnet"]
        worker = self.fake.on_host(WORKER)
        worker.add("network", "late")
        worker.subnets["late"] = [subnet]
        with self.assertRaises(GmError) as caught:
            self.restart()
        self.assertEqual(str(caught.exception),
                         f"the game's recorded overlay subnet {subnet}, inside 10.20.0.0/16 (the "
                         f"default range), now overlaps network late ({subnet}) on {WORKER}: "
                         "gmctl does not move a game's addresses on its own; remove that "
                         f"network, or choose another range, one that leaves {subnet} out: "
                         "gmctl restart --overlay-range <cidr> for this run, or gmctl fit "
                         "--overlay-range <cidr> for the playground's next games (fit refuses "
                         "while this one is deployed); nothing done")
        self.assertNotIn("restarts", self.st())
        # the way out it names
        result = self.restart(overlay_range="10.41.0.0/16")
        self.assertEqual(self.impl_now()[localimpl.OVERLAY], {"subnet": "10.41.0.0/24"})
        self.assertEqual(self.st()["restarts"][-1]["status"], restart.COMPLETED)
        self.assertIn("overlay subnet: 10.41.0.0/24", result.text())

    def test_a_bad_option_is_refused_before_anything(self):
        with self.assertRaisesRegex(GmError, r"--overlay-range '10\.0\.0\.0/6': wider than /8"):
            self.restart(overlay_range="10.0.0.0/6")
        self.assertNotIn("restarts", self.st())
        self.assertFalse(self.fake.called("service", "rm"))

    def test_the_cli_option(self):
        r = run_gmctl("restart", self.scenario, "--playground", "duo", "--confirmation", WORDS,
                      "--overlay-range", "fd00::/48")
        self.assertEqual(r.returncode, 1)
        self.assertIn("gmctl restart: --overlay-range 'fd00::/48': not IPv4", r.stderr)


class TestSubnetStep(unittest.TestCase):
    """deploy.game_subnet: the one place deploy and restart choose it."""

    def test_one_host_has_none(self):
        self.assertIsNone(deploy.game_subnet(FakeDocker(), {"nodes": {"a": {"host": "h"}}}))
        # whatever the range, not even read
        self.assertIsNone(deploy.game_subnet(FakeDocker(), {"nodes": {"a": {"host": "h"}}},
                                             {"overlay_range": "nonsense"}, "nonsense",
                                             verb="restart"))


if __name__ == "__main__":
    unittest.main()
