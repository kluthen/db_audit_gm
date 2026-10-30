#!/bin/sh
# R5 dashboard faithful (shop-sales-reporting, v0.4 master spec 10.1, 12.6):
# the dashboards' revenue query returns, for each day it shows, the revenue
# rpt.sales_daily holds for that day. A definition, judged on the live
# state: exit 0 or 1, never 3.
#
# Runs on the consumer node (the dashboards) as root, fed to `sh -s` by
# gmctl check. It reads the live repository's dashboard.revenue entry
# (queries.yaml, where the node's configuration puts the repository) and
# runs its SELECT read-only as gm_check through check-sql, beside
# rpt.sales_daily: it reads, it runs no job (12.6). The query must keep the
# columns day_local and revenue, the dashboard's contract.
#
# Exit 1: a day shown with another revenue than rpt.sales_daily's, or the
# query gone, no longer a plain SELECT, failing, or showing nothing while
# rpt.sales_daily holds days of its fourteen-day window. Exit 0: every day
# shown as published. Exit 2: it cannot judge (a helper failed, the
# repository unreadable).
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from decimal import Decimal

TARGET = ("reporting", "reporting")  # the target part: node, database
KEY = "dashboard.revenue"
CHECK_SQL = "/usr/local/lib/gm/check-sql"


def cannot(text):
    print(f"R5 cannot be judged: {text}")
    sys.exit(2)


def present(text):
    print(f"R5 present: {text}")
    sys.exit(1)


from gm_scheduler.runner import load_config         # noqa: E402 (the node's program)
import yaml                                         # noqa: E402

try:
    path = os.path.join(load_config()["repository"], "queries.yaml")
    with open(path, encoding="utf-8") as f:
        queries = (yaml.safe_load(f) or {}).get("queries") or {}
except Exception as exc:                            # unreadable: not the definition's fault
    cannot(f"the repository's queries.yaml: {exc}")
entry = queries.get(KEY)
if not isinstance(entry, dict) or not isinstance(entry.get("sql"), str):
    present(f"the dashboards' revenue query {KEY} is gone from {path} or no longer a plain query")
if entry.get("params"):
    cannot(f"{KEY} takes parameters: its result depends on values the check cannot choose")
query = entry["sql"].strip().rstrip(";")


def run(statement):
    p = subprocess.run([CHECK_SQL, "-h", TARGET[0], "-d", TARGET[1]], input=statement,
                       capture_output=True, text=True)
    return p.returncode, [line.split("|") for line in p.stdout.splitlines()], p.stderr.strip()


code, rows, err = run("SELECT to_char(q.day_local, 'YYYY-MM-DD'), q.revenue::text, "
                      "coalesce(d.revenue::text, '') "
                      f"FROM ({query}\n) AS q LEFT JOIN rpt.sales_daily d ON d.day_local = q.day_local")
if code == 1:
    present(f"the dashboards' revenue query {KEY} does not run read-only with its columns "
            f"day_local and revenue: {err.removeprefix('check-sql: ')}")
if code != 0:
    cannot(err or f"check-sql exited {code}")

wrong = [(day, shown, held) for day, shown, held in rows
         if not held or Decimal(shown or "0") != Decimal(held)]
if wrong:
    day, shown, held = wrong[0]
    more = f" ({len(wrong)} days differ)" if len(wrong) > 1 else ""
    present(f"the dashboards show {day} at revenue {shown or 'none'} where rpt.sales_daily "
            f"holds {held or 'no row'}{more}")
if not rows:
    code, held, err = run("SELECT count(*) FROM rpt.sales_daily d, rpt.business_settings s "
                          "WHERE d.day_local >= (now() AT TIME ZONE s.timezone)::date - 13")
    if code != 0:
        cannot(err or f"check-sql exited {code}")
    if int(held[0][0]) > 0:
        present(f"the dashboards' revenue query shows no day while rpt.sales_daily holds "
                f"{held[0][0]} of the last fourteen")
print(f"R5 fixed: the dashboards' revenue query shows {len(rows)} days, each at the revenue "
      "rpt.sales_daily holds")
sys.exit(0)
PY
