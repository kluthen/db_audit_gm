"""The application uvicorn serves (capture W1 item 5; W1-z).

    python3 -I -m uvicorn --factory gm_api.app:create_app --host 0.0.0.0 --port 8000

One process, one ASGI application: a dispatcher in front of one FastAPI
application per hostname, each holding the routers of the endpoints that
list the hostname. For each request:

  1. the `Host` header without its port picks the hostname's application;
     an unknown hostname answers 404;
  2. the route the request matches names its endpoint; when the endpoint
     lists credentials, `Authorization: Bearer <secret>` must carry one of
     them, else 401 before anything else runs (body, validation, route);
  3. the route runs; routes are plain `def`, run in AnyIO's worker threads
     (40), so one slow endpoint never holds the event loop; a database that
     cannot be reached (psycopg's OperationalError) or a pool with no free
     session in time answers 503; any other exception 500;
  4. one line in the request log, /var/log/api/api.log:
     <UTC time> request status=<s> ms=<latency> method=<M> host=<hostname>
       endpoint=<name or -> from=<client address> agent=<User-Agent> path=<path?query>
     the path last as it may hold anything; an exception adds an `error`
     line before it, naming the endpoint and the exception (type, message).

FastAPI's documentation routes (/docs, /redoc, /openapi.json) are off: a
hostname serves its endpoints' routes and nothing else. At start (the
lifespan), the server writes /run/gm-api/loaded: when, its process, the
files' fingerprint and each hostname's endpoints.
"""

import datetime
import hashlib
import hmac
import json
import os
import sys
import threading
import time
import traceback

from . import ConfigError, Unavailable, check, config
from . import http as gm_http
from . import pool as gm_pool

_log_lock = threading.Lock()
_log_file = None
_log_path = None


def utcnow():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def log_line(text):
    """Appends one line to the request log (stderr when it cannot be opened)."""
    global _log_file, _log_path
    line = f"{utcnow()} {text}\n"
    with _log_lock:
        if _log_path != config.LOG_FILE:
            if _log_file not in (None, sys.stderr):
                _log_file.close()
            _log_file, _log_path = None, config.LOG_FILE
        if _log_file is None:
            try:
                _log_file = open(config.LOG_FILE, "a", encoding="utf-8", buffering=1)
            except OSError:
                _log_file = sys.stderr
        try:
            _log_file.write(line)
            _log_file.flush()
        except OSError:
            sys.stderr.write(line)


def _clean(value, limit=200):
    out = "".join(c if c.isprintable() and not c.isspace() else "_" for c in value)
    return out[:limit] or "-"


def _oneline(value, limit=300):
    """An exception's message on one line, spaces kept, control characters
    dropped (the error line's last field)."""
    out = " ".join(str(value).split())
    return "".join(c for c in out if c.isprintable())[:limit]


def fingerprint():
    """sha256 over api.yaml and the endpoint files, by name and content."""
    h = hashlib.sha256()
    paths = [config.API_YAML]
    for d in (config.ROUTES_DIR, config.DB_DIR):
        try:
            paths += sorted(os.path.join(d, n) for n in os.listdir(d) if n.endswith(".py"))
        except OSError:
            pass
    for p in paths:
        h.update(p.encode() + b"\0")
        try:
            with open(p, "rb") as f:
                h.update(f.read())
        except OSError:
            h.update(b"<unreadable>")
        h.update(b"\0")
    return h.hexdigest()


def _json_response(status, detail, extra_headers=()):
    body = json.dumps({"detail": detail}, separators=(",", ":")).encode()
    headers = [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())]
    headers += list(extra_headers)
    return status, headers, body


