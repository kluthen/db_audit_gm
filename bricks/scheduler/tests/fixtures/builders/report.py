# Stack test fixture of the scheduler brick: a builder.
def build(intensity, options):
    sql = "INSERT INTO reports (n) SELECT count(*) FROM orders WHERE at > now() - %(days)s * interval '1 day'"
    return [(sql, {"days": options["days"]})], True
