"""gmctl clean-restart (v0.6 master spec 9.4 step 6, 9.9 fixes 2, 4, 8;
capture W2 items 8, 10, 11, 13): the unit parts. The restart itself is
fixture-fill's short run (tools/tests/fixtures/fixture-fill/run-short-test.sh)."""

import datetime
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

from tools.gm import aging, cleanrestart, fill
from tools.gm.execnode import ExecResult
from tools.gm.model import REPO_ROOT, GmError
from tools.tests import FIXTURES


def ok(stdout="", code=0):
    return ExecResult("n", "root", "c", code, stdout, "")


class FakeNodes:
    def __init__(self, replies=None):
        self.runs, self.replies = [], list(replies or [])

    def run(self, node, user, stdin=None, argv=None, timeout=None, env=None):
        self.runs.append((node, user, stdin, argv))
        return self.replies.pop(0) if self.replies else ok()


# capture W2 item 13's form
COVER = {"node": "db", "what": "P0's cover: search_path of procedure rpt.close_day() in sales (spec D523)",
         "how": "ALTER PROCEDURE rpt.close_day() SET search_path = gm_vclock, pg_catalog, pg_temp",
         "left_off": False,
         "routine": {"database": "sales", "kind": "procedure", "signature": "rpt.close_day()",
                     "original": "pg_catalog, pg_temp"},
         "restore": {"user": "postgres", "database": "sales",
                     "sql": ["ALTER PROCEDURE rpt.close_day() SET search_path = pg_catalog, pg_temp;"]}}


def game(st, record=None, nodes=None):
    impl = {"game_id": "g1", "nodes": {"db": {"service": "g1_db", "brick": {"id": "postgres"}}}}
    scenario = SimpleNamespace(dir=str(FIXTURES / "fixture-fill"), nodes=[])
    run = cleanrestart.CleanRestart(scenario, "/nonexistent", impl, st, record or {}, nodes or FakeNodes(),
                                    docker=None, out=lambda *a: None)
    run.primaries = lambda: ["db"]
    return run


class TestWalRate(unittest.TestCase):

    def test_a_node_without_its_file_is_refused_naming_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(GmError, r"node db: nodes/db/wal-rate\.yaml missing"):
                cleanrestart.wal_rates(SimpleNamespace(dir=tmp), ["db"])
            Path(tmp, "nodes", "db").mkdir(parents=True)
            Path(tmp, "nodes", "db", "wal-rate.yaml").write_text("source: x\nbytes_per_hour: -1\n")
            with self.assertRaisesRegex(GmError, "positive whole number"):
                cleanrestart.wal_rates(SimpleNamespace(dir=tmp), ["db"])
            Path(tmp, "nodes", "db", "wal-rate.yaml").write_text("source: x\nsource: y\nbytes_per_hour: 1\n")
            with self.assertRaisesRegex(GmError, "cannot be read"):
                cleanrestart.wal_rates(SimpleNamespace(dir=tmp), ["db"])

    def test_the_shops_and_the_fixtures(self):
        for where in (REPO_ROOT / "scenarios" / "tarnbeck-outdoor-shop", FIXTURES / "fixture-fill"):
            self.assertEqual(cleanrestart.wal_rates(SimpleNamespace(dir=str(where)), ["db"]),
                             {"db": 43881262})

    def test_the_refusal_comes_before_anything_is_done(self):
        nodes = FakeNodes()
        run = game({"fill": {"outcome": "ok", "quiet": [dict(COVER)]}}, nodes=nodes)
        run.primaries = lambda: ["db", "reporting"]
        with mock.patch.object(run, "record_state") as recorded, \
                self.assertRaisesRegex(GmError, "node reporting: nodes/reporting/wal-rate.yaml missing"):
            run.run()
        self.assertEqual((nodes.runs, recorded.call_count), ([], 0))

    def test_the_padding_reaches_a_days_worth(self):
        sql = cleanrestart.pad_sql(24 * 43881262)
        self.assertIn("< 1053150288 LOOP", sql)
        self.assertIn("pg_logical_emit_message(false, 'gm_pad', chunk)", sql)
        self.assertEqual(sql.count("CHECKPOINT;\nSELECT pg_switch_wal()"), 2)

    def test_the_resets_end_in_one_session(self):
        # one stats_reset instant: postgres last, its statement and shared
        # resets in one psql session
        nodes = FakeNodes()
        run = game({}, nodes=nodes)
        with mock.patch("tools.gm.inject._databases", return_value=["postgres", "shop", "template1"]):
            run.reset()
        self.assertEqual([r[3][-1] for r in nodes.runs], ["shop", "template1", "postgres"])
        self.assertEqual([cleanrestart.SHARED_RESET_SQL in r[2] for r in nodes.runs], [False, False, True])
        self.assertTrue(all(cleanrestart.STATEMENTS_RESET_SQL in r[2] for r in nodes.runs))


