"""api.yaml as the brick reads it (capture W1 item 5, chunk 2's template)."""

import textwrap
import unittest

from gm_api import ConfigError, config


def parse(text):
    return config.parse(textwrap.dedent(text))


GOOD = """
    endpoints:
      orders:
        hosts: [lab-api]
        credentials: [interfaces_lab_api]
      xlab_results:
        hosts: [xlab, xlab-backup]
    connections:
      lab: {driver: sql/postgresql, target: lab:5432/lab, role: lab_api, pool: {size: 4}}
      once: {driver: sql/postgresql, target: lab:6432/lab, role: lab_once, pool: {per-call: true}}
      xlab-results: {driver: http, target: lab-api:8000, credential: xlab_results, pool: 1}
      public: {driver: http, target: owners:8000, timeout: 3s}
"""


class TestParse(unittest.TestCase):

    def test_the_template_shape(self):
        cfg = parse(GOOD)
        self.assertEqual(list(cfg.endpoints), ["orders", "xlab_results"])
        self.assertEqual(cfg.endpoints["orders"].credentials, ("interfaces_lab_api",))
        self.assertEqual(cfg.endpoints["xlab_results"].credentials, ())
        self.assertEqual(cfg.hosts(), ["lab-api", "xlab", "xlab-backup"])
        lab = cfg.connections["lab"]
        self.assertEqual((lab.host, lab.port, lab.database, lab.role, lab.pool_size, lab.per_call),
                         ("lab", 5432, "lab", "lab_api", 4, False))
        self.assertTrue(cfg.connections["once"].per_call)
        x = cfg.connections["xlab-results"]
        self.assertEqual((x.driver, x.host, x.port, x.credential, x.pool_size, x.timeout, x.target),
                         ("http", "lab-api", 8000, "xlab_results", 1, 10, "lab-api:8000"))
        self.assertEqual(cfg.connections["public"].timeout, 3)
        self.assertIsNone(cfg.connections["public"].credential)
        self.assertEqual(cfg.target_hosts(), ["lab", "lab-api", "owners"])

    def test_connections_are_optional(self):
        cfg = parse("endpoints: {status: {hosts: [owners]}}")
        self.assertEqual(cfg.connections, {})
        self.assertEqual(cfg.target_hosts(), [])

    def assertRefused(self, text, fragment):
        with self.assertRaises(ConfigError) as cm:
            parse(text)
        self.assertIn(fragment, str(cm.exception))

    def test_refusals(self):
        self.assertRefused("endpoints: {}", "endpoints: not a non-empty mapping")
        self.assertRefused("endpoints: {Orders: {hosts: [a]}}", "endpoints.Orders: not an endpoint name")
        self.assertRefused("endpoints: {lab-orders: {hosts: [a]}}", "not an endpoint name")
        self.assertRefused("endpoints: {orders: {hosts: []}}", "hosts: not a non-empty list")
        self.assertRefused("endpoints: {orders: {hosts: [a, a]}}", "listed twice")
        self.assertRefused("endpoints: {orders: {hosts: [a], credentials: []}}", "credentials: not a non-empty")
        self.assertRefused("endpoints: {orders: {hosts: [a], public: true}}", "orders.public: not a key")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nroutes: {}", "routes: not a key of api.yaml")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: mysql}}",
                           "driver: 'mysql' is not")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: sql/postgresql, "
                           "target: lab:5432, role: r}}", "is not <node>:<port>/<database>")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: sql/postgresql, "
                           "target: lab:5432/lab}}", "role: None is not a role name")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: sql/postgresql, "
                           "target: lab:5432/lab, role: r, timeout: 3s}}", "an http connection's key")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: http, "
                           "target: lab:8000, role: r}}", "an http connection has no role")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: http, "
                           "target: lab:8000, pool: {size: 2}}}", "not a positive integer")
        self.assertRefused("endpoints: {o: {hosts: [a]}}\nconnections: {c: {driver: http, "
                           "target: lab:8000, timeout: 61s}}", "is not <n>s, 1 to 60")

    def test_a_duplicate_key_is_refused(self):
        self.assertRefused("endpoints:\n  o: {hosts: [a]}\n  o: {hosts: [b]}\n", "duplicate key 'o'")


if __name__ == "__main__":
    unittest.main()
