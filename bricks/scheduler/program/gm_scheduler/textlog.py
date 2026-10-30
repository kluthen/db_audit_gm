"""The scheduler's log: one append-only file, one event a line (capture W1
item 7, W1-y).

Every line is `<UTC instant> <event>` then `name=value` fields. A value
holding a space, a quote, a backslash or an equals sign is quoted (`"..."`,
with `\\"` and `\\\\` escaped) and is the line's last field; control
characters become spaces. The log names keys, jobs and connections, never
rates or shapes.

One event has free text instead: `<UTC instant> script job=<name> <text>`,
what a transformer script passed to `log(text)` (master spec 7.1),
control characters as spaces. A reader takes the event from the second
word only (parse_line), so a script's text never passes for another
event; `completed_runs` and `last_reload` are what a purpose check reads
(master spec 12.1, 12.2; /usr/local/lib/gm/check-runs).
"""

import os
import re
import sys
import threading
import time

from .timeutil import instant

_PLAIN = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-:/+,@%[]()")


def format_value(value):
    text = "-" if value is None else str(value)
    text = "".join(" " if ord(c) < 32 or ord(c) == 127 else c for c in text)
    if text and all(c in _PLAIN for c in text):
        return text, False
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"', True


def format_line(ts, event, fields):
    """`fields`: (name, value) pairs in order; at most one value may need
    quoting, and it must be last (the caller puts free text last)."""
    parts = [instant(ts), event]
    quoted_seen = False
    for name, value in fields:
        text, quoted = format_value(value)
        if quoted_seen:
            raise ValueError(f"log field {name} after a quoted field")
        quoted_seen = quoted
        parts.append(f"{name}={text}")
    return " ".join(parts)


def clean_text(text):
    return "".join(" " if ord(c) < 32 or ord(c) == 127 else c for c in str(text))


def script_line(ts, job, text):
    return f"{instant(ts)} script job={job} {clean_text(text)}"


_LINE_RE = re.compile(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z) ([a-z]+)(?: (.*))?$")
_FIELD_RE = re.compile(r"([a-z0-9_]+)=")


def parse_line(line):
    """A log line -> (instant, event, {name: value}, text), or None for a
    line not of the log's grammar. `text` is a `script` line's free text
    (None for every other event, whose fields are all parsed)."""
    m = _LINE_RE.match(line.rstrip("\n"))
    if not m:
        return None
    at, event, rest = m.group(1), m.group(2), m.group(3) or ""
    if event == "script":
        job, _, text = rest.partition(" ")
        if not job.startswith("job="):
            return None
        return at, event, {"job": job[4:]}, text
    fields, i = {}, 0
    while i < len(rest):
        f = _FIELD_RE.match(rest, i)
        if not f:
            return None
        name, i = f.group(1), f.end()
        if rest.startswith('"', i):
            body = rest[i + 1:]
            if not body.endswith('"'):
                return None
            fields[name] = re.sub(r"\\(.)", r"\1", body[:-1])
            break
        end = rest.find(" ", i)
        end = len(rest) if end < 0 else end
        fields[name] = rest[i:end]
        i = end + 1
    return at, event, fields, None


def read_events(path):
    """The log's lines, parsed (lines not of the grammar skipped)."""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if parsed is not None:
                yield parsed


def completed_runs(path, job, since):
    """The runs of `job` whose `run ... phase=end status=ok` line is after
    `since` (an instant, YYYY-MM-DDTHH:MM:SSZ): [(start instant or None,
    end instant, rows, ms)], in order. The start is the job's previous
    `phase=start` line (runs of one job never overlap)."""
    out, start = [], None
    for at, event, fields, _ in read_events(path):
        if event != "run" or fields.get("job") != job:
            continue
        if fields.get("phase") == "start":
            start = at
        elif fields.get("phase") == "end":
            if fields.get("status") == "ok" and at > since:
                out.append((start, at, fields.get("rows"), fields.get("ms")))
            start = None
    return out


def last_reload(path):
    """The instant of the log's last `reload status=ok` line, or None."""
    last = None
    for at, event, fields, _ in read_events(path):
        if event == "reload" and fields.get("status") == "ok":
            last = at
    return last


class Log:
    """Appends lines to the log file, flushed at each line. Lines that
    cannot be written go to standard error (the container's log). Safe to
    call from a script's worker thread."""

    def __init__(self, path):
        self.path = path
        self._file = None
        self._lock = threading.Lock()

    def _open(self):
        if self._file is None and self.path:
            fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o640)
            self._file = os.fdopen(fd, "a", encoding="utf-8", errors="replace")
        return self._file

    def write(self, event, *fields, ts=None):
        return self._append(format_line(time.time() if ts is None else ts, event, fields))

    def write_script(self, job, text, ts=None):
        """A script's `log(text)`: `script job=<name> <text>`."""
        return self._append(script_line(time.time() if ts is None else ts, job, text))

    def _append(self, line):
        with self._lock:
            try:
                f = self._open()
                if f is None:
                    raise OSError("no log path")
                f.write(line + "\n")
                f.flush()
            except OSError as exc:
                print(f"gm-scheduler: cannot write the log ({exc}): {line}", file=sys.stderr, flush=True)
        return line

    def close(self):
        with self._lock:
            if self._file is not None:
                self._file.close()
                self._file = None
