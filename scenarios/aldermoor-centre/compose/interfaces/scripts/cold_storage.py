"""The readings shipped to the vault (purpose 14, cold-storage-archive;
vet-machinery-domain.md, "cold-storage-archive"; cold-storage.md 2 and 3;
capture W4 items 0 and 6; spec D296, D297, D381, D418): ship-partitions, a
script job of the centre's integration engine.

Called by the scheduler as ship(conns, options, log): `conns["vitals"]` and
`conns["biomed"]` the machinery's databases as mach_archive (psycopg 3,
autocommit off), `conns["partner"]` cold storage's upload (the scheduler's
HTTP client, the customer's account key with it).

For each data type, `vitals` (mach_vitals in vitals) and `machine-readings`
(mach_readings in biomed): the day partitions (mach_vitals_YYYYMMDD,
mach_readings_YYYYMMDD, read from pg_inherits) older than the window, the
customer's local today less window_days, both read from the database's
settings (mach_vitals_settings, mach_settings: its fixed offset, the
partitions' day boundary). For each such day, oldest first:
  - for the readings, the day's aggregate first (mach_readings_daily: each
    machine's rows and each numeric channel's min, max and mean), committed
    before anything ships (cold storage 2, "Aggregates first");
  - the day's rows, read through the parent, as NDJSON (every column is
    `internal`, rule 10), posted to POST /shipments with the header
    Shipment-Id `<type>-<YYYYMMDD>` (the same on a resend: the vault
    replaces its manifest), Shipment-Type, Shipment-Source (options
    ["source"], the node whose partitions ship, D381), Shipment-Rows,
    Shipment-From and Shipment-To (the day);
  - on a receipt (2xx) whose rows received equal the rows sent, the
    partition detached and dropped by mach_drop_shipped(day); otherwise it
    is kept, and the next run sends it again with the same id.
Then, in one transaction per database: the run's ops.runs row, each day's
ops.shipments row (upserted on (type, day), its attempts counted), the
drops, and, from the local hour options["last_hour"] on, one ops.incidents
row (kind unshipped, ref the shipment id) for each day still on site,
once. A run with nothing to ship writes its run rows only.

Logs shipment ids and counts only. Returns the rows written. Imports
nothing but the standard library.
"""

import datetime
import json

PURPOSE = "cold-storage-archive"
JOB = "ship-partitions"

# type -> (connection, parent table, settings table, its time column)
TYPES = (
    ("vitals", "vitals", "mach_vitals", "mach_vitals_settings", "at"),
    ("machine-readings", "biomed", "mach_readings", "mach_settings", "read_at"),
)

STATE = (
    "SELECT ((now() AT TIME ZONE 'UTC') + make_interval(hours => s.utc_offset_hours))::date,"
    " extract(hour FROM (now() AT TIME ZONE 'UTC') + make_interval(hours => s.utc_offset_hours))::int,"
    " s.window_days, s.utc_offset_hours FROM {settings} s")
PARTITIONS = (
    "SELECT c.relname FROM pg_catalog.pg_inherits i JOIN pg_catalog.pg_class c ON c.oid = i.inhrelid"
    " WHERE i.inhparent = %s::regclass AND c.relname ~ %s ORDER BY c.relname")
BOUNDS = ("SELECT (%(day)s::date::timestamp - make_interval(hours => %(o)s)) AT TIME ZONE 'UTC',"
          " ((%(day)s::date + 1)::timestamp - make_interval(hours => %(o)s)) AT TIME ZONE 'UTC'")
