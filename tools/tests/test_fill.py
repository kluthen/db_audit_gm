"""Unit tests of `gmctl fill` (tools/gm/fill.py; v0.6 build plan chunks 8b
and 15, capture W1 items 7, 8 and 9, W2 items 9, 10 and 13): the refusals,
the plan read from the game's files, the program's input, the settings
quieted and restored, the pauses' plantings, P0's cover, the hold, the
records and the outputs. The program and the nodes are
stand-ins (FakeNodes); the program itself is tested in its image
(bricks/scheduler/tests/unit/test_fill.py) and the whole on the fixture
(tools/tests/fixtures/fixture-fill/run-short-test.sh)."""

import datetime
import io
import json
import shutil
from types import SimpleNamespace
from unittest import mock

import yaml

from tools.gm import fill, fit, localimpl, model, render
from tools.gm.execnode import ExecResult
from tools.gm.inject import initial_plantings
from tools.gm.model import GmError, HistoryEntry
from tools.tests import FIXTURES, SUFFICIENT, ScenarioCopyTest

FIXTURE = FIXTURES / "fixture-fill"
PG = "laptop"
UTC = datetime.timezone.utc
PGBOUNCER_INI = (FIXTURE / "nodes" / "pooler" / "pgbouncer.ini").read_text()
PROGRAM_INPUT = "gm-scheduler-input 1\npassword shop_app s3cret\nschedule\nseed: 1\n"
SURVEY = {"auto": {}, "settings": {"pg_stat_statements.track": "top", "log_statement": "none",
                                   "log_min_duration_statement": "100", "log_temp_files": "0",
                                   "log_min_error_statement": "error",
                                   "autovacuum_naptime": "60", "archive_mode": "off",
                                   "archive_command": ""}, "roles": {}}


def ok(stdout="", code=0):
    return ExecResult("n", "root", "c", code, stdout, "")


class FakeProc:
    """The program: reads its JSON, pauses at each pause (waiting for GO),
    then DONE; `fail_at_start` answers FAILED at once."""

    def __init__(self, fake):
        self.fake = fake
        self.lines = []
        self.stdin = self
        self.stdout = self._out()
        self.killed = False

    def write(self, text):
        self.lines += [x for x in text.splitlines() if x]

    def flush(self):
        pass

    def close(self):
        pass

    def _out(self):
        self.fake.config = json.loads(self.lines[0]) if self.lines else None
        self.fake.events.append("spawned")
        if self.fake.fail_at_start:
            yield "FAILED node producer: no service time for x\n"
            return
        for at in self.fake.config["pauses"]:
            yield f"PAUSE {at}\n"
            if self.lines[-1] != "GO":
                yield f"FAILED stopped at the pause at {at}: {self.lines[-1]}\n"
                return
        yield "DONE " + json.dumps({"fill_s": 12.5, "pauses": self.fake.config["pauses"],
                                    "visits": {"sessions": 3120, "errors": 0},
                                    "nodes": {"producer": {"calls": 9, "errors": 0, "runs": 0,
                                                           "skips": 0, "lines": 4, "minutes": 2}}}) + "\n"

    def __iter__(self):
        return self.stdout

    def wait(self):
        return 0

    def kill(self):
        self.killed = True


CLOSE_DAY = "rpt.close_day()"


def cover_row(signature, setting, kind="procedure"):
    """A row of the program's COVER_SQL, as the stand-in's database lists it."""
    word = kind.upper()
    head = "gm_vclock, " if "pg_catalog" in setting.split(", ") else "gm_vclock, pg_catalog, "
    return {"kind": kind, "signature": signature, "setting": setting,
            "covered": setting.startswith("gm_vclock, "),
            "cover": f"ALTER {word} {signature} SET search_path = {head}{setting};",
            "restore": f"DO $gm_cover$ RESTORE {signature} TO {setting} $gm_cover$;"}


