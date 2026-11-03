# Stack test fixture of the scheduler brick (v0.5): a stand-in HTTP/1.1
# server for the HTTP driver, `stub` on the stack's network (a network
# alias), port 8080. Not a brick: the brick under test is the scheduler.
# Prints one `REQ <json>` line per request on standard output (the test
# reads `docker logs`): method, path, the Host, User-Agent, Authorization
# and Content-Type headers, the JSON body parsed or the raw body's length,
# the client's address. /fail answers 503 with a long body, /slow after
# 3 s, anything else 201 with a receipt; a kept connection idle 5 s is
# closed (as uvicorn does), so the caller's reconnection is exercised.
import http.server
import json
import threading
import time

PORT = 8080
IDLE = 5
_lock = threading.Lock()
_count = 0


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = IDLE

    def log_message(self, *args):
        pass

    def answer(self):
        global _count
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        rec = {"method": self.command, "path": self.path, "host": self.headers.get("Host"),
               "agent": self.headers.get("User-Agent"), "auth": self.headers.get("Authorization"),
               "type": self.headers.get("Content-Type"), "peer": "%s:%s" % self.client_address, "size": len(body)}
        if body and rec["type"] == "application/json":
            try:
                rec["json"] = json.loads(body)
            except ValueError:
                rec["json"] = "not JSON"
        with _lock:
            _count += 1
            number = _count
            print("REQ " + json.dumps(rec, sort_keys=True), flush=True)
        if self.path.startswith("/slow"):
            time.sleep(3)
            status, out = 200, b"{}"
        elif self.path.startswith("/fail"):
            status, out = 503, ("the lab is closed for maintenance; " * 12).encode()
        else:
            status, out = 201, json.dumps({"accession": f"A{number:06d}", "received": len(body)}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = answer


server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
server.daemon_threads = True
print(f"stub: listening on {PORT}", flush=True)
server.serve_forever()
