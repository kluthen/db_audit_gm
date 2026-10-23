"""Five-field numeric cron expressions, in a time zone `tzdata` names.

    minute hour day-of-month month day-of-week
    each a list of `*`, `N`, `A-B`, `*/S`, `A-B/S` or `N/S` (N to the end)

Day of week 0 to 7, 0 and 7 Sunday. When both day of month and day of
week are restricted, a day matching either runs (cron's rule). Names
(`mon`, `jan`) and `@` macros are not accepted (capture W1 item 7: the
program accepts any numeric 5-field cron).
"""

import datetime
import re
import zoneinfo

from . import ConfigError

UTC = datetime.timezone.utc
FIELDS = (("minute", 0, 59), ("hour", 0, 23), ("day of month", 1, 31), ("month", 1, 12), ("day of week", 0, 7))
_PART_RE = re.compile(r"^(\*|[0-9]+(?:-[0-9]+)?)(?:/([0-9]+))?$")
# a cron that has not fired in this many days never will (29 February, a Sunday: 28 years)
HORIZON_DAYS = 366 * 29


def _field(text, name, lo, hi):
    values = set()
    for part in text.split(","):
        m = _PART_RE.match(part)
        if not m:
            raise ConfigError(f"{name} field {text!r}: numbers, ranges, steps and * only")
        base, step = m.group(1), m.group(2)
        if base == "*":
            a, b = lo, hi
        elif "-" in base:
            a, b = (int(x) for x in base.split("-"))
        else:
            a = int(base)
            b = hi if step else a
        s = int(step) if step else 1
        if s < 1 or not (lo <= a <= hi and lo <= b <= hi) or a > b:
            raise ConfigError(f"{name} field {text!r}: out of {lo}-{hi}")
        values.update(range(a, b + 1, s))
    return frozenset(values)


class Cron:
    def __init__(self, expr, zone="UTC"):
        if not isinstance(expr, str):
            raise ConfigError("at: a cron expression in quotes, such as \"30 1 * * *\"")
        parts = expr.split()
        if len(parts) != 5:
            raise ConfigError(f"at {expr!r}: five fields, minute hour day-of-month month day-of-week")
        self.expr = expr
        fields = [_field(p, *spec) for p, spec in zip(parts, FIELDS)]
        self.minutes, self.hours, self.days, self.months, dow = fields
        self.weekdays = frozenset(0 if d == 7 else d for d in dow)  # 0 Sunday
        # a field beginning with * counts as unrestricted for the either-day rule, as in cron
        self.dom_any, self.dow_any = parts[2].startswith("*"), parts[4].startswith("*")
        self.zone_name = zone
        try:
            self.zone = UTC if zone in ("UTC", None) else zoneinfo.ZoneInfo(zone)
        except (zoneinfo.ZoneInfoNotFoundError, ValueError):
            raise ConfigError(f"timezone {zone!r}: not a zone tzdata names") from None

    def _day_matches(self, d):
        if d.month not in self.months:
            return False
        dom = d.day in self.days
        dow = (d.isoweekday() % 7) in self.weekdays
        if self.dom_any or self.dow_any:
            return dom and dow
        return dom or dow

    def next_after(self, ts):
        """The first run strictly after `ts` (seconds since the epoch), as
        seconds since the epoch; None when it never runs."""
        start = datetime.datetime.fromtimestamp(ts, UTC).astimezone(self.zone)
        day = start.date()
        hours, minutes = sorted(self.hours), sorted(self.minutes)
        for offset in range(HORIZON_DAYS):
            d = day + datetime.timedelta(days=offset)
            if not self._day_matches(d):
                continue
            for h in hours:
                for m in minutes:
                    local = datetime.datetime(d.year, d.month, d.day, h, m, tzinfo=self.zone)
                    when = local.timestamp()
                    if when > ts:
                        # a local time skipped by a clock change does not run
                        back = datetime.datetime.fromtimestamp(when, UTC).astimezone(self.zone)
                        if (back.hour, back.minute) == (h, m):
                            return when
        return None
