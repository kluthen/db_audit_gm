"""Per-key counters: the minute summaries of the log and the metrics
endpoint (master spec 7.1; capture W1 item 7; names: W1-y).

A call counts in the UTC minute it ends in. A key appears in a minute's
summary when a stream had it as its key during that minute (zeros
included) or a call of it ended in that minute (a job's run included).

Endpoint: HTTP on port 9120, `GET /metrics`, Prometheus text format 0.0.4:

    scheduler_calls_total{key}                  calls ended, failed ones included
    scheduler_errors_total{key}                 calls that failed
    scheduler_call_duration_seconds{key}        histogram of call latencies
    scheduler_job_runs_total{key,job}           fixed-time runs started
    scheduler_job_skips_total{key,job,reason}   runs skipped (still-running, connection-refused)
    scheduler_running                           1 running its schedule, 0 idle
    scheduler_start_time_seconds                when the program started
"""

import asyncio
import math

from .timeutil import minute_label, minute_start

BUCKETS = (0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0)


def percentile(sorted_values, p):
    """Nearest rank: the smallest value with at least p% of the values at
    or below it."""
    if not sorted_values:
        return None
    rank = max(1, math.ceil(p / 100.0 * len(sorted_values)))
    return sorted_values[rank - 1]


def fmt_ms(seconds):
    return "-" if seconds is None else f"{seconds * 1000:.1f}"


