"""The scheduler's log: one append-only file, one event a line (capture W1
item 7, W1-y).

Every line is `<UTC instant> <event>` then `name=value` fields. A value
holding a space, a quote, a backslash or an equals sign is quoted (`"..."`,
with `\\"` and `\\\\` escaped) and is the line's last field; control
characters become spaces. The log names keys, jobs and connections, never
rates or shapes.
"""

import os
import sys
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


class Log:
    """Appends lines to the log file, flushed at each line. Lines that
    cannot be written go to standard error (the container's log)."""

    def __init__(self, path):
        self.path = path
        self._file = None

    def _open(self):
        if self._file is None and self.path:
            fd = os.open(self.path, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW, 0o640)
            self._file = os.fdopen(fd, "a", encoding="utf-8", errors="replace")
        return self._file

    def write(self, event, *fields, ts=None):
        line = format_line(time.time() if ts is None else ts, event, fields)
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
        if self._file is not None:
            self._file.close()
            self._file = None