class FakeNodes:
    def __init__(self):
        self.runs = []
        self.events = []
        self.limits_set = []
        self.config = None
        self.fail_at_start = False
        self.inject_fails = False
        self.cron_up = True
        self.survey = json.loads(json.dumps(SURVEY))
        self.routines = {}              # {(node, database): {signature: [kind, setting]}}
        self.originals = {}             # {(node, database, signature): the setting before its cover}
        self.on_inject = None           # what a planting changes, a callable
        self.on_cover = None            # called at each cover's ALTER (the state then)
        self.restore_fails = False
        self.drop_fails = False

    def cover_sql(self, node, database, text):
        if text.endswith("COVER-SQL\n"):
            rows = [cover_row(sig, setting, kind) for sig, (kind, setting)
                    in sorted(self.routines.get((node, database), {}).items())]
            return ok("".join(json.dumps(r) + "\n" for r in rows))
        for sig, entry in self.routines.get((node, database), {}).items():
            if f" {sig} SET search_path = gm_vclock" in text:
                if self.on_cover:
                    self.on_cover(node, database, sig)
                self.originals[(node, database, sig)] = entry[1]
                entry[1] = text.split("SET search_path = ", 1)[1].split(";")[0]
                self.events.append(f"cover {node}/{database} {sig}")
                return ok()
            if f"RESTORE {sig} TO " in text:
                self.events.append(f"restore {node}/{database} {sig}")
                if self.restore_fails:
                    return ExecResult(node, "postgres", "c", 3, "", "ERROR:  could not restore\n")
                if entry[1].startswith("gm_vclock, "):
                    entry[1] = text.split(" TO ", 1)[1].split(" $gm_cover$")[0]
                return ok()
        return None

    def run(self, node, user, stdin=None, argv=None, timeout=None, env=None):
        text = stdin.decode() if isinstance(stdin, bytes) else (stdin or "")
        argv = tuple(argv or ())
        self.runs.append({"node": node, "user": user, "stdin": text, "argv": argv, "env": env})
        if text == fill.INPUT_SCRIPT:
            return ok(PROGRAM_INPUT)
        if argv[-2:] == ("fill-sql", "--cover"):
            return ok("COVER-SQL\n")
        if user == "postgres" and argv[:1] == ("psql",):
            done = self.cover_sql(node, argv[-1], text)
            if done is not None:
                return done
        if "DROP SCHEMA" in text and self.drop_fails:
            self.events.append(f"drop failed {node}/{argv[-1]}")
            return ExecResult(node, "postgres", "c", 3, "",
                              "ERROR:  gm_vclock not dropped: default value for column at of table t\n")
        if fill.SEQUENCES in text and text.startswith("cat "):
            return ok('{"delivery-events": 512}' if node == "producer" else "")
        if argv[:2] == ("cat", fill.PGBOUNCER_INI):
            return ok(PGBOUNCER_INI)
        if "pg_file_settings" in text:
            return ok("SET\n" + json.dumps(self.survey) + "\n")
        if text.startswith(fill.CRON_CHECK):
            return ok("true\n" if self.cron_up else "false\n")
        if argv[-2:] == ("fill-sql", "--drop"):
            return ok("DROP SCHEMA IF EXISTS gm_vclock CASCADE;\n")
        if argv[-1:] == ("fill-sql",):
            return ok("CREATE SCHEMA gm_vclock;\n")
        if "CREATE SCHEMA gm_vclock" in text:
            self.events.append(f"shim {node}/{argv[-1]}")
        if "DROP SCHEMA" in text:
            self.events.append(f"drop {node}/{argv[-1]}")
        if "ALTER ROLE" in text:
            self.events.append(f"roles {node}")
        if argv and argv[0] == "tar":
            return ExecResult(node, user, "c", 0, b"TAR", b"")
        if argv[:1] == ("cat",) and argv[1].endswith(".log"):
            return ok("2026-11-16T22:00:00Z state state=stopping\n")
        if argv[:1] == ("cat",) and argv[1].endswith(fill.METRICS_SUFFIX):
            return ok('{"at": "x"}\n')
        if argv[:1] == ("cat",) and argv[1].endswith("sequences.json"):
            return ok('{"delivery-events": 1024}' if "producer" in argv[1] else "", 0)
        if env and env.get("FAULT_TABLE_NAME"):
            self.events.append(f"inject {node}")
            if self.on_inject and not self.inject_fails:
                self.on_inject(self)
            return ok("planted", 1 if self.inject_fails else 0)
        return ok()

    def limits(self, node):
        return {"cpus": "0.25", "memory": "134217728", "memory-swap": "268435456"}

    def set_limits(self, node, limits):
        self.limits_set.append((node, dict(limits)))
        self.events.append(f"limits {limits['cpus']}")

    def spawn(self, node, argv):
        self.events.append(f"spawn {node}")
        self.spawn_argv = argv
        return FakeProc(self)

    def ran(self, pred):
        return [r for r in self.runs if pred(r)]


def next_hour(hours):
    now = datetime.datetime.now(UTC).replace(minute=0, second=0, microsecond=0)
    return now + datetime.timedelta(hours=hours + 1)


