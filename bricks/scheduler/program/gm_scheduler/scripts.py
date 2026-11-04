"""Transformer scripts (master spec 7.1, "The transformer script
contract"; v0.4 capture W1 item 7; as built: W1-y; v0.5: HTTP connections,
v0.5 master spec 7.2, capture W1 item 4).

A script key's job runs here, in a worker thread of the program, beside
the asyncio tasks:

  1. `open_connections`: one psycopg connection per name of the job's
     `connections:`, as the schedule's role for that connection with its
     password, autocommit off, `application_name` the node's hostname, no
     server-side prepared statement (any PgBouncer pool mode works), the
     driver's TCP keepalives (a script idle on one connection while it
     works on the other keeps both through a Swarm service VIP). A
     connection that cannot be opened closes the others, and the run is
     skipped as any job's is (`reason=connection-refused`). v0.5: a name
     whose schedule connection is `http` gets the small HTTP client
     (gm_scheduler.drivers.http.Client: `get`, `post`), opened at its
     first call, never refused here: a refused or silent target raises
     HttpError at the call. Each call is reported to `on_call(name, ...)`,
     which the runner logs (`http job=<job> connection=<name> ...`) and
     counts under `<key>/<name>`.
  2. `call`: `<function>(conns, options, log)`; `conns` maps each name to
     its open connection, `options` is a copy of the entry's, `log(text)`
     appends `script job=<name> <text>` to the scheduler's log. The script
     commits what it means to commit and returns the number of rows it
     wrote (a whole number, at least 0). What it leaves uncommitted is
     rolled back when the runner closes the connections, after the call,
     whatever happened.

An exception (or a return that is not a number of rows) ends the run with
`status=error`, `sqlstate=<code>` for a database error, `error=<class>`
otherwise; nothing else stops. The thread is a daemon: a program stopping
mid-run does not wait for it, and the server rolls back what was open.
A script's database connections talk psycopg 3, outside the driver
interface; its HTTP connections the driver's client.
"""

from .drivers import DriverError, in_thread  # noqa: F401  (in_thread: the runner's)
from .drivers.http import Client, HttpError  # noqa: F401  (HttpError: for a script that imports it)

CONNECT_TIMEOUT = 10


def open_connections(names, schedule, passwords, application_name, credentials=None, on_call=None):
    """{script's name: schedule connection name} -> {name: an open psycopg
    connection, or an HTTP client}; raises DriverError (connect=True)
    naming the connection that could not be opened, after closing the
    others. `on_call(name, method, target, status, latency, error)`: each
    HTTP call's report."""
    import psycopg
    from .drivers.postgresql import KEEPALIVES, _error

    conns = {}
    try:
        for name, cname in names.items():
            c = schedule.connections[cname]
            if c.http:
                secret = (credentials or {}).get(c.credential) if c.credential else None
                report = None
                if on_call is not None:
                    def report(method, target, status, latency, error, _name=name):
                        on_call(_name, method, target, status, latency, error)
                conns[name] = Client(c, secret, application_name, report)
                continue
            try:
                conns[name] = psycopg.connect(
                    host=c.host, port=c.port, dbname=c.database, user=c.role,
                    password=passwords.get(c.role), application_name=application_name,
                    connect_timeout=CONNECT_TIMEOUT, autocommit=False, prepare_threshold=None,
                    **KEEPALIVES)
            except psycopg.Error as exc:
                raise _error(exc, connect=True) from None
            except OSError as exc:
                raise DriverError("08001", f"{type(exc).__name__}: {exc}", connect=True, lost=True) from None
    except DriverError:
        close_connections(conns)
        raise
    return conns


def close_connections(conns):
    import psycopg
    for conn in conns.values():
        if isinstance(conn, Client):
            conn.close()
            continue
        try:
            conn.close()
        except (psycopg.Error, OSError):
            pass  # closing: the server rolls back whatever the session left open


class Outcome:
    """How a call ended: `rows` (ok) or the error's field, value and
    message for the log."""

    def __init__(self, rows=None, field=None, value=None, message=None):
        self.rows, self.field, self.value, self.message = rows, field, value, message

    @property
    def ok(self):
        return self.field is None


def classify(exc):
    """An exception a script raised -> Outcome (`sqlstate` for a database
    error carrying one, `error=<class>` otherwise)."""
    code = getattr(exc, "sqlstate", None)
    if code:
        diag = getattr(exc, "diag", None)
        primary = getattr(diag, "message_primary", None) if diag is not None else None
        return Outcome(field="sqlstate", value=code, message=" ".join((primary or str(exc)).split()))
    text = " ".join(str(exc).split())
    name = type(exc).__name__
    return Outcome(field="error", value=name, message=f"script: {name}: {text}" if text else f"script: {name}")


def call(fn, conns, options, log):
    """Calls the script and closes its connections; returns an Outcome,
    never raises."""
    try:
        rows = fn(conns, dict(options), log)
    except BaseException as exc:  # the script's own failure ends its run, never the program
        return classify(exc)
    finally:
        close_connections(conns)
    if not isinstance(rows, int) or isinstance(rows, bool) or rows < 0:
        return Outcome(field="error", value="TypeError",
                       message=f"script: returned {type(rows).__name__}, not the number of rows it wrote")
    return Outcome(rows=rows)
