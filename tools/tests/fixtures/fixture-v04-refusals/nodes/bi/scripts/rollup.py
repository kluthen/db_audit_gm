"""Transformer script of fixture-v04-refusals' bi node (tools/tests, v0.4
chunk 2): loaded by the unit tests, never run."""


def hourly(conns, options, log):
    """Copies the hour's totals from source to target; returns the rows written."""
    with conns["source"].cursor() as src, conns["target"].cursor() as dst:
        src.execute("SELECT date_trunc('hour', placed_at), sum(total) FROM orders GROUP BY 1")
        rows = src.fetchall()[: options.get("batch", 500)]
        dst.executemany("INSERT INTO sales_hourly (hour, total, copied_at) "
                        "VALUES (%s, %s, now())", rows)
    conns["target"].commit()
    log(f"rows={len(rows)}")
    return len(rows)