class FilledGame(ScenarioCopyTest):
    """fixture-fill fitted and rendered (the hand-over four hours ahead), at
    `injected` with inject's plantings, its restart record written as
    render --aging fake will (W1 item 7)."""

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-fill"
        shutil.copytree(FIXTURE, self.scenario)
        fit.fit(self.scenario, PG, **SUFFICIENT)
        self.handover = next_hour(4)
        render.render(self.scenario, PG, handover=self.handover.strftime("%Y-%m-%dT%H:%MZ"))
        self.ldir = self.scenario / "local" / PG
        self.impl = localimpl.read_implementation(self.ldir)
        sc = model.load_scenario(self.scenario)
        at = localimpl.now_iso()

        def injected(st):
            localimpl.enter_stage(st, "injected", at)
            st["plantings"] = initial_plantings(sc, self.impl, at)
        localimpl.update_state(self.ldir, injected)
        self.vt0 = self.handover - datetime.timedelta(hours=16)
        self.anchor = self.handover - datetime.timedelta(hours=3)
        self.f8_at = fill.iso(self.handover - datetime.timedelta(hours=6))
        self.write_record()
        (self.ldir / "secrets").mkdir(exist_ok=True)
        (self.ldir / "secrets" / "monitoring_password").write_text("m0n\n")
        self.nodes = FakeNodes()
        self.printed = []

    def write_record(self, **changes):
        rec = {"mode": "fake", "virtual_t0": fill.iso(self.vt0), "anchor": fill.iso(self.anchor),
               "tail": "3h", "handover_planned": fill.iso(self.handover), "refused": []}
        rec.update(changes)
        (self.ldir / localimpl.RESTART_RECORD_FILE).write_text(yaml.safe_dump(rec))

    def fill(self, **kwargs):
        return fill.fill(self.scenario, PG, nodes=self.nodes, out=self.printed.append, **kwargs)

    def st(self):
        return localimpl.read_state(self.ldir)

    def plan(self):
        sc = model.load_scenario(self.scenario)
        return fill.plan_fill(sc, self.impl, self.st(), PG,
                              localimpl.read_restart_record(self.ldir),
                              {"pooler": fill.parse_pgbouncer_ini(PGBOUNCER_INI)},
                              fill.now_utc())


class TestRecordReader(FilledGame):
    def test_reads_the_record_none_when_absent_refused_when_not_a_map(self):
        self.assertEqual(localimpl.read_restart_record(self.ldir)["mode"], "fake")
        (self.ldir / localimpl.RESTART_RECORD_FILE).unlink()
        self.assertIsNone(localimpl.read_restart_record(self.ldir))
        (self.ldir / localimpl.RESTART_RECORD_FILE).write_text("- a list\n")
        with self.assertRaisesRegex(GmError, "not a map"):
            localimpl.read_restart_record(self.ldir)


class TestRefusals(FilledGame):
    def refused(self, pattern):
        with self.assertRaisesRegex(GmError, pattern):
            self.fill()
        self.assertNotIn("fill", self.st())
        self.assertEqual(self.st()["stage"], "injected")
        self.assertFalse(self.nodes.ran(lambda r: "ALTER" in r["stdin"]))

    def test_no_record(self):
        (self.ldir / localimpl.RESTART_RECORD_FILE).unlink()
        self.refused("no restart record")

    def test_a_real_game(self):
        self.write_record(mode="real")
        self.refused("not fake: a real game has no fill")

    def test_the_anchor_passed(self):
        self.write_record(anchor=fill.iso(fill.now_utc() - datetime.timedelta(minutes=1)),
                          virtual_t0=fill.iso(fill.now_utc() - datetime.timedelta(hours=13)))
        self.refused("has passed")

    def test_another_stage(self):
        localimpl.set_stage(self.ldir, "load-started")
        with self.assertRaisesRegex(GmError, "needs stage injected"):
            self.fill()

    def test_a_key_without_a_service_time_names_the_key_and_the_file(self):
        path = self.scenario / "nodes" / "consumer" / "service-times.yaml"
        doc = yaml.safe_load(path.read_text())
        del doc["keys"]["reports.export"]
        path.write_text(yaml.safe_dump(doc))
        self.refused(r"node consumer: no service time for reports\.export in "
                     r"nodes/consumer/service-times\.yaml")

    def test_a_pgwatch_node(self):
        sc = model.load_scenario(self.scenario)
        with mock.patch.dict(sc.bricks, {"exporter": SimpleNamespace(id="pgwatch", data={})}):
            with self.assertRaisesRegex(GmError, "pgwatch node"):
                fill.plan_fill(sc, self.impl, self.st(), PG,
                               localimpl.read_restart_record(self.ldir),
                               {"pooler": fill.parse_pgbouncer_ini(PGBOUNCER_INI)},
                               fill.now_utc())

    def test_a_fill_runs_once_and_a_failed_one_is_never_resumed(self):
        localimpl.update_state(self.ldir, lambda st: st.update(
            fill={"started_at": "x", "ended_at": "y", "outcome": "ok"}))
        with self.assertRaisesRegex(GmError, "a fill runs once"):
            self.fill()
        localimpl.update_state(self.ldir, lambda st: st.update(
            fill={"started_at": "x", "ended_at": None, "outcome": None}))
        with self.assertRaisesRegex(GmError, "never finished.*never resumed"):
            self.fill()


