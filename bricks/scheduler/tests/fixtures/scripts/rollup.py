# Stack test fixture of the scheduler brick: a transformer script (v0.4
# master spec 7.1). Reads the shop's orders as the source connection's role
# and writes one roll-up row into reporting as the target's, in one
# transaction there; returns the rows it wrote.


def hourly(conns, options, log):
    src, dst = conns["source"], conns["target"]
    with src.cursor() as cur:
        cur.execute("SELECT current_user, count(*), coalesce(sum(amount), 0) FROM orders")
        src_role, orders, amount = cur.fetchone()
    src.rollback()                      # read only: nothing to keep open
    with dst.cursor() as cur:
        cur.execute("INSERT INTO rollup (orders, amount, src_role, dst_role) "
                    "VALUES (%s, %s, %s, current_user)", (orders, amount, src_role))
    dst.commit()
    log(f"rolled up {orders} orders as {src_role} into {options['into']}")
    return 1
