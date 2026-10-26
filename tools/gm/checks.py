"""`gmctl validate` and `gmctl check`: the evaluation's live evidence.

Master spec 13 ("Evaluation": the official validator run and the sealed
checks, before teardown), 11, and 8.1 (exit-code contracts); behaviour
fixed by capture W3-A (`specs/versions/v0.1/wave-log.md`). Neither changes
the game's stage.

- `validate`, at every deployed stage: each node, in `nodes` order, runs
  its brick's public validator, `extra.validator: {path, run_as}` in
  `brick.yaml`, started through `exec_node` as `exec <path>` on `sh -s`.
  Its lines are printed under a `<node>:` heading. Exit 0 when every node
  is green, 1 when any is red and none errored, 2 when any errored or could
  not be started.
- `check`, at `injected` and every later deployed stage: each fault
  instance, in `fault_instances` order, runs its fault's
  `sealed_check.script` on its node as `sealed_check.run_as` (default
  root) with its `FAULT_*` variables, and, for a behavioural check, the
  answer key's `window` in seconds as `CHECK_WINDOW_SECONDS` and its
  `threshold` as `CHECK_THRESHOLD` (v0.3 W1 item 4, spec D165). It prints
  one line, `<instance> <fault-id>: fixed|present|error — <first output
  line>`, or `<instance> <fault-id>: too-soon — <N> s of the window
  remain: <free text>` for an exit 3 whose first output line reads
  `remaining=<N>[ <free text>]` (v0.3 capture W2, item 9; master spec 11,
  rule 3); an exit 3 without that line is an error. Exit 2 when any
  errored, else 1 when any is present, else 3 when any is too soon, else
  0. A database check connects as the GM check role through its node's
  `check-psql` (W1 item 8, W1-x); `check` itself runs the scripts one at
  a time.

A refusal (no game, a stage that does not allow the run, a required
parameter without a value) runs nothing; the command line exits 2 for it,
the result being unknown.
"""

import re
import shlex
from dataclasses import dataclass, field

from . import localimpl, model, state
from .docker import for_local_dir
from .execnode import exec_node
from .inject import DEFAULT_RUN_AS, INJECT_STAGE, fault_env, fault_instances, node_of, \
    output_lines
from .model import GmError

GREEN, RED, ERROR = 0, 1, 2
FIXED, PRESENT, TOO_SOON = 0, 1, 3
_REMAINING_RE = re.compile(r"^remaining=([0-9]+)(?: (.*))?$")
CHECK_STAGES = state.DEPLOYED_STAGES[state.DEPLOYED_STAGES.index(INJECT_STAGE):]


def _deployed_game(scenario_dir, playground, allowed, what):
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    if st.get("stage") not in allowed:
        raise GmError(f"game {st.get('game_id')} is at stage {st.get('stage')}; {what} needs "
                      f"stage {' or '.join(allowed)}")
    return ldir, localimpl.read_implementation(ldir)


def _verdict(returncode, labels):
    return labels.get(returncode, "error")


def _exit_code(verdicts, bad):
    """2 when any errored, else 1 when any is `bad`, else 0."""
    if "error" in verdicts:
        return ERROR
    return RED if bad in verdicts else GREEN


# --- validate ------------------------------------------------------------------

@dataclass
class NodeValidation:
    node: str
    verdict: str                    # green | red | error
    lines: list = field(default_factory=list)


@dataclass
class ValidateResult:
    game_id: str
    nodes: list = field(default_factory=list)

    @property
    def exit_code(self):
        return _exit_code([n.verdict for n in self.nodes], "red")

    def text(self):
        out = []
        for node in self.nodes:
            out.append(f"{node.node}:")
            out += [f"  {line}" for line in node.lines]
        out.append(f"Validators of game {self.game_id}: "
                   + ", ".join(f"{n.node} {n.verdict}" for n in self.nodes) + ".")
        return "\n".join(out)


def validator_of(brick):
    """The brick's `extra.validator` as (path, run_as); GmError if it has none."""
    spec = (brick.data.get("extra") or {}).get("validator")
    if not isinstance(spec, dict) or not spec.get("path") or not spec.get("run_as"):
        raise GmError(f"brick {brick.id} {brick.version} declares no extra.validator "
                      "{path, run_as}")
    return str(spec["path"]), str(spec["run_as"])


def validate(scenario_dir, playground, docker=None):
    """`gmctl validate`; returns a ValidateResult (its `exit_code` is the
    command's). Raises GmError on a refusal (nothing run)."""
    ldir, impl = _deployed_game(scenario_dir, playground, state.DEPLOYED_STAGES, "validate")
    scenario = model.load_scenario(scenario_dir)
    docker = docker or for_local_dir(ldir)
    result = ValidateResult(impl["game_id"])
    labels = {GREEN: "green", RED: "red"}
    for node in scenario.nodes:
        name = node["name"]
        try:
            path, run_as = validator_of(scenario.bricks[name])
            run = exec_node(ldir, name, run_as, stdin=f"exec {shlex.quote(path)}\n",
                            docker=docker)
        except GmError as exc:
            result.nodes.append(NodeValidation(name, "error", [f"ERROR: the validator could "
                                                               f"not be started: {exc}"]))
            continue
        lines = output_lines(run)
        verdict = _verdict(run.returncode, labels)
        if verdict == "error":
            lines.append(f"(validator exit status {run.returncode})")
        result.nodes.append(NodeValidation(name, verdict, lines))
    return result


# --- check ---------------------------------------------------------------------

