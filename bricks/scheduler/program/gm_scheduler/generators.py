"""Parameter generators (master spec 7.1; forms: capture W1 item 7).

    {int: [lo, hi]}              an integer, lo <= n <= hi
    {decimal: [lo, hi, places]}  a decimal in [lo, hi] with `places` digits
    {choice: [v, ...]}           one of the values
    {sequence: [start, step]}    start, start + step, ... (never reused, below)
    {now: utc}                   the current time, a timestamp with time zone

Any other value (a string, a number, a boolean, null) is a constant.

A sequence never gives a value twice, a restart included: its position is
reserved in blocks of `SEQUENCE_BLOCK` values in a state file, so a program
that resumes skips the rest of the block it was using, as a database
sequence's cache does.
"""

import datetime
import decimal
import json
import os

from . import ConfigError

SEQUENCE_BLOCK = 1000
GENERATOR_NAMES = ("int", "decimal", "choice", "sequence", "now")


def _number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _integer(v):
    return isinstance(v, int) and not isinstance(v, bool)


class Generator:
    def __init__(self, kind, args, ident):
        self.kind, self.args, self.ident = kind, args, ident

    def draw(self, rng, ctx):
        kind, a = self.kind, self.args
        if kind == "const":
            return a
        if kind == "int":
            return rng.randint(a[0], a[1])
        if kind == "decimal":
            lo, hi, places = a
            quantum = decimal.Decimal(1).scaleb(-places)
            value = decimal.Decimal(repr(rng.uniform(lo, hi))).quantize(quantum, rounding=decimal.ROUND_HALF_EVEN)
            return min(max(value, decimal.Decimal(repr(lo)).quantize(quantum)),
                       decimal.Decimal(repr(hi)).quantize(quantum))
        if kind == "choice":
            return a[rng.randrange(len(a))]
        if kind == "sequence":
            start, step = a
            return start + step * ctx.sequences.next(self.ident)
        if kind == "now":
            return datetime.datetime.fromtimestamp(ctx.now(), datetime.timezone.utc)
        raise AssertionError(kind)


def compile_param(value, where, ident):
    """A params value -> a Generator; raises ConfigError naming `where`."""
    if not isinstance(value, dict):
        if isinstance(value, (list, tuple)):
            raise ConfigError(f"{where}: a list is not a parameter; use {{choice: [...]}}")
        return Generator("const", value, ident)
    if len(value) != 1:
        raise ConfigError(f"{where}: a generator is a map with one key, one of {', '.join(GENERATOR_NAMES)}")
    (kind, args), = value.items()
    if kind == "int":
        if not (isinstance(args, list) and len(args) == 2 and all(_integer(x) for x in args) and args[0] <= args[1]):
            raise ConfigError(f"{where}: int takes [lo, hi], two integers, lo <= hi")
        return Generator(kind, tuple(args), ident)
    if kind == "decimal":
        if not (isinstance(args, list) and len(args) == 3 and _number(args[0]) and _number(args[1])
                and args[0] <= args[1] and _integer(args[2]) and 0 <= args[2] <= 12):
            raise ConfigError(f"{where}: decimal takes [lo, hi, places], lo <= hi, 0 <= places <= 12")
        return Generator(kind, tuple(args), ident)
    if kind == "choice":
        if not (isinstance(args, list) and args):
            raise ConfigError(f"{where}: choice takes a non-empty list")
        return Generator(kind, tuple(args), ident)
    if kind == "sequence":
        if not (isinstance(args, list) and len(args) == 2 and all(_integer(x) for x in args) and args[1] != 0):
            raise ConfigError(f"{where}: sequence takes [start, step], two integers, step not 0")
        return Generator(kind, tuple(args), ident)
    if kind == "now":
        if args != "utc":
            raise ConfigError(f"{where}: now takes utc ({{now: utc}})")
        return Generator(kind, args, ident)
    raise ConfigError(f"{where}: unknown generator {kind!r}; one of {', '.join(GENERATOR_NAMES)}")


def compile_params(params, where, ident):
    if params is None:
        return {}
    if not isinstance(params, dict):
        raise ConfigError(f"{where}: params is a map of name -> generator")
    out = {}
    for name, value in params.items():
        if not isinstance(name, str) or not name:
            raise ConfigError(f"{where}: a parameter name is a non-empty string (quote a name YAML reads "
                              "as a boolean or a number: no, yes, on, off)")
        out[name] = compile_param(value, f"{where}.{name}", f"{ident}.{name}")
    return out


def draw_params(compiled, rng, ctx):
    return {name: g.draw(rng, ctx) for name, g in compiled.items()}


class Sequences:
    """Sequence positions, reserved in blocks in `path` (None: in memory
    only, for the checks)."""

    def __init__(self, path=None, block=SEQUENCE_BLOCK):
        self.path, self.block = path, block
        self.reserved = {}
        self.position = {}
        if path and os.path.exists(path):
            try:
                with open(path, encoding="utf-8") as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    self.reserved = {k: int(v) for k, v in data.items() if _integer(v)}
            except (OSError, ValueError):
                self.reserved = {}
        # a resuming program starts at the next block of each sequence
        self.position = dict(self.reserved)

    def next(self, ident):
        n = self.position.get(ident, 0)
        if n >= self.reserved.get(ident, 0):
            self.reserved[ident] = n + self.block
            self._save()
        self.position[ident] = n + 1
        return n

    def _save(self):
        if not self.path:
            return
        tmp = f"{self.path}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.reserved, f, sort_keys=True)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self.path)
