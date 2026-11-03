"""Build assertions of the api image (G6's conditions, specs/versions/v0.5/
wave-log.md; run by the Dockerfile with python3 -I, never shipped):
Python 3.13; each package of requirements.txt installed at exactly its pin;
psycopg on its pure-Python implementation over Debian's libpq, version 17 or
later (never psycopg[binary]'s bundled one); no other distribution in
/usr/local/lib/python3.13/dist-packages; the brick's own modules import.
Usage: python3 -I check-image.py <requirements.txt>
"""

import importlib.metadata as md
import re
import sys

assert sys.version_info[:2] == (3, 13), sys.version

pins = {}
with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        m = re.match(r"^([A-Za-z0-9_.-]+)==([^ ]+)\s+--hash=sha256:[0-9a-f]{64}\s*$", line)
        if m:
            pins[m.group(1).lower().replace("_", "-")] = m.group(2)
        else:
            assert not line.strip() or line.startswith("#"), f"requirements.txt: {line!r}"
assert len(pins) == 15, f"{len(pins)} pins, G6 gave 15"
for name, version in sorted(pins.items()):
    got = md.version(name)
    assert got == version, f"{name} {got}, pinned {version}"

local = set()
for d in md.distributions(path=["/usr/local/lib/python3.13/dist-packages"]):
    local.add(d.metadata["Name"].lower().replace("_", "-"))
assert local == set(pins), f"dist-packages holds {sorted(local - set(pins))} beyond the pins, " \
    f"lacks {sorted(set(pins) - local)}"

import psycopg  # noqa: E402

assert psycopg.pq.__impl__ == "python", psycopg.pq.__impl__
assert psycopg.pq.version() >= 170000, psycopg.pq.version()
import yaml  # noqa: E402  (Debian's python3-yaml: api.yaml, safe loading only)
import fastapi, uvicorn, gm_api, gm_api.app, gm_api.__main__  # noqa: E401,E402,F401

print(f"image checks: Python {sys.version.split()[0]}, {len(pins)} pins as G6 gave them, psycopg "
      f"{psycopg.__version__} ({psycopg.pq.__impl__}) over libpq {psycopg.pq.version()}, "
      f"PyYAML {yaml.__version__}")