class Dispatcher:
    def __init__(self, cfg, hosts, endpoint_of, credentials):
        self.cfg = cfg
        self.hosts = hosts                    # hostname -> FastAPI application
        self.endpoint_of = endpoint_of        # id(route) -> endpoint name
        self.credentials = credentials        # credential name -> secret

    async def _lifespan(self, receive, send):
        while True:
            message = await receive()
            if message["type"] == "lifespan.startup":
                try:
                    write_loaded(self.cfg)
                except OSError as exc:
                    await send({"type": "lifespan.startup.failed",
                                "message": f"{config.LOADED_FILE}: {exc.strerror}"})
                    return
                log_line(f"start pid={os.getpid()} hosts={','.join(self.cfg.hosts())} "
                         f"endpoints={','.join(self.cfg.endpoints)}")
                await send({"type": "lifespan.startup.complete"})
            elif message["type"] == "lifespan.shutdown":
                gm_pool.close_all()
                log_line(f"stop pid={os.getpid()}")
                await send({"type": "lifespan.shutdown.complete"})
                return

    def _match(self, app, scope):
        from starlette.routing import Match
        partial = None
        for route in app.router.routes:
            m, _ = route.matches(scope)
            if m == Match.FULL:
                return self.endpoint_of.get(id(route))
            if m == Match.PARTIAL and partial is None:
                partial = self.endpoint_of.get(id(route))
        return partial

    def _authorised(self, endpoint, scope):
        accepted = self.cfg.endpoints[endpoint].credentials
        if not accepted:
            return True
        value = None
        for k, v in scope.get("headers") or ():
            if k == b"authorization":
                value = v.decode("latin-1")
                break
        if not value or not value[:7].lower() == "bearer ":
            return False
        token = value[7:].strip().encode("utf-8", errors="replace")
        ok = False
        for name in accepted:
            if hmac.compare_digest(token, self.credentials[name].encode("utf-8")):
                ok = True
        return ok

    async def __call__(self, scope, receive, send):
        if scope["type"] == "lifespan":
            await self._lifespan(receive, send)
            return
        if scope["type"] != "http":
            return                             # no websockets
        t0 = time.monotonic()
        host = ""
        agent = "-"
        for k, v in scope.get("headers") or ():
            if k == b"host":
                host = v.decode("latin-1")
            elif k == b"user-agent":
                agent = v.decode("latin-1")
        hostname = host.rsplit(":", 1)[0] if not host.startswith("[") else host
        hostname = hostname.lower().rstrip(".")
        state = {"status": None, "started": False}
        scope.setdefault("state", {})

        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                state["status"] = message["status"]
                state["started"] = True
            await send(message)

        async def answer(status, detail, extra=()):
            s, headers, body = _json_response(status, detail, extra)
            await send_wrapper({"type": "http.response.start", "status": s, "headers": headers})
            await send_wrapper({"type": "http.response.body", "body": body})

        endpoint = None
        app = self.hosts.get(hostname)
        try:
            if app is None:
                await answer(404, "Not Found")
            else:
                endpoint = self._match(app, scope)
                if endpoint is not None and not self._authorised(endpoint, scope):
                    await answer(401, "unauthorized", [(b"www-authenticate", b"Bearer")])
                else:
                    await app(scope, receive, send_wrapper)
        except Exception as exc:
            log_line(f"error endpoint={endpoint or '-'} {type(exc).__name__}: {_oneline(exc)}")
            traceback.print_exc(file=sys.stderr)
            if not state["started"]:
                await answer(500, "Internal Server Error")
        err = scope["state"].get("gm_error")
        if err:
            log_line(f"error endpoint={endpoint or '-'} {err}")
        path = scope.get("raw_path") or scope.get("path", "").encode()
        path = path.decode("latin-1")
        if scope.get("query_string"):
            path += "?" + scope["query_string"].decode("latin-1")
        client = (scope.get("client") or ("-",))[0]
        ms = (time.monotonic() - t0) * 1000
        log_line(f"request status={state['status'] or '-'} ms={ms:.1f} method={scope.get('method')} "
                 f"host={_clean(hostname or '-', 100)} endpoint={endpoint or '-'} from={client} "
                 f"agent={_clean(agent, 64)} path={_clean(path, 500)}")


def write_loaded(cfg):
    lines = [f"loaded={utcnow()}", f"pid={os.getpid()}", f"fingerprint={fingerprint()}"]
    for h in cfg.hosts():
        names = [n for n, e in cfg.endpoints.items() if h in e.hosts]
        lines.append(f"host {h} {' '.join(names)}")
    tmp = config.LOADED_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(tmp, 0o644)
    os.replace(tmp, config.LOADED_FILE)


def _unavailable_handler(request, exc):
    from starlette.responses import JSONResponse
    request.scope.setdefault("state", {})["gm_error"] = f"{type(exc).__name__}: {_oneline(exc)}"
    return JSONResponse({"detail": "service unavailable"}, status_code=503)


def build(cfg=None):
    """-> (Dispatcher, cfg); raises ConfigError on the first problem."""
    import psycopg
    from fastapi import FastAPI

    cfg = cfg or config.load()
    credentials, passwords = config.secrets_for(cfg)
    loaded = check.load_endpoints(cfg)
    check.check_duplicates(cfg, loaded)
    hosts, endpoint_of = {}, {}
    for h in cfg.hosts():
        app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
        app.add_exception_handler(psycopg.OperationalError, _unavailable_handler)
        app.add_exception_handler(Unavailable, _unavailable_handler)
        for name, e in cfg.endpoints.items():
            if h not in e.hosts:
                continue
            before = len(app.router.routes)
            app.include_router(loaded[name][0])
            for r in app.router.routes[before:]:
                endpoint_of[id(r)] = name
        hosts[h] = app
    gm_pool.configure(cfg.connections, passwords)
    gm_http.configure(cfg.connections, passwords)
    return Dispatcher(cfg, hosts, endpoint_of, credentials), cfg


def create_app():
    """uvicorn's factory: the application, or exit 3 naming the first problem
    (the s6 service then waits a few seconds before it tries again)."""
    try:
        app, _ = build()
    except ConfigError as exc:
        log_line(f"fatal {exc}")
        print(f"gm-api: not started: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(3) from None
    return app
