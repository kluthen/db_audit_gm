"""The `http` driver and the scripts' HTTP client (v0.5 master spec 7.2;
capture W1 items 3 and 4, specs/versions/v0.5/wave-log.md; as built:
W1-y). The standard library only (`http.client`), plain HTTP/1.1.

On the wire, every request carries `Host: <target as written>`,
`User-Agent: <the caller's hostname>` (as `application_name` names a SQL
session, so the players find the caller in the `api` node's log) and,
when the connection names a credential, `Authorization: Bearer <secret>`.
A JSON body is sent as `application/json`, UTF-8: an `int` as a number, a
`decimal` as a number with its digits, a `now` as an ISO 8601 UTC string
(`2026-11-03T08:15:00.123456Z`).

A connection's `pool` is its kept-alive connections: a stream's task holds
at most that many sessions (gm_scheduler.pools), each one kept-alive
connection; a script's client keeps at most that many idle. A kept
connection the server closed while idle is opened again and the request
sent once more (the server never answered it). `timeout` bounds the
connection and the answer's head together, and each read of its body.

A stream's call (`HttpSession.request`) is one request in a daemon thread;
an answer that is not 2xx, a timeout or no connection is a DriverError
whose code is the status: three digits, `timeout` or `refused`, its
message the reason or the answer's first 200 characters. A script's call
(`Client.get`, `Client.post`) returns the answer whatever its status, and
raises HttpError (`.status` `timeout` or `refused`) when there is none.
"""

import datetime
import decimal
import http.client
import json
import re
import socket
import threading
import time
from urllib.parse import urlencode

from . import Driver, DriverError, Result, Session, in_thread

METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE")
QUERY_METHODS = ("GET", "DELETE")    # the parameters go in the query string, never a body
DEFAULT_TIMEOUT = 10                 # seconds: the SQL driver's connect timeout
MESSAGE_CHARS = 200                  # of a refused answer's body, in the log's error line
FORBIDDEN_HEADERS = ("authorization", "host")
JSON_TYPE = "application/json"
BYTES_TYPE = "application/octet-stream"
_PATH_RE = re.compile(r"^/[\x21-\x7e]*$")    # absolute, no space or control character

_UTC = datetime.timezone.utc


class HttpError(Exception):
    """A call that got no answer: `status` is `timeout` or `refused`."""

    def __init__(self, status, message):
        super().__init__(f"{status}: {message}")
        self.status, self.message = status, message


class Answer:
    """An answer, whatever its status: `status` (an integer), `reason`,
    `headers` (case-insensitive `get`), `content` (bytes), `text`, `json()`."""

    def __init__(self, status, reason, headers, content):
        self.status, self.reason, self.headers, self.content = status, reason, headers, content

    @property
    def ok(self):
        return 200 <= self.status < 300

    @property
    def text(self):
        return self.content.decode("utf-8", errors="replace")

    def json(self):
        return json.loads(self.content.decode("utf-8")) if self.content else None


# --- values on the wire ------------------------------------------------------------
def iso_utc(value):
    if value.tzinfo is None:
        value = value.replace(tzinfo=_UTC)
    return value.astimezone(_UTC).isoformat().replace("+00:00", "Z")


def scalar_text(value):
    """A drawn value in a path or a query string."""
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, datetime.datetime):
        return iso_utc(value)
    if isinstance(value, decimal.Decimal):
        return format(value, "f")
    return str(value)


def encode_json(value):
    """`value` as UTF-8 JSON bytes; a Decimal is a number with its own digits,
    a datetime an ISO 8601 UTC string. Raises TypeError or ValueError on
    what JSON cannot hold."""
    marks = {}

    def default(o):
        if isinstance(o, decimal.Decimal):
            if not o.is_finite():
                raise ValueError("a decimal that is not a finite number")
            token = f"\x00gm-decimal-{len(marks)}\x00"
            marks[json.dumps(token)] = format(o, "f")
            return token
        if isinstance(o, datetime.datetime):
            return iso_utc(o)
        if isinstance(o, datetime.date):
            return o.isoformat()
        if isinstance(o, (tuple, set, frozenset)):
            return list(o)
        raise TypeError(f"{type(o).__name__} is not JSON serialisable")

    text = json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=default, allow_nan=False)
    for quoted, digits in marks.items():
        text = text.replace(quoted, digits)
    return text.encode("utf-8")


