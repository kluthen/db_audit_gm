"""beta's state, its database side (fixture-partners, v0.5 chunk 11a): the
rows of beta.state for one hostname, as the role beta (capture W2 item 6)."""

import gm_api


def state(hostname):
    """{name: value} of the hostname's state rows."""
    with gm_api.connection("beta-db") as conn:
        rows = conn.execute("SELECT name, value FROM beta.state WHERE hostname = %s",
                            (hostname,)).fetchall()
    return dict(rows)
