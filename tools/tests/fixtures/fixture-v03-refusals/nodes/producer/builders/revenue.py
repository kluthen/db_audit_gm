"""Builder of the fixture's reports.revenue key (master spec 7.1)."""


def build(intensity, options):
    months = int(options.get("months", 1))
    sql = ("SELECT date_trunc('month', placed_at), sum(total) FROM orders "
           "WHERE placed_at > now() - %(span)s::interval GROUP BY 1")
    return {"statements": [(sql, {"span": f"{months} months"})], "transaction": False}
