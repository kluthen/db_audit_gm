"""Merge the archive fixture's planted overlays into a copy of the fixture
(v0.5 chunk 23; capture W5 item 0 of specs/versions/v0.5/wave-log.md).

The committed fixture stays unfaulted; a fault's short test plants it on a
copy, from its overlay under planted/<fault-id>/: `scenario.yaml` (the fault
instances and issues to append), `gm/answer-key.yaml` (the answer-key
entries to append) and any other file at its scenario path (a seed change,
the register the data-register skill generated for the merged copy), copied
over the copy's. The overlays are merged in the order given; the difficulty
score follows the instances. The copy's README is not regenerated. The
loader never reads planted/.

s2 and s6 are planted together (master spec 17.2), s2 first: s6's overlay
carries the register generated for that merge (its digests name the merged
scenario.yaml and answer key), so the merge must stay byte-for-byte what it
is: PyYAML's safe_dump, keys in their order.

Usage: python3 merge.py <copy of the fixture> <fault-id> [<fault-id> ...]
"""

import shutil
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
FRAGMENTS = ("scenario.yaml", "gm/answer-key.yaml")


def _load(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def _dump(data, path):
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True, width=100)


def merge(copy, fault_ids, overlays=HERE):
    copy, overlays = Path(copy), Path(overlays)
    scenario = _load(copy / "scenario.yaml")
    key = _load(copy / "gm" / "answer-key.yaml")
    for fid in fault_ids:
        overlay = overlays / fid
        if not overlay.is_dir():
            raise SystemExit(f"merge: no overlay {overlay}")
        fragment = _load(overlay / "scenario.yaml") or {}
        scenario["fault_instances"] = list(scenario.get("fault_instances") or []) \
            + list(fragment.get("fault_instances") or [])
        scenario["issues"] = list(scenario.get("issues") or []) + list(fragment.get("issues") or [])
        entries = _load(overlay / "gm" / "answer-key.yaml") or {}
        key["instances"] = list(key.get("instances") or []) + list(entries.get("instances") or [])
        for path in sorted(overlay.rglob("*")):
            rel = path.relative_to(overlay).as_posix()
            if path.is_file() and rel not in FRAGMENTS:
                (copy / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, copy / rel)
    scenario["difficulty"]["score"] = len(scenario["fault_instances"])
    _dump(scenario, copy / "scenario.yaml")
    _dump(key, copy / "gm" / "answer-key.yaml")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip().splitlines()[-1])
    merge(sys.argv[1], sys.argv[2:])
