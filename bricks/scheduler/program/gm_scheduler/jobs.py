"""Fixed-time operations: `jobs.yaml` (master spec 7.1; capture W1 item 7).

    jobs:
      - name: close-day
        key: invoices.close-day       # a key of queries.yaml
        connection: app               # a connection of the schedule
        at: "30 1 * * *"              # numeric 5-field cron
        timezone: Etc/GMT-3           # optional: a zone tzdata names; UTC when absent

The rendered file is in UTC; a player may edit the times and zones.
"""

import re

from . import ConfigError
from .cron import Cron
from .repository import KEY_RE, load_yaml, read_regular

NAME_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
JOBS_FILE = "jobs.yaml"


class Job:
    def __init__(self, name, key, connection, cron):
        self.name, self.key, self.connection, self.cron = name, key, connection, cron


def parse_jobs(doc):
    if doc is None:
        doc = {"jobs": []}
    if not isinstance(doc, dict) or set(doc) != {"jobs"}:
        raise ConfigError(f"{JOBS_FILE}: one top-level key, jobs")
    items = doc["jobs"]
    if items is None:
        items = []
    if not isinstance(items, list):
        raise ConfigError(f"{JOBS_FILE}: jobs is a list")
    jobs, names = [], set()
    for i, item in enumerate(items):
        where = f"{JOBS_FILE}: jobs[{i}]"
        if not isinstance(item, dict):
            raise ConfigError(f"{where}: a map with name, key, connection, at")
        unknown = set(item) - {"name", "key", "connection", "at", "timezone"}
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        name = item.get("name")
        if not isinstance(name, str) or not NAME_RE.match(name):
            raise ConfigError(f"{where}.name: lowercase letters, digits, '.', '_', '-'")
        where = f"{JOBS_FILE}: job {name}"
        if name in names:
            raise ConfigError(f"{where}: the name is used twice")
        names.add(name)
        key = item.get("key")
        if not isinstance(key, str) or not KEY_RE.match(key):
            raise ConfigError(f"{where}.key: a key of queries.yaml")
        connection = item.get("connection")
        if not isinstance(connection, str) or not connection:
            raise ConfigError(f"{where}.connection: a connection name")
        try:
            cron = Cron(item.get("at"), item.get("timezone", "UTC"))
        except ConfigError as exc:
            raise ConfigError(f"{where}: {exc}") from None
        jobs.append(Job(name, key, connection, cron))
    return jobs


def load_jobs(path):
    return parse_jobs(load_yaml(read_regular(path, JOBS_FILE), JOBS_FILE))