class TestLeftovers(unittest.TestCase):

    def test_an_unrestored_cover_is_restored_in_its_database(self):
        held = {"node": "db", "what": fill.PG_CRON_WHAT, "left_off": True,
                "restore": {"user": "postgres", "sql": ["ALTER SYSTEM RESET cron.launch_active_jobs;"]}}
        done = dict(COVER, restored_at="2026-11-21T10:59:00Z")
        st = {"fill": {"outcome": "ok", "quiet": [held, dict(COVER), done]}}
        nodes = FakeNodes()
        run = game(st, nodes=nodes)
        with mock.patch("tools.gm.localimpl.update_state") as update, \
                mock.patch("tools.gm.inject.clock_plan", return_value=None):
            run.restore_leftovers()
        (node, user, stdin, argv), = nodes.runs
        self.assertEqual((node, user, argv), ("db", "postgres", fill.psql_argv("sales")))
        self.assertTrue(stdin.endswith(COVER["restore"]["sql"][0] + "\n"))
        self.assertTrue(st["fill"]["quiet"][1]["restored_at"])
        self.assertNotIn("restored_at", held)
        update.assert_called_once()

    def test_a_failed_restore_stops_it(self):
        st = {"fill": {"outcome": "ok", "quiet": [dict(COVER)]}}
        run = game(st, nodes=FakeNodes([ExecResult("db", "postgres", "c", 3, "", "psql:<stdin>:4: ERROR:  boom\n")]))
        with self.assertRaisesRegex(GmError, "not restored: exit 3: psql:<stdin>:4: ERROR:  boom"):
            run.restore_leftovers()
        self.assertNotIn("restored_at", st["fill"]["quiet"][0])

    def test_the_left_off_items_come_back_for_the_next_start_without_their_scripts(self):
        hold = {"items": [{"node": "db", "what": fill.CRON_WHAT, "left_off": True,
                           "restore": {"user": "root", "script": fill.CRON_ON}},
                          {"node": "db", "what": fill.PG_CRON_WHAT, "left_off": True,
                           "restore": {"user": "postgres",
                                       "sql": ["ALTER SYSTEM RESET cron.launch_active_jobs;"]}}]}
        nodes = FakeNodes()
        game({"hold": hold, "fill": {"quiet": []}}, nodes=nodes).restore_left_off()
        (node, user, stdin, argv), = nodes.runs
        self.assertEqual((user, argv), ("postgres", fill.psql_argv("postgres")))
        self.assertIn("ALTER SYSTEM RESET cron.launch_active_jobs;", stdin)
        self.assertNotIn("pg_reload_conf", stdin)


class TestFileTimes(unittest.TestCase):
    FILL = (1000.0, 1600.0)          # the fill's real ten minutes
    VIRTUAL = (0.0, 46800.0)         # 22:00 to 11:00, thirteen virtual hours

    def test_the_last_virtual_write(self):
        f = lambda t: cleanrestart.virtual_mtime(t, self.FILL, self.VIRTUAL)
        self.assertEqual(f(940.0), -60.0)           # the load, a minute before the fill
        self.assertEqual(f(1000.0), 0.0)
        self.assertEqual(f(1300.0), 23400.0)        # halfway
        self.assertEqual(f(1600.0), 46800.0)        # the clean-up's checkpoints: the anchor
        self.assertEqual(f(2000.0), 46800.0)

    def test_the_helpers_script(self):
        script, n = cleanrestart.touch_script("1300.5 base/5/16384\n\n1000 global/pg_control\n",
                                              self.FILL, self.VIRTUAL)
        self.assertEqual(n, 2)
        self.assertIn("touch -c -m -d @23439.000000 -- /gm-clean/base/5/16384", script)
        self.assertIn("touch -c -m -d @0.000000 -- /gm-clean/global/pg_control", script)


class TestRecord(unittest.TestCase):

    def test_explains_kept_where_they_hold(self):
        plain = cleanrestart.explains({"hold": {"items": []}, "fill": {"quiet": []}})
        self.assertEqual(len(plain), len(cleanrestart.EXPLAINS) - 2)
        self.assertEqual(set(plain[0]), {"observation", "where", "in_world"})
        full = cleanrestart.explains({"hold": {"items": [{"what": fill.ARCHIVING_WHAT}]},
                                      "fill": {"quiet": [COVER]}})
        self.assertEqual(len(full), len(cleanrestart.EXPLAINS))

    def test_refusals(self):
        fake = {"timeline": {"virtual_t0": "2026-11-20T22:00:00Z"}}
        self.assertIn("not a fake game", cleanrestart.refusal({}, {"timeline": {}}, None))
        self.assertIn("run gmctl fill first", cleanrestart.refusal({"fill": {"outcome": "failed"}}, fake, {"mode": "fake"}))
        self.assertIn("already done", cleanrestart.refusal({"clean_restart": {"outcome": "ok"}}, fake, {"mode": "fake"}))
        self.assertIsNone(cleanrestart.refusal({"fill": {"outcome": "ok"}}, fake, {"mode": "fake"}))
        # the planned anchor not yet come: refused; at it, run
        record = {"mode": "fake", "anchor": "2026-11-21T13:00:00Z"}
        anchor = aging.parse_instant(record["anchor"])
        early = cleanrestart.refusal({"fill": {"outcome": "ok"}}, fake, record,
                                     anchor - datetime.timedelta(seconds=1))
        self.assertIn("the anchor 2026-11-21T13:00:00Z has not come", early)
        self.assertIsNone(cleanrestart.refusal({"fill": {"outcome": "ok"}}, fake, record, anchor))


if __name__ == "__main__":
    unittest.main()