class TestPlan(FilledGame):
    def test_the_plan(self):
        p = self.plan()
        self.assertEqual((p.vt0, p.anchor), (self.vt0, self.anchor))
        self.assertEqual(p.seed, self.impl["timeline"]["seed"])
        self.assertEqual((p.fill_node, p.nodes, p.pg_nodes), ("producer", ["producer", "consumer"],
                                                              ["db"]))
        self.assertEqual(p.pauses, {self.f8_at: ["f8"]})
        self.assertEqual(p.queue, [])
        self.assertEqual(p.overrides, {
            "producer": {"app": {"target": "db:5432",
                                 "pool": {"id": "pooler/shop/shop_app", "size": 3}}},
            "consumer": {}})
        self.assertEqual(p.sessions, {("db", "shop"): ["shop_app", "shop_reports"]})
        self.assertEqual(sorted(p.service_times["producer"]),
                         ["catalog.lookup", "deliveries.ingest", "orders.close-day",
                          "orders.detail", "orders.place", "orders.status"])
        self.assertEqual(p.service_times["consumer"]["reports.rollup"].keys(), {"median", "sigma"})
        (visit,) = p.visits
        self.assertEqual((visit["target"], visit["role"], visit["every"], visit["node"]),
                         ("db:5432/postgres", "monitoring", 15, "exporter"))
        self.assertEqual(visit["sql"][-1], fill.STAT_STATEMENTS_SQL)

    def test_a_planted_instance_is_no_pause(self):
        localimpl.update_state(self.ldir, lambda st: st["plantings"]["f8"].update(
            planted_at="2026-11-16T10:00:00Z"))
        self.assertEqual(self.plan().pauses, {})

    def test_queue_entries_from_the_instances_history(self):
        entries = {"f8": (HistoryEntry("queue", {"key": "orders.detail",
                                                 "service": {"median": 0.03, "sigma": 0.3}}, ()),
                          HistoryEntry("queue", {"key": "orders.place", "node": "producer",
                                                 "lock": {"median": 1, "sigma": 0.1,
                                                          "blocks": ["orders.place"]}},
                                       ("fixture-dropped-index",)),
                          HistoryEntry("counter_per_call", {"series": "x", "key": "y",
                                                            "per_call": 1}, ()))}
        with mock.patch.object(model, "instance_history", lambda sc, iid: entries.get(iid)):
            q = self.plan().queue
        self.assertEqual(q, [{"instance": "f8", "node": "producer", "key": "orders.detail",
                              "planted_at": self.f8_at,
                              "service": {"median": 0.03, "sigma": 0.3}}])

    def test_the_programs_input(self):
        p = self.plan()
        cfg = fill.program_input(p, {"producer": "IN-P", "consumer": "IN-C"}, "m0n")
        self.assertEqual(cfg["nodes"]["producer"]["repository"], fill.REPOSITORY)
        self.assertEqual(cfg["nodes"]["consumer"]["repository"],
                         f"{fill.WORK}/nodes/consumer/repository")
        self.assertEqual(cfg["nodes"]["consumer"]["jobs"], f"{fill.WORK}/nodes/consumer/jobs/jobs.yaml")
        self.assertEqual(cfg["nodes"]["producer"]["connections"]["app"]["target"], "db:5432")
        self.assertNotIn("connections", cfg["nodes"]["consumer"])
        self.assertEqual(cfg["nodes"]["consumer"]["input"], "IN-C")
        self.assertEqual(cfg["visits"][0]["password"], "m0n")
        self.assertNotIn("node", cfg["visits"][0])
        self.assertEqual((cfg["vt0"], cfg["pauses"]), (fill.iso(self.vt0), [self.f8_at]))