def query_string(params):
    """A map -> `a=1&b=x`, values as scalar_text (a list repeats its name)."""
    pairs = []
    for name, value in params.items():
        values = value if isinstance(value, (list, tuple)) else [value]
        pairs += [(str(name), scalar_text(v)) for v in values]
    return urlencode(pairs)


def check_path(path):
    if not isinstance(path, str) or not _PATH_RE.match(path):
        raise ValueError("a path is a string beginning with /, without spaces or control characters")
    return path


def join_query(path, query):
    if not query:
        return path
    return f"{path}{'&' if '?' in path else '?'}{query}"


def wire_headers(connection, credential, user_agent, content_type=None, extra=None):
    headers = {"Host": connection.target, "User-Agent": user_agent}
    if credential:
        headers["Authorization"] = f"Bearer {credential}"
    if content_type:
        headers["Content-Type"] = content_type
    for name, value in (extra or {}).items():
        for k in [k for k in headers if k.lower() == name.lower()]:
            del headers[k]
        headers[name] = value
    return headers


def extra_headers(headers):
    """A script's `headers=`: a map of names to values, never Authorization
    or Host (raises ValueError)."""
    if headers is None:
        return {}
    if not isinstance(headers, dict):
        raise ValueError("headers is a map of header names to values")
    out = {}
    for name, value in headers.items():
        if not isinstance(name, str) or not re.match(r"^[A-Za-z0-9!#$%&'*+.^_`|~-]+$", name):
            raise ValueError(f"header name {name!r} is not a token")
        if name.lower() in FORBIDDEN_HEADERS:
            raise ValueError(f"headers never sets {name}: the connection does")
        text = str(value)
        if any(ord(c) < 32 and c != "\t" for c in text):
            raise ValueError(f"header {name}: a control character in its value")
        out[name] = text
    return out


def answer_message(status, reason, content):
    """A refused answer in the log: its body's first 200 characters, or its
    reason phrase when it has no body."""
    text = " ".join(content.decode("utf-8", errors="replace").split())
    return text[:MESSAGE_CHARS].rstrip() if text else f"{status} {reason}".strip()


def _reason(exc):
    text = " ".join(str(exc).split())
    return f"{type(exc).__name__}: {text}" if text else type(exc).__name__


# --- one kept-alive connection ----------------------------------------------------------
class Wire:
    """One kept-alive connection to a target, used by one thread at a time;
    http.client opens it again when it was closed."""

    def __init__(self, host, port, timeout):
        self.conn = http.client.HTTPConnection(host, port, timeout=timeout)
        self.used = False            # it has carried an answer: a server may close it while idle

    def close(self):
        self.conn.close()
        self.used = False

    def abort(self):
        """From another thread: wakes a call blocked on the socket, then closes."""
        sock = self.conn.sock
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        self.close()


def _remaining(wire, deadline, timeout):
    left = deadline - time.monotonic()
    if left <= 0:
        raise TimeoutError(f"no answer within {timeout:g}s")
    if wire.conn.sock is not None:
        wire.conn.sock.settimeout(left)


def exchange(wire, method, target, body, headers, timeout):
    """One request on `wire` -> (status, reason, headers, content, latency);
    raises HttpError (timeout, refused)."""
    start = time.monotonic()
    deadline = start + timeout
    for attempt in (1, 2):
        reused = wire.used
        try:
            wire.conn.timeout = timeout
            wire.conn.request(method, target, body=body, headers=headers)
            _remaining(wire, deadline, timeout)
            resp = wire.conn.getresponse()
            _remaining(wire, deadline, timeout)
            content = resp.read()
        except TimeoutError:
            wire.close()
            raise HttpError("timeout", f"no answer within {timeout:g}s") from None
        except (ConnectionResetError, BrokenPipeError, ConnectionAbortedError) as exc:
            # http.client.RemoteDisconnected is a ConnectionResetError
            wire.close()
            if reused and attempt == 1:
                continue             # a kept connection the server closed while idle
            raise HttpError("refused", _reason(exc)) from None
        except (OSError, http.client.HTTPException) as exc:
            wire.close()
            raise HttpError("refused", _reason(exc)) from None
        wire.used = True
        if resp.will_close:
            wire.close()
        return resp.status, resp.reason, resp.headers, content, time.monotonic() - start
    raise AssertionError("attempts")


