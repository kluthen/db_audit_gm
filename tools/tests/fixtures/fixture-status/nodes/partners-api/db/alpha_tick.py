"""alpha's tick, its database side (fixture-partners, v0.5 chunk 11a): the
moment of the tick written to alpha.state as last_tick, as the role alpha."""

import gm_api


def tick(hostname):
    """Records the tick; -> its moment, ISO 8601 UTC."""
    with gm_api.connection("alpha-db") as conn:
        (at,) = conn.execute(
            "INSERT INTO alpha.state (hostname, name, value) "
            "VALUES (%s, 'last_tick', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')) "
            "ON CONFLICT (hostname, name) DO UPDATE SET value = EXCLUDED.value, set_at = now() "
            "RETURNING value", (hostname,)).fetchone()
        conn.commit()
    return at
