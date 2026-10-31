"""The governance check set's GM side (v0.4 master spec 11.6; capture W3-a
of specs/versions/v0.4/wave-log.md, items 1 to 3; spec D230, D231).

The set itself is `governance.sh`, POSIX shell defining `check_governance`
and its helpers, its SQL inside. `gmctl check` streams a check's text into
`sh -s` on its instance's node, and nothing else of the GM's is there at
check time, so a sealed check calling the set is sent as `governance.sh`,
a newline, then its script (`check_text`), with the scenario's rules in
`CHECK_GOVERNANCE` (`env_value`). The call is the declaration: a script
containing `check_governance` (`uses_governance`); every other check is
sent byte for byte as before. `checks.check_plan` applies both, so the
early and the hand-over checks pass through it too.

`CHECK_GOVERNANCE` is one line of JSON, keys sorted: `classes`
(`governance.classes` as written, a missing `internal` as `{"locations":
"any"}`), `columns` (the classification's entries but `internal`),
`database_nodes` and `transformer_nodes` (topology order), `own_roles`
(`model.RESERVED_DB_ROLES`: skipped as readers only, spec D230).

`python3 -B -m tools.gm.governance env <scenario-dir>` prints the value;
`python3 -B -m tools.gm.governance text <script-file>` the text sent for a
script (`-`: standard input). The harness `tools/tests/check-governance.sh`
uses both.
"""

import json
import sys
from pathlib import Path

from . import model
from .model import GmError

SCRIPT = Path(__file__).resolve().with_name("governance.sh")
CALL = "check_governance"
ENV = "CHECK_GOVERNANCE"
RULES = ("G1", "G2", "G3", "G4")


def uses_governance(script_text):
    """Whether a check's script calls the set (W3-a item 1: the call is the
    declaration)."""
    return CALL in script_text


def check_text(script_text):
    """The text sent for a script calling the set: governance.sh, a
    newline, then the script."""
    try:
        head = SCRIPT.read_text(encoding="utf-8")
    except OSError as exc:
        raise GmError(f"the governance check set {SCRIPT}: cannot be read: "
                      f"{exc.strerror}") from None
    return head + "\n" + script_text


def _classification(scenario):
    gov = scenario.data.get("governance") or {}
    rel = gov.get("classification")
    path = scenario.dir / str(rel)
    try:
        import yaml
        with open(path, encoding="utf-8") as fh:
            content = yaml.safe_load(fh) or {}
    except (OSError, ValueError) as exc:
        raise GmError(f"governance.classification {rel}: cannot be read: {exc}") from None
    columns = content.get("columns") if isinstance(content, dict) else None
    if not isinstance(columns, dict):
        raise GmError(f"governance.classification {rel}: no columns")
    return columns


def env_value(scenario):
    """CHECK_GOVERNANCE for a loaded scenario (W3-a item 3); GmError for a
    scenario without governance:."""
    gov = scenario.data.get("governance")
    if not isinstance(gov, dict):
        raise GmError(f"scenario {scenario.id} has no governance: the governance check set "
                      "has nothing to judge against")
    classes = dict(gov.get("classes") or {})
    classes.setdefault(model.UNRESTRICTED_CLASS, {"locations": "any"})
    columns = {key: cls for key, cls in _classification(scenario).items()
               if cls != model.UNRESTRICTED_CLASS}
    value = {
        "classes": classes,
        "columns": columns,
        "database_nodes": [n["name"] for n in scenario.nodes if n.get("role") == "database"],
        "transformer_nodes": [n["name"] for n in scenario.nodes
                              if n.get("role") == "transformer"],
        "own_roles": list(model.RESERVED_DB_ROLES),
    }
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def main(argv):
    usage = ("usage: python3 -B -m tools.gm.governance env <scenario-dir> | "
             "text <script-file|->")
    if len(argv) != 2 or argv[0] not in ("env", "text"):
        print(usage, file=sys.stderr)
        return 2
    try:
        if argv[0] == "env":
            print(env_value(model.load_scenario(argv[1])))
        else:
            script = sys.stdin.read() if argv[1] == "-" else \
                Path(argv[1]).read_text(encoding="utf-8")
            sys.stdout.write(check_text(script))
    except (GmError, OSError) as exc:
        print(f"governance: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