@dataclass
class CheckLine:
    instance: str
    fault_id: str
    verdict: str                    # fixed | present | too-soon | error
    reason: str                     # too-soon: the free text after remaining=<N>
    returncode: int = None          # the script's exit; None when it could not start
    remaining: int = None           # too-soon only: seconds of the window left

    def text(self):
        if self.verdict == "too-soon":
            head = f"{self.instance} {self.fault_id}: too-soon — {self.remaining} s of the " \
                   "window remain"
            return f"{head}: {self.reason}" if self.reason else head
        return f"{self.instance} {self.fault_id}: {self.verdict} — {self.reason}"


@dataclass
class CheckResult:
    game_id: str
    lines: list = field(default_factory=list)

    @property
    def exit_code(self):
        """2 when any errored, else 1 when any is present, else 3 when any
        is too soon, else 0 (W2 item 9: a definite answer outranks an
        undetermined one)."""
        verdicts = [line.verdict for line in self.lines]
        if "error" in verdicts:
            return ERROR
        if "present" in verdicts:
            return RED
        return TOO_SOON if "too-soon" in verdicts else GREEN

    def text(self):
        if not self.lines:
            return f"Game {self.game_id}: no fault instance to check."
        return "\n".join(line.text() for line in self.lines)


def check_env(scenario, fault, instance):
    """The check's environment: the instance's `FAULT_*` variables, and for
    a behavioural check (the answer key's entry has them) its `window` in
    seconds as `CHECK_WINDOW_SECONDS` and its `threshold` as written as
    `CHECK_THRESHOLD` (W1 item 4, spec D165)."""
    env = fault_env(fault, instance)
    entries = (scenario.answer_key or {}).get("instances") or []
    entry = next((e for e in entries
                  if isinstance(e, dict) and e.get("instance") == instance.get("id")), {})
    sealed = entry.get("sealed_check") or {}
    if sealed.get("window") is not None:
        try:
            env["CHECK_WINDOW_SECONDS"] = str(model.parse_duration(sealed["window"]))
        except ValueError as exc:
            raise GmError(f"fault instance {instance.get('id')}: gm/answer-key.yaml "
                          f"sealed_check.window: {exc}") from None
    if sealed.get("threshold") is not None:
        env["CHECK_THRESHOLD"] = str(sealed["threshold"])
    return env


def check_plan(scenario, impl, instances=None):
    """[(instance, fault, node, run_as, env, script text)], in
    `fault_instances` order, every instance or those listed in `instances`;
    refuses (GmError) before anything runs."""
    pairs = fault_instances(scenario)
    if instances is not None:
        known = {inst["id"] for inst, _ in pairs}
        unknown = [iid for iid in instances if iid not in known]
        if unknown:
            raise GmError(f"not a fault instance of the scenario: {', '.join(unknown)}")
        pairs = [(inst, fault) for inst, fault in pairs if inst["id"] in instances]
    plan = []
    for inst, fault in pairs:
        sealed = fault.data.get("sealed_check") or {}
        node = node_of(inst, impl)
        env = check_env(scenario, fault, inst)
        try:
            text = (fault.dir / str(sealed.get("script"))).read_text(encoding="utf-8")
        except OSError as exc:
            raise GmError(f"fault {fault.id}: sealed check {sealed.get('script')}: cannot be "
                          f"read: {exc.strerror}") from None
        plan.append((inst["id"], fault, node, sealed.get("run_as") or DEFAULT_RUN_AS, env,
                     text))
    return plan


def read_check(iid, fault_id, returncode, lines):
    """One run's CheckLine: exit 0 fixed, 1 present, 3 with a first line
    `remaining=<N>[ <free text>]` (N >= 1) too soon, anything else an error
    (W2 item 9)."""
    first = lines[0] if lines else None
    if returncode == TOO_SOON:
        m = _REMAINING_RE.match(first or "")
        if m and int(m.group(1)) >= 1:
            return CheckLine(iid, fault_id, "too-soon", (m.group(2) or "").strip(),
                             returncode, int(m.group(1)))
        said = f": {first}" if first else ", no output"
        return CheckLine(iid, fault_id, "error",
                         f"exit status 3 (too soon) without a first line remaining=<N> "
                         f"(N seconds, at least 1){said}", returncode)
    verdict = _verdict(returncode, {FIXED: "fixed", PRESENT: "present"})
    reason = first or "no output"
    if verdict == "error" and first is None:
        reason = f"exit status {returncode}, no output"
    return CheckLine(iid, fault_id, verdict, reason, returncode)


def check(scenario_dir, playground, docker=None, instances=None):
    """`gmctl check`; returns a CheckResult (its `exit_code` is the
    command's). `instances`: the instance ids to run (in `fault_instances`
    order whatever their order here), None for all. Raises GmError on a
    refusal (nothing run)."""
    ldir, impl = _deployed_game(scenario_dir, playground, CHECK_STAGES, "check")
    scenario = model.load_scenario(scenario_dir)
    plan = check_plan(scenario, impl, instances)
    docker = docker or for_local_dir(ldir)
    result = CheckResult(impl["game_id"])
    for iid, fault, node, run_as, env, text in plan:
        try:
            run = exec_node(ldir, node, run_as, stdin=text, env=env, docker=docker)
        except GmError as exc:
            result.lines.append(CheckLine(iid, fault.id, "error",
                                          f"the check could not be started: {exc}"))
            continue
        result.lines.append(read_check(iid, fault.id, run.returncode, output_lines(run)))
    return result
