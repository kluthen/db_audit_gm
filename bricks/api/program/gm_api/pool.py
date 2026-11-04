"""`gm_api.connection(name)`: the pooled SQL connections of api.yaml's
sql/postgresql connections (capture W1 item 5).

`pool: {size: N}`: at most N sessions per connection for the whole server,
opened when first needed and kept; a request waits for a free one, at most
WAIT seconds (then Unavailable, answered 503); a session that broke is
closed and replaced at the next checkout. `pool: {per-call: true}`: a
session opened for each checkout and closed after it.

Each session: the connection's role and the password the brick read from
its secret, `application_name` the node's hostname (as on a scheduler
node), autocommit off, no server-side prepared statements (any PgBouncer
pool mode works), libpq's TCP keepalives (a Swarm service address forgets
a TCP flow idle for 900 s), a 10 s connect timeout.

On leaving the context, whatever is uncommitted is rolled back, so a
transaction-local setting (set_config(..., true)) never outlives its
request. Session-level settings stay with the pooled session: `session=`
applies a mapping of settings (set_config(..., false), committed) whenever
the session's last applied mapping differs, resetting those it no longer
names; a `SET` an endpoint runs itself stays with that session too.
"""

import contextlib
import socket
import threading

import psycopg
from psycopg import sql

from . import ConfigError, Unavailable

CONNECT_TIMEOUT = 10
WAIT = 30
KEEPALIVES = {"keepalives": 1, "keepalives_idle": 300, "keepalives_interval": 30,
              "keepalives_count": 3}

_pools = {}
_lock = threading.Lock()


class Pool:
    def __init__(self, conn, password, application_name):
        self.conn = conn
        self.password = password
        self.application_name = application_name
        # per-call: no bound of the brick's (each checkout its own session)
        self._slots = None if conn.per_call else threading.BoundedSemaphore(conn.pool_size)
        self._idle = []
        self._idle_lock = threading.Lock()
        self._applied = {}                       # id(session) -> its session settings

    def _connect(self):
        c = self.conn
        return psycopg.connect(host=c.host, port=c.port, dbname=c.database, user=c.role,
                               password=self.password, application_name=self.application_name,
                               connect_timeout=CONNECT_TIMEOUT, autocommit=False,
                               prepare_threshold=None, **KEEPALIVES)

    def _take(self):
        while True:
            with self._idle_lock:
                s = self._idle.pop() if self._idle else None
            if s is None:
                return self._connect()
            if s.closed or s.broken:
                self._applied.pop(id(s), None)
                continue
            return s

    def _drop(self, s):
        self._applied.pop(id(s), None)
        with contextlib.suppress(Exception):
            s.close()

    def _apply(self, s, session):
        wanted = {str(k): str(v) for k, v in (session or {}).items()}
        if self._applied.get(id(s), {}) == wanted:
            return
        old = self._applied.get(id(s), {})
        for name in old:
            if name not in wanted:
                s.execute(sql.SQL("RESET {}").format(
                    sql.SQL(".").join(sql.Identifier(p) for p in name.split("."))))
        for name, value in wanted.items():
            s.execute("SELECT set_config(%s, %s, false)", (name, value))
        s.commit()
        self._applied[id(s)] = wanted

    @contextlib.contextmanager
    def session(self, session=None):
        if self._slots is not None and not self._slots.acquire(timeout=WAIT):
            raise Unavailable(f"connection {self.conn.name}: no free session within {WAIT}s "
                              f"(pool size {self.conn.pool_size})")
        s = None
        try:
            s = self._take()
            try:
                self._apply(s, session)
            except BaseException:
                self._drop(s)
                s = None
                raise
            yield s
        finally:
            if s is not None:
                self._release(s)
            if self._slots is not None:
                self._slots.release()

    def _release(self, s):
        if self.conn.per_call or s.closed or s.broken:
            self._drop(s)
            return
        try:
            if s.info.transaction_status != psycopg.pq.TransactionStatus.IDLE:
                s.rollback()
        except Exception:
            self._drop(s)
            return
        with self._idle_lock:
            self._idle.append(s)

    def close(self):
        with self._idle_lock:
            idle, self._idle = self._idle, []
        for s in idle:
            self._drop(s)


def configure(connections, passwords, application_name=None):
    """Called once by the application's build: one pool per sql/postgresql
    connection, with the password the brick read."""
    name = application_name or socket.gethostname()
    with _lock:
        for p in _pools.values():
            p.close()
        _pools.clear()
        for c in connections.values():
            if c.driver == "sql/postgresql":
                _pools[c.name] = Pool(c, passwords[c.name], name)


def close_all():
    with _lock:
        for p in _pools.values():
            p.close()
        _pools.clear()


def connection(name, session=None):
    """A context manager giving a pooled psycopg connection of api.yaml's
    sql/postgresql connection <name> (see the module's text)."""
    pool = _pools.get(name)
    if pool is None:
        raise ConfigError(f"gm_api.connection({name!r}): not an sql/postgresql connection of "
                          "api.yaml")
    return pool.session(session)
