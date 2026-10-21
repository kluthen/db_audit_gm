"""The game's recorded state: `gmctl status`, setup failures, GM stages.

Master spec 11 (`status`) and 12 ("Failures"). `state.yaml` itself (stage,
history, failure, teardown record; capture W2-A, spec D50) is read and
written by `localimpl`; this
module adds what a setup step needs: if the step fails, or anyone stops it,
what it deployed is torn down and the failure is recorded with its reason.
It also records the stages no script reaches, which only the GM can tell
(`gmctl status --set`; spec D49, capture W3-A). `gmctl status` lists the
game's network and, once deployed, its secret files (v0.2 chunk 3).
"""

import contextlib

from . import localimpl
from .model import GmError

# Stages at which the game holds objects on the swarm.
DEPLOYED_STAGES = ("deployed", "data-loaded", "injected", "handed-over", "final-answer",
                   "feedback-given")

# Stages only the GM records (`status --set`), each with the stage it follows.
GM_STAGES = {"handed-over": "injected", "final-answer": "handed-over",
             "feedback-given": "final-answer"}


class SetupFailed(GmError):
    """A setup step failed; the failure is recorded in state.yaml."""

    def __init__(self, stage, reason, undone=None):
        self.stage = stage
        self.reason = reason
        self.undone = undone
        text = f"setup failed before stage {stage}: {reason}"
        if undone:
            text += f"\n{undone}"
        text += "\nRecorded in state.yaml (stage failed)."
        super().__init__(text)


def _reason(exc):
    if isinstance(exc, KeyboardInterrupt):
        return "stopped on request (interrupted)"
    text = " ".join(str(exc).split())
    return text or type(exc).__name__


@contextlib.contextmanager
def setup_step(ldir, stage, undo=None):
    """Run a setup step working towards `stage`.

    On any error, or an interruption, calls `undo()` (the teardown of what
    the setup deployed; its own failure is added to the reason), records the
    failure (`stage: failed`, `failure: {stage, reason, at}`), and raises
    SetupFailed. The caller records `stage` itself when the step succeeds.
    """
    try:
        yield
    except (Exception, KeyboardInterrupt) as exc:
        reason = _reason(exc)
        undone = None
        if undo is not None:
            try:
                undone = undo()
            except Exception as undo_exc:   # the teardown failed too: record both
                reason += f"; teardown after the failure also failed: {_reason(undo_exc)}"
        localimpl.set_failed(ldir, stage, reason)
        raise SetupFailed(stage, reason, undone) from exc


def set_gm_stage(ldir, stage):
    """`gmctl status --set <stage>`: record a stage only the GM can tell.

    `handed-over` follows `injected`, `final-answer` follows `handed-over`,
    `feedback-given` follows `final-answer`. Returns True when the stage was
    recorded, False when the game is already at it (nothing changed); raises
    GmError, state.yaml unchanged, for any other transition."""
    if stage not in GM_STAGES:
        raise GmError(f"--set {stage}: the GM records only {', '.join(GM_STAGES)}")
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game in {ldir}: run gmctl fit first")
    current = st.get("stage")
    if current == stage:
        return False
    if current != GM_STAGES[stage]:
        raise GmError(f"game {st.get('game_id')} is at stage {current}: {stage} can only "
                      f"follow {GM_STAGES[stage]}; nothing changed")
    localimpl.set_stage(ldir, stage)
    return True


def record_text(record):
    """A teardown record, readable (`status`, `teardown`)."""
    return (f"at {record.get('at')}, from stage {record.get('stage')}: "
            f"{record.get('reason') or 'no reason given'}")


def status_text(ldir):
    """`gmctl status`: the game's recorded state, readable."""
    state = localimpl.read_state(ldir)
    if state is None:
        raise GmError(f"no game in {ldir}: run gmctl fit first")
    pg = localimpl.read_playground(ldir) or {}
    lines = [f"Game {state.get('game_id')}",
             f"  playground: {pg.get('name', ldir.name)} "
             f"({pg.get('docker_endpoint') or 'local engine'})",
             f"  stage: {state.get('stage')}"]
    if state.get("stage") == localimpl.FAILED:
        lines[-1] += f" (last stage reached: {localimpl.effective_stage(state) or 'none'})"
    failure = state.get("failure")
    if failure:
        lines.append(f"  failure: before stage {failure.get('stage')}, at {failure.get('at')}: "
                     f"{failure.get('reason')}")
    record = localimpl.teardown_record(state)
    if record:
        lines.append(f"  torn down: {record_text(record)}")
    lines.append("  history:")
    for entry in state.get("history") or []:
        lines.append(f"    {entry.get('at')}  {entry.get('stage')}")
    impl = localimpl.read_yaml(ldir / localimpl.IMPLEMENTATION_FILE) or {}
    if impl.get("network"):
        lines.append(f"  network: {impl['network']}")
    if localimpl.effective_stage(state) in DEPLOYED_STAGES \
            and state.get("stage") != localimpl.FAILED:
        lines.append(f"  secrets: {localimpl.secrets_dir(ldir)}/ (mode 0600, not printed)")
        lines += [f"    {name}: {what}" for name, what in secret_files(impl)]
    return "\n".join(lines)


def secret_files(impl):
    """`[(file in secrets/, what it holds)]` for an implementation, in its
    order: a password (`handed over` when players type it), or one half of
    a key pair; a pair's two files are listed once, together."""
    out, seen = [], set()
    for sec in impl.get("secrets") or []:
        if sec.get("kind") == localimpl.KEY_PAIR:
            pair = sec.get("pair")
            files = [(pair, f"private key of pair {pair}"),
                     (pair + localimpl.PUBLIC_KEY_SUFFIX, f"public key of pair {pair}")]
        else:
            files = [(sec.get("secret"),
                      "password, handed over" if sec.get("handed_over") else "password")]
        for name, what in files:
            if name not in seen:
                seen.add(name)
                out.append((name, what))
    return out
