"""The messaging service's messages endpoint, its database side (purpose
16's stub): as the role messaging, on partners. A call's number is
nextval('messaging.calls'); the service's id is md5('messaging:' ||
message_key)::uuid, as the portal's derivation writes a sent row's
provider_id, so the same key always gets the same id."""

import json

import gm_api


def state(hostname):
    with gm_api.connection("messaging-db") as conn:
        rows = conn.execute("SELECT name, value FROM messaging.state WHERE hostname = %s", (hostname,)).fetchall()
    return dict(rows)


def take(message, fail_one_in):
    """-> the service's id, or None for a call answered 503."""
    key = message["message_key"]
    with gm_api.connection("messaging-db") as conn:
        (call,) = conn.execute("SELECT nextval('messaging.calls')").fetchone()
        if fail_one_in > 0 and call % fail_one_in == 0:
            conn.execute("INSERT INTO messaging.message_calls (call, message_key, status) VALUES (%s, %s, 503)",
                         (call, key))
            conn.commit()
            return None
        (provider_id,) = conn.execute(
            "INSERT INTO messaging.messages (message_key, provider_id, channel, address, template, account_id,"
            " payload) VALUES (%s, md5('messaging:' || %s)::uuid, %s, %s, %s, %s, %s::jsonb)"
            " ON CONFLICT (message_key) DO UPDATE SET accepted = messaging.messages.accepted + 1"
            " RETURNING provider_id::text",
            (key, key, message["channel"], message["address"], message["template"], message.get("account_id"),
             json.dumps(message["payload"]))).fetchone()
        conn.execute("INSERT INTO messaging.message_calls (call, message_key, status) VALUES (%s, %s, 202)",
                     (call, key))
        conn.commit()
    return provider_id
