# The carriers' feed: one delivery event per call, with the carrier's own
# event id. When our acknowledgement is late (a share of the calls, the
# `resend` option), the feed client sends the event again.
import uuid

STATUSES = ("picked-up", "in-transit", "delivered", "failed")
INSERT = ("INSERT INTO delivery_events (event_id, order_id, status, received_at) "
          "VALUES (%(event_id)s, %(order_id)s, %(status)s, now())")


def ingest(intensity, options, rng):
    params = {
        "event_id": str(uuid.uuid4()),
        "order_id": rng.randint(1, int(options.get("orders", 1000))),
        "status": rng.choice(STATUSES),
    }
    statements = [(INSERT, params)]
    if rng.random() < float(options.get("resend", 0)):
        statements.append((INSERT, params))
    return statements, False
