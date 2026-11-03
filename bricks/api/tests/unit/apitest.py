"""Helpers of gm_api's unit tests: a node's files in a temporary folder, and
an ASGI request without a server."""

import asyncio
import json
import os
import shutil
import tempfile
import textwrap

from gm_api import config

PG = {k: os.environ.get(f"GM_TEST_PG_{k.upper()}") for k in ("host", "port", "db", "role", "password")}


class Node:
    """A node's /srv/api, /run/gm-api and request log under a temporary folder;
    config's paths point there until close()."""

    def __init__(self, api_yaml, routes=None, db=None, secrets=None):
        self.dir = tempfile.mkdtemp(prefix="gmapi-")
        self.root = os.path.join(self.dir, "srv")
        self.run = os.path.join(self.dir, "run")
        self.log = os.path.join(self.dir, "api.log")
        for d in ("routes", "db"):
            os.makedirs(os.path.join(self.root, d))
        os.makedirs(os.path.join(self.run, "secrets"))
        self.write("api.yaml", api_yaml)
        for name, text in (routes or {}).items():
            self.write(f"routes/{name}.py", text)
        for name, text in (db or {}).items():
            self.write(f"db/{name}.py", text)
        for name, value in (secrets or {}).items():
            with open(os.path.join(self.run, "secrets", name), "w") as f:
                f.write(value)
        config.set_paths(self.root, self.run, self.log)

    def write(self, rel, text):
        with open(os.path.join(self.root, rel), "w") as f:
            f.write(textwrap.dedent(text))

    def remove(self, rel):
        os.remove(os.path.join(self.root, rel))

    def log_lines(self):
        try:
            with open(self.log) as f:
                return f.read().splitlines()
        except FileNotFoundError:
            return []

    def close(self):
        from gm_api import pool
        pool.close_all()
        config.set_paths()
        shutil.rmtree(self.dir, ignore_errors=True)


def request(app, method, path, host, headers=None, body=b"", client=("10.0.0.9", 40000)):
    """-> (status, headers dict, body bytes) of one request through the app."""
    if isinstance(body, (dict, list)):
        body = json.dumps(body).encode()
        headers = dict(headers or {}, **{"content-type": "application/json"})
    raw_path, _, query = path.partition("?")
    hdrs = [(b"host", host.encode())] + [(k.lower().encode(), v.encode())
                                         for k, v in (headers or {}).items()]
    scope = {"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1", "method": method,
             "scheme": "http", "path": raw_path, "raw_path": raw_path.encode(),
             "query_string": query.encode(), "root_path": "", "headers": hdrs, "client": client,
             "server": ("127.0.0.1", 8000)}
    sent = []
    messages = [{"type": "http.request", "body": body, "more_body": False}]

    async def receive():
        if messages:
            return messages.pop(0)
        await asyncio.sleep(3600)

    async def send(message):
        sent.append(message)

    asyncio.run(app(scope, receive, send))
    start = next(m for m in sent if m["type"] == "http.response.start")
    data = b"".join(m.get("body", b"") for m in sent if m["type"] == "http.response.body")
    return start["status"], {k.decode(): v.decode() for k, v in start["headers"]}, data


ORDERS_ROUTE = """
    from fastapi import APIRouter, HTTPException
    from pydantic import BaseModel

    from db import orders

    router = APIRouter()


    class Order(BaseModel):
        id: int
        label: str


    @router.get("/orders/{order_id}")
    def get_order(order_id: int):
        row = orders.find(order_id)
        if row is None:
            raise HTTPException(status_code=404, detail="no such order")
        return row


    @router.post("/orders", status_code=201)
    def post_order(order: Order):
        return orders.add(order.id, order.label)


    @router.get("/whoami")
    def whoami(owner: str = "-"):
        return orders.whoami(owner)


    @router.get("/boom")
    def boom():
        return orders.boom()
"""

ORDERS_DB = """
    import gm_api

    SESSION = {"statement_timeout": "5s"}


    def find(order_id):
        with gm_api.connection("lab", session=SESSION) as conn:
            row = conn.execute("SELECT id, label FROM orders WHERE id = %s", (order_id,)).fetchone()
        return None if row is None else {"id": row[0], "label": row[1]}


    def add(order_id, label):
        with gm_api.connection("lab") as conn:
            conn.execute("INSERT INTO orders VALUES (%s, %s)", (order_id, label))
            conn.commit()
        return {"id": order_id, "label": label}


    def whoami(owner):
        with gm_api.connection("lab", session=SESSION) as conn:
            before = conn.execute("SELECT current_setting('portal.owner_id', true)").fetchone()[0]
            conn.execute("SELECT set_config('portal.owner_id', %s, true)", (owner,))
            definer = conn.execute("SELECT record_owner()").fetchone()[0]
            row = conn.execute("SELECT current_user, current_setting('portal.owner_id', true), "
                               "current_setting('statement_timeout')").fetchone()
        return {"user": row[0], "owner": row[1], "before": before, "timeout": row[2],
                "definer": definer}


    def boom():
        raise RuntimeError("the database side failed")
"""

STATUS_ROUTE = """
    from fastapi import APIRouter

    import db.status

    router = APIRouter()


    @router.get("/status")
    def status():
        return db.status.status()
"""

STATUS_DB = """
    def status():
        return {"ok": True}
"""


def api_yaml(orders_hosts="[lab-api]", status_hosts="[xlab]", target=None):
    t = target or f"{PG['host'] or '127.0.0.1'}:{PG['port'] or 5432}/{PG['db'] or 'lab'}"
    return f"""
        endpoints:
          orders:
            hosts: {orders_hosts}
            credentials: [lab_key, other_key]
          status:
            hosts: {status_hosts}
        connections:
          lab: {{driver: sql/postgresql, target: "{t}", role: {PG['role'] or 'lab_api'}, pool: {{size: 2}}}}
    """


def secrets():
    return {"http_lab_key": "s3cret-lab\n", "http_other_key": "s3cret-other",
            f"role_{PG['role'] or 'lab_api'}_password": (PG["password"] or "x") + "\n"}


def standard_node(**kw):
    return Node(api_yaml(**kw), routes={"orders": ORDERS_ROUTE, "status": STATUS_ROUTE},
                db={"orders": ORDERS_DB, "status": STATUS_DB}, secrets=secrets())
