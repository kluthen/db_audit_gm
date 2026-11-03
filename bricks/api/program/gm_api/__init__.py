"""gm_api: the db_audit_gm `api` brick's library (v0.5 master spec 7.2,
"The `api` brick"; capture W1 items 0, 3 and 5, and W1-z, in
specs/versions/v0.5/wave-log.md).

The brick serves the endpoint files the GM drops in: for each endpoint
<name> of `api.yaml`, `routes/<name>.py` (its FastAPI `router`, the
contract) and `db/<name>.py` (its database side). The image is generic and
holds no scenario content.

What a `db/` module uses (its whole surface):

    gm_api.connection(name, session=None)  a pooled psycopg connection of
        api.yaml's sql/postgresql connection <name>, as its application
        role, autocommit off; a context manager: on leaving, whatever is
        uncommitted is rolled back and the connection goes back to the pool.
        `session`, a mapping of setting -> value, is applied to the session
        (set_config(..., false), committed) before it is handed over,
        whenever the session does not already have exactly those settings.
    gm_api.client(name)  a small HTTP client on api.yaml's http connection
        <name>: get(path, params=None, *, headers=None) and post(path,
        body=None, *, headers=None); answers have status, headers, text and
        json(), whatever their status; a timeout or a refused connection
        raises HttpError (.status "timeout" or "refused").
    gm_api.HttpError, gm_api.Unavailable (no free connection in time).

Passwords and HTTP credentials are read by the brick, never by endpoint
code.
"""

VERSION = "0.1.0"


class ConfigError(Exception):
    """A file the brick reads is not valid; the message names the file and
    the place, never a secret."""


class Unavailable(Exception):
    """No connection of the pool became free in time (answered 503)."""


from .pool import connection  # noqa: E402  (the public surface, after the exceptions)
from .http import HttpError, client  # noqa: E402

__all__ = ["VERSION", "ConfigError", "Unavailable", "HttpError", "connection", "client"]
