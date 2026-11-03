"""`gm_api.client(name)`: the HTTP client of api.yaml's http connections, for
an endpoint that reads, calls and writes (master spec 7.2; capture W1
items 3 and 4: the scheduler's client, with the same wire form).

On the wire: `Authorization: Bearer <secret>` when the connection has a
credential; `Host:` the target as written; `User-Agent:` this node's
hostname; JSON bodies as application/json, UTF-8. `pool: N` kept-alive
connections, shared by the server's threads; a call waits for a free one.
`timeout` (default 10 s) bounds the connection and the answer.

    get(path, params=None, *, headers=None)
    post(path, body=None, *, headers=None)

`body` is JSON-serialisable (sent as application/json) or bytes (sent as
is, Content-Type from `headers`, default application/octet-stream);
`headers` never sets Authorization or Host. A call returns an Answer
(`status`, `headers`, `text`, `json()`) whatever its status; a timeout or
a refused connection raises HttpError with `.status` "timeout" or
"refused".
"""

import http.client
import json
import socket
import threading
import urllib.parse

from . import ConfigError

_clients = {}
_lock = threading.Lock()
FORBIDDEN_HEADERS = ("authorization", "host")


class HttpError(Exception):
    def __init__(self, status, message):
        super().__init__(f"{status}: {message}")
        self.status = status


class Answer:
    def __init__(self, status, headers, data):
        self.status = status
        self.headers = headers
        self._data = data

    @property
    def text(self):
        return self._data.decode("utf-8", errors="replace")

    def json(self):
        return json.loads(self._data.decode("utf-8"))


class Client:
    def __init__(self, conn, secret, user_agent):
        self.conn = conn
        self.secret = secret
        self.user_agent = user_agent
        self._slots = threading.BoundedSemaphore(conn.pool_size)
        self._idle = []
        self._idle_lock = threading.Lock()

    def _new(self):
        return http.client.HTTPConnection(self.conn.host, self.conn.port, timeout=self.conn.timeout)

    def _headers(self, extra):
        h = {"Host": self.conn.target, "User-Agent": self.user_agent, "Accept": "application/json"}
        if self.secret:
            h["Authorization"] = f"Bearer {self.secret}"
        for k, v in (extra or {}).items():
            if k.lower() in FORBIDDEN_HEADERS:
                raise ValueError(f"headers: {k} is the client's to set")
            h[k] = v
        return h

    def _call(self, method, path, body, headers):
        if not path.startswith("/"):
            raise ValueError(f"path {path!r} is not absolute")
        self._slots.acquire()
        try:
            for attempt in (0, 1):
                with self._idle_lock:
                    c = self._idle.pop() if self._idle else None
                reused = c is not None
                if c is None:
                    c = self._new()
                try:
                    c.request(method, path, body=body, headers=headers)
                    r = c.getresponse()
                    data = r.read()
                except (http.client.RemoteDisconnected, BrokenPipeError, ConnectionResetError) as exc:
                    c.close()
                    if reused and attempt == 0:
                        continue                 # a kept-alive connection the server closed
                    raise HttpError("refused", str(exc) or type(exc).__name__) from None
                except (socket.timeout, TimeoutError):
                    c.close()
                    raise HttpError("timeout", f"no answer within {self.conn.timeout}s") from None
                except OSError as exc:
                    c.close()
                    raise HttpError("refused", exc.strerror or str(exc)) from None
                except http.client.HTTPException as exc:
                    c.close()
                    raise HttpError("refused", f"{type(exc).__name__}: {exc}") from None
                if r.will_close:
                    c.close()
                else:
                    with self._idle_lock:
                        self._idle.append(c)
                return Answer(r.status, r.headers, data)
        finally:
            self._slots.release()

    def get(self, path, params=None, *, headers=None):
        if params:
            path = f"{path}{'&' if '?' in path else '?'}{urllib.parse.urlencode(params)}"
        return self._call("GET", path, None, self._headers(headers))

    def post(self, path, body=None, *, headers=None):
        h = self._headers(headers)
        if isinstance(body, (bytes, bytearray)):
            if not any(k.lower() == "content-type" for k in h):
                h["Content-Type"] = "application/octet-stream"
            data = bytes(body)
        else:
            h["Content-Type"] = "application/json"
            data = json.dumps(body).encode("utf-8")
        return self._call("POST", path, data, h)

    def close(self):
        with self._idle_lock:
            idle, self._idle = self._idle, []
        for c in idle:
            c.close()


def configure(connections, secrets, user_agent=None):
    agent = user_agent or socket.gethostname()
    with _lock:
        for c in _clients.values():
            c.close()
        _clients.clear()
        for c in connections.values():
            if c.driver == "http":
                _clients[c.name] = Client(c, secrets.get(c.name), agent)


def client(name):
    c = _clients.get(name)
    if c is None:
        raise ConfigError(f"gm_api.client({name!r}): not an http connection of api.yaml")
    return c
