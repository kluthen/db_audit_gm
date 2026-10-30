"""The sales reporting purpose (purposes/shop-sales-reporting, v0.4 build
plan chunk 10) in the scheduler's unit-test harness: run by run-tests.sh
beside this file, which mounts it into the `unit-test` stage of the
scheduler brick's image with the purpose, the shop domain and the brick's
check helpers.

Two databases of the harness's throwaway PostgreSQL, p1_shop and
p1_reporting, are loaded with the domain's data and the purpose's target
material at a shift of +5 (the names adapted as the GM adapts them). The
scheduler program runs the purpose's runner material (its queries.yaml,
scripts/ and schedule.yaml fragments, jobs.yaml with the jobs' times
moved to the coming minutes and reloaded, as a player moves a job): real
time throughout, no clock moved, no job triggered by hand. The source
changes the test makes are the producer's (an order placed, the
close-of-day invoicing, an order updated). The checks are fed to `sh -s`
as root, as gmctl check does, with CHECK_SINCE."""

import glob
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timedelta, timezone

import yaml

from pgtest import ADMIN, ADMIN_PASSWORD, DST_PASSWORD, DST_ROLE, HOST, PORT, SRC_PASSWORD, SRC_ROLE, admin, needs_pg

PURPOSE = "/opt/gm-test/purpose"
DOMAIN = "/opt/gm-test/domain"
SHOP, REPORTING = "p1_shop", "p1_reporting"
OFFSET, ZONE = 5, "Etc/GMT-5"
WRONG_ZONE = "Etc/GMT-8"                 # the close's day cut three hours off (f7's kind)
GM_CHECK_PASSWORD = "gm-check-unit"
SETTLE = 60
FMT = "%Y-%m-%dT%H:%M:%SZ"
PSQL = sorted(glob.glob("/usr/lib/postgresql/*/bin/psql"))[-1]


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def psql(text, db="postgres", variables=None):
    argv = [PSQL, "-X", "-q", "-h", HOST, "-p", str(PORT), "-U", ADMIN, "-d", db, "-v", "ON_ERROR_STOP=1"]
    for name, value in (variables or {}).items():
        argv += ["-v", f"{name}={value}"]
    p = subprocess.run(argv, input=text, capture_output=True, text=True,
                       env={**os.environ, "PGPASSWORD": ADMIN_PASSWORD})
    if p.returncode != 0:
        raise AssertionError(f"psql failed: {p.stderr}")


def adapted(text, existing_roles):
    """A data file with the scenario names this harness uses: the databases
    p1_shop and p1_reporting, and no CREATE ROLE of a role the harness made."""
    text = re.sub(r"(?m)^CREATE ROLE (\w+)\b.*$",
                  lambda m: f"-- {m.group(0)}" if m.group(1) in existing_roles else m.group(0), text)
    for old, new in (("shop", SHOP), ("reporting", REPORTING)):
        text = re.sub(rf"(?m)^CREATE DATABASE {old} ", f"CREATE DATABASE {new} ", text)
        text = re.sub(rf"(?m)^\\connect {old}$", rf"\\connect {new}", text)
    return text.replace("dbname 'shop'", f"dbname '{SHOP}'")


def check(name, since):
    """(exit code, first line) of a purpose check, fed to sh -s as gmctl
    check feeds it, its node names kept (db and reporting resolve to the
    harness), its databases adapted."""
    text = read(f"{PURPOSE}/checks/{name}")
    for part, db in (('SOURCE = ("db", "shop")', f'SOURCE = ("db", "{SHOP}")'),
                     ('TARGET = ("reporting", "reporting")', f'TARGET = ("reporting", "{REPORTING}")')):
        text = text.replace(part, db)
    p = subprocess.run(["sh", "-s"], input=text, capture_output=True, text=True,
                       env={**os.environ, "CHECK_SINCE": iso(since)}, timeout=180)
    lines = p.stdout.splitlines()
    return p.returncode, (lines[0] if lines else p.stderr.strip())


