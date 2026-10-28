# Builder of the scheduler-insert-retry-duplicates fault (capture W4 item 5):
# material the scenario copies into nodes/<node>/builders/ and adapts (the
# INSERT's table, columns and values are the scenario's). queries.yaml maps
# the ingestion key to it:
#
#   queries:
#     deliveries.ingest:
#       builder: builders/resend.py:ingest
#       options: {resend: 0.2, orders: 20000}
#
# Each call inserts one event carrying the client's own id (a fresh UUID, the
# id column) and the current time (the time column, filled by the database).
# For a share of the calls (`resend`, 0 to 1) the client sends the same
# INSERT again with the same values, as a client does when its
# acknowledgement comes late: in autocommit, so the copy lands as a second
# row unless a unique constraint refuses it (SQLSTATE 23505 in the log).
# The fix is the scenario's to accept: ON CONFLICT DO NOTHING behind a unique
# constraint on the id, or the resend gone.
import uuid

STATUSES = ("picked-up", "in-transit", "delivered", "failed")
INSERT = ("INSERT INTO delivery_events (event_id, order_id, status, received_at) "
          "VALUES (%(event_id)s, %(order_id)s, %(status)s, now())")


def ingest(intensity, options, rng):
    params = {
        "event_id": str(uuid.uuid4()),          # the client's id: unique, even across restarts
        "order_id": rng.randint(1, int(options.get("orders", 1000))),
        "status": rng.choice(STATUSES),
    }
    statements = [(INSERT, params)]
    if rng.random() < float(options.get("resend", 0)):
        statements.append((INSERT, params))      # the resend: the same row again
    return statements, False                     # autocommit: each INSERT on its own
