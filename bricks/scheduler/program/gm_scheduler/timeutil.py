"""Durations, rates and UTC instants, in the forms of capture W1 item 0."""

import datetime
import re

from . import ConfigError

UTC = datetime.timezone.utc

DURATION_RE = re.compile(r"^([0-9]+)(s|m|h|d)$")
DURATION_UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400}
RATE_RE = re.compile(r"^([0-9]+(?:\.[0-9]+)?)/(s|min|h)$")
RATE_UNITS = {"s": 1, "min": 60, "h": 3600}
INSTANT_RE = re.compile(r"^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z$")


def parse_duration(value, where):
    """`30s`, `16h`, `2d`, `0m` -> seconds (an int)."""
    m = DURATION_RE.match(value) if isinstance(value, str) else None
    if not m:
        raise ConfigError(f"{where}: a duration is <integer><s|m|h|d>, such as 30s or 2m")
    return int(m.group(1)) * DURATION_UNITS[m.group(2)]


def parse_rate(value, where):
    """`40/min`, `2/h`, `0.5/s` -> calls per second (a float)."""
    m = RATE_RE.match(value) if isinstance(value, str) else None
    if not m:
        raise ConfigError(f"{where}: a rate is <number>/s, /min or /h, such as 40/min")
    return float(m.group(1)) / RATE_UNITS[m.group(2)]


def parse_instant(value, where):
    """`YYYY-MM-DDTHH:MM:SSZ` -> seconds since the epoch (a float)."""
    m = INSTANT_RE.match(value) if isinstance(value, str) else None
    if not m:
        raise ConfigError(f"{where}: a UTC instant is YYYY-MM-DDTHH:MM:SSZ")
    try:
        dt = datetime.datetime(*(int(g) for g in m.groups()), tzinfo=UTC)
    except ValueError:
        raise ConfigError(f"{where}: not a valid date and time") from None
    return dt.timestamp()


def instant(ts):
    """Seconds since the epoch -> `YYYY-MM-DDTHH:MM:SSZ` (UTC, truncated)."""
    return datetime.datetime.fromtimestamp(int(ts), UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def minute_label(minute_start):
    """The start of a UTC minute -> `YYYY-MM-DDTHH:MMZ`, the summary's `minute`."""
    return datetime.datetime.fromtimestamp(int(minute_start), UTC).strftime("%Y-%m-%dT%H:%MZ")


def minute_start(ts):
    """The start of the UTC minute holding `ts`."""
    return float(int(ts // 60) * 60)


def next_hour(ts):
    """The first UTC hour boundary strictly after `ts`."""
    return float((int(ts // 3600) + 1) * 3600)


def weekday_hour(ts):
    """(weekday, hour) of `ts` in UTC; Monday is 0."""
    dt = datetime.datetime.fromtimestamp(ts, UTC)
    return dt.weekday(), dt.hour
