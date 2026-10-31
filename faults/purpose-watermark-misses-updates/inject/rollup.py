"""The BI agency's hourly sales roll-up (the sales reporting purpose,
rollup-hourly; v0.4 master spec 7.1, 10.1).

Called by the scheduler as hourly(conns, options, log): `conns["source"]`
reads the shop's database as shop_etl, `conns["target"]` writes the
reporting database as bi_etl, both with autocommit off.

1. On the target: the customer's zone (rpt.business_settings), the last
   watermark of a finished run, and this run's rpt.etl_runs row.
2. On the source, in one read-only repeatable-read snapshot: the orders
   placed since the watermark (placed_at past it, less an overlap that
   catches a transaction committing late), read row by row; each one's
   local hour and day is affected. Then the affected hours' figures per
   category and the affected days' figures, recomputed whole.
3. On the target, in the transaction that already holds the run's row:
   the affected hours deleted and re-inserted, the affected days written
   (a day the nightly close has closed keeps its orders and revenue: only
   its invoiced revenue moves), the run's row finished with the new
   watermark, the source's time of the snapshot. One commit.

Returns the rows it wrote. Imports nothing but the standard library.
"""

import datetime

JOB = "rollup-hourly"


def _ranges(starts, step):
    """Sorted starts -> merged [lo, hi) ranges, each start covering `step`."""
    out = []
    for s in sorted(starts):
        if out and out[-1][1] == s:
            out[-1][1] = s + step
        else:
            out.append([s, s + step])
    return [r[0] for r in out], [r[1] for r in out]


def hourly(conns, options, log):
    src, dst = conns["source"], conns["target"]
    overlap = datetime.timedelta(seconds=int(options.get("overlap_seconds", 600)))

    with dst.cursor() as cur:
        cur.execute("SELECT timezone FROM rpt.business_settings")
        (tz,) = cur.fetchone()
        cur.execute("SELECT watermark FROM rpt.etl_runs"
                    " WHERE job = %s AND finished_at IS NOT NULL AND watermark IS NOT NULL"
                    " ORDER BY id DESC LIMIT 1", (JOB,))
        last = cur.fetchone()
        cur.execute("INSERT INTO rpt.etl_runs (job, started_at) VALUES (%s, clock_timestamp())"
                    " RETURNING id", (JOB,))
        (run,) = cur.fetchone()
    since = last[0] - overlap if last else None

    with src.cursor() as cur:
        cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
        cur.execute("SELECT now()")
        (upper,) = cur.fetchone()

    # The new orders, row by row: their local hours and days.
    hours, days, read = set(), set(), 0
    with src.cursor(name="new_orders") as cur:
        cur.itersize = 5000
        if since is None:
            cur.execute("SELECT o.placed_at AT TIME ZONE %(tz)s FROM orders o", {"tz": tz})
        else:
            cur.execute("SELECT o.placed_at AT TIME ZONE %(tz)s FROM orders o"
                        " WHERE o.placed_at > %(since)s", {"tz": tz, "since": since})
        for (placed_local,) in cur:
            read += 1
            hours.add(placed_local.replace(minute=0, second=0, microsecond=0))
            days.add(placed_local.date())

    hour_rows, day_rows = [], []
    with src.cursor() as cur:
        if hours:
            lo, hi = _ranges(hours, datetime.timedelta(hours=1))
            cur.execute(
                "SELECT date_trunc('hour', o.placed_at AT TIME ZONE %(tz)s), p.category,"
                "       count(DISTINCT o.id), sum(l.quantity), sum(l.line_total)"
                "  FROM orders o"
                "  JOIN unnest(%(lo)s::timestamp[], %(hi)s::timestamp[]) AS r (lo, hi)"
                "    ON o.placed_at >= r.lo AT TIME ZONE %(tz)s AND o.placed_at < r.hi AT TIME ZONE %(tz)s"
                "  JOIN order_lines l ON l.order_id = o.id"
                "  JOIN products p ON p.id = l.product_id"
                " GROUP BY 1, 2", {"tz": tz, "lo": lo, "hi": hi})
            hour_rows = cur.fetchall()
        if days:
            starts = [datetime.datetime.combine(d, datetime.time()) for d in days]
            lo, hi = _ranges(starts, datetime.timedelta(days=1))
            cur.execute(
                "SELECT (o.placed_at AT TIME ZONE %(tz)s)::date, count(*), coalesce(sum(o.total), 0),"
                "       coalesce(sum(o.total) FILTER (WHERE o.status = 'invoiced'), 0)"
                "  FROM orders o"
                "  JOIN unnest(%(lo)s::timestamp[], %(hi)s::timestamp[]) AS r (lo, hi)"
                "    ON o.placed_at >= r.lo AT TIME ZONE %(tz)s AND o.placed_at < r.hi AT TIME ZONE %(tz)s"
                " GROUP BY 1", {"tz": tz, "lo": lo, "hi": hi})
            day_rows = cur.fetchall()
    src.rollback()                      # read only: the snapshot ends here

    written = 0
    with dst.cursor() as cur:
        if hours:
            cur.execute("DELETE FROM rpt.sales_hourly WHERE hour_local = ANY(%s::timestamp[])",
                        (sorted(hours),))
            cur.executemany(
                "INSERT INTO rpt.sales_hourly (hour_local, category, orders, units, revenue, run_id)"
                " VALUES (%s, %s, %s, %s, %s, %s)", [(*row, run) for row in hour_rows])
            written += len(hour_rows)
        cur.executemany(
            "INSERT INTO rpt.sales_daily AS d (day_local, orders, revenue, invoiced_revenue, closed, run_id)"
            " VALUES (%s, %s, %s, %s, false, %s)"
            " ON CONFLICT (day_local) DO UPDATE"
            "    SET orders = CASE WHEN d.closed THEN d.orders ELSE excluded.orders END,"
            "        revenue = CASE WHEN d.closed THEN d.revenue ELSE excluded.revenue END,"
            "        invoiced_revenue = excluded.invoiced_revenue,"
            "        run_id = CASE WHEN d.closed THEN d.run_id ELSE excluded.run_id END",
            [(*row, run) for row in day_rows])
        written += len(day_rows)
        cur.execute("UPDATE rpt.etl_runs SET finished_at = clock_timestamp(), rows_read = %s,"
                    " rows_written = %s, watermark = %s WHERE id = %s", (read, written, upper, run))
    dst.commit()
    log(f"read {read} new orders since {since.isoformat() if since else 'the start'},"
        f" rewrote {len(hours)} hours and {len(days)} days, watermark {upper.isoformat()}")
    return written
