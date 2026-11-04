"""The v0.5 monitoring fixture (build plan chunk 10): it loads, fits and
renders, and each new monitor targeting a node without the option
`monitoring` is refused (master spec 7.1 item 3, 7.4; capture W2 items 1
and 5, W2-a)."""

import shutil

import yaml

from tools.gm import fit, model, render
from tools.tests import FIXTURES, ScenarioCopyTest

FIXTURE_MONITORING_V05 = FIXTURES / "fixture-monitoring-v05"
NODES = ("bastion", "records", "prometheus", "pgwatch", "grafana", "health")


class MonitoringV05Copy(ScenarioCopyTest):

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-monitoring-v05"
        shutil.copytree(FIXTURE_MONITORING_V05, self.scenario)

    def load(self):
        return model.load_scenario(self.scenario)

    def refused(self):
        with self.assertRaises(model.IncompleteScenario) as cm:
            self.load()
        return "\n".join(cm.exception.missing)


class TestMonitoringV05Fixture(MonitoringV05Copy):

    def test_loads_with_its_six_nodes(self):
        sc = self.load()
        self.assertEqual(tuple(n["name"] for n in sc.data["nodes"]), NODES)
        self.assertEqual(sc.node("records")["options"], ["monitoring"])
        self.assertEqual({n: sc.bricks[n].id for n in ("pgwatch", "health", "grafana")},
                         {"pgwatch": "pgwatch", "health": "health-check", "grafana": "grafana"})

    def test_the_monitors_targets(self):
        sc = self.load()
        for name in ("pgwatch", "health"):
            with self.subTest(monitor=name):
                self.assertEqual(model.monitor_targets(sc.node(name), sc.bricks[name],
                                                       self.scenario), ["records"])

    def test_prometheus_scrapes_pgwatch_and_the_bastion_routes_health(self):
        sc = self.load()
        prom = yaml.safe_load((self.scenario / "nodes/prometheus/prometheus.yml").read_text())
        jobs = {j["job_name"]: j["static_configs"][0]["targets"] for j in prom["scrape_configs"]}
        self.assertEqual(jobs["pgwatch"], ["pgwatch:9188"])
        self.assertEqual(sorted(jobs["node-health"]), sorted(f"{n}:9110" for n in NODES))
        self.assertEqual(sc.node("bastion")["parameters"]["web_routes"]["health"], "health:8080")
        self.assertIn("pgwatch.json", sc.node("grafana")["seed_files"])

    def test_fits_the_laptop_playground_and_renders(self):
        result = fit.fit(self.scenario, "laptop", cpu="2", memory="4G", disk="8G")
        self.assertTrue(result.ok, result.text())
        rendered = render.render(self.scenario, "laptop")
        self.assertIn("health.conf", [p.name for p in rendered.node_config_files])


class TestMonitorWithoutTheOption(MonitoringV05Copy):
    """records without the option: each monitor targeting it is refused."""

    def drop_option(self):
        path = self.scenario / "scenario.yaml"
        data = yaml.safe_load(path.read_text())
        next(n for n in data["nodes"] if n["name"] == "records").pop("options")
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def test_each_monitor_is_refused(self):
        self.drop_option()
        text = self.refused()
        for rel, name, brick in (("nodes/pgwatch/sources.yaml", "pgwatch", "pgwatch"),
                                 ("nodes/health/health.yaml", "health", "health-check")):
            with self.subTest(monitor=name):
                self.assertIn(f"{rel}: node {name} ({brick}) monitors records, but node records "
                              "does not choose option monitoring", text)

    def test_a_disabled_pgwatch_source_is_no_target(self):
        self.drop_option()
        src = self.scenario / "nodes/pgwatch/sources.yaml"
        src.write_text(src.read_text().replace("is_enabled: true", "is_enabled: false"))
        text = self.refused()
        self.assertNotIn("node pgwatch (pgwatch) monitors records", text)
        self.assertIn("node health (health-check) monitors records", text)
