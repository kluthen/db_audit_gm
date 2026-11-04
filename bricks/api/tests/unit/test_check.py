"""The endpoint pairs' checks (gm_api.check): what the server, gm-reload-api
and the validator refuse, each named by file and line."""

import textwrap
import unittest

from gm_api import ConfigError, app

from apitest import ORDERS_DB as _DB, ORDERS_ROUTE as _ROUTE, standard_node

ORDERS_DB = textwrap.dedent(_DB)
ORDERS_ROUTE = textwrap.dedent(_ROUTE)


class TestCheck(unittest.TestCase):

    def setUp(self):
        self.node = standard_node()

    def tearDown(self):
        self.node.close()

    def assertRefused(self, fragment):
        with self.assertRaises(ConfigError) as cm:
            app.build()
        self.assertIn(fragment, str(cm.exception))
        return str(cm.exception)

    def test_the_standard_pair_builds(self):
        dispatcher, cfg = app.build()
        self.assertEqual(sorted(dispatcher.hosts), ["lab-api", "xlab"])

    def test_a_missing_file(self):
        self.node.remove("db/orders.py")
        self.assertRefused("endpoints.orders: db/orders.py is missing")
        self.node.write("db/orders.py", ORDERS_DB)
        self.node.remove("routes/status.py")
        self.assertRefused("routes/status.py is missing")

    def test_a_route_imports_only_fastapi_pydantic_the_standard_library_and_db(self):
        self.node.write("routes/orders.py", "import json, typing\n" + ORDERS_ROUTE.replace(
            "from db import orders", "from db import orders\nimport psycopg"))
        self.assertRefused("routes/orders.py: line")
        msg = self.assertRefused("imports psycopg; a route file imports FastAPI, Pydantic")
        self.assertNotIn("json", msg)
        self.node.write("routes/orders.py", "from db import nowhere\n")
        self.assertRefused("from db import nowhere: there is no db/nowhere.py")
        self.node.write("routes/orders.py", "from . import x\n")
        self.assertRefused("a relative import")
        self.node.write("routes/orders.py", "import gm_api\n")
        self.assertRefused("imports gm_api; a route file")

    def test_a_db_file_imports_only_psycopg_the_standard_library_and_gm_api(self):
        self.node.write("db/status.py", "import fastapi\n")
        self.assertRefused("db/status.py: line 1: imports fastapi; a db file imports psycopg, "
                           "the standard library and gm_api only")
        self.node.write("db/status.py", "import gm_api.config\n")
        self.assertRefused("uses gm_api itself, not its modules")
        self.node.write("db/status.py", "import psycopg.rows, datetime\nfrom gm_api import connection\n"
                        "def status():\n    return {'ok': True}\n")
        app.build()

    def test_a_syntax_error_is_named_by_line(self):
        self.node.write("db/orders.py", ORDERS_DB + "\ndef broken(:\n")
        self.assertRefused("db/orders.py: line")
        self.assertRefused("SyntaxError")

    def test_an_exception_on_import_is_named(self):
        self.node.write("db/orders.py", ORDERS_DB + "\nLIMIT = int('ten')\n")
        self.assertRefused("ValueError on import")

    def test_a_route_without_router(self):
        self.node.write("routes/status.py", "from fastapi import APIRouter\nr = APIRouter()\n")
        self.assertRefused("routes/status.py: defines no `router`")

    def test_an_async_route_is_refused(self):
        self.node.write("routes/status.py", "from fastapi import APIRouter\nimport db.status\n"
                        "router = APIRouter()\n@router.get('/status')\nasync def s():\n"
                        "    return db.status.status()\n")
        self.assertRefused("routes/status.py: /status: an async def route; routes are plain def")

    def test_a_db_side_dropping_a_function_the_route_calls(self):
        self.node.write("db/orders.py", ORDERS_DB.replace("def find(", "def find_one("))
        self.assertRefused("uses find of db/orders.py, which db/orders.py does not define")
        self.node.write("db/orders.py", ORDERS_DB)
        self.node.write("db/status.py", "def state():\n    return {}\n")
        self.assertRefused("routes/status.py: line")             # import db.status; db.status.status()

    def test_db_names_only_api_yamls_connections(self):
        self.node.write("db/status.py", "import gm_api\ndef status():\n"
                        "    with gm_api.connection('nowhere') as c:\n        pass\n")
        self.assertRefused("db/status.py: line 3: gm_api.connection('nowhere'): not an "
                           "sql/postgresql connection of api.yaml")
        self.node.write("db/status.py", "from gm_api import client\ndef status():\n"
                        "    return client('lab').get('/')\n")
        self.assertRefused("gm_api.client('lab'): not an http connection")

    def test_two_routes_of_one_host_declaring_one_method_and_path(self):
        from apitest import api_yaml
        self.node.write("routes/status.py", "from fastapi import APIRouter\nimport db.status\n"
                        "router = APIRouter()\n@router.get('/orders/{x}')\ndef s(x: int):\n"
                        "    return db.status.status()\n")
        app.build()                                        # on two hostnames: no clash
        self.node.write("api.yaml", api_yaml(orders_hosts="[lab-api]", status_hosts="[xlab, lab-api]"))
        self.assertRefused("host lab-api: GET /orders/{x} (routes/status.py) is GET "
                           "/orders/{order_id} of routes/orders.py")

    def test_a_missing_secret_is_named_never_valued(self):
        import os
        os.remove(os.path.join(self.node.run, "secrets", "http_other_key"))
        msg = self.assertRefused("credentials: other_key: its secret http_other_key is not mounted")
        self.assertNotIn("s3cret", msg)


if __name__ == "__main__":
    unittest.main()
