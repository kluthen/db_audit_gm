"""gm_api.client (the wire form of capture W1 item 3) against a local
http.server, and the write policy's owners and modes (gm_api.policy)."""

import http.server
import json
import os
import stat
import tempfile
import threading
import time
import unittest

import gm_api
from gm_api import config, http as gm_http, policy

SEEN = []


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            pass                             # the client gave up first (the timeout test)

    def _answer(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        SEEN.append(("GET", self.path, dict(self.headers), b""))
        if self.path.startswith("/slow"):
            time.sleep(2)
        self._answer(404 if self.path.startswith("/missing") else 200, {"path": self.path})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        SEEN.append(("POST", self.path, dict(self.headers), body))
        self._answer(201, {"got": len(body)})


class TestClient(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        SEEN.clear()
        cfg = config.parse(f"""
endpoints: {{x: {{hosts: [a]}}}}
connections:
  partner: {{driver: http, target: "127.0.0.1:{self.port}", credential: xlab, pool: 1, timeout: 1s}}
  public: {{driver: http, target: "127.0.0.1:{self.port}"}}
  closed: {{driver: http, target: "127.0.0.1:1"}}
""")
        gm_http.configure(cfg.connections, {"partner": "tok-123"}, user_agent="lab-api")

    def test_the_wire_form(self):
        a = gm_api.client("partner").get("/orders", params={"since": "2026-11-03", "n": 2})
        self.assertEqual((a.status, a.json()), (200, {"path": "/orders?since=2026-11-03&n=2"}))
        method, path, headers, _ = SEEN[-1]
        self.assertEqual(headers["Authorization"], "Bearer tok-123")
        self.assertEqual(headers["Host"], f"127.0.0.1:{self.port}")
        self.assertEqual(headers["User-Agent"], "lab-api")
        a = gm_api.client("public").post("/results", {"id": 3})
        self.assertEqual(a.status, 201)
        _, _, headers, body = SEEN[-1]
        self.assertNotIn("Authorization", headers)
        self.assertEqual((headers["Content-Type"], json.loads(body)), ("application/json", {"id": 3}))
        gm_api.client("public").post("/ship", b'{"a":1}\n', headers={"Content-Type": "application/x-ndjson"})
        self.assertEqual((SEEN[-1][2]["Content-Type"], SEEN[-1][3]), ("application/x-ndjson", b'{"a":1}\n'))
        gm_api.client("public").post("/raw", b"\x00\x01")
        self.assertEqual(SEEN[-1][2]["Content-Type"], "application/octet-stream")

    def test_any_status_is_an_answer(self):
        a = gm_api.client("public").get("/missing")
        self.assertEqual(a.status, 404)
        self.assertIn("missing", a.text)

    def test_refused_and_timeout_raise_http_error(self):
        with self.assertRaises(gm_api.HttpError) as cm:
            gm_api.client("closed").get("/")
        self.assertEqual(cm.exception.status, "refused")
        with self.assertRaises(gm_api.HttpError) as cm:
            gm_api.client("partner").get("/slow")
        self.assertEqual(cm.exception.status, "timeout")

    def test_headers_never_set_authorization_or_host(self):
        for h in ("Authorization", "host"):
            with self.assertRaises(ValueError):
                gm_api.client("public").get("/", headers={h: "x"})

    def test_kept_alive_and_reused(self):
        c = gm_api.client("partner")
        for _ in range(3):
            self.assertEqual(c.get("/a").status, 200)
        self.assertEqual(len(c._idle), 1)


class TestPolicy(unittest.TestCase):

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="gmapi-policy-")
        for d in ("routes", "db"):
            os.makedirs(os.path.join(self.root, d))
        for rel in ("api.yaml", "routes/orders.py", "db/orders.py", "db/status.py"):
            with open(os.path.join(self.root, rel), "w") as f:
                f.write("x\n")
        os.symlink("/etc/passwd", os.path.join(self.root, "db", "link.py"))
        self.uid, self.gid = 4321, 4322

    def mode(self, rel):
        st = os.lstat(os.path.join(self.root, rel))
        return st.st_uid, st.st_gid, oct(stat.S_IMODE(st.st_mode))

    def test_fixable_report_only_override_and_no_access(self):
        if os.geteuid() != 0:
            self.skipTest("needs root (the unit-test image runs as root)")
        for pol, overrides, dmode, fmode in (("fixable", [], "0o2775", "0o664"),
                                             ("report-only", [], "0o2755", "0o644"),
                                             ("report-only", ["/srv/api/db"], "0o2775", "0o664"),
                                             ("no-access", [], "0o2755", "0o644")):
            notes = policy.restore(pol, overrides, root=self.root, uid=self.uid, gid=self.gid)
            self.assertEqual(self.mode("db"), (self.uid, self.gid, dmode), pol)
            self.assertEqual(self.mode("db/orders.py"), (self.uid, self.gid, fmode), pol)
            self.assertEqual(self.mode("routes"), (0, 0, "0o755"))
            self.assertEqual(self.mode("routes/orders.py"), (0, 0, "0o644"))
            self.assertEqual(self.mode("api.yaml"), (0, 0, "0o644"))
            self.assertEqual(notes, [f"{self.root}/db/link.py: a symbolic link, left alone"])
        self.assertEqual(os.stat("/etc/passwd").st_uid, 0)

    def test_the_entrypoints_refusals(self):
        self.assertIsNone(policy.check_policy("report-only", ["/srv/api/db"]))
        self.assertIn("is not one of", policy.check_policy("read-only", []))
        self.assertIn("writable_paths", policy.check_policy("report-only", ["/srv/api/routes"]))
        self.assertIn("no player", policy.check_policy("no-access", ["/srv/api/db"]))
        self.assertTrue(policy.db_fixable("fixable", []))
        self.assertFalse(policy.db_fixable("report-only", []))
        self.assertTrue(policy.db_fixable("report-only", ["/srv/api/db"]))
        self.assertFalse(policy.db_fixable("no-access", []))


if __name__ == "__main__":
    unittest.main()