class TestSettings(FilledGame):
    def test_quieted_and_restored(self):
        survey = {"auto": {"autovacuum_naptime": "30s", "cron.launch_active_jobs": "on"},
                  "settings": dict(SURVEY["settings"], **{"pgaudit.log": "ddl",
                                                          "cron.launch_active_jobs": "on",
                                                          "archive_mode": "on",
                                                          "archive_command": "vault-post %p"}),
                  "roles": {"shop/shop_app": ["log_min_duration_statement=0", "work_mem=8MB"]}}
        sql, items = fill.settings_plan("db", survey, [("shop", "shop_app"), ("shop", "shop_reports")])
        self.assertIn('ALTER ROLE "shop_app" IN DATABASE "shop" SET pg_stat_statements.track = '
                      "'none';", sql)
        self.assertIn('ALTER ROLE "shop_reports" IN DATABASE "shop" SET pgaudit.log = \'none\';', sql)
        self.assertIn("ALTER SYSTEM SET autovacuum_naptime = '1s';", sql)
        self.assertIn("ALTER SYSTEM SET cron.launch_active_jobs = off;", sql)
        self.assertIn("ALTER SYSTEM SET archive_command = '/bin/true';", sql)
        self.assertTrue(sql.startswith(fill.UNSEEN_SQL))
        self.assertTrue(sql.rstrip().endswith("SELECT pg_catalog.pg_reload_conf();"))
        by = {i["what"].split(" (")[0]: i for i in items}
        stats = by["statement statistics, statement log and pgaudit for the fill's sessions"]
        self.assertFalse(stats["left_off"])
        self.assertIn('ALTER ROLE "shop_app" IN DATABASE "shop" SET log_min_duration_statement = '
                      "'0';", stats["restore"]["sql"])
        self.assertIn('ALTER ROLE "shop_reports" IN DATABASE "shop" RESET log_min_duration_statement;',
                      stats["restore"]["sql"])
        self.assertEqual(by["autovacuum_naptime"]["restore"]["sql"][0],
                         "ALTER SYSTEM SET autovacuum_naptime = '30s';")
        self.assertTrue(by["pg_cron's job runs"]["left_off"])
        self.assertEqual(by["pg_cron's job runs"]["restore"]["sql"],
                         ["ALTER SYSTEM SET cron.launch_active_jobs = 'on';"])
        self.assertEqual(by["archiving"]["restore"]["sql"], ["ALTER SYSTEM RESET archive_command;"])

    def test_no_pgaudit_no_pg_cron_no_archiving(self):
        sql, items = fill.settings_plan("db", SURVEY, [("shop", "shop_app")])
        sql = sql[len(fill.UNSEEN_SQL):]
        self.assertNotIn("pgaudit", sql)
        self.assertNotIn("cron.", sql)
        self.assertNotIn("archive", sql)
        self.assertEqual([i["left_off"] for i in items], [False, False])

    def test_the_quiet_settings_are_load_datas(self):
        self.assertEqual(dict(fill.QUIET_SETTINGS), {
            "log_statement": "none", "log_min_duration_statement": "-1",
            "log_min_error_statement": "panic", "log_temp_files": "-1", "pgaudit.log": "none",
            "pg_stat_statements.track": "none"})


class TestRun(FilledGame):
    def test_a_fill(self):
        result = self.fill()
        self.assertTrue(result.ok, result.text())
        st = self.st()
        self.assertEqual(st["stage"], "injected")
        rec = st["fill"]
        self.assertEqual(rec["outcome"], "ok")
        self.assertIsNone(rec["reason"])
        self.assertTrue(rec["started_at"] <= rec["ended_at"])
        whats = [(i["node"], i["what"], i["left_off"], bool(i.get("restored_at")))
                 for i in rec["quiet"]]
        self.assertEqual(whats, [
            ("db", "statement statistics, statement log and pgaudit for the fill's sessions (fix 3)",
             False, True),
            ("db", "autovacuum_naptime (fix 7)", False, True),
            ("db", "the cron daemon", True, False)])
        p = st["plantings"]["f8"]
        self.assertEqual(p["planted_at"], self.f8_at)
        (attempt,) = p["attempts"]
        self.assertEqual((attempt["by"], attempt["virtual_at"], attempt["outcome"]),
                         ("fill", self.f8_at, "ok"))
        # the order: quieted, the shim, the limits raised, the program, the planting, the shim
        # dropped, the quieting restored, the limits back
        ev = self.nodes.events
        self.assertLess(ev.index("roles db"), ev.index("shim db/shop"))
        self.assertLess(ev.index("shim db/shop"), ev.index("spawn producer"))
        self.assertLess(ev.index("limits 2"), ev.index("spawn producer"))
        self.assertLess(ev.index("spawn producer"), ev.index("inject db"))
        self.assertLess(ev.index("inject db"), ev.index("drop db/shop"))
        self.assertEqual(ev[-1], "limits 0.25")
        self.assertEqual(self.nodes.spawn_argv, (*fill.PROGRAM, "fill"))
        self.assertEqual(self.nodes.config["pauses"], [self.f8_at])
        # outputs: each node's lines appended, the metrics kept, the sequences installed
        appended = self.nodes.ran(lambda r: r["argv"] == ("sh", "-c", f"cat >> {fill.SCHEDLOG}"))
        self.assertEqual([r["node"] for r in appended], ["producer", "consumer"])
        self.assertTrue((self.ldir / "fill" / "producer.metrics.jsonl").is_file())
        self.assertTrue((self.ldir / "fill" / "consumer.metrics.jsonl").is_file())
        seq = self.nodes.ran(lambda r: r["argv"][:2] == ("sh", "-c")
                             and f"mv {fill.SEQUENCES}.gm-fill" in r["argv"][2])
        self.assertEqual([(r["node"], r["stdin"]) for r in seq],
                         [("producer", '{"delivery-events": 1024}')])
        self.assertTrue(self.nodes.ran(lambda r: r["stdin"] == '{"delivery-events": 512}'))
        self.assertTrue(self.nodes.ran(lambda r: r["node"] == "producer"
                                       and r["stdin"] == f"rm -rf {fill.WORK}\n"))
        self.assertIn(f"f8 planted at virtual {self.f8_at}", result.text())
        self.assertIn("left off for clean-restart", result.text())

    def test_a_failed_planting_fails_the_fill_recorded_and_undone(self):
        self.nodes.inject_fails = True
        with self.assertRaisesRegex(GmError, "the planting of f8 at virtual .* failed.*never "
                                             "resumed"):
            self.fill()
        st = self.st()
        self.assertEqual(st["fill"]["outcome"], "failed")
        self.assertIn("f8", st["fill"]["reason"])
        self.assertEqual(st["plantings"]["f8"]["attempts"][-1]["outcome"], "failed")
        self.assertIsNone(st["plantings"]["f8"]["planted_at"])
        self.assertIn("drop db/shop", self.nodes.events)
        restored = [i for i in st["fill"]["quiet"] if not i["left_off"]]
        self.assertTrue(all(i.get("restored_at") for i in restored))
        self.assertEqual(self.nodes.events[-1], "limits 0.25")
        with self.assertRaisesRegex(GmError, "never resumed"):
            self.fill()

    def test_the_program_failing(self):
        self.nodes.fail_at_start = True
        with self.assertRaisesRegex(GmError, "the program: node producer: no service time"):
            self.fill()
        self.assertEqual(self.st()["fill"]["outcome"], "failed")
        self.assertIn("drop db/shop", self.nodes.events)

    def test_no_cron_daemon_no_item(self):
        self.nodes.cron_up = False
        self.fill()
        self.assertEqual([i["what"] for i in self.st()["fill"]["quiet"]],
                         ["statement statistics, statement log and pgaudit for the fill's "
                          "sessions (fix 3)", "autovacuum_naptime (fix 7)"])


