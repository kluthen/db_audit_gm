"""The dispatcher (gm_api.app): by hostname, the credential before anything
runs, the request log, 503 and 500; against the throwaway PostgreSQL."""

import json
import re
import unittest

from gm_api import app

from apitest import request, standard_node

LAB = {"Authorization": "Bearer s3cret-lab"}
LINE_RE = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z request status=(\S+) ms=[0-9.]+ "
                     r"method=(\S+) host=(\S+) endpoint=(\S+) from=(\S+) agent=(\S+) path=(.*)$")


class TestDispatch(unittest.TestCase):

    def setUp(self):
        self.node = standard_node()
        self.app, _ = app.build()

    def tearDown(self):
        self.node.close()

    def call(self, method, path, host, headers=None, body=b""):
        status, headers, data = request(self.app, method, path, host, headers, body)
        try:
            return status, headers, json.loads(data) if data else None
        except ValueError:
            return status, headers, data.decode()

    def test_each_hostname_answers_only_its_own_routes(self):
        self.assertEqual(self.call("GET", "/orders/1", "lab-api", LAB)[::2], (200, {"id": 1, "label": "first"}))
        self.assertEqual(self.call("GET", "/orders/1", "lab-api:8000", LAB)[0], 200)
        self.assertEqual(self.call("GET", "/orders/1", "LAB-API", LAB)[0], 200)
        self.assertEqual(self.call("GET", "/status", "xlab")[::2], (200, {"ok": True}))
        self.assertEqual(self.call("GET", "/status", "lab-api", LAB)[0], 404)
        self.assertEqual(self.call("GET", "/orders/1", "xlab", LAB)[0], 404)
        self.assertEqual(self.call("GET", "/orders/1", "elsewhere", LAB)[0], 404)
        self.assertEqual(self.call("GET", "/docs", "lab-api", LAB)[0], 404)
        self.assertEqual(self.call("GET", "/openapi.json", "xlab")[0], 404)

    def test_a_missing_or_wrong_credential_answers_401_before_the_route_runs(self):
        status, headers, body = self.call("GET", "/orders/1", "lab-api")
        self.assertEqual((status, body, headers.get("www-authenticate")), (401, {"detail": "unauthorized"}, "Bearer"))
        self.assertEqual(self.call("GET", "/orders/1", "lab-api", {"Authorization": "Bearer nope"})[0], 401)
        self.assertEqual(self.call("GET", "/orders/1", "lab-api", {"Authorization": "s3cret-lab"})[0], 401)
        self.assertEqual(self.call("GET", "/orders/1", "lab-api", {"Authorization": "Bearer s3cret-other"})[0], 200)
        self.assertEqual(self.call("GET", "/orders/1", "lab-api", {"Authorization": "bearer s3cret-lab"})[0], 200)
        # an invalid body without the credential: 401, never 422 (nothing parsed it)
        self.assertEqual(self.call("POST", "/orders", "lab-api", {"content-type": "application/json"},
                                   b"{not json")[0], 401)
        self.assertEqual(self.call("POST", "/orders", "lab-api", dict(LAB, **{"content-type": "application/json"}),
                                   b"{not json")[0], 422)
        # a wrong method on a protected path: 401 first
        self.assertEqual(self.call("DELETE", "/orders/1", "lab-api")[0], 401)
        self.assertEqual(self.call("DELETE", "/orders/1", "lab-api", LAB)[0], 405)

    def test_the_request_log(self):
        self.call("GET", "/orders/1?x=1", "lab-api:8000", dict(LAB, **{"User-Agent": "lis node"}))
        self.call("GET", "/orders/1", "lab-api")
        self.call("GET", "/nothing", "nowhere")
        lines = [l for l in self.node.log_lines() if " request " in l]
        self.assertEqual(len(lines), 3)
        got = [LINE_RE.match(l).groups() for l in lines]
        self.assertEqual(got[0], ("200", "GET", "lab-api", "orders", "10.0.0.9", "lis_node", "/orders/1?x=1"))
        self.assertEqual(got[1][:4], ("401", "GET", "lab-api", "orders"))
        self.assertEqual(got[2][:4], ("404", "GET", "nowhere", "-"))
        self.assertFalse(any("s3cret" in l for l in self.node.log_lines()))

    def test_an_exception_answers_500_and_logs_an_error_line(self):
        status, _, body = self.call("GET", "/boom", "lab-api", LAB)
        self.assertEqual(status, 500)
        errors = [l for l in self.node.log_lines() if " error " in l]
        self.assertEqual(len(errors), 1)
        self.assertIn("error endpoint=orders RuntimeError: the database side failed", errors[0])

    def test_a_transaction_local_setting_never_outlives_its_request(self):
        first = self.call("GET", "/whoami?owner=42", "lab-api", LAB)[2]
        self.assertEqual((first["user"], first["owner"], first["timeout"]), ("lab_api", "42", "5s"))
        self.assertEqual(first["definer"], "postgres")             # the SECURITY DEFINER function
        for _ in range(4):                                         # every pooled session
            again = self.call("GET", "/whoami?owner=7", "lab-api", LAB)[2]
            self.assertIn(again["before"], (None, ""))
            self.assertEqual(again["owner"], "7")


class TestUnavailable(unittest.TestCase):

    def test_a_database_out_of_reach_answers_503(self):
        node = standard_node()
        node.write("api.yaml", __import__("apitest").api_yaml(target="127.0.0.1:1/lab"))
        try:
            dispatcher, _ = app.build()
            status, _, data = request(dispatcher, "GET", "/orders/1", "lab-api", LAB)
            self.assertEqual((status, json.loads(data)), (503, {"detail": "service unavailable"}))
            errors = [l for l in node.log_lines() if " error " in l]
            self.assertTrue(errors and "endpoint=orders OperationalError" in errors[0], errors)
        finally:
            node.close()


if __name__ == "__main__":
    unittest.main()