def _label(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def _num(v):
    if isinstance(v, float):
        if math.isinf(v):
            return "+Inf"
        return repr(v)
    return str(v)


class KeyTotals:
    def __init__(self):
        self.calls = 0
        self.errors = 0
        self.sum = 0.0
        self.buckets = [0] * len(BUCKETS)


class Stats:
    def __init__(self):
        self.totals = {}
        self.minutes = {}       # minute start -> {key: [calls, errors, [latencies]]}
        self.touched = {}       # minute start -> {keys}
        self.job_runs = {}      # (key, job) -> n
        self.job_skips = {}     # (key, job, reason) -> n
        self.running = 0
        self.start_time = 0.0

    def declare(self, key):
        """Makes `key`'s series exist (at zero) before its first call."""
        self.totals.setdefault(key, KeyTotals())

    def touch(self, keys, ts):
        m = minute_start(ts)
        self.touched.setdefault(m, set()).update(keys)
        for k in keys:
            self.declare(k)

    def record(self, key, latency, error, ts):
        t = self.totals.setdefault(key, KeyTotals())
        t.calls += 1
        t.errors += 1 if error else 0
        t.sum += latency
        for i, b in enumerate(BUCKETS):
            if latency <= b:
                t.buckets[i] += 1
        m = self.minutes.setdefault(minute_start(ts), {}).setdefault(key, [0, 0, []])
        m[0] += 1
        m[1] += 1 if error else 0
        m[2].append(latency)

    def job_run(self, key, job):
        self.declare(key)
        self.job_runs[(key, job)] = self.job_runs.get((key, job), 0) + 1

    def job_skip(self, key, job, reason):
        self.declare(key)
        self.job_skips[(key, job, reason)] = self.job_skips.get((key, job, reason), 0) + 1

    def summary(self, minute):
        """The `summary` and `key` lines of `minute` (its start), as
        (event, fields) pairs, and forgets the minute."""
        per_key = self.minutes.pop(minute, {})
        keys = set(per_key) | self.touched.pop(minute, set())
        for old in [m for m in self.minutes if m < minute]:
            del self.minutes[old]
        for old in [m for m in self.touched if m < minute]:
            del self.touched[old]
        label = minute_label(minute)
        total_calls = sum(v[0] for v in per_key.values())
        total_errors = sum(v[1] for v in per_key.values())
        lines = [("summary", [("minute", label), ("keys", len(keys)),
                              ("calls", total_calls), ("errors", total_errors)])]
        for key in sorted(keys):
            calls, errors, lat = per_key.get(key, [0, 0, []])
            lat = sorted(lat)
            lines.append(("key", [("minute", label), ("key", key), ("calls", calls), ("errors", errors),
                                  ("p50_ms", fmt_ms(percentile(lat, 50))),
                                  ("p95_ms", fmt_ms(percentile(lat, 95))),
                                  ("p99_ms", fmt_ms(percentile(lat, 99)))]))
        return lines

    def prometheus(self):
        out = []

        def family(name, kind, help_text):
            out.append(f"# HELP {name} {help_text}")
            out.append(f"# TYPE {name} {kind}")

        keys = sorted(self.totals)
        family("scheduler_calls_total", "counter", "Calls ended, per repository key, failed ones included.")
        for k in keys:
            out.append(f'scheduler_calls_total{{key="{_label(k)}"}} {self.totals[k].calls}')
        family("scheduler_errors_total", "counter", "Calls that failed, per repository key.")
        for k in keys:
            out.append(f'scheduler_errors_total{{key="{_label(k)}"}} {self.totals[k].errors}')
        family("scheduler_call_duration_seconds", "histogram", "Call latency, per repository key.")
        for k in keys:
            t = self.totals[k]
            for b, n in zip(BUCKETS, t.buckets):
                out.append(f'scheduler_call_duration_seconds_bucket{{key="{_label(k)}",le="{_num(b)}"}} {n}')
            out.append(f'scheduler_call_duration_seconds_bucket{{key="{_label(k)}",le="+Inf"}} {t.calls}')
            out.append(f'scheduler_call_duration_seconds_sum{{key="{_label(k)}"}} {_num(float(t.sum))}')
            out.append(f'scheduler_call_duration_seconds_count{{key="{_label(k)}"}} {t.calls}')
        family("scheduler_job_runs_total", "counter", "Fixed-time runs started.")
        for (k, j), n in sorted(self.job_runs.items()):
            out.append(f'scheduler_job_runs_total{{key="{_label(k)}",job="{_label(j)}"}} {n}')
        family("scheduler_job_skips_total", "counter", "Fixed-time runs skipped, by reason.")
        for (k, j, r), n in sorted(self.job_skips.items()):
            out.append(f'scheduler_job_skips_total{{key="{_label(k)}",job="{_label(j)}",reason="{_label(r)}"}} {n}')
        family("scheduler_running", "gauge", "1 when the scheduler runs its schedule, 0 when idle.")
        out.append(f"scheduler_running {self.running}")
        family("scheduler_start_time_seconds", "gauge", "When the scheduler program started, seconds since the epoch.")
        out.append(f"scheduler_start_time_seconds {_num(float(self.start_time))}")
        return "\n".join(out) + "\n"


async def serve_metrics(stats, host, port, path="/metrics"):
    """An HTTP/1.0-style endpoint: `GET <path>` -> 200 with the metrics,
    anything else 404 or 405; one request per connection."""

    async def handle(reader, writer):
        try:
            line = await asyncio.wait_for(reader.readline(), 10)
            while True:
                header = await asyncio.wait_for(reader.readline(), 10)
                if header in (b"\r\n", b"\n", b""):
                    break
            parts = line.decode("latin-1").split()
            if len(parts) >= 2 and parts[0] in ("GET", "HEAD") and parts[1].split("?", 1)[0] == path:
                body = stats.prometheus().encode()
                head = (f"HTTP/1.0 200 OK\r\nContent-Type: text/plain; version=0.0.4; charset=utf-8\r\n"
                        f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n").encode()
                writer.write(head + (body if parts[0] == "GET" else b""))
            elif len(parts) >= 2 and parts[0] not in ("GET", "HEAD"):
                writer.write(b"HTTP/1.0 405 Method Not Allowed\r\nAllow: GET\r\nContent-Length: 0\r\n\r\n")
            else:
                writer.write(b"HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 10\r\n\r\nnot found\n")
            await writer.drain()
        except (asyncio.TimeoutError, ConnectionError, OSError):
            pass
        finally:
            writer.close()

    return await asyncio.start_server(handle, host, port, reuse_address=True)