ROWS = "SELECT row_to_json(t)::text FROM {parent} t WHERE t.{col} >= %s AND t.{col} < %s ORDER BY t.{col}"
AGGREGATE = """
WITH r AS (SELECT machine_id, channels FROM mach_readings WHERE read_at >= %(lo)s AND read_at < %(hi)s),
n AS (SELECT machine_id, count(*) AS rows FROM r GROUP BY machine_id),
c AS (SELECT r.machine_id, k.key, min((k.value #>> '{}')::numeric) AS mn,
             max((k.value #>> '{}')::numeric) AS mx, avg((k.value #>> '{}')::numeric) AS av
        FROM r CROSS JOIN LATERAL jsonb_each(r.channels) AS k
       WHERE jsonb_typeof(k.value) = 'number' GROUP BY r.machine_id, k.key)
INSERT INTO mach_readings_daily (machine_id, day, rows, channels)
SELECT n.machine_id, %(day)s::date, n.rows,
       coalesce((SELECT jsonb_object_agg(c.key, jsonb_build_object('min', round(c.mn, 2), 'max', round(c.mx, 2),
                                                                   'mean', round(c.av, 2)))
                   FROM c WHERE c.machine_id = n.machine_id), '{}'::jsonb)
  FROM n
ON CONFLICT (machine_id, day) DO UPDATE SET rows = EXCLUDED.rows, channels = EXCLUDED.channels
"""
UPSERT = (
    "INSERT INTO ops.shipments (type, day, shipment_id, rows_sent, rows_received, posted_at, receipt_at,"
    " dropped_at, run_id) VALUES (%(type)s, %(day)s, %(id)s, %(sent)s, %(received)s, %(posted)s,"
    " %(receipt)s, %(dropped)s, %(run)s)"
    " ON CONFLICT (type, day) DO UPDATE SET shipment_id = EXCLUDED.shipment_id, rows_sent = EXCLUDED.rows_sent,"
    " rows_received = EXCLUDED.rows_received, attempts = ops.shipments.attempts + 1,"
    " posted_at = EXCLUDED.posted_at, receipt_at = EXCLUDED.receipt_at, dropped_at = EXCLUDED.dropped_at,"
    " run_id = EXCLUDED.run_id")


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _post(partner, kind, source, day, rows, log):
    """(rows received or None, the receipt's instant or None)."""
    shipment_id = f"{kind}-{day:%Y%m%d}"
    body = ("\n".join(rows) + "\n").encode("utf-8") if rows else b""
    headers = {"Shipment-Id": shipment_id, "Shipment-Type": kind, "Shipment-Source": source,
               "Shipment-Rows": str(len(rows)), "Shipment-From": day.isoformat(),
               "Shipment-To": day.isoformat()}
    try:
        answer = partner.post("/shipments", body, headers=headers)
    except partner.HttpError as exc:
        log(f"shipment={shipment_id} rows={len(rows)} no receipt ({exc.status})")
        return None, None
    if not answer.ok:
        log(f"shipment={shipment_id} rows={len(rows)} refused ({answer.status})")
        return None, None
    try:
        received = int((answer.json() or {}).get("rows_received"))
    except (ValueError, TypeError, AttributeError):
        log(f"shipment={shipment_id} rows={len(rows)} receipt without rows_received")
        return None, _now()
    log(f"shipment={shipment_id} rows={len(rows)} received={received}")
    return received, _now()


def _ship_type(conns, options, log, kind, cname, parent, settings, col):
    db, partner = conns[cname], conns["partner"]
    source = str(options.get("source", "machines"))
    last_hour = int(options.get("last_hour", 5))
    started = _now()
    with db.cursor() as cur:
        cur.execute(STATE.format(settings=settings))
        today, hour, window, offset = cur.fetchone()
        cur.execute(PARTITIONS, (parent, f"^{parent}_[0-9]{{8}}$"))
        names = [r[0] for r in cur.fetchall()]
    db.rollback()
    cutoff = today - datetime.timedelta(days=int(window))
    days = []
    for name in names:
        try:
            day = datetime.datetime.strptime(name[-8:], "%Y%m%d").date()
        except ValueError:
            continue
        if day < cutoff:
            days.append(day)
    done, read = [], 0
    for day in days:
        with db.cursor() as cur:
            cur.execute(BOUNDS, {"day": day, "o": offset})
            lo, hi = cur.fetchone()
            if kind == "machine-readings":
                cur.execute(AGGREGATE, {"lo": lo, "hi": hi, "day": day})
        db.commit()                              # the aggregate kept before anything ships
        with db.cursor() as cur:
            cur.execute(ROWS.format(parent=parent, col=col), (lo, hi))
            rows = [r[0] for r in cur.fetchall()]
        db.rollback()
        read += len(rows)
        posted = _now()
        received, receipt = _post(partner, kind, source, day, rows, log)
        done.append((day, len(rows), received, posted, receipt))
    with db.cursor() as cur:
        cur.execute("SELECT ref FROM ops.incidents WHERE purpose = %s AND kind = 'unshipped'", (PURPOSE,))
        opened = {r[0] for r in cur.fetchall()}
        shipped = [d for d in done if d[2] is not None and d[2] == d[1]]
        late = [d for d in done if d not in shipped and hour >= last_hour
                and f"{kind}-{d[0]:%Y%m%d}" not in opened]
        written = len(done) + len(late)
        cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                    " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, JOB, started, read, written))
        run_id = cur.fetchone()[0]
        for day, sent, received, posted, receipt in done:
            dropped = None
            if (day, sent, received, posted, receipt) in shipped:
                cur.execute("SELECT mach_drop_shipped(%s)", (day,))
                cur.fetchone()                   # false: already gone, dropped all the same
                dropped = _now()
                log(f"shipment={kind}-{day:%Y%m%d} partition dropped")
            cur.execute(UPSERT, {"type": kind, "day": day, "id": f"{kind}-{day:%Y%m%d}", "sent": sent,
                                 "received": received, "posted": posted, "receipt": receipt,
                                 "dropped": dropped, "run": run_id})
        for day, *_ in late:
            ref = f"{kind}-{day:%Y%m%d}"
            cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                        " VALUES (%s, %s, 'unshipped', %s, %s, %s)",
                        (PURPOSE, JOB, ref, f"{kind} day {day} still on site at its last shipping run", run_id))
            log(f"shipment={ref} unshipped: incident opened")
    db.commit()
    return written + 1


def ship(conns, options, log):
    total = 0
    for kind, cname, parent, settings, col in TYPES:
        total += _ship_type(conns, options, log, kind, cname, parent, settings, col)
    return total
