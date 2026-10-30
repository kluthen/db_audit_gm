"""Transformer scripts (master spec 7.1, "The transformer script
contract"; v0.4 capture W1 item 7; as built: W1-y).

A script key's job runs here, in a worker thread of the program, beside
the asyncio tasks:

  1. `open_connections`: one psycopg connection per name of the job's
     `connections:`, as the schedule's role for that connection with its
     password, autocommit off, `application_name` the node's hostname, no
     server-side prepared statement (any PgBouncer pool mode works). A
     connection that cannot be opened closes the others, and the run is
     skipped as any job's is (`reason=connection-refused`).
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
PostgreSQL only: a script talks psycopg 3, outside the driver interface.
"""

import asyncio
import threading

from .drivers import DriverError

CONNECT_TIMEOUT = 10


def in_thread(fn, *args, name="gm-script"):
    """Runs `fn(*args)` in a daemon thread; returns an asyncio future of its
    result (or its exception)."""
    loop = asyncio.get_running_loop()
    future = loop.create_future()

    def settle(result, exc):
        if future.cancelled():
            return
        if exc is not None:
            future.set_exception(exc)
        else:
            future.set_result(result)

    def target():
        try:
            result, exc = fn(*args), None
        except BaseException as e:  # handed to the awaiting task, which logs it
            result, exc = None, e
        try:
            loop.call_soon_threadsafe(settle, result, exc)
        except RuntimeError:
            pass  # the loop is gone: the program is stopping and nobody awaits the run

    threading.Thread(target=target, name=name, daemon=True).start()
    return future


def open_connections(names, schedule, passwords, application_name):
    """{script's name: schedule connection name} -> {name: open psycopg
    connection}; raises DriverError (connect=True) naming the connection
    that could not be opened, after closing the others."""
    import psycopg
    from .drivers.postgresql import _error

    conns = {}
    try:
        for name, cname in names.items():
            c = schedule.connections[cname]
            try:
                conns[name] = psycopg.connect(
                    host=c.host, port=c.port, dbname=c.database, user=c.role,
                    password=passwords.get(c.role), application_name=application_name,
                    connect_timeout=CONNECT_TIMEOUT, autocommit=False, prepare_threshold=None)
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
