"""Plant a fault's overlay on a copy of its fixture (v0.5 capture W5 item 0
of specs/versions/v0.5/wave-log.md): a fixture keeps its committed files
unfaulted, so its own short test stands; a fault's short test plants on a
copy, from the overlay committed in the fixture under planted/<fault-id>/.
The loader never reads planted/.

An overlay holds:
- scenario.yaml, a fragment: `fault_instances:` and `issues:` appended to
  the copy's lists (each optional), `difficulty.score` then set to the
  number of fault instances (master spec 15.1);
- answer-key.yaml, a fragment: `instances:`, `tooling_expectations:` and
  `false_alarms:` appended to the copy's gm/answer-key.yaml (each optional);
- any other file, at its scenario path (a seed change in a composed node's
  scenario layer, compose/<node>/...; a player/ file), copied over the
  copy's.

`merge(copy_dir, overlay_dir)` plants it and removes planted/ from the copy;
the copy's YAML is rewritten by PyYAML (comments dropped) and its README is
not regenerated (no commit). A composed node's layer changed, the caller
reruns `gmctl compose` on the copy.

Also a tiny unified-diff applier for a fault's `material` written as a diff
(the edit alone, W5 item 0): `apply_diff(text, diff)` finds each hunk's old
lines (context and removed) once in `text` and replaces them, so two faults'
diffs of one file apply in either order when their hunks do not overlap.

Usage: python3 tools/tests/planted.py <copy dir> <overlay dir>
"""

import shutil
import sys
from pathlib import Path

import yaml

FRAGMENTS = {"scenario.yaml": ("scenario.yaml", ("fault_instances", "issues")),
             "answer-key.yaml": ("gm/answer-key.yaml",
                                 ("instances", "tooling_expectations", "false_alarms"))}


class PlantError(Exception):
    pass


def _merge_lists(target, fragment, keys, label):
    data = yaml.safe_load(target.read_text())
    frag = yaml.safe_load(fragment.read_text()) or {}
    unknown = sorted(set(frag) - set(keys))
    if unknown:
        raise PlantError(f"{label}: keys {unknown} are not appended by an overlay ({', '.join(keys)})")
    for key in keys:
        if key in frag:
            if not isinstance(frag[key], list):
                raise PlantError(f"{label}: {key}: not a list")
            data[key] = list(data.get(key) or []) + frag[key]
    return data


def merge(copy_dir, overlay_dir):
    copy_dir, overlay_dir = Path(copy_dir), Path(overlay_dir)
    if not overlay_dir.is_dir():
        raise PlantError(f"{overlay_dir}: no overlay")
    for path in sorted(p for p in overlay_dir.rglob("*") if p.is_file()):
        rel = path.relative_to(overlay_dir).as_posix()
        if rel in FRAGMENTS:
            target_rel, keys = FRAGMENTS[rel]
            target = copy_dir / target_rel
            data = _merge_lists(target, path, keys, f"{overlay_dir.name}/{rel}")
            if rel == "scenario.yaml":
                data.setdefault("difficulty", {})["score"] = len(data.get("fault_instances") or [])
            target.write_text(yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=100))
        else:
            target = copy_dir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    shutil.rmtree(copy_dir / "planted", ignore_errors=True)


def _hunks(diff):
    hunks, cur = [], None
    for line in diff.splitlines(keepends=True):
        if line.startswith(("--- ", "+++ ")) and cur is None:
            continue
        if line.startswith("@@"):
            cur = ([], [])
            hunks.append(cur)
        elif cur is not None and line[:1] in (" ", "-", "+"):
            body = line[1:]
            if line[0] in " -":
                cur[0].append(body)
            if line[0] in " +":
                cur[1].append(body)
        elif cur is not None and line.startswith("\\"):
            continue
        elif line.strip():
            raise PlantError(f"not a unified diff line: {line!r}")
    if not hunks:
        raise PlantError("no hunk in the diff")
    return hunks


def apply_diff(text, diff):
    """`text` with each hunk of the unified `diff` applied, each hunk's old
    lines found exactly once."""
    lines = text.splitlines(keepends=True)
    for old, new in _hunks(diff):
        found = [i for i in range(len(lines) - len(old) + 1) if lines[i:i + len(old)] == old]
        if len(found) != 1:
            raise PlantError(f"a hunk's {len(old)} old lines found {len(found)} times, not once: "
                             f"{''.join(old)[:120]!r}")
        i = found[0]
        lines[i:i + len(old)] = new
    return "".join(lines)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__.rsplit("Usage: ", 1)[1].strip())
    try:
        merge(sys.argv[1], sys.argv[2])
    except (PlantError, OSError, yaml.YAMLError) as exc:
        sys.exit(f"planted: {exc}")