class TestCover(FilledGame):
    """P0's cover (master spec 9.4, spec D523; capture W2 item 13), the hold
    (W2 item 10) and the plantings' session means (spec D527, W2 item 9)."""

    def setUp(self):
        super().setUp()
        self.nodes.routines = {("db", "shop"): {CLOSE_DAY: ["procedure", "pg_catalog, pg_temp"]}}

    def items(self):
        return [i for i in self.st()["fill"]["quiet"] if "routine" in i]

    def test_listed_before_its_alter_and_restored_in_its_database(self):
        listed = []
        self.nodes.on_cover = lambda node, db, sig: listed.append(
            [i["routine"]["signature"] for i in self.items()] if "fill" in self.st() else [])
        result = self.fill()
        self.assertTrue(result.ok, result.text())
        self.assertEqual(listed, [[CLOSE_DAY]])
        (item,) = self.items()
        self.assertEqual(item["what"], f"P0's cover: search_path of procedure {CLOSE_DAY} in shop (spec D523)")
        self.assertEqual(item["how"], f"ALTER PROCEDURE {CLOSE_DAY} SET search_path = gm_vclock, pg_catalog, "
                                      "pg_temp")
        self.assertFalse(item["left_off"])
        self.assertEqual(item["routine"], {"database": "shop", "kind": "procedure", "signature": CLOSE_DAY,
                                           "original": "pg_catalog, pg_temp"})
        self.assertEqual(item["restore"], {"user": "postgres", "database": "shop",
                                           "sql": [cover_row(CLOSE_DAY, "pg_catalog, pg_temp")["restore"]]})
        self.assertTrue(item["restored_at"])
        # the query, the cover and the restore all ran as postgres in the routine's database, unseen
        sent = self.nodes.ran(lambda r: CLOSE_DAY in r["stdin"] or r["stdin"].endswith("COVER-SQL\n"))
        self.assertTrue(sent)
        for r in sent:
            self.assertEqual((r["node"], r["user"], r["argv"][-1]), ("db", "postgres", "shop"))
            self.assertTrue(r["stdin"].startswith(fill.UNSEEN_SQL))
        self.assertEqual(self.nodes.routines[("db", "shop")][CLOSE_DAY][1], "pg_catalog, pg_temp")
        # covered after the shim, before the program; restored before the shim is dropped
        ev = self.nodes.events
        self.assertLess(ev.index("shim db/shop"), ev.index(f"cover db/shop {CLOSE_DAY}"))
        self.assertLess(ev.index(f"cover db/shop {CLOSE_DAY}"), ev.index("spawn producer"))
        self.assertLess(ev.index(f"restore db/shop {CLOSE_DAY}"), ev.index("drop db/shop"))
        self.assertIn(f"P0's cover: search_path of procedure {CLOSE_DAY} in shop (spec D523): restored",
                      result.text())

    def test_a_database_without_a_pinned_routine_gives_no_item(self):
        self.nodes.routines = {}
        self.assertTrue(self.fill().ok)
        self.assertEqual(self.items(), [])
        self.assertTrue(self.nodes.ran(lambda r: r["stdin"].endswith("COVER-SQL\n")))

    def test_restored_when_the_program_fails(self):
        self.nodes.fail_at_start = True
        with self.assertRaisesRegex(GmError, "the program"):
            self.fill()
        self.assertEqual(self.st()["fill"]["outcome"], "failed")
        (item,) = self.items()
        self.assertTrue(item["restored_at"])
        self.assertEqual(self.nodes.routines[("db", "shop")][CLOSE_DAY][1], "pg_catalog, pg_temp")

    def test_restored_when_gmctl_fill_itself_fails(self):
        def boom(run):
            raise GmError("the metrics record cannot be read")
        with mock.patch.object(fill.FillRun, "collect", boom):
            with self.assertRaisesRegex(GmError, "the metrics record"):
                self.fill()
        self.assertEqual(self.st()["fill"]["outcome"], "failed")
        (item,) = self.items()
        self.assertTrue(item["restored_at"])
        self.assertEqual(self.nodes.routines[("db", "shop")][CLOSE_DAY][1], "pg_catalog, pg_temp")

    def test_a_routine_a_planting_replaces_or_adds_is_covered_again(self):
        def planting(nodes):
            routines = nodes.routines[("db", "shop")]
            routines[CLOSE_DAY] = ["procedure", "public, pg_temp"]            # CREATE OR REPLACE
            routines["rpt.reopen_day(date)"] = ["function", '"$user", public']  # a new one
        self.nodes.on_inject = planting
        self.assertTrue(self.fill().ok)
        by = {i["routine"]["signature"]: i for i in self.items()}
        self.assertEqual(sorted(by), [CLOSE_DAY, "rpt.reopen_day(date)"])
        self.assertEqual(by[CLOSE_DAY]["routine"]["original"], "public, pg_temp")
        self.assertEqual(by[CLOSE_DAY]["restore"]["sql"], [cover_row(CLOSE_DAY, "public, pg_temp")["restore"]])
        self.assertEqual(by[CLOSE_DAY]["how"], f"ALTER PROCEDURE {CLOSE_DAY} SET search_path = gm_vclock, "
                                               "pg_catalog, public, pg_temp")
        self.assertEqual(by["rpt.reopen_day(date)"]["routine"]["original"], '"$user", public')
        self.assertEqual(self.nodes.events.count(f"cover db/shop {CLOSE_DAY}"), 2)
        ev = self.nodes.events
        self.assertLess(ev.index("inject db"), len(ev) - 1 - ev[::-1].index(f"cover db/shop {CLOSE_DAY}"))
        routines = self.nodes.routines[("db", "shop")]
        self.assertEqual(routines[CLOSE_DAY][1], "public, pg_temp")
        self.assertEqual(routines["rpt.reopen_day(date)"][1], '"$user", public')
        self.assertTrue(all(i["restored_at"] for i in by.values()))

    def test_a_cover_no_item_lists_fails_the_fill(self):
        self.nodes.routines[("db", "shop")][CLOSE_DAY][1] = "gm_vclock, pg_catalog, pg_temp"
        with self.assertRaisesRegex(GmError, "under a cover no fill.quiet item lists"):
            self.fill()
        self.assertEqual(self.st()["fill"]["outcome"], "failed")

    def test_a_failed_end_restore_or_drop_leaves_the_outcome_ok(self):
        self.nodes.restore_fails = True
        self.nodes.drop_fails = True
        result = self.fill()
        self.assertTrue(result.ok)
        rec = self.st()["fill"]
        self.assertEqual(rec["outcome"], "ok")
        (item,) = self.items()
        self.assertNotIn("restored_at", item)
        self.assertIn(f"db: P0's cover: search_path of procedure {CLOSE_DAY} in shop (spec D523) not restored "
                      "(ERROR:  could not restore)", rec["reason"])
        self.assertIn("db/shop: gm_vclock not dropped (ERROR:  gm_vclock not dropped: default value for "
                      "column at of table t)", rec["reason"])
        self.assertIn("not restored: clean-restart restores it", result.text())
        self.assertIn("Next: gmctl clean-restart.", result.text())

    def test_an_actor_the_hold_lists_is_left_to_the_hold(self):
        self.nodes.survey["settings"].update({"cron.launch_active_jobs": "off", "archive_mode": "on",
                                              "archive_command": "/bin/true"})
        hold = [{"node": "db", "what": w, "how": "-", "left_off": True,
                 "restore": {"user": "postgres", "sql": ["-"]}}
                for w in (fill.PG_CRON_WHAT, fill.ARCHIVING_WHAT, fill.CRON_WHAT)]
        localimpl.update_state(self.ldir, lambda st: st.update(hold={"at": "2026-11-17T08:00:00Z",
                                                                    "items": hold}))
        self.assertTrue(self.fill().ok)
        whats = [i["what"] for i in self.st()["fill"]["quiet"]]
        for w in (fill.PG_CRON_WHAT, fill.ARCHIVING_WHAT, fill.CRON_WHAT):
            self.assertNotIn(w, whats)
        self.assertFalse(self.nodes.ran(lambda r: r["stdin"].startswith(fill.CRON_CHECK)
                                        or r["stdin"].startswith(fill.CRON_OFF)))
        quieting = self.nodes.ran(lambda r: "ALTER SYSTEM SET autovacuum_naptime" in r["stdin"])[0]["stdin"]
        self.assertNotIn("cron.launch_active_jobs", quieting)
        self.assertNotIn("archive_command", quieting)

    def test_a_hold_on_another_node_changes_nothing_here(self):
        sql, items = fill.settings_plan("db", {**SURVEY, "settings": dict(
            SURVEY["settings"], **{"cron.launch_active_jobs": "on"})}, [], held=set())
        self.assertIn(fill.PG_CRON_WHAT, [i["what"] for i in items])
        st = {"hold": {"items": [{"node": "other", "what": fill.PG_CRON_WHAT}]}}
        self.assertEqual(fill.held_whats(st, "db"), set())
        self.assertEqual(fill.held_whats({}, "db"), set())

    def test_a_pauses_planting_runs_at_its_virtual_instant(self):
        self.fill()
        runs = self.nodes.ran(lambda r: (r["env"] or {}).get("FAULT_TABLE_NAME"))
        self.assertTrue(runs)
        for run in runs:        # each of f8's scripts, its own environment kept
            self.assertEqual(run["env"]["PGOPTIONS"],
                             f'-c gm.vclock={self.f8_at} -c search_path="$user",public,gm_vclock,pg_catalog')
        self.assertEqual(fill.session_means({"PGOPTIONS": "-c work_mem=8MB"}, "X")["PGOPTIONS"],
                         '-c work_mem=8MB -c gm.vclock=X -c search_path="$user",public,gm_vclock,pg_catalog')