# --- the driver: a stream's calls ------------------------------------------------------------
class HttpSession(Session):
    """One kept-alive connection of a stream's (or a job's) pool."""

    def __init__(self, connection, credential, user_agent):
        self.connection, self.credential, self.user_agent = connection, credential, user_agent
        self.wire = Wire(connection.host, connection.port, connection.timeout)
        self._broken = False

    @property
    def broken(self):
        return self._broken

    async def request(self, call):
        """`call`: a repository.CallPlan. Returns Result(1, latency); raises
        DriverError (field status) for an answer that is not 2xx, a timeout,
        no connection."""
        headers = wire_headers(self.connection, self.credential, self.user_agent, call.content_type)
        try:
            status, reason, _headers, content, latency = await in_thread(
                exchange, self.wire, call.method, call.target, call.body, headers, self.connection.timeout,
                name="gm-http")
        except HttpError as exc:
            raise DriverError(exc.status, exc.message, field="status") from None
        except BaseException:
            # cancelled mid-call (the program stops, a pool closes): the thread
            # still holds the connection, which is no longer this session's
            self._broken = True
            self.wire.abort()
            raise
        if not 200 <= status < 300:
            raise DriverError(str(status), answer_message(status, reason, content), field="status")
        return Result(1, latency)

    async def close(self):
        self.wire.close()


class HttpDriver(Driver):
    name = "http"

    async def connect(self, connection, secret, application_name):
        """Opens nothing yet: the connection opens at the first request (a
        target that refuses is a call's error, `status=refused`)."""
        return HttpSession(connection, secret, application_name)


DRIVER = HttpDriver()


# --- the scripts' client ------------------------------------------------------------------------
class Client:
    """`conns[<name>]` for an HTTP connection in a script job (capture W1
    item 4): `get(path, params=None, *, headers=None)` and `post(path,
    body=None, *, headers=None)`. Each call is reported to `on_call(method,
    target, status, latency, error)`, `status` three digits, `timeout` or
    `refused`, `error` true for any of them but a 2xx; the runner logs it
    and counts it. Thread-safe."""

    HttpError = HttpError            # so a script catches it without an import

    def __init__(self, connection, credential, user_agent, on_call=None):
        self.connection, self._credential, self._user_agent = connection, credential, user_agent
        self._on_call = on_call
        self._idle = []
        self._lock = threading.Lock()

    def __repr__(self):
        return f"<gm_scheduler http client {self.connection.name}>"

    def get(self, path, params=None, *, headers=None):
        check_path(path)
        if params is not None and not isinstance(params, dict):
            raise ValueError("params is a map of names to values")
        return self._call("GET", join_query(path, query_string(params or {})), None, None, headers)

    def post(self, path, body=None, *, headers=None):
        check_path(path)
        if body is None:
            data, content_type = None, None
        elif isinstance(body, (bytes, bytearray, memoryview)):
            data, content_type = bytes(body), BYTES_TYPE
        else:
            data, content_type = encode_json(body), JSON_TYPE
        return self._call("POST", path, data, content_type, headers)

    def _take(self):
        with self._lock:
            if self._idle:
                return self._idle.pop()
        c = self.connection
        return Wire(c.host, c.port, c.timeout)

    def _give(self, wire):
        with self._lock:
            if len(self._idle) < self.connection.pool_size:
                self._idle.append(wire)
                return
        wire.close()

    def _report(self, method, target, status, latency, error):
        if self._on_call is not None:
            self._on_call(method, target, status, latency, error)

    def _call(self, method, target, data, content_type, headers):
        extra = extra_headers(headers)
        sent = wire_headers(self.connection, self._credential, self._user_agent, content_type, extra)
        wire = self._take()
        start = time.monotonic()
        try:
            status, reason, answer_headers, content, latency = exchange(
                wire, method, target, data, sent, self.connection.timeout)
        except HttpError as exc:
            self._give(wire)
            self._report(method, target, exc.status, time.monotonic() - start, True)
            raise
        self._give(wire)
        self._report(method, target, f"{status:03d}", latency, not 200 <= status < 300)
        return Answer(status, reason, answer_headers, content)

    def close(self):
        with self._lock:
            idle, self._idle = self._idle, []
        for wire in idle:
            wire.close()
