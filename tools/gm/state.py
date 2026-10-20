"""The game's recorded state: `gmctl status`, and setup failures.

Master spec 11 (`status`) and 12 ("Failures"). `state.yaml` itself (stage,
history, failure; capture W2-A) is read and written by `localimpl`; this
module adds what a setup step needs: if the step fails, or anyone stops it,
what it deployed is torn down and the failure is recorded with its reason.
"""

import contextlib

from . import localimpl
from .model import GmError

# Stages at which the game holds objects on the swarm.
DEPLOYED_STAGES = ("deployed", "data-loaded", "injected", "handed-over", "final-answer",
                   "feedback-given")


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
    lines.append("  history:")
    for entry in state.get("history") or []:
        lines.append(f"    {entry.get('at')}  {entry.get('stage')}")
    if localimpl.effective_stage(state) in DEPLOYED_STAGES \
            and state.get("stage") != localimpl.FAILED:
        lines.append(f"  credentials: {localimpl.secrets_dir(ldir)}/ (not printed)")
    return "\n".join(lines)