class TestParsing(FilledGame):
    def test_pgbouncer_ini(self):
        ini = fill.parse_pgbouncer_ini(PGBOUNCER_INI)
        self.assertEqual(ini["databases"]["shop"], {"host": "db", "port": "5432", "dbname": "shop"})
        self.assertEqual(ini["pgbouncer"]["default_pool_size"], "3")

    def test_scrape_interval(self):
        prom = {"global": {"scrape_interval": "30s"},
                "scrape_configs": [{"job_name": "a", "static_configs": [{"targets": ["x:1"]}]},
                                   {"job_name": "b", "scrape_interval": "1m",
                                    "static_configs": [{"targets": ["y:2"]}]}]}
        self.assertEqual(fill.scrape_interval(prom, "x:1"), 30)
        self.assertEqual(fill.scrape_interval(prom, "y:2"), 60)
        self.assertIsNone(fill.scrape_interval(prom, "z:3"))
        self.assertEqual(fill.scrape_interval({"scrape_configs": prom["scrape_configs"]}, "x:1"),
                         fill.PROMETHEUS_DEFAULT_INTERVAL)

    def test_a_connection_to_an_unknown_host(self):
        with self.assertRaisesRegex(GmError, "neither a postgres nor a pgbouncer node"):
            fill.connection_plan("producer", {"connections": {"app": {
                "driver": "sql/postgresql", "target": "elsewhere:5432/shop", "role": "r"}}},
                ["db"], {})
        with self.assertRaisesRegex(GmError, "the fill runs SQL only"):
            fill.connection_plan("producer", {"connections": {"api": {
                "driver": "http", "target": "api:8000/x"}}}, ["db"], {})

    def test_the_gmctl_verb(self):
        from tools.gm import build_parser
        args = build_parser().parse_args(["fill", str(self.scenario), "--playground", PG])
        self.assertEqual((args.command, args.playground), ("fill", PG))
        with mock.patch("sys.stdout", io.StringIO()), mock.patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit):
                build_parser().parse_args(["fill", str(self.scenario)])
