"""The fixture's loader: check_scenario as tools/gm/model.py's, its
result read from the scenario file (a line `missing: <item>` is a
missing item)."""

from pathlib import Path


def check_scenario(scenario_dir, catalog_root=None):
    text = (Path(scenario_dir) / "scenario.yaml").read_text()
    missing = [line.split(":", 1)[1].strip() for line in text.splitlines()
               if line.startswith("missing:")]
    return (None if missing else object()), missing