@needs_pg
class TestSalesReporting(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        roles = {r[0] for r in admin("SELECT rolname FROM pg_roles")}
        for db in (SHOP, REPORTING):
            admin(f"DROP DATABASE IF EXISTS {db} WITH (FORCE)")
        variables = {"customer_timezone": ZONE, "customer_utc_offset": OFFSET}
        psql(adapted(read(f"{DOMAIN}/data/schema.sql"), roles) + read(f"{DOMAIN}/data/load.sql")
             .replace("\\connect shop", f"\\connect {SHOP}"), variables=variables)
        roles = {r[0] for r in admin("SELECT rolname FROM pg_roles")}
        cls.target_sql = read(f"{PURPOSE}/material/target/data.sql")
        psql(adapted(cls.target_sql, roles), variables=variables)
        # what load-data does: the mapping's password from its remote role's secret, the GM
        # check role on every instance
        admin(f"ALTER USER MAPPING FOR {DST_ROLE} SERVER shop_db OPTIONS (ADD password '{SRC_PASSWORD}')",
              db=REPORTING)
        if "gm_check" not in roles:
            admin(f"CREATE ROLE gm_check LOGIN PASSWORD '{GM_CHECK_PASSWORD}'")
        admin("GRANT pg_read_all_data, pg_use_reserved_connections TO gm_check")
        os.makedirs("/opt/gm/secrets", exist_ok=True)
        with open("/opt/gm/secrets/gm_check_password", "w") as f:
            f.write(GM_CHECK_PASSWORD + "\n")
        os.chmod("/opt/gm/secrets/gm_check_password", 0o400)

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="gm-p1-test-")
        self.paths = {
            "log": f"{self.root}/log/scheduler.log", "status": f"{self.root}/run/status",
            "loaded": f"{self.root}/run/loaded", "marker": f"{self.root}/state/load-started",
            "state": f"{self.root}/lib", "repository": f"{self.root}/repository",
            "jobs": f"{self.root}/jobs/jobs.yaml", "schedule_seed": f"{self.root}/seed/schedule.yaml",
            "metrics": {"listen": "127.0.0.1", "port": 19121, "path": "/metrics"},
        }
        for d in ("log", "run", "state", "lib", "repository/scripts", "jobs", "seed"):
            os.makedirs(f"{self.root}/{d}", exist_ok=True)
        runner = f"{PURPOSE}/material/runner"
        shutil.copy(f"{runner}/queries.yaml", self.paths["repository"])
        shutil.copy(f"{runner}/scripts/rollup.py", f"{self.paths['repository']}/scripts")
        self.jobs_fragment = yaml.safe_load(read(f"{runner}/jobs.yaml"))
        self.schedule = yaml.safe_load(read(f"{runner}/schedule.yaml"))
        self.schedule["connections"]["shop"]["target"] = f"db:{PORT}/{SHOP}"
        self.schedule["connections"]["reporting"]["target"] = f"reporting:{PORT}/{REPORTING}"
        self.schedule.update(seed=20261030, intensity=1.0, shapes={}, timeline=[])
        # the node's configuration, where check-runs and the checks read it
        os.makedirs("/etc/scheduler", exist_ok=True)
        with open("/etc/scheduler/scheduler.yaml", "w") as f:
            yaml.safe_dump(self.paths, f)
        self.cfg = "/etc/scheduler/scheduler.yaml"

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)
        os.remove("/etc/scheduler/scheduler.yaml")

    # --- the program and its log --------------------------------------------

    def write_jobs(self, hourly, close):
        """The purpose's jobs.yaml lines with their times moved: `hourly` and
        `close` lists of UTC instants (whole minutes) each job runs at."""
        def at(instants):
            ts = [datetime.fromtimestamp(t, timezone.utc) for t in instants]
            return (",".join(sorted({str(t.minute) for t in ts}, key=int)) + " "
                    + ",".join(sorted({str(t.hour) for t in ts}, key=int)) + " * * *")
        doc = {"jobs": [dict(j) for j in self.jobs_fragment["jobs"]]}
        for job in doc["jobs"]:
            job["at"] = at(hourly if job["name"] == "rollup-hourly" else close)
        with open(self.paths["jobs"], "w") as f:
            yaml.safe_dump(doc, f)

    def log(self):
        try:
            return read(self.paths["log"]).splitlines()
        except FileNotFoundError:
            return []

    def wait_for(self, predicate, until, what):
        while time.time() < until:
            if predicate():
                return
            time.sleep(0.5)
        self.fail(f"timed out waiting for {what}:\n" + "\n".join(self.log()[-30:]))

    def wait_run(self, job, due, end=" phase=end status=ok"):
        """Waits for `job`'s run due at `due` to end; returns its end line."""
        stamp = time.strftime("%Y-%m-%dT%H:%M", time.gmtime(due))
        def done():
            return [l for l in self.log() if l >= stamp and f" job={job} " in l and end in l]
        self.wait_for(done, due + 150, f"{job}'s run at {stamp}")
        return done()[-1]

    def place_order(self):
        """The web shop's checkout: one order of two units of product 7, now."""
        admin("WITH o AS (INSERT INTO orders (customer_id, placed_at, status, total, updated_at, ship_country) "
              "SELECT 1, now(), 'paid', 2 * price, now(), 'DE' FROM products WHERE id = 7 RETURNING id) "
              "INSERT INTO order_lines (order_id, product_id, sku, product_name, quantity, unit_price, "
              "vat_rate, line_total, created_at) SELECT o.id, p.id, p.sku, p.name, 2, p.price, 20.00, "
              "2 * p.price, now() FROM o, products p WHERE p.id = 7", db=SHOP)

    def invoice_yesterday(self, parity):
        """The close-of-day's invoicing, of half of yesterday's shipped orders."""
        n = admin("WITH i AS (UPDATE orders SET status = 'invoiced', updated_at = now() "
                  " WHERE status = 'shipped' AND id %% 2 = %s "
                  "   AND (placed_at + make_interval(hours => %s))::date "
                  "       = (now() + make_interval(hours => %s))::date - 1 RETURNING 1) "
                  "SELECT count(*) FROM i", (parity, OFFSET, OFFSET), db=SHOP)[0][0]
        self.assertGreater(n, 0, "no shipped order of yesterday to invoice")

    def source_figures(self):
        """The source's local hours and days, computed here with the offset
        (not AT TIME ZONE)."""
        hours = {(h.strftime("%Y-%m-%d %H:%M"), c): (int(o), int(u), r) for h, c, o, u, r in admin(
            "SELECT date_trunc('hour', o.placed_at AT TIME ZONE 'UTC' + make_interval(hours => %s)), "
            "p.category, count(DISTINCT o.id), sum(l.quantity), sum(l.line_total) FROM orders o "
            "JOIN order_lines l ON l.order_id = o.id JOIN products p ON p.id = l.product_id GROUP BY 1, 2",
            (OFFSET,), db=SHOP)}
        days = {d.isoformat(): (int(o), r, i) for d, o, r, i in admin(
            "SELECT (o.placed_at AT TIME ZONE 'UTC' + make_interval(hours => %s))::date, count(*), "
            "sum(o.total), coalesce(sum(o.total) FILTER (WHERE o.status = 'invoiced'), 0) FROM orders o "
            "GROUP BY 1", (OFFSET,), db=SHOP)}
        return hours, days

    def published(self):
        hours = {(h.strftime("%Y-%m-%d %H:%M"), c): (o, u, r) for h, c, o, u, r in admin(
            "SELECT hour_local, category, orders, units, revenue FROM rpt.sales_hourly", db=REPORTING)}
        days = {d.isoformat(): (o, r, i) for d, o, r, i in admin(
            "SELECT day_local, orders, revenue, invoiced_revenue FROM rpt.sales_daily", db=REPORTING)}
        return hours, days

    def assertCheck(self, name, since, code, text=None):
        got = check(name, since)
        self.assertEqual(got[0], code, got)
        if text:
            self.assertRegex(got[1], text)
        return got[1]

    def procedure(self, zone=None):
        """rpt.close_day() as the material writes it, or cutting its day in
        `zone` instead of the customer's."""
        body = self.target_sql[self.target_sql.index("CREATE PROCEDURE rpt.close_day()"):]
        body = body[:body.index("$$;") + 3].replace("CREATE PROCEDURE", "CREATE OR REPLACE PROCEDURE")
        if zone:
            line = "SELECT timezone INTO STRICT tz FROM rpt.business_settings;"
            self.assertIn(line, body)
            body = body.replace(line, f"tz := '{zone}';")
        return body

    # --- the test ------------------------------------------------------------

    def test_rollup_close_and_checks(self):
        stdin = (f"gm-scheduler-input 1\npassword {SRC_ROLE} {SRC_PASSWORD}\npassword {DST_ROLE} {DST_PASSWORD}\n"
                 "schedule\n" + yaml.safe_dump(self.schedule))
        # the published figures start empty, as the reporting data file leaves them
        admin("TRUNCATE rpt.sales_hourly, rpt.sales_daily, rpt.etl_runs RESTART IDENTITY", db=REPORTING)
        m0 = (int(time.time()) + 75) // 60 * 60
        minute = 60
        hourly = [m0, m0 + 2 * minute, m0 + 8 * minute]
        close = [m0 + 3 * minute, m0 + 6 * minute]
        self.write_jobs(hourly, close)
        with open(self.paths["marker"], "w") as f:
            f.write(time.strftime("%Y-%m-%dT%H:%M:%SZ\n", time.gmtime()))
        p = subprocess.Popen([sys.executable, "-I", "-m", "gm_scheduler", "run", "--config", self.cfg],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        p.stdin.write(stdin.encode())
        p.stdin.close()
        p.stdin = None
        try:
            self.run_phases(p, m0, minute, hourly, close)
        finally:
            if p.poll() is None:
                p.send_signal(signal.SIGTERM)
            out = p.communicate(timeout=30)[0].decode()
        self.assertNotIn("Traceback", out)
        self.assertNotIn(SRC_PASSWORD, "\n".join(self.log()))

    def run_phases(self, p, m0, minute, hourly, close):
        self.wait_for(lambda: read(self.paths["status"]).split()[:1] == ["running"]
                      if os.path.exists(self.paths["status"]) else False, time.time() + 30, "running")
        judged = time.time()
        time.sleep(1)

        # 1. the first run publishes every hour and day of the history
        self.wait_run("rollup-hourly", hourly[0])
        self.invoice_yesterday(0)
        self.place_order()
        # 2. the next run picks up the invoicing and the new order (updated_at past the watermark)
        self.wait_run("rollup-hourly", hourly[1])
        # 3. the nightly close (moved) closes yesterday in the customer's zone
        self.wait_run("rollup-close", close[0])
        self.assertEqual(admin("SELECT count(*) FROM pg_proc WHERE proname = 'close_day'", db=REPORTING), [(1,)])
        admin(self.procedure(WRONG_ZONE), db=REPORTING)   # the next close cuts its day three hours off

        # the script moved the right rows: every published hour and day is the source's local one
        src_hours, src_days = self.source_figures()
        pub_hours, pub_days = self.published()
        self.assertEqual(pub_hours, src_hours)
        self.assertEqual(pub_days, src_days)
        yesterday = ((datetime.now(timezone.utc) + timedelta(hours=OFFSET)).date() - timedelta(days=1)).isoformat()
        self.assertEqual(admin("SELECT day_local::text FROM rpt.sales_daily WHERE closed", db=REPORTING),
                         [(yesterday,)])
        ledger = admin("SELECT job, rows_read, rows_written > 0, watermark IS NOT NULL FROM rpt.etl_runs "
                       "ORDER BY id", db=REPORTING)
        self.assertEqual([(j, w, m) for j, _, w, m in ledger],
                         [("rollup-hourly", True, True), ("rollup-hourly", True, True),
                          ("rollup-close", True, True)])
        self.assertEqual(ledger[0][1], 300000)
        self.assertEqual(ledger[2][1], src_days[yesterday][0])
        self.assertTrue(any(" script job=rollup-hourly read 300000 changed orders since the start," in l
                            for l in self.log()), self.log())
        # nothing of the customer crossed: no customer column on the target, none readable
        self.assertEqual(admin("SELECT count(*) FROM information_schema.columns WHERE table_schema IN "
                               "('rpt', 'src') AND column_name LIKE '%customer%'", db=REPORTING), [(0,)])

        # clean runs since the judged moment, each with a witness: 0
        self.assertCheck("r1-reconciled.sh", judged, 0, r"^R1 fixed: 2 rollup-hourly runs ")
        self.assertCheck("r2-counted-once.sh", judged, 0, r"^R2 fixed: 3 runs ")
        self.assertCheck("r3-local-days.sh", judged, 0, r"^R3 fixed: 3 runs ")
        self.assertCheck("r4-fresh.sh", judged, 0, r"^R4 fixed: 2 rollup-hourly runs ")
        # no run since the judged moment: 3, with the time to the next run
        now = time.time()
        for name in ("r1-reconciled.sh", "r2-counted-once.sh", "r3-local-days.sh", "r4-fresh.sh"):
            line = self.assertCheck(name, now, 3, r"^remaining=[0-9]+ ")
            self.assertLessEqual(int(line.split()[0][10:]), hourly[2] - now + 2, line)
        self.assertLess(time.time(), close[1] - 5, "the checks ran past the next close")

        # 4. the close with its day cut in the wrong zone; then an order of that day updated and
        #    its hour rewritten by the hourly run, right: the closed day no longer sums its hours
        self.wait_run("rollup-close", close[1])
        wrong_day = admin("SELECT (now() AT TIME ZONE %s)::date - 1", (WRONG_ZONE,), db=REPORTING)[0][0]
        touched = admin("UPDATE orders SET updated_at = now() WHERE id = (SELECT min(id) FROM orders "
                        "WHERE (placed_at AT TIME ZONE 'UTC' + make_interval(hours => %s))::date = %s) "
                        "RETURNING id", (OFFSET, wrong_day), db=SHOP)
        self.assertEqual(len(touched), 1)
        self.wait_run("rollup-hourly", hourly[2])
        self.assertCheck("r3-local-days.sh", judged, 1, r"^R3 present: the rollup-close run of ")
        self.assertCheck("r2-counted-once.sh", judged, 1, r"^R2 present: the rollup-(close|hourly) run of .* left day ")
        admin(self.procedure(), db=REPORTING)

        # 5. the hourly script picking rows by placed_at (f4's kind), reloaded: the next
        #    invoicing of yesterday never reaches reporting
        script = f"{self.paths['repository']}/scripts/rollup.py"
        text = read(script)
        self.assertEqual(text.count('" WHERE o.updated_at > %(since)s"'), 1)
        with open(script, "w") as f:
            f.write(text.replace('" WHERE o.updated_at > %(since)s"', '" WHERE o.placed_at > %(since)s"'))
        self.invoice_yesterday(1)
        self.place_order()
        reload_at = time.time()
        m1 = (int(reload_at) + SETTLE + 69) // 60 * 60   # at least SETTLE + 10 s after the changes
        self.write_jobs([m1, m1 + 2 * minute], [m0 + 3 * minute])
        p.send_signal(signal.SIGHUP)
        self.wait_for(lambda: any(" reload status=ok" in l and l >= iso(reload_at)[:16] for l in self.log()),
                      time.time() + 20, "the reload")
        self.wait_run("rollup-hourly", m1)
        self.assertCheck("r1-reconciled.sh", judged, 1,
                         r"^R1 present: the rollup-hourly run of .* left closed day [0-9-]+ at invoiced revenue ")
        self.assertCheck("r4-fresh.sh", judged, 0, r"^R4 fixed: 1 rollup-hourly runs since ")

        # 6. the source role expired (f5's kind): the next run is refused its connection
        admin(f"ALTER ROLE {SRC_ROLE} VALID UNTIL '2000-01-01'")
        try:
            self.wait_run("rollup-hourly", m1 + 2 * minute, end="reason=connection-refused")
            self.assertCheck("r4-fresh.sh", judged, 1, r"^R4 present: the rollup-hourly run at .* was refused")
        finally:
            admin(f"ALTER ROLE {SRC_ROLE} VALID UNTIL 'infinity'")

    def test_dashboard_definition(self):
        """R5 on the consumer's repository: the baseline faithful, a changed
        revenue column and a broken query not. Needs published days: the
        hourly script run once, as the runner would."""
        consumer = f"{self.root}/consumer"
        os.makedirs(consumer)
        shutil.copy(f"{PURPOSE}/material/consumer/queries.yaml", consumer)
        paths = dict(self.paths, repository=consumer)
        with open(self.cfg, "w") as f:
            yaml.safe_dump(paths, f)
        if not admin("SELECT count(*) FROM rpt.sales_daily", db=REPORTING)[0][0]:
            self.publish_once()
        self.assertCheck("r5-dashboard-faithful.sh", time.time(), 0,
                         r"^R5 fixed: the dashboards' revenue query shows 1[0-4] days")
        text = read(f"{consumer}/queries.yaml")
        with open(f"{consumer}/queries.yaml", "w") as f:
            f.write(text.replace("d.day_local, d.orders, d.revenue, d.invoiced_revenue",
                                 "d.day_local, d.orders, d.invoiced_revenue AS revenue"))
        self.assertCheck("r5-dashboard-faithful.sh", time.time(), 1,
                         r"^R5 present: the dashboards show [0-9-]+ at revenue ")
        with open(f"{consumer}/queries.yaml", "w") as f:
            f.write(text.replace("FROM rpt.sales_daily d,", "FROM rpt.sales_dayly d,"))
        self.assertCheck("r5-dashboard-faithful.sh", time.time(), 1,
                         r"^R5 present: the dashboards' revenue query dashboard.revenue does not run")

    def publish_once(self):
        import psycopg
        sys.path.insert(0, f"{PURPOSE}/material/runner/scripts")
        try:
            import rollup
        finally:
            sys.path.pop(0)
        conns = {"source": psycopg.connect(host=HOST, port=PORT, dbname=SHOP, user=SRC_ROLE,
                                           password=SRC_PASSWORD),
                 "target": psycopg.connect(host=HOST, port=PORT, dbname=REPORTING, user=DST_ROLE,
                                           password=DST_PASSWORD)}
        try:
            self.assertGreater(rollup.hourly(conns, {"overlap_seconds": 600}, lambda text: None), 0)
        finally:
            for c in conns.values():
                c.close()
